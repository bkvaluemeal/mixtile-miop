# Brick Log — known crash/brick causes

## 1. Self-test writing through iATU → controller RAM corruption

**What:** `dma_submit` self-test wrote to `dest_addr = 0x9000e0000` which
went through the outbound iATU window (`target=0x02CC0000`) to PCIe
`0x02DA0000` → landed in the controller's system RAM (256 MB at
`0x00000000–0x0fffffff`), corrupting kernel data.

**Effect:** Controller boot-loops or crashes. Blades may also crash if the
controller's miop driver panics and takes the fabric down.

**Fix:** Self-test now writes to a safe local buffer
`pcie->dma_dma + 0x200000` (within the 4 MB coherent DMA buffer, past
all ring structures).  This is local DDR, not routed through iATU.

**Commit-ish:** `0x9000e0000` dest replaced with `dma_dma + 0x200000`.

---

## 2. PEER_ELBI conflict with eDMA ring in the DMA buffer

**What:** When PEER_DESC/PEER_ELBI were placed in the inbound BAR0
region at `0x0e000000+`, PEER_ELBI[3] at `0x0e100000` exactly overlaps
with `chan[0].ring` (eDMA descriptor ring 0).  Every TX broadcast
writes the doorbell value (4 bytes) over the ring's descriptor
control/address fields, and the eDMA engine fetches garbage.

**Effect:** Instant kernel panic / bus error.  Blade becomes a brick in
the cluster and can cause the controller to boot-loop.

**Fix:** PEER_DESC/PEER_ELBI are now in the outbound iATU region
(`0x900000000+`), completely separate from the DMA pool at
`0x0e000000–0x0e3fffff`.  Peer index 3 is also skipped (only 3 blades
exist).

**Commit-ish:** PEER addresses moved back to `0x900000000+` base.

---

## 3. BAR0 size mismatch (64 KB vs 32 MB)

**What:** Our `miop_pcie_ep_set_bar(pcie, 0, 0x10000, …)` requested a
64 KB BAR0.  The factory requests 32 MB (`0x2000000`).  The controller
can only allocate bridge windows for ~2 blades with 32 MB each in its
256 MB PCIe window; with an anomalous 64 KB BAR it may fail to probe
at all or assign conflicting windows.

**Effect:** Controller can only probe 1–2 blades; the third shows
`pci_iomap() BAR0 failed`.  Cross-blade fabric routing is incomplete.

**Fix:** BAR0 size is now `0x2000000` (32 MB), matching the factory.

**Commit-ish:** set_bar size changed from `0x10000` → `0x2000000`.

---

## 4. Raw skb data written to PEER_DESC instead of software descriptor

**What:** The old `dma_submit` copied raw skb data to the staging
buffer, then the eDMA blasted it into PEER_DESC verbatim.  The
controller's miop driver reads PEER_DESC *as a formatted descriptor*
(CB, len, data_addr, ext) — it tried to parse ICMP/IP headers as
descriptor fields.

**Effect:** Controller-side crashes, misforwarded data, boot-loops.

**Fix:** `dma_submit` now builds a 24-byte software descriptor at the
start of the staging buffer, followed by the inline packet data:

```
offset 0  status = CB (1)
      4  len    = packet length
      8  data   = PEER_DESC + 24 (inline data address)
     16  ext    = same (matching factory convention)
     24 …        = inline packet data
```

**Commit-ish:** descriptor loop rewritten in `miop_rk35_dma_submit`.

---

## 5. iATU programmed before link training → reset by APB glue

**What:** Programming the outbound iATU window *during `probe`* (before
`apb[0] = 0xf00000` / `apb[0] = 0xc000c` and the link-training poll)
can lose the configuration.  The factory programs outbound iATU in the
*interrupt handler* (`rk35_ep_interrupt`, pcie_asm.S:1515), which fires
*after* link-up.

**Effect:** iATU window configured but silently disabled after APB
glue writes.  TX data never reaches the fabric.

**Fix:** The outbound iATU window is now programmed inside
`miop_pcie_peer_online()`, which is called from the link-train poll
*after* `LTSSM == L0` and *after* the APB glue writes.

**Commit-ish:** ATU setup moved to `miop_pcie_peer_online`.

---

## Deployment rules

1. **Never `rmmod` → `insmod` live.**  Hot-reloading always crashes.
   Use `./power-cycle.sh` (or shut down→wait→restart) after copying
   `.ko` files to `/lib/miop/`.

2. **Never deploy to all 3 blades at once.**  Test on ONE blade first
   with the others still on factory modules.  Verify cross-blade ping
   before deploying to the remaining blades.

3. **Always capture `dmesg` on the controller BEFORE and AFTER**
   deploying new modules.  This tells us `bar0_pci`, `tx_staging`, and
   which nodes are probed.

4. **Avoid allocating data in the coherent DMA buffer** that overlaps
   with the eDMA rings.  The rings start at `dma_dma + 0x100000`.
   Any PEER_DESC/PEER_ELBI in the `0x0e000000` range must stay
   *below* `0x0e100000`.

---

## Architecture reference

| Entity | Physical addr | Notes |
|--------|--------------|-------|
| eDMA ring[0] | `dma_dma + 0x100000` | 128 × 24-byte descriptors + trailer |
| eDMA ring[1] | `dma_dma + 0x110000` | same layout |
| Self-test dest | `dma_dma + 0x200000` | local DDR, safe |
| PEER_DESC[p] | `0x900000000 + 0x020000 + p×0x040000` | outbound iATU region |
| PEER_ELBI[p] | `0x900000000 + 0x040000 + p×0x040000` | outbound iATU region |
| Outbound iATU region | `0x900000000–0x93ffffff` | DT ranges #2 for `fe150000.pcie` |
