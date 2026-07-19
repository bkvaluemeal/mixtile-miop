# MiOP RK35 PCIe EP driver — agent instructions

## Build / deploy workflow
- `./build.sh` — tars LOCAL `/root/miop` (excludes `.ko`, `.o`, `.*`, `.cmd`), `scp`s to node3 (192.168.0.203, user/pass `mixtile`), cross-compiles on node3, pulls `.ko` back. **Do NOT reintroduce `git clone`** — local edits will be overwritten.
- `./deploy.sh` — copies the four `.ko` to node3:/lib/miop/.  Deploy to node2 as well when testing node-to-node: `for f in *.ko; do sshpass scp $f mixtile@192.168.0.202:/tmp/ && ssh mixtile@192.168.0.202 "echo mixtile | sudo -S cp /tmp/$f /lib/miop/"; done`
- `./power-cycle.sh` — shuts down blades 201/202/203, reboots controller 200, waits 45s. **Full cluster power-cycle is the only reliable way to test.** Single-node reboots or `rmmod` produce inconsistent results (PCIe links may not retrain, BAR assignments may be stale, controller may not re-enumerate). See troubleshooting #4.
- Build happens ON node3 (RK3588 ARM64 target), not locally. Controller is OpenWrt/MIPS.
- **Node0 (192.168.0.201) still runs factory binaries** — do not deploy to it.

## Module load order (from miop-driver-loader.sh)
1. `miop-reg.ko` (registry)
2. `pcie-ep-rk35.ko` (low-level controller)
3. `miop-ep-net.ko` (network layer)
4. `miop-ep.ko` (top-level platform driver)

## Critical build gotchas
- **objcopy CRC stripping**: Makefile runs `objcopy --remove-section __kcrctab --remove-section __kcrctab_gpl` on each `.ko` after build. If this fails or is skipped, modules fail to load with "Invalid argument" (-22) due to CONFIG_MODVERSIONS mismatch.
- **meta.c symlinks**: `make shared_c` creates `meta_ep.c`, `meta_reg.c`, `meta_net.c`, `meta_pcie.c` as symlinks to `meta.c`. These are gitignored.
- **Compiler warning is benign**: "compiler differs from the one used to build the kernel" (GCC 13.3 vs kernel's 11.4) — module loads fine.

## Verifying DMA / network
- `dmesg | grep -i "self-test: PASS"` — eDMA write-engine self-test passed.
- `ping -I bond0 <peer-ip>` from any node reaches others over PCIe fabric (`pci0` device, enslaved in `bond0`). 0% loss = DMA TX path healthy.
- `busybox devmem 0xfe150300 32` — check PCIe link LTSSM state (0x230011 = L0, link trained).

## Node topology
| Node | Mgmt IP      | pci0 IP    | PCIe bus | MIOP node id | Role          |
|------|--------------|------------|----------|--------------|---------------|
| node1| 192.168.0.201| —          | bus 06 (DEAD) | 0     | build host (x86 VM now) |
| node2| 192.168.0.202| 10.20.0.3  | bus 05   | 1            | test target   |
| node3| 192.168.0.203| 10.20.0.4  | bus 03   | 2            | reference peer / build host |

Controller: 192.168.0.200 (OpenWrt/MIPS, runs miop.ko RC manager + nodectl).

## Key DMA (eDMA) facts (DesignWare eDMA legacy register map @ 0x380000)
- 0x38000C = WRITE_ENGINE_EN, 0x38002C = READ_ENGINE_EN
- 0x380010 = WRITE_DOORBELL (channel in bits[2:0]); 0x380058 = clear/arm (write `(1<<ch)|(1<<(ch+16))` to clear done/abort)
- 0x38004C = WRITE_INT_STATUS (bit[ch]=done, bit[ch+16]=abort) — this is the **REAL completion signal**; hardware never writes back the descriptor control field.
- Channel context: 0x380200 CH_CONTROL1, 0x38021C/0x220 = LLP (ring base).
- **Cycle Bit (CB) in descriptor control is POSITIONAL** (slot0=1, slot1=0, ...): the engine resets CB to 1 at the ring base on every doorbell re-fetch.
- The engine re-fetches from the ring base and walks the LLI chain until it hits a CB-mismatched terminator; **reap must NOT zero the descriptor control field** (only the software tracking/busy flag), or re-fetch stalls.

## Documentation references
- `docs/ARCHITECTURE.md` — system architecture, struct layouts, probe flow, memory map
- `docs/STATUS.md` — translation progress and TODO list
- `docs/TROUBLESHOOTING.md` — debugging guide, known issues, debug commands
- `docs/CONTROLLER-PROTOCOL.md` — RC protocol reverse-engineered from controller's miop.ko

## ATU register layout (critical — discovered 2026-07-18)

The RK3588 DWC EP uses a **non-standard** ATU register layout:

**Outbound ATU** (works, proven by eDMA self-test and BAR assignment):
| Offset | Register |
|--------|----------|
| 0x00   | CTRL1 / SOURCE base |
| 0x04   | CTRL2 (enable = 0x80000000) |
| 0x08   | LOWER_TARGET (PCIe destination) |
| 0x0C   | UPPER_TARGET |
| 0x10   | LOWER_LIMIT |
| 0x14   | SIZE |
| 0x18   | SIZE_UPPER |
| 0x20   | UPPER_LIMIT |

**Inbound ATU** (working as of 2026-07-18 — BAR match mode):
| Offset | Register |
|--------|----------|
| 0x00   | CTRL1 (= 0x0) |
| 0x04   | CTRL2 = 0xC0080000 (ENABLE|BAR_MODE|FUNC_MATCH|bar<<8) |
| 0x14   | LOWER_TARGET (local DMA address) |
| 0x18   | UPPER_TARGET |
- Window base: `atu_base + (index << 9) | 0x100` (BIT(8) separates IB from OB space)
- BAR match mode: `CTRL2 = 0xC0080000 | (bar << 8)` — the RC-assigned BAR address is matched automatically
- This configuration is an **exact mirror** of the kernel's `dw_pcie_prog_inbound_atu`

**ELBI registers** (all at DBI+0x200e00 base):
- 0x200e00: INT_GEN0 (doorbell — polled by RX path)
- 0x200e08/0c: LOCAL_ENABLE = 0xffff0000 (ELBI snoop on inbound BAR writes)
- 0x200e10: "MIOP" magic = 0x504f494d (read by controller via config 0xE10)
- 0x200e14: desc offset = 0x40 (read by controller via config 0xE14)
- 0x200e18: rx desc offset = 0
- **Must be written while 0x8BC bit 0 (DBI write enable) is set**

## BAR configuration (working)
- BAR0: 64-bit prefetchable, REBAR ctrl=0x40 cap=0x5C0 (factory values), std flag=0x8
- BAR4: 64-bit prefetchable, REBAR ctrl=0x10 cap=0xC0, std flag=0xC
- All unused BARs must be cleared in REBAR (loop bars 0-5 → write 0 to ctrl+cap)
- `miop_pcie_ep_set_bar` for BAR0 NOT needed (REBAR-only, matching kernel driver)
- BAR0 assigned by RC at 0x20000000 (bus 03), 0x20800000 (bus 05), 0x20C00000 (bus 06)
