# Mixtile Blade 3 — miop driver stack

This repository is a C reimplementation of the vendor Mixtile Blade 3
"TCP/IP over PCIe" driver stack, reverse-engineered from the shipped
ARM64 `.ko` modules (the original `.S` disassembly lives alongside each
`.c` for reference).

## Modules

The stack is layered. `miop-ep.ko` is the top-level platform driver that
binds to the `mixtile,miop-ep-rk3588` device tree node; the other three
publish *driver structs* into a small registry (`miop-reg.ko`) that
`miop-ep.ko` pulls out during its `probe()`.

| Module            | Role                                                                 | Status (see STATUS.md) |
|-------------------|----------------------------------------------------------------------|------------------------|
| `miop-reg.ko`     | Cross-module registry: `miop_register_pcie_ep_drv()`, `miop_register_ep_net_drv()`, `miop_register_is_ready()`. | done |
| `miop-ep.ko`      | Top-level EP platform driver. Waits for both lower drivers, allocs `struct miop_ep`, runs net init, parses DT resources, then hands off to the pcie driver's `probe()`. | done (thin) |
| `miop-ep-net.ko`  | Network layer. Allocs the `pci0` netdev and runs the peer/link handshake + data path callbacks (`on_peer_online`, `on_rx`, `on_tx_ready`, ...). | thin (netdev only) |
| `pcie-ep-rk35.ko` | Lowest layer. Owns the RK3588 PCIe EP controller, trains the link, programs inbound/outbound iATU windows, wires MSI/legacy IRQs, and drives the peer handshake. | thin (stub) |

## Probe flow (`miop-ep.ko`)

```
miop_ep_probe(pdev)
  ├─ wait up to 6s for miop_register_is_ready()  (both lower drivers registered)
  ├─ devm_kzalloc(struct miop_ep)                // zeroed → ep+0x148 == NULL
  ├─ ep->pcie_ep_drv = miop_register_pcie_ep_drv(NULL)
  ├─ ep->net_drv    = miop_register_ep_net_drv(NULL)
  ├─ *(pdev+0x88) = ep                           // recovered by net init as (dev+0x78)
  ├─ net_drv->init(dev)                          // allocs + registers pci0 netdev
  ├─ miop_pcie_ep_resource_setup(pdev, &ep->hw)  // DT: DBI/APB, reset-gpio, windows,
  │                                             //      lanes, memory-region, tx-staging, irq,
  │                                             //      publishes func_a/func_b (RX ring helpers)
  ├─ regulator / clocks / phy / resets
  └─ pcie_drv->probe(dev)                        // <-- pcie-ep-rk35 does link bring-up here
```

The RX ring alloc/free helpers used by the pcie layer live in `ep.c`
(`miop_pcie_rx_region_alloc` / `_free`) and are published into
`struct miop_ep_hw.func_a` / `func_b`.

## struct miop_ep (ABI-critical)

`struct miop_ep` and `struct miop_ep_hw` are laid out by absolute offset
because the lower layers address them by fixed offset (and the asm builds
do too). Field offsets in `miop.h` must not change. Key back-links:

- `ep+0x88`  → `ep` pointer (written by `miop-ep.ko`, recovered by net init)
- `ep+0x150` (`hw.net_priv`) → net private area (written by net init)
- net priv base `netdev+0xa00`; `priv+8` → `ep`, `priv+48` → `netdev`

## Build / deploy / verify

Build host is **node1** (`192.168.0.201`, has kernel headers). The driver
files live in `/root/miop`; the build helper is `/tmp/opencode/miop_build.sh`
(tar → node1 → `make` → pull `.ko` back).

Verification target is **node2** (`192.168.0.202`). **node3**
(`192.168.0.203`) is the untouched factory reference (responds on
`10.20.0.4`).

### Critical operational notes
- **Full power cycle required for a clean link.** A soft reboot
  (`nodectl reboot`) does *not* reset the shared NTB/PCIe switch, so the
  peer handshake deadlocks. Reboot the whole cluster from the controller
  (`sudo /sbin/reboot` on `192.168.0.200`) and wait ~150 s.
- **Controller power cycle reverts `/lib/miop`** to the controller's
  module copy. A direct `sudo reboot` on node2 preserves `/lib/miop`.
- **Oops dependency:** the *factory* `miop-ep-net.ko` imports
  `miop_ep_machine_id` from `pcie-ep-rk35.ko`. Our thin `pcie.c` does not
  export it (our thin `net.c` derives the MAC locally instead), so testing
  thin `pcie.c` must use our thin `net.c`, or `ep->net_drv` ends up NULL
  and `miop_ep_probe` oopses on the `net_drv->init()` call.

### Verify a module loads/registers without oops
1. Build, `scp` the `.ko` to node2 `/lib/miop/`.
2. Full power cycle the cluster.
3. `dmesg | grep -iE 'RK35 EP driver|EP network driver|EP driver probe|unable to handle|Oops|BUG'`
   — expect the three banners and **no** oops.
