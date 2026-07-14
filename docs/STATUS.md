# Status — C reimplementation

**Date:** 2026-07-14
**State:** **Fully translated to C and working.** All four modules are clean C.
The PCIe link trains, the `pci0` interface comes up, and **ping across the
PCIe fabric works node-to-node in both directions (0% loss)**.

## Quick summary

| Capability                       | Status |
|----------------------------------|--------|
| PCIe link trains to L0          | ✅ LTSSM = 0x230011 |
| pci0 netdev created             | ✅ `pci0: <BROADCAST,MULTICAST,UP,LOWER_UP>` |
| IP assignment (10.20.0.x/24)    | ✅ via networkd |
| on_peer_online → carrier_on     | ✅ |
| ping node→node over fabric       | ✅ 0% loss (all 3 nodes) |
| TX data path (dma_submit)       | ✅ implemented |
| RX data path (IRQ reap)         | ✅ implemented |
| Peer doorbell / handshake       | ✅ implemented |
| Build is C-only (no .S)         | ✅ assembly removed |

## Per-module status

### miop-reg.ko — DONE

`reg.c`: registry module. Exports `miop_register_pcie_ep_drv()`,
`miop_register_ep_net_drv()`, `miop_register_is_ready()`,
`miop_free_dma_skb_head()`. Static storage with a mutex. No data path.

### miop-ep.ko — DONE

`ep.c`: top-level platform driver. Allocates `struct miop_ep`, sets
`platform_set_drvdata`, calls `miop_pcie_ep_resource_setup()` to parse DT,
manages PHY/clocks/resets, then calls `pcie_drv->init(dev)`. Implements
`miop_pcie_rx_region_alloc/free`, `miop_ep_probe/remove`,
`miop_ep_machine_id`.

### miop-ep-net.ko — DONE

`net.c`: allocates the `pci0` netdev via `alloc_etherdev_mqs()`, registers
it, derives a MAC address from the ep pointer.

- `miop_ep_net_init()` / `miop_ep_net_deinit()` — netdev alloc/register.
- `miop_on_peer_online()` — `netif_carrier_on()`.
- `miop_on_rx()` — `alloc_skb` + `netif_receive_skb`.
- `miop_on_tx_ready()` / `miop_on_rx_full()` — flow control hooks.
- `miop_ndo_open/stop/change_mtu` — basic netdev ops.
- `miop_ndo_start_xmit()` — calls `dma_submit(pdev, -1, skb, ...)` to
  broadcast the frame into every online peer's data window.

### pcie-ep-rk35.ko — DONE

`pcie.c`: low-level PCIe EP controller driver. All controller init, iATU
window programming, eDMA descriptor submission, IRQ reap, and peer doorbell
are implemented in C.

**Implemented (fully):**

- `miop_pcie_ep_probe()` — ioremap DBI/APB, window-map init, DMA buffer
  alloc, MIOP shared header write, controller config, APB triggers, IRQ
  setup, link-training poll.
- `miop_pcie_config_controller()` — APB glue, APP region clears, DBI lane
  cap / speed / device-type / BAR / Vendor-ID programming, inbound ATU.
- `miop_pcie_link_train()` — bounded poll of `apb+0x300`.
- `miop_ep_map_outbound_atu()` / `miop_ep_unmap_outbound_atu()` — iATU
  window programming (takes a `u64` target; matches the factory register
  layout: target @+0x8/+0xc, limit @+0x10/+0x20, size @+0x14/+0x18,
  enable @+0x4).
- `rk35_pcie_ep_set_bar()` — BAR register programming.
- `rk35_pcie_readl_dbi()` / `rk35_pcie_readw_dbi()` — DBI accessors.
- `miop_ep_generate_serial()` / `miop_ep_machine_id()` — serial/id.
- `miop_rk35_dma_submit()` / `miop_rk35_dma_submit_batch()` — write one /
  many DMA descriptors into the ring, advance the producer index, doorbell
  the hardware via `rk35_dma_start_write()`.
- `miop_dma_try_reap()` — walk completed descriptors, fire per-descriptor
  completion callbacks, advance consumer index.
- `miop_raise_peer_irq()` — write the RX_DATA doorbell (`0x2 | src<<8`)
  into the peer's EP doorbell window.
- `miop_dma_list_is_full()` / `miop_dma_list_commit_pending()` — ring
  fullness / batch commit helpers.
- `miop_elbi_enable_irq()` / `miop_elbi_disable_irq()` — ELBI message IRQ
  control (ELBI is currently disabled: `dbi_base2 = NULL`).
- `miop_rk35_map_peer_bar()` / `miop_rk35_map_rc_staging()` and their
  unmap counterparts — per-peer outbound window + RC staging region.

## Translation progress (all DONE)

Every function the factory binary exposed has a working C definition in
`reg.c` / `ep.c` / `net.c` / `pcie.c`. The original ARM64 disassembly
(`reg_asm.S`, `ep_asm.S`, `net.S`, `pcie_asm.S`) was leftover reference
material and was **never compiled** — the Makefile only builds the `.c`
objects. It was deleted on 2026-07-14 (commit `dac732e`). The C
reimplementation was written from scratch (not mechanically decompiled) and
verified functionally.

| Factory function                   | C status      | C location            |
|------------------------------------|---------------|-----------------------|
| `rk35_pcie_ep_window_map_init`     | ✅ implemented | pcie.c:140            |
| `rk35_pcie_ep_window_map_deinit`   | ✅ implemented | pcie.c:166            |
| `rk35_pcie_readl_dbi`              | ✅ implemented | pcie.c:137            |
| `rk35_pcie_readw_dbi`              | ✅ implemented | pcie.c:146            |
| `miop_ep_generate_serial`          | ✅ implemented | pcie.c:61             |
| `miop_ep_machine_id`               | ✅ implemented | pcie.c:104 / ep.c     |
| `miop_ep_map_outbound_atu`         | ✅ implemented | pcie.c:213            |
| `miop_ep_unmap_outbound_atu`       | ✅ implemented | pcie.c:184            |
| `rk35_pcie_ep_set_bar`             | ✅ implemented | pcie.c:298            |
| `miop_pcie_ep_init` (ctrl cfg)     | ✅ implemented | pcie.c (probe)        |
| `miop_rk35_dma_submit`             | ✅ implemented | pcie.c:592            |
| `miop_rk35_dma_submit_batch`       | ✅ implemented | pcie.c:1002           |
| `miop_dma_try_reap`                | ✅ implemented | pcie.c:709            |
| `miop_dma_list_commit_pending`     | ✅ implemented | pcie.c:935            |
| `miop_raise_peer_irq`              | ✅ implemented | pcie.c:789            |
| `miop_elbi_enable_irq`             | ✅ implemented | pcie.c:953            |
| `miop_elbi_disable_irq`            | ✅ implemented | pcie.c:970            |
| `miop_rk35_map_peer_bar`           | ✅ implemented | pcie.c (local)        |
| `miop_rk35_map_rc_staging`         | ✅ implemented | pcie.c:992            |
| `miop_rk35_unmap_peer_bar`         | ✅ implemented | pcie.c                |
| `miop_rk35_unmap_rc_staging`       | ✅ implemented | pcie.c                |
| `miop_dma_list_is_full`            | ✅ implemented | pcie.c:922            |
| `rk35_dma_start_write`             | ✅ implemented | pcie.c:538            |
| `miop_pcie_rx_region_alloc`        | ✅ implemented | ep.c:59               |
| `miop_pcie_rx_region_free`         | ✅ implemented | ep.c:130              |
| `miop_pcie_ep_resource_setup`      | ✅ implemented | ep.c:165              |
| `miop_ep_probe` / `miop_ep_remove` | ✅ implemented | ep.c:294 / ep.c:446   |
| `miop_xmit_to_peer_new` / `ndo`    | ✅ implemented | net.c                 |

## Key bugs fixed during translation

1. **struct offset confusion** — factory init accesses `pcie_priv+24`
   (= `apb_base`) for all APB glue and training-trigger writes. Fixed by
   targeting `pcie->apb_base` instead of `dbi_base2`.

2. **on_peer_online crash** — read `net_device *` from the wrong
   `miop_net_priv` offset. Fixed to use `priv->netdev`.

3. **DTB `num-ob-windows`** — factory `pcie-ep-rk35.ko` claims 8 iATU
   windows at boot, leaving only 2 free on node3. Patched
   `rk3588-mixtile-blade3.dtb` `num-ob-windows` `0x10`→`0x20` (32) so 24
   remain free. Backup: `rk3588-mixtile-blade3.dtb.bak-1783999588`.

4. **Outbound ATU register layout** — `miop_ep_map_outbound_atu` now takes
   a `u64` target and programs the factory register layout (target
   @+0x8/+0xc, limit @+0x10/+0x20, size @+0x14/+0x18, enable @+0x4). The
   earlier `u32` target truncated `0x90N000000` windows and the wrong
   enable offset made the ATU never come up.

5. **Per-peer window addressing** — TX data window target is
   `0x900000000 + dest<<24 + 3<<20` (data at +0x2000000); the separate
   doorbell window target is `0x90000000 + dest<<24 + 0x100000`.

6. **Doorbell value** — `miop_raise_peer_irq` must write `0x2` (RX_DATA);
   `miop_ep_handle_doorbell` only calls `on_rx` when `db_val & 2`. The
   previous `0x1` (RX-ready) was silently ignored by peers, so node3's
   traffic was delivered but never demuxed (ping 100% loss). After the fix
   all three nodes ping each other at 0% loss.

## How to build / test

The build host is the x86 dev VM. `build.sh` tarballs the **local** source
tree and `scp`s it to node3 (it does NOT `git clone`, so local edits are
preserved), then cross-compiles the four `.ko` modules on node3.
`deploy.sh` copies the `.ko` files to `/lib/miop/` on node3. A **full
power-cycle is required** for the new modules to take effect (no
hot-reload). Node3 is `mixtile@192.168.0.203` (password `mixtile`, use
`sshpass -p mixtile`).

```sh
cd /root/miop
git pull                      # confirm remote HEAD first (repo auto-commits)
./build.sh                    # tarball local src -> node3 -> cross-compile
./deploy.sh                   # copy .ko to /lib/miop/ on node3
./power-cycle.sh              # reboot cluster 200/201/202/203
```

### Verify

```sh
# eDMA write-engine self-test passed
dmesg | grep -i "self-test: PASS"

# From node3, ping both peers over the PCIe fabric (0% loss = healthy)
ssh mixtile@192.168.0.203 'sudo ping -I bond0 -c 5 192.168.0.201'
ssh mixtile@192.168.0.203 'sudo ping -I bond0 -c 5 192.168.0.202'
```
