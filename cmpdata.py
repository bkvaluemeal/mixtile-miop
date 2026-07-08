#!/usr/bin/env python3
import subprocess, sys, re, os

KO_ORIG = "/root/ref"
KO_OURS = "/lib/miop"
SECS = [".data", ".rodata", ".data.once", ".data.dyndbg", ".rodata.str1.1"]

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout

def parse_sections(ko):
    out = run(f"readelf -S {ko}")
    secs = {}
    lines = out.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"\s*\[\s*(\d+)\]\s+(\S+)\s+(\S+)\s+([0-9a-f]+)\s+([0-9a-f]+)", lines[i])
        if m:
            nr, name, typ, addr, off = m.groups()
            # next line has Size EntSize ...
            if i+1 < len(lines):
                m2 = re.match(r"\s*([0-9a-f]+)\s+([0-9a-f]+)", lines[i+1])
                if m2:
                    size = int(m2.group(1),16)
                    secs[name] = {"off": int(off,16), "size": size, "nr": int(nr)}
        i += 1
    return secs

def parse_relocs(ko):
    out = run(f"readelf -r -W {ko}")
    relocs = {}
    cur = None
    for line in out.splitlines():
        m = re.match(r"Relocation section '\.rela(\S+)' at offset", line)
        if m:
            cur = "." + m.group(1); relocs.setdefault(cur, []); continue
        if cur is None: continue
        parts = line.split()
        if len(parts) < 5: continue
        try: off = int(parts[0], 16)
        except: continue
        tail = line.split(None, 4)
        if len(tail) < 5: continue
        relocs[cur].append((off, tail[4]))
    return relocs

def build_symmap(ko):
    out = run(f"readelf -s -W {ko}")
    secs = parse_sections(ko)
    nr2name = {v["nr"]: k for k,v in secs.items()}
    symmap = {}
    for line in out.splitlines():
        m = re.match(r"\s*\[\s*\d+\]\s+([0-9a-f]+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)", line)
        if not m: continue
        val, size, typ, bind, vis, ndx, name = m.groups()
        val = int(val,16)
        try: ndx_i = int(ndx)
        except: continue
        if ndx_i in nr2name and name:
            symmap[(nr2name[ndx_i], val)] = name
    return symmap

def canonicalize_token(tail, symmap):
    if "+" not in tail: return tail
    left, right = tail.rsplit("+", 1)
    left = left.strip(); right = right.strip()
    if left.startswith("."):
        try: off = int(right, 16)
        except: return tail
        return symmap.get((left, off), f"{left}+{off:#x}")
    return f"{left}+0"

def canonical_section(ko, secname, secs, relocs, symmap):
    if secname not in secs: return None
    s = secs[secname]
    data = open(ko,"rb").read()
    seg = data[s["off"]: s["off"]+s["size"]]
    rel = {off: t for (off,t) in relocs.get(secname, [])}
    out = []
    for i in range(0, len(seg)-7, 8):
        word = int.from_bytes(seg[i:i+8], "little")
        if i in rel:
            out.append(("PTR", canonicalize_token(rel[i], symmap)))
        else:
            out.append(("VAL", word))
    return out

def main():
    mods = ["miop-ep","miop-ep-net","pcie-ep-rk35","miop-reg"]
    for mod in mods:
        orig = os.path.join(KO_ORIG, mod+".ko"); ours = os.path.join(KO_OURS, mod+".ko")
        if not os.path.exists(orig) or not os.path.exists(ours):
            print(f"skip {mod}"); continue
        so = parse_sections(ours); ro = parse_sections(orig)
        symmap = build_symmap(ours)
        rel_o = parse_relocs(ours); rel_r = parse_relocs(orig)
        print(f"\n########## MODULE {mod} ##########")
        for sec in SECS:
            co = canonical_section(ours, sec, so, rel_o, symmap)
            cr = canonical_section(orig, sec, ro, rel_r, symmap)
            if co is None and cr is None:
                continue
            if co is None or cr is None:
                print(f"  [{sec}] MISSING: ours={co is not None} orig={cr is not None}"); continue
            n = min(len(co), len(cr))
            diffs = [(i*8, co[i], cr[i]) for i in range(n) if co[i] != cr[i]]
            # also report length mismatch tail
            if len(co) != len(cr):
                print(f"  [{sec}] LENGTH ours={len(co)} orig={len(cr)}")
            if diffs:
                print(f"  [{sec}] {len(diffs)} differences (of {n} slots):")
                for off,c,r in diffs[:50]:
                    print(f"     +0x{off:04x}: ours={c}  orig={r}")
            else:
                print(f"  [{sec}] IDENTICAL ({n} slots)")

main()
