/* SPDX-License-Identifier: GPL-2.0 */
/*
 * miop.h - Shared types for the Mixtile PCIe TCP/IP-over-PCIe driver stack.
 *
 * These structures are the C reconstruction of the original vendor .ko
 * disassembly. The layout of struct miop_ep is ABI-critical: the lower-layer
 * modules (pcie-ep-rk35.ko, miop-ep-net.ko) and the asm builds address its
 * fields by absolute offset, so the field offsets below must not change.
 */
#ifndef MIOP_H
#define MIOP_H

#include <linux/types.h>
#include <linux/skbuff.h>
#include <linux/device.h>
#include <linux/phy/phy.h>
#include <linux/reset.h>
#include <linux/regulator/consumer.h>
#include <linux/gpio/consumer.h>
#include <linux/clk.h>
#include <linux/resource.h>
#include <linux/of.h>

/* Forward declaration so the driver-struct callbacks below can name
 * struct miop_ep in their parameter lists without a local forward decl. */
struct miop_ep;

/* Forward declaration of the pcie private struct (defined fully below). The
 * pcie-ep-rk35.ko probe allocates one of these and hangs it off struct miop_ep
 * so the ATU / region helpers and the net layer can reach it. */
struct miop_pcie;

/* Driver structs published into the miop-reg registry. Only the function
 * pointers exercised by miop-ep.ko are typed here; the remaining slots are
 * filled in by pcie-ep-rk35.ko / miop-ep-net.ko and used internally. */
struct miop_pcie_ep_driver {
	int (*probe)(struct device *dev);
	unsigned long priv[8];
};

/* The network-layer driver struct as published by miop-ep-net.ko. Offsets
 * below are reproduced from net.S (the _data struct at the end of the file):
 *   init@0x00  deinit@0x08  on_peer_online@0x10  on_peer_offline@0x18
 *   on_rx@0x20  on_tx_ready@0x28  on_rx_full@0x30
 * miop-ep.ko only touches init/remove; the rest are used internally by
 * pcie-ep-rk35.ko to drive the peer/link handshake. */
struct miop_ep_net_driver {
	int (*init)(struct device *dev);
	int (*remove)(struct device *dev);
	int (*on_peer_online)(struct miop_ep *ep, int peer);
	int (*on_peer_offline)(struct miop_ep *ep, int peer);
	int (*on_rx)(struct miop_ep *ep, int peer, void *buf, int len);
	int (*on_tx_ready)(struct miop_ep *ep, int peer);
	int (*on_rx_full)(struct miop_ep *ep, int peer);
};

/*
 * struct miop_ep_hw - the hardware/resource sub-struct, located at offset 0x18
 * of struct miop_ep. Field offsets below are taken directly from the asm.
 */
/*
 * NOTE on layout: the lower-layer modules (pcie-ep-rk35.ko, miop-ep-net.ko)
 * and the asm builds address these fields by ABSOLUTE offset, so the gaps
 * below are not accidental padding - they must be reproduced exactly or the
 * RX callbacks / region bookkeeping will not line up. The original binary
 * confirms (via pcie.S / ep.S disassembly) the following hw offsets:
 *   region_start@0x50  region_size@0x60  field@0x78 (pcie-ep-rk35 owned)
 *   rx_region_size[4]@0x80  rx_region_vaddr[4]@0xa0  rx_region_dma[4]@0xe0
 *   func_a@0x120  func_b@0x128
 */
struct miop_ep_hw {
	struct phy *phy;			/* +0x00 (ep+0x18) */
	struct clk_bulk_data *clks;		/* +0x08 (ep+0x20) */
	u32 clk_count;				/* +0x10 (ep+0x28) */
	u32 _pad0[1];
	struct reset_control *reset;		/* +0x18 (ep+0x30) */
	struct regulator *regulator;		/* +0x20 (ep+0x38) */
	struct resource *res_dbi;		/* +0x28 (ep+0x40) */
	struct resource *res_apb;		/* +0x30 (ep+0x48) */
	struct gpio_desc *reset_gpio;		/* +0x38 (ep+0x50) */
	int irq;				/* +0x40 (ep+0x58) */
	u32 num_ib_windows;			/* +0x44 (ep+0x5c) */
	u32 num_ob_windows;			/* +0x48 (ep+0x60) */
	u32 num_lanes;				/* +0x4c (ep+0x64) */
	phys_addr_t region_start;		/* +0x50 memory-region start */
	u64 _pad_region;			/* +0x58 8-byte hole before size */
	u32 region_size;			/* +0x60 memory-region size */
	u8 has_tx_staging;			/* +0x64 */
	u8 _pad2[3];
	phys_addr_t tx_staging_start;		/* +0x68 miop,tx-staging-region start */
	phys_addr_t tx_staging_size;		/* +0x70 miop,tx-staging-region size */
	u64 rx_region_ctx;			/* +0x78 written by pcie-ep-rk35.ko */
	u32 rx_region_size[4];			/* +0x80 per-index RX region size */
	u64 _pad_90[2];				/* +0x90 .. +0xa0 gap */
	void *rx_region_vaddr[4];		/* +0xa0 CPU virtual address of RX ring */
	u64 _pad_c0[4];				/* +0xc0 .. +0xe0 gap */
	dma_addr_t rx_region_dma[4];		/* +0xe0 bus address of RX ring */
	u64 _pad_100[4];			/* +0x100 .. +0x120 gap */
	void *func_a;				/* +0x120 = miop_pcie_rx_region_alloc */
	void *func_b;				/* +0x128 = miop_pcie_rx_region_free */
	u64 _pad130;				/* +0x130 */
	void *net_priv;				/* +0x138 (ep+0x150) back-link to net priv */
};

/* struct miop_pcie - the pcie-ep-rk35.ko private context, allocated in
 * miop_pcie_ep_probe() and referenced by the ATU / window-map helpers. Field
 * semantics are taken from the pcie.S disassembly (dbi/apb/atu bases, the
 * outbound-window bitmaps, the TX/DMA buffer); the exact byte layout is our
 * own (the lower layers all agree on these field names). */
struct miop_pcie {
	struct miop_ep *ep;		/* back-pointer to the per-blade context */
	void __iomem *dbi_base;		/* ioremap of the DBI register window */
	void __iomem *dbi_base2;	/* DBI + 0x100000 (controller block) */
	void __iomem *apb_base;		/* ioremap of the APB register window */
	void __iomem *atu_base;		/* DBI + 0x300000 (outbound iATU windows) */
	struct device *dev;		/* the endpoint struct device */
	unsigned long *map1;		/* window bitmap #1 (kcalloc) */
	unsigned long *map2;		/* outbound alloc bitmap (kcalloc) */
	u64 *addrs;			/* per-window mapped target low (kcalloc) */
	void *dma_buf;		/* 0x400000 TX/DMA coherent buffer (CPU va) */
	dma_addr_t dma_dma;		/* 0x400000 TX/DMA buffer bus address */
};

/* struct miop_ep - per-blade endpoint context. */
struct miop_ep {
	struct platform_device *pdev;		/* +0x00 */
	void *pcie_ep_drv;			/* +0x08 */
	void *net_drv;				/* +0x10 */
	u32 n_free;				/* outbound-window free count */
	u32 n_win;				/* outbound-window total count */
	struct miop_ep_hw hw;			/* +0x18 */
	struct miop_pcie *pcie_priv;		/* set by pcie-ep-rk35.ko probe */
};

/* EP-layer API implemented in ep.c and consumed by the lower-layer modules.
 * The two rx_region_* helpers are published into struct miop_ep_hw (func_a /
 * func_b) and invoked by pcie-ep-rk35.ko via those pointers. Their second
 * argument is the &struct miop_ep_hw (the layout the caller expects), not the
 * top-level &struct miop_ep. */

/* Registry API provided by miop-reg.ko (declared here so every module in the
 * stack can call it without pulling in reg.c). */
void *miop_register_pcie_ep_drv(void *drv);
void *miop_register_ep_net_drv(void *drv);
int miop_register_is_ready(void);
void miop_free_dma_skb_head(struct device *dev, struct sk_buff *skb, size_t size);

int miop_pcie_ep_resource_setup(struct platform_device *pdev,
				struct miop_ep_hw *hw);
int miop_pcie_rx_region_alloc(struct device *dev, struct miop_ep_hw *hw,
			      unsigned int idx);
void miop_pcie_rx_region_free(struct device *dev, struct miop_ep_hw *hw,
			      unsigned int idx);

#endif /* MIOP_H */
