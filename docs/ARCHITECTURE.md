# Mixtile Blade 3 — MIOP Driver Stack (C reimplementation)

## 1. Cluster Hardware

```
             Cluster Controller (192.168.0.200)
             OpenWrt/MIPS, kernel 5.15.150
             runs: miop.ko (RC manager) + nodectl
                        |
                   Root Complex
                        |
              ASMedia ASM2824 PCIe Gen3 switch
              (downstream ports 00.0/04.0/08.0/0c.0)
                 |        |        |
              bus 03   bus 05   bus 06      (bus 04 empty)
                 |        |        |
              Blade3   Blade2   Blade1      (RK3588, each a PCIe EP)
              (node3)  (node2)  (node1, link DEAD)
```

| Node | Mgmt IP      | pci0 IP     | PCIe bus | MIOP node id | Role          |
|------|-------------|-------------|----------|--------------|----------------|
| node1| 192.168.0.201| —           | bus 06 (dead) | 0        | build host (x86 VM now) |
| node2| 192.168.0.202| 10.20.0.3   | bus 05   | 1            | test target    |
| node3| 192.168.0.203| 10.20.0.4   | bus 03   | 2            | reference peer |

Each blade's RK3588 PCIe controller (`fe150000.pcie`) is configured as an
**Endpoint** (not a Root Complex). The controller's `miop.ko` RC manager
scans the buses, reads each blade's `machine_id` from its EP BAR0, manages
DMA rings, and brings nodes online. Blade↔blade traffic goes peer-to-peer
through the ASM2824 switch.

### Blade memory map (relevant regions)
From `/proc/iomem` on node3:

```
06000000-07ffffff : miop_tx_dma@0x06000000    (TX staging, 32 MiB)
0e000000-0e3fffff : miop_dma@0x0e000000       (DMA buffer, 4 MiB)
a40000000-a403fffff : fe150000.pcie pcie-dbi  (DBI, 4 MiB)
fe150000-fe153fff : fe150000.pcie apb         (APB, 16 KiB)
```

`dbi_base` at `0xa40000000` maps the DWC core's DBI (4 MiB). Sub-regions:
- `dbi_base + 0x000000` — DBI config registers (Vendor/Device ID, BARs, etc.)
- `dbi_base + 0x100000` — DBI2 / ATU viewport (alias to DBI config space)
- `dbi_base + 0x200000` — Vendor-specific mailbox / doorbell region
- `dbi_base + 0x300000` — ATU (Address Translation Unit) iATU window table
- `dbi_base + 0x380000` — APP (Application) region (DMA, doorbell)

`apb_base` at `0xfe150000` maps the RK3588 APB peripheral registers:
- `apb + 0x000` — PHY control / link status (partially write-1-set, auto-clears)
- `apb + 0x010` — Interrupt status (write-to-clear)
- `apb + 0x024` — Interrupt mask
- `apb + 0x104/0x108/0x10C/0x114/0x11C` — PHY configuration
- `apb + 0x180` — Link training trigger
- `apb + 0x300` — LTSSM state register (mask `0x3003f`, target L0 = `0x30011`)

### Key register values (node2, link up)

| Register      | Value    | Notes                          |
|---------------|----------|--------------------------------|
| APB+0x000     | 0x0000080C | PHY control (partially RO)   |
| APB+0x024     | 0x00007FFF | Interrupt mask                |
| APB+0x104     | 0x00004407 | PHY config                    |
| APB+0x108     | 0x00000001 |                                |
| APB+0x10C     | 0x0000008C |                                |
| APB+0x114     | 0x0000F173 |                                |
| APB+0x11C     | 0x00000001 |                                |
| APB+0x180     | 0x00000010 | Link training trigger          |
| APB+0x300     | 0x00230011 | LTSSM = L0 (link up)          |
| DBI+0x000     | 0xB6F24586 | Vendor 0xB6F2, Device 0x4586  |
| DBI+0x00A     | 0x00000280 | Class code 0x0280 (network)   |
| DBI+0x100     | 0x14823011 | LTSSM state (low 16 = status) |
| DBI+0x710     | 0x00600001 | Link cap (width = x1, Gen2)   |

---

## 2. Software Architecture (four kernel modules)

```
┌─────────────────────────────────────────────────┐
│                 miop-ep.ko                       │
│  Top-level platform driver                       │
│  binds to "mixtile,miop-ep-rk3588" DT node      │
│  Allocates struct miop_ep, parses DT, orchestrates │
├─────────────────────────────────────────────────┤
│              miop-reg.ko                         │
│  Static registry: stores pointers to lower-layer  │
│  driver structs (pcie_ep_drv, ep_net_drv).       │
│  miop_register_is_ready() polled during probe.   │
├────────────────────┬────────────────────────────┤
│  pcie-ep-rk35.ko   │    miop-ep-net.ko           │
│  Low-level DWC PCIe │    Network layer             │
│  EP controller:     │    Allocates pci0 netdev,    │
│  ioremap DBI/APB,   │    runs peer handshake,      │
│  link train, ATU,   │    TX/RX data path.          │
│  DMA, IRQ.          │                             │
└────────────────────┴────────────────────────────┘
```

### Module interfaces (the registry)

All four modules are independent `.ko` files. At boot, they load in a fixed
order. Each of the three "leaf" modules calls into `miop-reg`'s exported
functions to **register** or **retrieve** a driver struct pointer.

```
  pcie-ep-rk35.ko        miop-ep-net.ko
  module_init():          module_init():
    miop_register_pcie_     miop_register_ep_
      ep_drv(&drv)            net_drv(&drv)

                         miop-ep.ko (platform driver)
                         miop_ep_probe():
                           pcie_drv = miop_register_pcie_ep_drv(NULL)
                           net_drv  = miop_register_ep_net_drv(NULL)
                           // use the retrieved pointers
```

The registry (`reg.c`) is trivial:
```c
static void *pcie_ep_drv;
static void *ep_net_drv;

void *miop_register_pcie_ep_drv(void *drv) {
    void *old = pcie_ep_drv;
    if (drv) pcie_ep_drv = drv;
    else     drv = pcie_ep_drv;  // fetch (NULL = query)
    return old;
}
```

### struct miop_pcie_ep_driver (pcie-ep-rk35 publishes this)

```c
struct miop_pcie_ep_driver {
    int (*init)(struct device *dev);              // → miop_pcie_ep_probe
    int (*deinit)(struct device *dev);
    u32 (*machine_id)(struct device *dev);
    void (*elbi_enable_irq)(struct device *dev, u32 irq_idx);
    void (*elbi_disable_irq)(struct device *dev, u32 irq_idx);
    void (*raise_peer_irq)(struct device *dev, u32 peer_id, u32 vector);
    int (*dma_list_is_full)(struct device *dev, u32 channel);
    void (*dma_list_commit_pending)(struct device *dev);
    void *(*map_peer_bar)(struct device *dev, u32 peer, u64 phys, u32 size, u64 *out_phys);
    void (*unmap_peer_bar)(struct device *dev, u32 peer);
    void *(*map_rc_staging)(struct device *dev, u64 phys, u32 size, u32 dir);
    void (*unmap_rc_staging)(struct device *dev, u32 dir);
    int (*dma_submit)(struct device *dev, u32 ch, u64 data, u64 ext, u32 len, u64 cookie, void *cb);
    int (*dma_submit_batch)(struct device *dev, u32 ch, void *batch, u32 count, u64 comp, void *cb);
};
```

### struct miop_ep_net_driver (miop-ep-net publishes this)

```c
struct miop_ep_net_driver {
    int (*init)(struct device *dev);               // alloc netdev, register pci0
    int (*remove)(struct device *dev);
    int (*on_peer_online)(struct miop_ep *ep, int peer);  // carrier on
    int (*on_peer_offline)(struct miop_ep *ep, int peer);
    int (*on_rx)(struct miop_ep *ep, int peer, void *buf, int len);
    int (*on_tx_ready)(struct miop_ep *ep, int peer);
    int (*on_rx_full)(struct miop_ep *ep, int peer);
};
```

---

## 3. Probe Flow

```
insmod miop-reg.ko
  → miop_reg_module_init(): zeros the registry struct

insmod pcie-ep-rk35.ko
  → miop_pcie_ep_module_init(): registers miop_pcie_ep_driver

insmod miop-ep-net.ko
  → miop_ep_net_module_init(): registers miop_ep_net_driver

insmod miop-ep.ko
  → driver binds to fe150000.pcie (platform device)
  → miop_ep_probe(pdev):
    1. poll miop_register_is_ready() (6 s timeout, 100 ms sleep)
    2. kzalloc(struct miop_ep)
    3. ep->pcie_ep_drv = miop_register_pcie_ep_drv(NULL)
    4. ep->net_drv     = miop_register_ep_net_drv(NULL)
    5. store ep at dev+0x78 (recovered by net init via raw offset)
    6. net_drv->init(dev)           → miop_ep_net_init()
         - alloc_etherdev_mqs(priv_size, 4, 4)
         - register_netdev(netdev)  → creates "pci0"
         - netif_carrier_off(netdev)
         - ep->hw.net_priv = priv
    7. miop_pcie_ep_resource_setup(pdev, &ep->hw)
         - reads DT: DBI/APB resources, reset-gpio, window counts,
           lanes, reserved memory (tx_staging, dma), irq, phy/clocks
    8. clk_bulk_get / clk_bulk_prepare_enable
    9. reset_control_deassert
   10. phy_init / phy_power_on
   11. pcie_drv->init(dev)          → miop_pcie_ep_probe()
         - ioremap DBI (4 MiB), compute dbi_base2 / atu_base
         - ioremap APB (16 KiB)
         - rk35_pcie_ep_window_map_init()  (bitmaps for ATU windows)
         - dmam_alloc_coherent(4 MiB)      (DMA buffer at 0xe000000)
         - Write MIOP shared header into DMA buffer
         - miop_pcie_config_controller():
             · APB glue: writel(0x8000800, apb+0)
                         writel(0x80000000, apb+0x24)
             · APP region: writel(0, dbi+0x380054)
                           writel(0, dbi+0x3800a8)
             · DBI 0x710: link capability width
             · DBI 0x80c: link speed encoding
             · DBI 0x4: device type (6 = EP)
             · DBI 0x8bc: controller enable
             · set_bar x4 (BAR0/2/3/4)
             · Vendor/Device/Class IDs
             · DBI 0x8bc: controller disable
             · Inbound ATU: map DMA buffer for RC access
         - MIOP tag: writel(0x504f494d, dbi+0x200e10)
                     writel(0x100000, dbi+0x200e14)
         - APB trigger: writel(0x100010, apb+0x180)
                        writel(0xf00000, apb+0)
                        writel(0xc000c, apb+0)
         - Poll LTSSM: readl(apb+0x300), msleep(20), up to 5 s
         - On link up: dev_info("PCIe Link up")
                       net_drv->on_peer_online(ep, 0)
         - devm_request_threaded_irq(irq, stub, stub, IRQF_SHARED)
```

---

## 4. Critical Data Structures

### struct miop_pcie (pcie-ep-rk35 private, in miop.h)

| Offset | Field            | Type              | Description                              |
|--------|------------------|-------------------|------------------------------------------|
| +0     | ep               | struct miop_ep *  | back-link to top-level ep                |
| +8     | dbi_base         | void __iomem *    | ioremap of DBI (0xa40000000, 4 MiB)      |
| +16    | dbi_base2        | void __iomem *    | dbi_base + 0x100000 (ATU viewport)       |
| +24    | apb_base         | void __iomem *    | ioremap of APB (0xfe150000, 16 KiB)      |
| +32    | atu_base         | void __iomem *    | dbi_base + 0x300000 (iATU table)         |
| +40    | dev              | struct device *   | for dev_err/dev_info etc.                |
| +48    | map1             | unsigned long *   | inbound window alloc bitmap              |
| +56    | map2             | unsigned long *   | outbound window alloc bitmap             |
| +64    | addrs            | u64 *             | outbound target addresses                |
| +72    | dma_buf          | void *            | 4 MiB coherent DMA buffer                |
| +80    | dma_dma          | dma_addr_t        | DMA address of dma_buf                   |
| +88    | peer_bar_base    | void __iomem *    | ioremap of peer BAR                      |
| +96    | peer_bar_phys    | u64               | physical address of peer BAR             |
| +104   | link_slot        | int               | inbound iATU slot number                 |
| +108   | serial           | u32               | generated serial number                  |
| +112   | link_up          | int               | flag: link has trained                   |
| +120   | link_task        | struct task_struct *| (unused in C; was kthread in factory)  |

**IMPORTANT:** The factory assembly accessed these fields by absolute offset.
Our struct must maintain the same offsets (originally verified against the
factory disassembly, which has since been removed — see "Source layout" below).

### struct miop_ep (top-level, in miop.h)

| Offset | Field            | Type                  |
|--------|------------------|-----------------------|
| +0     | pdev             | struct platform_device * |
| +8     | pcie_ep_drv      | void * (struct miop_pcie_ep_driver *) |
| +16    | net_drv          | void * (struct miop_ep_net_driver *)  |
| +24    | n_free           | u32                   |
| +28    | n_win            | u32                   |
| +32    | hw               | struct miop_ep_hw     |

### struct miop_ep_hw (in miop.h)

| Offset | Field              | Type                |
|--------|-------------------|---------------------|
| +32    | phy               | struct phy *        |
| +40    | clks              | struct clk_bulk_data * |
| +48    | clk_count         | u32                 |
| +56    | reset             | struct reset_control * |
| +64    | regulator         | struct regulator *  |
| +72    | res_dbi           | struct resource *   |
| +80    | res_apb           | struct resource *   |
| +88    | reset_gpio        | struct gpio_desc *  |
| +96    | irq               | int                 |
| +100   | num_ib_windows    | u32                 |
| +104   | num_ob_windows    | u32                 |
| +108   | num_lanes         | u32                 |
| +112   | region_start      | phys_addr_t         |
| +128   | region_size       | u32                 |
| +132   | has_tx_staging    | u8                  |
| +136   | tx_staging_start  | phys_addr_t         |
| +144   | tx_staging_size   | phys_addr_t         |
| +152   | rx_region_ctx     | u64                 |
| +160   | rx_region_size[4] | u32[4]              |
| +208   | rx_region_vaddr[4]| void *[4]           |
| +272   | rx_region_dma[4]  | dma_addr_t[4]       |
| +336   | func_a            | void *              |
| +344   | func_b            | void *              |
| +360   | net_priv          | void *              |

### struct miop_net_priv (in net.c, at netdev + 0xa00)

| Offset | Field           | Type              |
|--------|-----------------|-------------------|
| +0     | ep              | struct miop_ep *  |
| +8     | pcie_drv        | struct miop_pcie_ep_driver * |
| +16    | netdev          | struct net_device * |
| +24    | dev             | struct device *   |
| +32    | tx_ring         | void *            |
| +40    | tx_ring_dma     | dma_addr_t        |
| +48    | tx_lock         | spinlock_t        |

---

## 5. DMA / TX/RX Ring Architecture

The factory implements a descriptor-ring DMA with two channels (TX/RX).

### DMA descriptor (24 bytes)

```c
struct miop_dma_desc {
    u32 status;       // [0x00] completion status
    u32 len;          // [0x04] data length
    u32 addr_low;     // [0x08] buffer DMA address low
    u32 addr_high;    // [0x0c] buffer DMA address high
    u16 meta_len;     // [0x10] metadata length
    u16 meta;         // [0x12] metadata flags
    u32 meta2;        // [0x14] extended metadata
};
```

### Ring structure

Each ring is a circular buffer of `MIOP_DMA_RING_SIZE` (128) descriptors
at `dma_buf + 0x100000` (TX) and `dma_buf + 0x101000` (RX). The producer
and consumer indices are maintained in the pcie private data.

### Data flow

```
TX path:
  miop_ndo_start_xmit(skb)
    → dma_map_single(skb->data)
    → pcie_drv->dma_submit(ch=0, dma_addr, ext, len, cookie, callback)
      → miop_rk35_dma_submit()  [TODO: implement]
        → write descriptor into ring
        → rk35_dma_start_write()
          → writel(trigger, dbi+0x380000+doorbell)

RX path:
  rk35_ep_interrupt(irq)  [TODO: implement]
    → read apb+0x10 (status)
    → miop_dma_try_reap()
      → read completed descriptors
      → net_drv->on_rx(ep, peer, buf, len)
        → miop_on_rx()
          → netdev_alloc_skb + skb_put_data + netif_receive_skb
    → miop_raise_peer_irq()
      → write DBI doorbell to notify peer

Peer handshake (on link up):
  on_peer_online(ep, peer)
    → netif_carrier_on(netdev)
    → (TODO) outbound ATU to discovered peer BAR target
    → (TODO) descriptor ring setup
```

---

## 6. Translation status (fully in C)

The MiOP driver is **fully implemented in C** (`reg.c`, `ep.c`, `net.c`,
`pcie.c`). The original ARM64 disassembly of the factory binary
(`reg_asm.S`, `ep_asm.S`, `net.S`, `pcie_asm.S`) was reference material
only — it was never compiled (the Makefile builds only the `.c` objects) —
and was deleted on 2026-07-14 (commit `dac732e`).

Every function the factory binary exposed has a working C definition. The
table below maps the factory symbol names to their current C locations
(verified against the working 3-node ping).

### Implemented in C (pcie.c unless noted)

| Factory symbol                | C location            |
|-------------------------------|-----------------------|
| rk35_pcie_ep_window_map_init  | pcie.c:140            |
| rk35_pcie_ep_window_map_deinit| pcie.c:166            |
| rk35_pcie_readl_dbi           | pcie.c:137            |
| rk35_pcie_readw_dbi           | pcie.c:146            |
| miop_ep_generate_serial       | pcie.c:61             |
| miop_ep_machine_id            | pcie.c:104 / ep.c     |
| miop_ep_map_outbound_atu      | pcie.c:213            |
| miop_ep_unmap_outbound_atu    | pcie.c:184            |
| rk35_pcie_ep_set_bar          | pcie.c:298            |
| miop_rk35_dma_submit          | pcie.c:592            |
| miop_rk35_dma_submit_batch    | pcie.c:1002           |
| miop_dma_try_reap             | pcie.c:709            |
| miop_dma_list_commit_pending  | pcie.c:935            |
| miop_raise_peer_irq           | pcie.c:789            |
| miop_elbi_enable_irq          | pcie.c:953            |
| miop_elbi_disable_irq         | pcie.c:970            |
| miop_rk35_map_peer_bar        | pcie.c (local helper) |
| miop_rk35_map_rc_staging      | pcie.c:992            |
| miop_rk35_unmap_peer_bar      | pcie.c                |
| miop_rk35_unmap_rc_staging    | pcie.c                |
| miop_dma_list_is_full         | pcie.c:922            |
| rk35_dma_start_write          | pcie.c:538            |
| miop_pcie_rx_region_alloc     | ep.c:59               |
| miop_pcie_rx_region_free      | ep.c:130              |
| miop_pcie_ep_resource_setup   | ep.c:165              |
| miop_ep_probe / remove        | ep.c:294 / ep.c:446   |
| miop_xmit_to_peer_new / ndo   | net.c                 |
| miop_register_pcie_ep_drv     | reg.c                 |

---

## 7. Current Status (2026-07-14)

- **PCIe link trains to L0** (LTSSM = 0x230011, matched node2 reference).
- **pci0 interface appears** with IP `10.20.0.x/24` and `LOWER_UP`.
- **on_peer_online** → `netif_carrier_on(netdev)` succeeds (no crash).
- **ping to management network** (e.g. `192.168.0.202`) works via `bond0`.
- **ping across the PCIe fabric works node-to-node** (0% loss) after the
  DMA/doorbell translation was completed (`miop_ndo_start_xmit` →
  `dma_submit` writes the descriptor ring and triggers the peer doorbell).
- **IRQ handler** reaps DMA completions and calls `on_rx`.

### Build / Deploy

Build host is the x86 dev VM. `build.sh` tarballs the **local** source and
`scp`s it to node3 (it does NOT `git clone`, so local edits are preserved),
then cross-compiles the four `.ko` modules there. Deploy copies them to
`/lib/miop/` on node3. A hard power-cycle is required after deploy (no clean
live-reload).

```sh
cd /root/miop
git pull                       # confirm remote HEAD first
./build.sh                     # tarball local src -> node3 -> cross-compile
./deploy.sh                    # copy .ko to /lib/miop/ on node3
./power-cycle.sh               # reboot cluster
```

### ABI Warning — struct offsets match factory

The `struct miop_pcie` layout matches the factory binary offset-for-offset
(originally verified against the factory disassembly, now removed). When
adding a field accessed by absolute offset, check `miop.h` to confirm which
field lives at that offset and place new fields at the correct offset.

Current struct offset mapping:
- `pcie_priv + 8` → `dbi_base`
- `pcie_priv + 16` → `dbi_base2` (dbi_base + 0x100000)
- `pcie_priv + 24` → `apb_base`
- `pcie_priv + 32` → `atu_base` (dbi_base + 0x300000)

The factory init targets `pcie_priv + 24` (= `apb_base`) for all APB glue
and trigger writes. Our earlier mistake was targeting `dbi_base2` (+16)
instead.
