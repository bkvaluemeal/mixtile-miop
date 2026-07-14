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

### pcie-ep-rk35.ko — stubbed / TODO (the probe)
`miop_pcie_ep_init()` (factory `pcie.S` ~line 2260, ~880 lines of asm) is
the link-bring-up core. Phases observed from the disassembly, in order:

1. `devm_ioremap_resource` ×2 — DBI + APB register windows.
2. `rk35_pcie_ep_window_map_init` — inbound/outbound window map setup.
3. `dma_alloc_attrs` — DMA buffers for rings / descriptors.
4. `miop_ep_generate_serial` — derive serial (→ MAC).
5. `rk35_pcie_readl_dbi` — read/configure DBI registers.
6. `rk35_pcie_ep_set_bar` ×4 — configure EP BARs.
7. `find_first_zero_bit` — allocate per-peer/ring slots.
8. `ioremap` — map peer BAR / RC staging regions.
9. `dma_alloc_attrs` ×2 — more DMA regions.
10. `devm_request_threaded_irq` — `rk35_ep_interrupt` handler.
11. link-training poll: `readl` + `msleep` until `PCIe Link up`.
12. `ioremap` ×2 — RC staging + peer BAR mapping (`miop_rk35_map_rc_staging`, `miop_rk35_map_peer_bar`).
13. outbound ATU: `miop_ep_map_outbound_atu` (`outbound free_win` messages).
14. peer handshake → calls `net_drv->on_peer_online()` → `Node online` / `tx staging` / `new-arch init`.

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

## Next increments
1. Implement `miop_pcie_ep_init()` phases in order, testing after each
   (expect `outbound free_win` / `PCIe Link up` to appear, then the peer
   handshake to start calling `net_drv->on_peer_online`).
2. Implement `miop-ep-net.ko` `on_peer_online` to bring `pci0` carrier UP
   and set up the rings.
3. Implement the TX/RX data path so ping works end-to-end.
