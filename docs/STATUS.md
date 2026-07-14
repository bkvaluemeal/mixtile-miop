# Status — incremental C reimplementation

Goal: reimplement all four modules in documented C, ultimately bringing
`pci0` UP with working ping. Approach: **thin-first** — each module
registers the same driver interface and loads without oops; the real
data-path logic is filled in incrementally afterward.

## Per-module status

| Module         | Thin wrapper | Data path | Verified (no oops, loads) |
|----------------|--------------|-----------|---------------------------|
| `miop-reg.ko`  | done         | n/a (registry only) | yes |
| `miop-ep.ko`   | done         | resource_setup done; calls lower `probe()` | yes |
| `miop-ep-net.ko` | done      | netdev alloc/register done; `on_peer_*`/`ndo_*` are stubs | yes (eth0, link down) |
| `pcie-ep-rk35.ko` | done    | `probe()` is a stub returning 0 | yes (link down) |

Current node2 boot state: our `ep` + `reg` + thin `net` + thin `pcie` →
`eth0` DOWN, no `pci0`, no ping. Expected for thin-first.

## Translated vs stubbed (per module)

### pcie-ep-rk35.ko — translated so far
- `miop_ep_generate_serial()` — serial-mixing hash (from `pcie.S`).
- `miop_ep_machine_id()` — walks `ep+0x78` → `+0x148`; returns the cached
  id or falls back to `miop_ep_generate_serial()`. Exported.
- `rk35_pcie_readl_dbi()` / `rk35_pcie_readw_dbi()` — DBI accessors
  (asm had a decompiler self-loop artifact; real op is just the read).
- `rk35_pcie_ep_window_map_init()` / `_deinit()` — allocate/kfree the three
  window bitmaps/arrays (`map1`/`map2`/`addrs` in `struct miop_pcie`).
- `miop_ep_map_outbound_atu()` — program one outbound iATU window (ATU base,
  0x200 stride, enable poll on bit31), set the alloc bit, store the target in
  `addrs[]`. Exported.
- `miop_ep_unmap_outbound_atu()` — find the slot by target, hit the viewport
  reg (+0x900/+0x908), clear the alloc bit. Exported.
- **`miop_pcie_ep_probe()` — early/structural stage WIRED** (transcribed from
  `pcie.S` `miop_pcie_ep_init`). It allocates `struct miop_pcie` (see
  `miop.h`), ioremaps the DBI/APB windows from `ep->hw.res_dbi`/`res_apb`,
  computes `dbi_base2` (DBI+0x100000) and `atu_base` (DBI+0x300000), runs
  `window_map_init` (sized from `ep->n_free`/`ep->n_win`), and carves out the
  4 MiB TX/DMA coherent buffer. Verified: probe prints
  `n_free=16 n_win=16`, banners present, **no oops**.

The ATU helpers were converted from raw offset arithmetic to named fields of
`struct miop_pcie`; `struct miop_pcie` and `ep->n_free`/`n_win`/`pcie_priv`
were added to `miop.h`. `ep.c` now sets `platform_set_drvdata(pdev, ep)` and
feeds `ep->n_free`/`n_win` from `hw->num_ob_windows`.

### pcie-ep-rk35.ko — stubbed / TODO (the probe)
`miop_pcie_ep_init()` (factory `pcie.S` ~line 2260, ~880 lines of asm) is
the link-bring-up core. **Status:** phases 1–3 (ioremap DBI/APB, window-map
init, DMA buffer) are WIRED and verified. Phase 5/11/10 core (DBI/APB config
block, bounded link-training poll, stub IRQ) are now WIRED and verified (see
verification log). Remaining phases (transcribe from `pcie.S`, each a
verifiable increment):

4. `miop_ep_generate_serial` — **DONE** (serial stored in `pcie->serial`,
   MIOP shared header written at start of the 4 MiB DMA buffer).
5. `rk35_pcie_readl_dbi` — read/configure DBI registers — **DONE** (DBI/APB
   controller-config block transcribed: APB glue, RK APP 0x380054/0xa8 clears,
   DBI 0x710 link-cap width, 0x80c link speed, 0x4, 0x0/0x2/0xc EP identity,
   0x8bc enable toggle).
6. `rk35_pcie_ep_set_bar` ×4 — configure EP BARs. **WIRED** (transcribed from
   `rk35_pcie_ep_set_bar.isra.0`). Uses `base_idx = ep->n_win` (16) so the BAR
   table sits at `dbi + 0x10 + bar*8`; faithful offset arithmetic preserved
   against `pcie->dbi_base`/`pcie->apb_base`. Load-tested: no oops (writes stay
   inside the 16 MiB DBI/APB ioremap); functional correctness only visible at
   link-up.
7. `find_first_zero_bit` — allocate per-peer/ring inbound slot + program the
   inbound iATU window. **WIRED** (`miop_pcie_map_inbound_atu`): allocates a slot
   from `pcie->map1` (bounded by `num_ib_windows`), maps it inbound to
   `pcie->dma_dma` (the reserved 4 MiB region). Verified slot 0 → 0xe000000.
8. `ioremap` — map peer BAR / RC staging regions. **STUBBED**.
9. `dma_alloc_attrs` ×2 — more DMA regions (peer-desc rings). **STUBBED**.
10. `devm_request_threaded_irq` — `rk35_ep_interrupt` handler. **WIRED** with a
    minimal stub handler that clears the APB status reg (`apb+0x10`) and
    returns `IRQ_HANDLED` (no DMA reap / handshake yet — prevents storm).
11. link-training poll: `readl(apb+0x300)` + `msleep(20)` until status matches
    `0x11 | (0x3<<16)` (mask `0x3f|(0x3<<16)`), bounded to `MIOP_LINK_TRAIN_ITERS`
    (250 → ~5 s) so a missing peer can never hang boot. **WIRED + verified**
    (graceful timeout when peer/switch not reset).
12. `ioremap` ×2 — RC staging + peer BAR mapping (`miop_rk35_map_rc_staging`, `miop_rk35_map_peer_bar`). **STUBBED**.
13. outbound ATU: `miop_ep_map_outbound_atu` (`outbound free_win` messages).
    Helpers exist; not yet driven by the link-up path.
14. peer handshake → calls `net_drv->on_peer_online()` → `Node online` / `tx staging` / `new-arch init`. **STUBBED** (lives in `rk35_ep_interrupt`, not wired).

**Key runtime finding (2026-07-12):** `fe150000.pcie` is bound to **our**
`miop-ep` driver and there is **no** kernel PCIe EP framework in use
(`/sys/class/pci_epc` empty; `rk-pcie`/`dw-pcie` not bound to the
controller). Therefore our `pcie_ep_rk35.ko` is the *complete* EP controller
driver and the asm's DBI/APB pokes are safe to reproduce against
`pcie->dbi_base`/`pcie->apb_base`. The asm reached the controller through a
`struct rockchip_pcie` handle only for `set_bar`/`raise_irq`/`map_*`, which we
rewrite against our raw mmio.

**Link-training caveat:** a *direct node2 reboot* does **not** reset the
shared ASM2824 NTB switch, so the switch↔node2 link cannot retrain even when
node3 (RC, `10.20.0.4`) is up. To actually observe `PCIe Link up`, a **full
cluster power cycle** (controller reboot) is required — this is the only way
to validate the LTSSM/training path.

Helper functions already present in `pcie.S` to translate:
`miop_rk35_dma_submit`, `miop_rk35_dma_submit_batch`, `miop_ep_map_outbound_atu`,
`miop_ep_unmap_outbound_atu`, `miop_rk35_map_rc_staging`, `miop_rk35_map_peer_bar`,
`rk35_pcie_ep_set_bar`, `rk35_pcie_readl_dbi`/`readw_dbi`, `rk35_ep_interrupt`,
`miop_dma_reap_thread`, `miop_dma_list_commit_pending`, `miop_raise_peer_irq`,
`miop_elbi_enable_irq`/`disable_irq`, `miop_intx_trigger_work`.

### miop-ep-net.ko — stubbed / TODO
- `on_peer_online()` — set up per-peer TX/RX rings + flip carrier.
- `ndo_start_xmit()` / `on_rx()` / `on_tx_ready()` — packet data path.
- Real MAC derivation (currently a local placeholder; could use
  `miop_ep_machine_id`).

## Verification log
- `reg.c`/`ep.c` (kzalloc fix): verified, ping 0% loss with factory net+pcie.
- `net.c` thin: verified loads/registers, `eth0` created, no oops.
- `pcie.c` thin: verified loads/registers, no oops (full power cycle).
  Discovered the `miop_ep_machine_id` import dependency (factory net).
- `pcie.c` ATU/region helpers transcribed (unwired): verified direct node2
  reboot, banners present, no oops/BUG.
- `pcie.c` probe early stage wired (ioremap DBI/APB, window_map_init, 4 MiB
  DMA): verified direct node2 reboot, prints `n_free=16 n_win=16`, no oops.
- `pcie.c` probe controller-config + bounded link-training + stub IRQ wired:
  verified clean reload (all 4 modules load, **no oops/panic, no IRQ storm**).
  Probe runs the full new path; link-training polls `apb+0x300` and times out
  gracefully (~5 s, bounded) because the peer/switch wasn't reset (node2-only
  reboot; node3 RC *was* up but switch↔node2 link can't retrain without a full
  power cycle). Serial `0x58c184bf` reported. `set_bar` (transcribed, bi@0x10/
  0x20/0x28/0x30) and inbound ATU (slot 0 → 0xe000000) also load clean.
  Next: a full cluster power cycle is needed to confirm the link actually
  trains + the EP function is visible with this config.

## Next increments
1. Implement `miop_pcie_ep_init()` phases in order, testing after each
   (expect `outbound free_win` / `PCIe Link up` to appear, then the peer
   handshake to start calling `net_drv->on_peer_online`).
2. Implement `miop-ep-net.ko` `on_peer_online` to bring `pci0` carrier UP
   and set up the rings.
3. Implement the TX/RX data path so ping works end-to-end.
