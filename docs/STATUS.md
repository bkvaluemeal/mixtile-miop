# Status — C reimplementation

**Date:** 2026-07-12  
**State:** PCIe link trains to L0; pci0 has IP and carrier; ping via pci0 fails
(TX data path is a stub).

## Quick summary

| Capability                     | Status |
|--------------------------------|--------|
| PCIe link trains to L0        | ✅ LTSSM = 0x230011 |
| pci0 netdev created           | ✅ `pci0: <BROADCAST,MULTICAST,UP,LOWER_UP>` |
| IP assignment (10.20.0.4/24)  | ✅ via networkd |
| on_peer_online → carrier_on   | ✅ returns 0, no crash |
| ping via pci0 (10.20.0.1)     | ❌ Destination Host Unreachable |
| ping via management network   | ✅ 0.343ms via bond0 |
| TX data path (dma_submit)     | ❌ stub (returns -1) |
| RX data path (IRQ reap)       | ❌ stub (clears status only) |
| Peer doorbell / handshake     | ❌ stub |

## Per-module status

### miop-reg.ko — DONE

`reg.c`: registry module. Exports `miop_register_pcie_ep_drv()`,
`miop_register_ep_net_drv()`, `miop_register_is_ready()`. Static storage
with a mutex. No data path. Verified: loads, symbols resolve, dependent
modules link without error.

### miop-ep.ko — DONE (thin wrapper)

`ep.c`: top-level platform driver. Allocates `struct miop_ep`, sets
`platform_set_drvdata`, calls `miop_pcie_ep_resource_setup()` to parse DT,
manages PHY/clocks/resets, then calls `pcie_drv->init(dev)`. Verified:
probes, prints banner, calls lower `init()`.

### miop-ep-net.ko — DONE (network init, data path stubbed)

`net.c`: allocates the `pci0` netdev via `alloc_etherdev_mqs()`, registers
it, derives a MAC address from the ep pointer.

**Implemented:**
- `miop_ep_net_init()` — alloc_etherdev, register_netdev, MAC derive
- `miop_ep_net_deinit()` — unregister + free netdev
- `miop_on_peer_online()` — `netif_carrier_on()` (was crashing due to
  wrong offset; fixed 2026-07-12)
- `miop_on_rx()` — alloc_skb + netif_receive_skb (wired but never called
  because IRQ handler is a stub)
- `miop_ndo_open/stop/change_mtu` — basic netdev ops

**TODO:**
- `ndo_start_xmit()` — currently calls `dma_submit()` which returns -1
  (driver struct op is NULL), drops the skb silently. Needs the real
  DMA descriptor write and doorbell trigger.

### pcie-ep-rk35.ko — PARTIAL (controller init done, DMA/IRQ still stubs)

`pcie.c`: low-level PCIe EP controller driver.

**Implemented (fully):**
- `miop_pcie_ep_probe()` — ioremap DBI/APB, window-map init, DMA buffer
  alloc, MIOP shared header write, controller config, APB triggers, IRQ
  stub, link-training poll.
- `miop_pcie_config_controller()` — APB glue (0x8000800/0x80000000),
  APP region clears (0x380054/0x3800a8), DBI 0x710 lane cap, 0x80c speed
  bits, 0x4 device type, 0x8bc enable/disable, BARs x4, Vendor/Device/Class
  IDs, inbound ATU mapping.
- `miop_pcie_link_train()` — bounded poll of `apb+0x300` (mask 0x3003f,
  target 0x30011), 20 ms sleep, 250 iterations max.
- `miop_pcie_peer_online()` — calls `net_drv->on_peer_online(ep, 0)`.
- `rk35_pcie_ep_window_map_init/deinit()` — bitmap alloc/free.
- `miop_ep_map_outbound_atu/unmap_outbound_atu()` — iATU window prog.
- `miop_pcie_ep_set_bar()` — BAR register programming.
- `rk35_pcie_readl_dbi/readw_dbi()` — DBI accessors.
- `miop_ep_generate_serial()` / `miop_ep_machine_id()` — serial/id hash.
- `miop_ep_irq_stub()` — clears `apb+0x10`, returns IRQ_HANDLED.

**TODO (in priority order):**

1. **`miop_rk35_dma_submit()`** — write one DMA descriptor into the ring,
   update producer index, call `rk35_dma_start_write()` to doorbell the
   hardware. Required for TX to work.
2. **`rk35_ep_interrupt()`** — full IRQ handler: read `apb+0x10` status,
   call `miop_dma_try_reap()` for completed TX descriptors, call
   `net_drv->on_rx()` for RX completions, raise peer IRQ on doorbell.
3. **`miop_dma_try_reap()`** — walk completed descriptors in the ring,
   invoke per-descriptor completion callbacks, update consumer index.
4. **`miop_raise_peer_irq()`** — trigger a doorbell write to the RC to
   signal new TX data.
5. **`miop_rk35_dma_submit_batch()`** — submit a batch of descriptors
   (used by the network layer for scatter/gather).
6. **`miop_dma_list_commit_pending()`** — commit pending TX descriptor
   list entries.
7. **`miop_rk35_map_peer_bar()` / `miop_rk35_map_rc_staging()`** — ioremap
   and iATU map the peer's BAR and RC staging region (required for the
   peer handshake after link-up).
8. **`miop_elbi_enable_irq/disable_irq()`** — ELBI message IRQ control.
9. **`miop_intx_trigger_work()`** — legacy INTx IRQ trigger workqueue.
10. **`miop_pcie_ep_deinit()`** — full cleanup: unmap, free DMA, deinit
    window maps.

## Translation progress

| Factory function                   | Lines     | C status         | C location        |
|------------------------------------|-----------|------------------|-------------------|
| `rk35_pcie_ep_window_map_init`     | 2217-2260 | ✅ implemented   | pcie.c:140        |
| `rk35_pcie_ep_window_map_deinit`   | 3141-3170 | ✅ implemented   | pcie.c:166        |
| `rk35_pcie_readl_dbi`              | 488-499   | ✅ implemented   | pcie.c:128        |
| `rk35_pcie_readw_dbi`              | 768-781   | ✅ implemented   | pcie.c:133        |
| `miop_ep_generate_serial`          | 332-376   | ✅ implemented   | pcie.c:52         |
| `miop_ep_machine_id`               | 377-398   | ✅ implemented   | pcie.c:95         |
| `miop_ep_map_outbound_atu`         | 1079-1207 | ✅ implemented   | pcie.c:202        |
| `miop_ep_unmap_outbound_atu`       | 214-257   | ✅ implemented   | pcie.c:175        |
| `rk35_pcie_ep_set_bar`             | 412-487   | ✅ implemented   | pcie.c:258        |
| `miop_pcie_ep_init` (ctrl cfg)     | 2527-2636 | ✅ implemented   | pcie.c:344        |
| `miop_pcie_ep_init` (MIOP tag)     | 2702-2723 | ✅ implemented   | pcie.c (probe)    |
| `miop_pcie_ep_init` (APB trigger)  | 2742-2754 | ✅ implemented   | pcie.c (probe)    |
| `miop_pcie_ep_init` (LTSSM poll)   | 2755-2779 | ✅ implemented   | pcie.c:448        |
| `miop_pcie_ep_init` (post-LTSSM)   | 2780-2810 | ❌ not done      | —                 |
| `rk35_ep_interrupt`                | 1208-1713 | ❌ stub (clears) | pcie.c:477        |
| `miop_rk35_dma_submit`             | 19-98     | ❌ not done      | —                 |
| `miop_rk35_dma_submit_batch`       | 859-1078  | ❌ not done      | —                 |
| `miop_dma_try_reap`                | 500-700   | ❌ not done      | —                 |
| `miop_dma_list_commit_pending`     | 2019-2194 | ❌ not done      | —                 |
| `miop_raise_peer_irq`              | 782-858   | ❌ not done      | —                 |
| `miop_elbi_enable_irq`             | 99-121    | ❌ not done      | —                 |
| `miop_elbi_disable_irq`            | 122-144   | ❌ not done      | —                 |
| `miop_intx_trigger_work`           | 174-213   | ❌ not done      | —                 |
| `miop_rk35_map_peer_bar`           | 1833-1952 | ❌ not done      | —                 |
| `miop_rk35_map_rc_staging`         | 1714-1832 | ❌ not done      | —                 |
| `miop_rk35_unmap_peer_bar`         | 297-331   | ❌ not done      | —                 |
| `miop_rk35_unmap_rc_staging`       | 258-296   | ❌ not done      | —                 |
| `miop_dma_list_is_full`            | 701-740   | ❌ not done      | —                 |
| `rk35_dma_start_write`             | 741-767   | ❌ not done      | —                 |
| `miop_dma_reap_thread`             | 1953-2018 | ❌ not done      | —                 |
| `miop_pcie_ep_deinit`              | 3171-3256 | ❌ not done      | —                 |

## Key bugs fixed

1. **2026-07-12: struct offset confusion** — The factory init accesses
   `pcie_priv+24` (= `apb_base`) for all APB glue and training-trigger
   writes. Our code was targeting `dbi_base2` (+16 = dbi+0x100000) instead.
   Fix: changed all `pcie->dbi_base2` → `pcie->apb_base`. The structs were
   never swapped — both have `apb_base` at +24.

2. **2026-07-12: on_peer_online crash** — `miop_on_peer_online()` read the
   `net_device *` from offset +48 of `miop_net_priv` (which is the spinlock).
   The correct offset is +16 (`priv->netdev`). Fix: use `priv->netdev`
   directly.

## How to test

### After deploy + power-cycle

```sh
# Check link status
busybox devmem 0xfe150300 32          # → 0x00230011 = L0

# Check dmesg
dmesg | grep -iE "miop|pcie|link|carrier"

# Check interface
ip addr show pci0                      # → 10.20.0.4/24, LOWER_UP

# Ping management (via bond0)
ping -c 3 192.168.0.202                # → 0% loss

# Ping fabric (via pci0 — WILL FAIL until DMA is implemented)
ping -c 3 10.20.0.1                    # → Destination Host Unreachable
```
