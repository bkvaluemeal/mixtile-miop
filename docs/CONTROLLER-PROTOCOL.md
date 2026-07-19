# Controller (RC) MIOP Protocol — Reverse-Engineered from miop.ko

Source: `/root/controller-src/package/custom-files/files/lib/modules/5.15.150/miop.ko`
Platform: OpenWrt MIPS32r2 (MT7620), kernel 5.15.150
Disassembly: `mipsel-linux-gnu-objdump` (binutils-mipsel-linux-gnu)

## Overview

The controller's `miop.ko` runs on the PCIe Root Complex (MT7620/MIPS)
and manages up to 4 RK3588 blade nodes acting as PCIe Endpoints.
Two communication paths exist: an **old path** (ELBI-based, limited)
and a **new path** (BAR-based DMA, full throughput). The "new path"
requires both BAR0 and BAR4 to be functional on the EP.

---

## Key Structures (from DWARF debug info)

### miop_bar_header (64 bytes) — at BAR0+0

| Offset | Field          | Type | Description                     |
|--------|----------------|------|----------------------------------|
| 0      | magic          | u32  | Must be `0x504f494d` ("MIOP")   |
| 4      | layout_version | u32  | Must be `0x00020000`            |
| 8      | machine_id     | u32  | EP serial number                |
| 12     | self_node_id   | u32  | EP's node ID                    |
| 16..63 | (more fields)  | …    | Additional header data          |

### miop_bar_ctrl (8448 bytes) — the full BAR0 layout

| Offset   | Field  | Description                            |
|----------|--------|-----------------------------------------|
| 0        | header | miop_bar_header (64 bytes)              |
| 64       | peer   | Per-peer descriptor array              |
| 4096     | rxq    | RX queue / DMA descriptors             |
| 8192     | event  | Event notification region              |

### miop_host_desc (32 bytes) — shared descriptor format

| Offset | Field          | Type   | Description                      |
|--------|----------------|--------|----------------------------------|
| 0      | layout_version | u32    | Layout version tag               |
| 4      | machine_id     | u32    | Machine identifier               |
| 8      | intx_message   | u32    | INTx message data                |
| 12     | reserved       | u8[20] | Reserved / padding               |

The controller validates a `miop_host_desc` at `BAR0_base + desc_offset`
and expects offset 0 to contain `0x103` (259 decimal) as a desc-type magic.

### miop_node_context (3728 bytes) — per-node tracking

Key fields (byte offsets):

| Offset | Field               | Description                              |
|--------|---------------------|------------------------------------------|
| 0      | bus_number          | PCI bus number                           |
| 4      | node_id             | MIOP node ID                             |
| 8      | machine_id          | Machine serial                           |
| 12     | node_ready          | Bool: peer handshake complete            |
| 36     | pdev                | struct pci_dev *                         |
| 40     | desc_base           | ioremap'd BAR4 base (DMA rings)          |
| 44     | dma_reg_base        | ioremap'd BAR0 base (bar_ctrl)           |
| 68     | bar_ctrl            | miop_bar_ctrl * (allocated locally)      |
| 72     | bar0_pci_base       | BAR0's PCI bus address                   |
| 80     | desc_offset_in_bar  | Offset of desc within BAR0               |
| 84     | new_tx_staging      | TX staging buffer ptr                    |
| 88     | new_tx_staging_dma  | TX staging DMA addr                      |
| 92     | new_rx_ring         | RX ring buffer ptr                       |
| 96     | new_rx_ring_dma     | RX ring DMA addr                         |
| 100    | new_tx_prod         | TX producer index                        |
| 104    | new_tx_published    | TX published flag                        |
| 108    | new_tx_cons_cache   | TX consumer cache                        |
| 112    | new_tx_doorbell     | TX doorbell address                      |
| 116    | new_tx_ring_offset  | TX ring offset within BAR                |
| 120    | new_rx_cons         | RX consumer index                        |
| 124    | new_peer_stalled    | Peer backpressure flag                   |

---

## Controller Probe Flow (miop_host_probe)

The probe is called once per discovered PCIe EP device. The sequence is:

### Phase 1: PCI BAR mapping

1. **`pci_iomap(pdev, BAR0, 0)`** — maps BAR0 (bar_ctrl region)
   - On failure: dev_err "pci_iomap() BAR0 failed" → abort
   - Result stored as the `dma_reg_base` for the node

2. **`pci_iomap(pdev, BAR4, 0)`** — maps BAR4 (DMA descriptor rings)
   - On failure: dev_err "pci_iomap() BAR4 failed" → abort
   - Result stored as the `desc_base` for the node

3. **`pci_alloc_irq_vectors_affinity(pdev, 1, 4, ...)`**
   - Requests 1 MSI-X, up to 4 IRQ vectors

### Phase 2: ELBI config-space discovery

The controller reads 3 DWORDs from the EP's PCI config space:

| Config Offset | DBI Register (EP side) | Expected Value / Purpose |
|---------------|------------------------|---------------------------|
| **0xE10**     | DBI+0x200e10           | `0x504f494d` ("MIOP" magic) |
| **0xE14**     | DBI+0x200e14           | Ring flag (0x100000) or desc offset within BAR0 |
| **0xE18**     | DBI+0x200e18           | DESC_OFFSET: descriptor offset within BAR0 |

#### 0xE10 validation (line 10c0-10f0)
```
if (config_0xE10 != 0x504f494d)
    dev_err("Node is not prepared: %04x", val);
    → ABORT
```

#### 0xE14 usage (line 1128-11a0)
The 0xE14 value is used as the offset from BAR0 base to locate the shared
descriptor. The controller:
1. Reads ioread32(BAR0_base + 0) — validates == "MIOP"
2. Reads ioread32(BAR0_base + 4) — validates == 0x00020000 (layout_version)
3. Reads ioread32(BAR0_base + 8) — captures machine_id

If either check (1) or (2) fails, the controller falls back to the
**old path** (dev_info "no bar_ctrl ..., new path disabled").

#### 0xE18 usage (line 1224-129c)
Reads the descriptor at `BAR0_base + config_0xE18` and checks that
offset 0 contains `0x103`. If valid, it allocates a local DMA buffer
(128KB) for the node's TX staging / RX ring infrastructure and
initializes the "new path" DMA rings.

### Phase 3: New-path DMA setup

4. Allocates a 128KB (`0x20000`) coherent DMA buffer
5. The descriptor at `BAR0 + desc_offset` is used to construct per-node
   TX staging and RX ring buffers
6. Writes the node_id back to the EP's shared header area

### Phase 4: Node online announcement

7. Registers the pci%d netdev (via alloc_etherdev)
8. Sets MAC from device serial
9. Writes "online" IRQ message (type 0x8) to config offset **0xE00**
10. Enables NAPI, IRQ handlers, starts polling

---

## Config Write Operations (pci_write_config_dword)

**Only one config offset is ever written: 0xE00** (DBI+0x200e00 on EP).

Three call sites write different message types:

| Function                     | Message Type | Purpose                       |
|------------------------------|-------------|-------------------------------|
| miop_irq_trigger_work        | (computed)  | Generic IRQ message           |
| miop_online_trigger_work     | 0x8         | Peer online notification      |
| miop_offline_trigger_work    | 0x10        | Peer offline notification     |

The EP-side interrupt handler decodes these writes as peer events.
The 0xE00 register is the **ELBI inbound message register** — a DWC EP
mechanism for the RC to send interrupt-like messages to the EP.

---

## Bar-Ctrl Header Validation (detailed)

After mapping BAR0, the controller validates the `miop_bar_header`:

```
val_at_0   = ioread32(BAR0_base + 0);     // magic
val_at_4   = ioread32(BAR0_base + 4);     // layout_version
val_at_8   = ioread32(BAR0_base + 8);     // machine_id
```

**Required values for "new path" enablement:**
- `val_at_0 == 0x504f494d` ("MIOP")
- `val_at_4 == 0x00020000`

If both match: logs `node[%u] bar_ctrl@BAR0+0 magic=0x%x ver=0x%x machine_id=0x%x bar0_pci=0x%llx`
If either fails: logs `node[%u] no bar_ctrl (magic=0x%x ver=0x%x), new path disabled`

The "old path" (no bar_ctrl) uses only ELBI message-based communication.
The "new path" (with bar_ctrl) adds DMA-based TX staging buffers and
RX rings for full-throughput operation.

---

## What Our EP Must Provide

### 1. ELBI registers (DBI+0x200e00–0x200e18)

| EP DBI Offset | Config Offset | Value to write | Purpose                 |
|---------------|---------------|----------------|--------------------------|
| 0x200e00      | 0xe00         | — (RC writes)  | Inbound message register |
| 0x200e08/0c   | —             | 0xffff0000     | **ELBI LOCAL ENABLE** — enables snoop on BAR0 writes |
| 0x200e10      | 0xe10         | 0x504f494d     | "MIOP" magic tag         |
| 0x200e14      | 0xe14         | 0x40           | Desc offset within BAR0 (constroller reads as BAR0+this) |
| 0x200e18      | 0xe18         | 0              | RX desc offset           |
| APB+0x24      | —             | 0x40000\|0x80000000\|0x0c000000 | CLIENT_INTR_MASK (RMW) |

**CRITICAL**: All ELBI register writes MUST happen while `DBI+0x8BC` bit 0 is set
(inside `miop_pcie_config_controller`).  Writes outside this window are silently ignored.

### 2. BAR0 (shared header / bar_ctrl)

Must be configured with sufficient size (currently 32MB via REBAR).
The shared header at BAR0 offset 0 must contain:

| Offset | Value         | Meaning            |
|--------|---------------|--------------------|
| 0      | 0x504f494d    | "MIOP" magic       |
| 4      | 0x00020000    | layout_version     |
| 8      | serial        | machine_id         |
| 12     | 0xffffffff    | (field TBD)        |
| 16     | 1             | (field TBD)        |

Our `pcie.c:1353-1361` writes this header to the DMA buffer start.
The inbound ATU must map the RC's BAR0 PCIe address to this buffer.

### 3. BAR4 (DMA descriptor rings)

Must be configured (currently 1MB via REBAR + set_bar).
The controller maps this for the "new path" DMA infrastructure.

### 4. Inbound iATU

The inbound ATU must translate RC PCIe addresses to the correct
local DMA buffer regions. Currently `miop_pcie_map_inbound_atu`
creates a single window mapping the entire address space to the
DMA buffer. It's unclear if the DWC EP properly routes separate
BAR0 and BAR4 PCIe addresses to different regions.

---

## Open Questions

1. **eDMA destination addressing** — The eDMA `meta_len/meta/meta2` fields
   may encode PCIe addresses directly (bypassing the outbound ATU). If true,
   `peer_pci_dma/peer_pci_elbi` should use PCIe addresses (peer BAR0 + offset)
   rather than outbound physical addresses (0x900000000 + offset). This is the
   next thing to test once nodes recover.

2. **Doorbell still not firing** — Despite ELBI LOCAL_ENABLE and correct inbound
   ATU, `RXpoll` remains 0.  Either the eDMA doorbell write never reaches the
   peer, or the ELBI snoop doesn't capture memory writes to BAR0+0x200e00.

3. **BAR4 separate inbound mapping** — The controller uses BAR4 for DMA rings
   ("new path").  May need a second inbound ATU window for BAR4.

## Resolved (2026-07-18)

1. ✅ Inbound ATU BAR match mode — `CTRL2=0xC0080000`, BIT(8) base,
   register offsets @0x14/0x18.  Controller successfully reads bar_ctrl.
2. ✅ REBAR values — `cap=0x5C0` for BAR0 (matches factory), clear loop
   for unused BARs eliminates ghost 512MB allocations.
3. ✅ ELBI register initialization — all values written inside 0x8BC enable
   window.  Controller reads config 0xE10/E14/E18 correctly.
4. ✅ Outbound ATU register layout — TARGET@0x08, LIMIT@0x10/0x20, SIZE@0x14.
   Non-standard layout specific to RK3588 DWC EP.
5. ✅ `miop_node_id` parameter — per-node bus offset mapping.
6. ✅ BAR0 assigned by RC at 0x20000000 (bus 03), 0x20800000 (bus 05).
