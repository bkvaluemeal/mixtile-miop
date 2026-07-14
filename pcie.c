// SPDX-License-Identifier: GPL-2.0
//
// pcie-ep-rk35: low-level RK35 PCIe endpoint + DMA driver for the Mixtile
// TCP/IP-over-PCIe stack.
//
// C reimplementation of the factory pcie_asm.S. This is the lowest layer
// of the stack: it owns the RK3588 PCIe EP controller, trains the link
// against the peer blade, programs the inbound/outbound iATU windows, wires
// up the MSI/legacy IRQ and runs the peer/link handshake that drives
// miop-ep-net.ko's on_peer_* callbacks.
//
// Status (2026-07-12):
//   ✅ PCIe link trains to L0 (LTSSM = 0x230011)
//   ✅ pci0 netdev created with IP and carrier
//   ✅ on_peer_online succeeds (netif_carrier_on)
//   ❌ TX data path (dma_submit) is a stub — ping via pci0 fails
//   ❌ IRQ handler is a stub (clears status, does not reap DMA)
//   ❌ DMA descriptor rings not yet wired
//   ❌ Peer doorbell / handshake not implemented
//
// See docs/STATUS.md for the full translation progress and docs/ARCHITECTURE.md
// for the system-level design.

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/device.h>
#include <linux/io.h>
#include <linux/slab.h>
#include <linux/bitops.h>
#include <linux/delay.h>
#include <linux/platform_device.h>
#include <linux/dma-mapping.h>
#include <linux/interrupt.h>
#include <linux/of_irq.h>
#include <linux/workqueue.h>
#include <linux/debugfs.h>

#include "miop.h"

/* Single active instance (one PCIe EP on the RK35 board). */
static struct miop_pcie *g_pcie;

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe RK35 EP driver (C pass)");

/*
 * miop_ep_generate_serial() / miop_ep_machine_id() - serial & MAC id.
 *
 * Translated from pcie.S. The vendor derives a per-blade serial from the
 * SoC system serial (system_serial_low / system_serial_high) via a small
 * mixing hash, and the MAC address from that serial. In the factory module
 * these two globals are populated from the SoC; here they are left as zeroes
 * (TODO: source them from the DT "serial-number" / RK3588 OTP) so the
 * translated algorithm is exercised without a hard dependency on the board
 * serial.
 */
static u32 system_serial_low;
static u32 system_serial_high;

/* Faithful C of miop_ep_generate_serial() from pcie.S. */
static u32 miop_ep_generate_serial(void)
{
	u32 low = system_serial_low;
	u32 high = system_serial_high;
	u32 w0 = 0xdeadbef7;
	u32 w1 = (high & 0xffff00ff) + w0;
	u32 w4 = w0 + (u8)low;
	u32 w2 = (low & 0xffff0000) + w4;

	w1 += high & 0xff00;
	w2 += low & 0xff00;

	w0 = w1 ^ w0;
	w0 -= ror32(w1, 18);

	w2 ^= w0;
	w2 -= ror32(w0, 21);

	w1 ^= w2;
	w1 -= ror32(w2, 7);

	w0 ^= w1;
	w0 -= ror32(w1, 16);

	w2 ^= w0;
	w2 -= ror32(w0, 28);

	w1 ^= w2;
	w1 -= ror32(w2, 18);

	w0 ^= w1;
	w0 -= ror32(w1, 8);

	return w0;
}

/*
 * miop_ep_machine_id() - per-blade id used to derive the MAC.
 * Translated from pcie.S: walks ep+0x78 -> +0x148; if either link is NULL
 * it falls back to miop_ep_generate_serial(), otherwise returns the cached
 * id at +4. NOTE: the ep+0x78 / +0x148 offsets are the factory struct layout
 * and will need reconciliation with struct miop_ep once this is wired in.
 */
u32 miop_ep_machine_id(struct miop_ep *ep)
{
	void *p1 = *(void **)((char *)ep + 0x78);
	void *p2;

	if (!p1)
		return miop_ep_generate_serial();

	p2 = *(void **)((char *)p1 + 0x148);
	if (!p2)
		return miop_ep_generate_serial();

	return *(u32 *)((char *)p2 + 4);
}
EXPORT_SYMBOL(miop_ep_machine_id);

/*
 * Outbound iATU / window-map helpers — translated from pcie.S.
 *
 * These operate on struct miop_pcie (see miop.h). The asm used absolute
 * offsets into the pcie private; here they are mapped to named fields. The
 * helpers are exported because miop-ep-net.ko's data path calls them once the
 * link is up.
 */

/* kmalloc_array.constprop.0 in pcie.S allocates (n*8) bytes (size inlined to 8). */
static void *miop_kcalloc_arr(unsigned long n)
{
	return kcalloc(n ? n : 1, 8, GFP_KERNEL);
}

/* rk35_pcie_readl_dbi / _readw_dbi: the vendor's DBI accessor (the asm has a
 * decompiler-introduced self-loop artifact; the real op is just the read). */
u32 rk35_pcie_readl_dbi(void *dbi, u32 off)
{
	return readl((char *)dbi + off);
}

u16 rk35_pcie_readw_dbi(void *dbi, u32 off)
{
	return readw((char *)dbi + off);
}
EXPORT_SYMBOL(rk35_pcie_readl_dbi);
EXPORT_SYMBOL(rk35_pcie_readw_dbi);

int rk35_pcie_ep_window_map_init(struct miop_pcie *pcie)
{
	struct miop_ep *ep = pcie->ep;
	unsigned long n_free = ep->n_free;
	unsigned long n_win  = ep->n_win;
	void *b;

	b = miop_kcalloc_arr((n_free + 0x3f) >> 6);
	if (!b)
		return -ENOMEM;
	pcie->map1 = b;

	b = miop_kcalloc_arr((n_win + 0x3f) >> 6);
	if (!b)
		return -ENOMEM;
	pcie->map2 = b;

	b = miop_kcalloc_arr(n_win);
	if (!b)
		return -ENOMEM;
	pcie->addrs = b;

	return 0;
}
EXPORT_SYMBOL(rk35_pcie_ep_window_map_init);

void rk35_pcie_ep_window_map_deinit(struct miop_pcie *pcie)
{
	kfree(pcie->map1); pcie->map1 = NULL;
	kfree(pcie->map2); pcie->map2 = NULL;
	kfree(pcie->addrs); pcie->addrs = NULL;
}
EXPORT_SYMBOL(rk35_pcie_ep_window_map_deinit);

/* Find the outbound slot whose stored target == @addr and tear it down. */
int miop_ep_unmap_outbound_atu(struct miop_pcie *pcie, u64 addr)
{
	struct miop_ep *ep = pcie->ep;
	unsigned long n_win = ep->n_win;
	u64 *addrs = pcie->addrs;
	unsigned long bit;

	for (bit = 0; bit < n_win; bit++)
		if (addrs[bit] == addr)
			break;
	if (bit >= n_win)
		return 0;

	writel(bit, (char *)pcie->dbi_base + 0x900);
	writel(0x7fffffff, (char *)pcie->dbi_base + 0x908);

	clear_bit(bit, pcie->map2);
	return 0;
}
EXPORT_SYMBOL(miop_ep_unmap_outbound_atu);

/*
 * miop_ep_map_outbound_atu(pcie, target, size, extra) - program one outbound
 * iATU window. The factory's miop_rk35_map_peer_bar passes phys as `target`
 * and expects a 1:1 map (local CPU physical == PCIe target), so a write to
 * ioremap(target) is translated by the iATU onto the fabric at `target`.
 * `size` is the window size, `extra` an added offset folded into the limit.
 * Returns 0 on success, -EINVAL if no free window.
 */
int miop_ep_map_outbound_atu(struct miop_pcie *pcie, u64 target, u32 size, u32 extra)
{
	struct miop_ep *ep = pcie->ep;
	unsigned long n_win = ep->n_win;
	unsigned long bit;
	void *win;
	int tries = 5;
	u32 t_lo = (u32)(target & 0xffffffff);
	u32 t_hi = (u32)(target >> 32);
	u64 limit = target + size - 1 + extra;

	bit = find_first_zero_bit(pcie->map2, n_win);
	if (bit >= n_win) {
		dev_err(pcie->dev, "outbound free_win exhausted\n");
		return -EINVAL;
	}

	win = (char *)pcie->atu_base + (bit << 9);
	/* Register layout transcribed from the factory miop_ep_map_outbound_atu
	 * (pcie_asm.S:1116-1162): target at +0x8/+0xc, limit at +0x10/+0x20,
	 * size at +0x14/+0x18, control(enable) at +0x4.  The source/base (+0x0)
	 * is left 0; the factory relies on target+limit+size alone. */
	writel(t_lo, (char *)win + 0x8);          /* target lower */
	writel(t_hi, (char *)win + 0xc);          /* target upper */
	writel((u32)(limit & 0xffffffff), (char *)win + 0x10);   /* limit lower */
	writel((u32)(limit >> 32),       (char *)win + 0x20);   /* limit upper */
	writel(size,  (char *)win + 0x14);        /* size lower */
	writel(0,     (char *)win + 0x18);        /* size upper */
	writel(0,     (char *)win + 0x0);         /* source/base */
	writel(0x80000000, (char *)win + 0x4);    /* enable */

	while (tries--) {
		int i;
		for (i = 0; i < 9; i++) {
			if (readl((char *)win + 0x4) & (1u << 31))
				goto enabled;
			udelay(250);
		}
	}

	dev_err(pcie->dev, "outbound ATU enable timeout (win %lu)\n", bit);
enabled:
	dev_err(pcie->dev, "outbound free_win %lu target %#llx size %#x\n",
		bit, (unsigned long long)target, size);

	set_bit(bit, pcie->map2);
	pcie->addrs[bit] = target;
	return 0;
}
EXPORT_SYMBOL(miop_ep_map_outbound_atu);

/*
 * miop_map_peer_bar() - map one per-peer outbound iATU window (local mirror of
 * the factory's miop_rk35_map_peer_bar).  Programs an outbound window that
 * translates a CPU write at `target` onto the fabric at `target` (identity
 * map, matching the factory), then ioremaps `target` so callers can write the
 * doorbell/data into it.  Returns the ioremap VA; *out_phys gets `target`.
 */
void *miop_map_peer_bar(struct miop_pcie *pcie, u64 target, u32 size, u64 *out_phys)
{
	void __iomem *va;

	if (!pcie || !size)
		return NULL;

	if (miop_ep_map_outbound_atu(pcie, (u32)(target & 0xffffffff), size, 0)) {
		dev_warn(pcie->dev, "map_peer_bar: ATU failed target=0x%llx\n",
			 (unsigned long long)target);
		return NULL;
	}

	va = ioremap(target, size);
	if (IS_ERR_OR_NULL(va)) {
		miop_ep_unmap_outbound_atu(pcie, target);
		return NULL;
	}

	if (out_phys)
		*out_phys = target;
	return va;
}
EXPORT_SYMBOL(miop_map_peer_bar);

/*
 * miop_pcie_ep_set_bar() - program one EP BAR. Transcribed from pcie.S
 * rk35_pcie_ep_set_bar.isra.0. The original ran on the vendor's struct
 * rockchip_pcie (dbi_base @0, apb_base @8); we drive our raw mmio directly.
 *
 * The vendor computed the BAR register offset as (base_idx + bar*8) where
 * base_idx was read from rockchip_pcie+0x20 (assumed here to be the outbound
 * window count, ep->n_win, which matches the +0x80-aligned BAR table the RK
 * DWC EP uses). The arithmetic below reproduces the asm exactly relative to
 * dbi_base (BAR regs) and apb_base (64-bit shadow). All writes stay inside the
 * 16 MiB DBI/APB ioremap, so a wrong offset cannot oops — it just yields a
 * non-functional BAR until validated at link-up.
 */
static void miop_pcie_ep_set_bar(struct miop_pcie *pcie, int bar,
				 u64 size, int flags)
{
	void __iomem *dbi = pcie->dbi_base;
	void __iomem *apb = pcie->apb_base;
	u32 base_idx = pcie->ep->n_win;	/* rockchip_pcie+0x20 guess */
	u32 bi  = base_idx + bar * 8;		/* BAR register index offset */
	u32 apo = (bar + 4) * 4;		/* APB 64-bit shadow offset */
	u32 sz_enc;

	/* BAR lower / size field (asm: *(D + BI + 4) = 0; *(D + BI + 8) = size) */
	writel(0, dbi + bi + 4);
	if (size > 0xfffff) {
		/* size encoding: clz(rbit(size)) - 20, placed at bits[12:8].
		 * clz(rbit(x)) == ffs(x)-1, so this is (ffs(size)-21) & 0x1f. */
		sz_enc = ((ffs((u32)size) - 1 - 0x14) & 0x1f) << 8;
		writel(sz_enc, dbi + bi + 8);
	} else {
		writel(0, dbi + bi + 8);
	}

	/* 64-bit BAR: clear the upper shadow (asm: flags & 0x4). */
	if (flags & 0x4) {
		writel(0, apb + apo + 4);
		writel(0, dbi + bi + 12);
		writel(0, dbi + bi + 16);
	}

	if (size != 0)
		writel(0, apb + apo);			/* BAR lower (APB shadow) */

	/* BAR type/flags (asm: *(D + BI) = flags; if !64-bit also clear +4). */
	writel(flags, dbi + bi);
	if (!(flags & 0x4))
		writel(0, dbi + bi + 4);

	dev_info(pcie->dev,
		 "set_bar(bar=%d size=%#llx flags=%#x) bi=%#x [transcribed]\n",
		 bar, size, flags, bi);
}

/*
 * miop_pcie_map_inbound_atu() - allocate an inbound iATU window (mirrors the
 * probe's find_first_zero_bit + atu_base window program, pcie.S ~2637-2911).
 * Maps the RC-visible PCIe address `pci_addr` to the local CPU address
 * `local` (our RX/DMA buffer). The iATU register stride (bit<<9) and field
 * layout match our outbound helper (standard DWC iATU).
 */
static int miop_pcie_map_inbound_atu(struct miop_pcie *pcie, u64 local)
{
	struct miop_ep *ep = pcie->ep;
	unsigned long n_ib = ep->hw.num_ib_windows;
	unsigned long bit;
	void __iomem *win;

	bit = find_first_zero_bit(pcie->map1, n_ib);
	if (bit >= n_ib) {
		dev_err(pcie->dev, "inbound slot exhausted\n");
		return -EINVAL;
	}

	win = (char __iomem *)pcie->atu_base + (bit << 9);
	writel(0x1, (char *)win + 0x0);		/* DIRECTION = inbound */
	writel(0x0, (char *)win + 0x4);
	writel((u32)local, (char *)win + 0x8);		/* target low (local) */
	writel((u32)(local >> 32), (char *)win + 0xc);
	writel(0xffffffff, (char *)win + 0x10);	/* limit */
	writel(0x0, (char *)win + 0x14);
	writel(0x80000000, (char *)win + 0x4);		/* enable */

	set_bit(bit, pcie->map1);
	pcie->link_slot = (int)bit;
	dev_info(pcie->dev, "inbound ATU slot %lu -> local %#llx\n", bit, local);
	return 0;
}

/*
 * miop_pcie_config_controller() - the controller/DLL configuration block
 * transcribed from pcie.S miop_pcie_ep_init (lines ~2527-2636). Pure mmio
 * pokes against pcie->dbi_base / pcie->apb_base; safe on our owned controller.
 *
 * Order matches factory: APB glue -> APP clears -> 0x710 lane cap -> 0x80c
 * speed -> 0x4 type -> 0x8bc enable -> set_bar x4 -> Vendor/Device/Class ->
 * 0x8bc disable -> inbound iATU.  IDs and BARs are programmed *after* the
 * controller enable (0x8bc bit 0), not before.
 */
static void miop_pcie_config_controller(struct miop_pcie *pcie,
					struct miop_ep *ep)
{
	void __iomem *dbi = pcie->dbi_base;
	void __iomem *apb = pcie->apb_base;
	u32 lanes = ep->hw.num_lanes ? ep->hw.num_lanes : 4;
	u32 v, cap;

	/* APB glue — factory writes three times:
	 *   apb[0x180] = 0x100010  — APB control
	 *   apb[0]     = 0x8000800 — APB glue (first, BEFORE link training)
	 *   apb[0x24]  = 0x80000000
	 * The second write (after IRQ request) uses 0xf00000 / 0xc000c. */
	writel(0x100010, apb + 0x180);
	writel(0x8000800, apb);

	/* RK APP region (DBI + 0x380000): clear two control registers. */
	writel(0, dbi + 0x380000 + 0x54);
	writel(0, dbi + 0x380000 + 0xa8);

	/* DBI 0x710: preserve type/class bits, set link capability width. */
	v = rk35_pcie_readl_dbi(dbi, 0x710);
	v = (v & 0xffffff7f) | 0x20;
	switch (lanes) {
	case 1:  cap = 0x10000; break;
	case 2:  cap = 0x30000; break;
	case 4:  cap = 0x70000; break;
	default:
		if (lanes > 4)
			cap = 0xf0000;
		else
			cap = 0x30000;
		break;
	}
	writel((v & 0xffc0ffff) | cap, dbi + 0x710);

	/* DBI 0x80c: max link speed + lane width (factory encoding). */
	v = rk35_pcie_readl_dbi(dbi, 0x80c);
	v &= 0xffffe0ff;
	switch (lanes) {
	case 1:  v |= 0x200100; break;
	case 2:  v |= 0x20200;  break;
	case 4:  v |= 0x20400;  break;
	default: v |= 0x20000;  break;
	}
	writel(v, dbi + 0x80c);

	writel(6, dbi + 0x4);

	/* Controller enable (0x8bc |= 1) BEFORE programming config/IDs/BARs */
	v = rk35_pcie_readl_dbi(dbi, 0x8bc);
	writel(v | 0x1, dbi + 0x8bc);

	/* set_bar x4 (EP BARs) — inside the enabled window, before IDs */
	miop_pcie_ep_set_bar(pcie, 0, 0x10000, 0x8); /* 64K, 32-bit prefetch — might fit controller's bridge */
	miop_pcie_ep_set_bar(pcie, 2, 0, 0);
	miop_pcie_ep_set_bar(pcie, 3, 0, 0);
	miop_pcie_ep_set_bar(pcie, 4, 0x100000, 0xc);

	/* EP function identity (type0 config header) — inside enabled window. */
	writew(0x4586, dbi + 0x0);
	writew(0xb6f2, dbi + 0x2);
	writew(0x280,  dbi + 0xa);

	/* Controller disable (0x8bc &= ~1). */
	v = rk35_pcie_readl_dbi(dbi, 0x8bc);
	writel(v & ~0x1, dbi + 0x8bc);

	/* Inbound iATU window mapping our local RX/DMA buffer for RC access. */
	miop_pcie_map_inbound_atu(pcie, pcie->dma_dma);
}

/*
 * miop_pcie_peer_online() - drive the peer/link handshake once the link is up.
 * Transcribed in spirit from the link-up branch of pcie.S rk35_ep_interrupt:
 * the vendor discovers the peer BAR target via the MIOP shared-header exchange
 * and programs an outbound iATU window, then calls net_drv->on_peer_online()
 * (which in miop-ep-net.ko flips pci0's carrier and sets up the TX/RX rings).
 *
 * The exact MIOP header exchange / per-peer descriptor-ring plumbing
 * (pcie.S fields +280/+600/+9024/+17352) is pending protocol fidelity, so for
 * this pass we notify the net layer with peer=0 (its on_peer_online is a safe
 * stub). This is driven from the reliable link-up poll rather than the IRQ.
 */
static int miop_raise_peer_irq(struct device *dev, u32 peer_id, u32 vector);

static void miop_pcie_peer_online(struct miop_pcie *pcie)
{
	struct miop_ep *ep = pcie->ep;
	struct miop_ep_net_driver *net = ep->net_drv;
	int i;

	if (!net || !net->on_peer_online)
		return;

	/* Bring up every potential peer and announce our presence by writing a
	 * peer-online doorbell into each destination node's EP doorbell window
	 * (bit[0] = peer online, bits[8:15] = our source id, per the factory
	 * rx_ep_interrupt decode).  The peer answers with its own doorbell,
	 * which our RX path turns into on_peer_online on that side. */
	for (i = 0; i < 4; i++) {
		int ret = net->on_peer_online(ep, i);

		dev_info(pcie->dev,
			 "peer online -> net_drv->on_peer_online(peer=%d) = %d\n",
			 i, ret);
		miop_raise_peer_irq(pcie->dev, i, 0x1);
	}
}

/*
 * miop_pcie_link_train() - bounded LTSSM link-training poll, transcribed from
 * pcie.S (apb_base+0x300 link-status register). Bounded to LINK_TRAIN_ITERS so
 * a missing peer can never hang boot; returns 0 if link came up, -ETIMEDOUT
 * otherwise (non-fatal: the module still loads).
 */
#define MIOP_LINK_TRAIN_ITERS 250
static int miop_pcie_link_train(struct miop_pcie *pcie)
{
	void __iomem *apb = pcie->apb_base;
	u32 mask = 0x3f | (0x3u << 16);
	u32 want = 0x11 | (0x3u << 16);
	int i;

	for (i = 0; i < MIOP_LINK_TRAIN_ITERS; i++) {
		u32 st = readl(apb + 0x300);

		if ((st & mask) == want) {
			pcie->link_up = 1;
			dev_info(pcie->dev, "PCIe Link up (status %#x)\n", st);
			miop_pcie_peer_online(pcie);
			return 0;
		}
		msleep(20);
	}
	dev_warn(pcie->dev, "PCIe Link training timed out (no peer?)\n");
	return -ETIMEDOUT;
}

/*
 * rk35_dma_start_write() — doorbell the hardware to process a channel's ring.
 * Translated from pcie_asm.S line 741.
 */
static void rk35_dma_start_write(struct miop_pcie *pcie, u32 ch)
{
	u32 v;
	u32 base = 0x380000 + ch * 0x200;
	dma_addr_t ring_dma = pcie->chan[ch].ring_dma;

	/* Factory batch path lines 990-1044 — exact order: */
	/* 1. Re-enable DMA write engine */
	writel(1, pcie->dbi_base + 0x38000C);
	dmb(oshst);

	/* 2. Re-program ring address (batch path writes it every time) */
	writel(0x40000308, pcie->dbi_base + base + 0x200);
	writel(0,          pcie->dbi_base + base + 0x204);
	writel((u32)ring_dma, pcie->dbi_base + base + 0x21C);
	writel((u32)(ring_dma >> 32), pcie->dbi_base + base + 0x220);
	/* Read-channel registers (interrupt handler also programs these) */
	writel(0x40000308, pcie->dbi_base + base + 0x300);
	writel(0,          pcie->dbi_base + base + 0x304);
	writel((u32)ring_dma, pcie->dbi_base + base + 0x31C);
	writel((u32)(ring_dma >> 32), pcie->dbi_base + base + 0x320);
	dmb(oshst);

	/* 3. Clear doorbell pending bits for this channel */
	v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380054);
	writel(v & ~(1u << ch), pcie->dbi_base + 0x380054);
	dmb(oshst);

	/* 4. Enable per-channel interrupt */
	v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380090);
	writel(v | (1u << (16 + ch)), pcie->dbi_base + 0x380090);
	dmb(oshst);

	/* 5. Arm channel */
	writel((1u << ch) | (1u << (16 + ch)), pcie->dbi_base + 0x380058);
	dmb(oshst);

	/* 6. Doorbell — write channel number (bits [2:0] selects channel) */
	v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380010);
	writel((v & ~7) | ch, pcie->dbi_base + 0x380010);
}

static void rk35_dma_start_write(struct miop_pcie *pcie, u32 ch);
static int miop_dma_try_reap(struct miop_pcie *pcie, u32 ch);

/*
 * miop_rk35_dma_submit() — submit one DMA descriptor.
 * Translated from pcie_asm.S line 19.
 *
 * Writes the descriptor to ring[prod_idx], stores the completion tracking
 * entry, advances the producer index, then doorbells the hardware.
 */
static int miop_raise_peer_irq(struct device *dev, u32 peer_id, u32 vector);

static int miop_rk35_dma_submit(struct device *dev, u32 ch, u64 data,
				u64 ext, u32 len, u64 cookie, void *cb)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;
	struct miop_pcie_channel *chan;
	struct miop_dma_desc *desc;
	struct miop_dma_track *track;
	unsigned long flags;
	u16 idx;
	int p;

	/* `peer == (u32)-1` broadcasts to every online peer's data window. */
	if (ch >= MIOP_DMA_NUM_CH)
		return -EINVAL;

	chan = &pcie->chan[ch];

	for (p = 0; p < 4; p++) {
		void __iomem *win;
		dma_addr_t win_dma;
		int tries;
		u32 st;

		if (pcie->peer_data_base[p] == NULL || pcie->peer_data_dma[p] == 0)
			continue;

		win = pcie->peer_data_base[p];
		win_dma = pcie->peer_data_dma[p];

		/* Copy the frame into the peer's data window (the eDMA reads
		 * from here and writes it across the fabric into the peer's
		 * RX ring). */
		memcpy_toio(win, (void *)(unsigned long)data, len);
		wmb();

		spin_lock_irqsave(&chan->lock, flags);
		idx = chan->prod_idx;
		desc = &chan->ring[idx];
		track = &chan->track[idx];

		if (chan->busy[idx]) {
			idx = (idx + 1) & (MIOP_DMA_RING_SIZE - 1);
			chan->prod_idx = idx;
			desc = &chan->ring[idx];
			track = &chan->track[idx];
		}

		desc->len       = len;
		desc->addr_low  = (u32)win_dma;
		desc->addr_high = (u32)(win_dma >> 32);
		desc->meta_len  = (u16)ext;
		desc->meta      = (u16)(ext >> 16);
		desc->meta2     = (u32)(ext >> 32);

		track->cookie = cookie;
		track->cb     = cb;
		track->dma    = (dma_addr_t)data;
		track->len    = len;
		chan->busy[idx] = 1;

		wmb();
		desc->status = ((idx + 1) & 1) | 0x8;
		wmb();

		{
			struct miop_dma_desc *next =
				&chan->ring[(idx + 1) & (MIOP_DMA_RING_SIZE - 1)];
			next->status = ((idx + 2) & 1);
			wmb();
		}

		chan->prod_idx = (idx + 1) & (MIOP_DMA_RING_SIZE - 1);

		*(u32 *)((char *)chan->ring +
			 MIOP_DMA_RING_SIZE * sizeof(struct miop_dma_desc) + 4) =
			chan->prod_idx;
		wmb();
		spin_unlock_irqrestore(&chan->lock, flags);

		rk35_dma_start_write(pcie, ch);

		/* Notify the peer its RX doorbell is pending. */
		if (pcie->peer_db_base[p])
			miop_raise_peer_irq(dev, p, 1);

		/* Poll for eDMA completion before reusing the window / freeing
		 * the skb (keeps the source buffer alive until the write lands). */
		tries = 1000;
		do {
			st = readl(pcie->dbi_base + 0x38004C);
			if (st & ((1u << ch) | (1u << (ch + 16))))
				break;
			cpu_relax();
			udelay(10);
		} while (--tries);

		if (!(st & ((1u << ch) | (1u << (ch + 16)))))
			dev_err(pcie->dev, "dma_submit ch=%u peer=%d NOT done "
				"0x38004C=0x%08x\n", ch, p, st);
		else
			miop_dma_try_reap(pcie, ch);
	}

	if (pcie->peer_data_base[0] == NULL && pcie->peer_data_base[1] == NULL)
		return -ENODEV;
	/* Free the skb once; it was copied into each peer window above and the
	 * eDMA reads have completed (we polled per peer). */
	dev_kfree_skb((struct sk_buff *)(unsigned long)cookie);
	return 0;
}

/*
 * miop_dma_try_reap() — walk the ring from cons_idx to prod_idx, reap
 * completed descriptors and invoke their callbacks.
 * Translated from pcie_asm.S line 500.
 */
static int miop_dma_try_reap(struct miop_pcie *pcie, u32 ch)
{
	struct miop_pcie_channel *chan = &pcie->chan[ch];
	u16 done = 0;
	unsigned long flags;
	u32 int_status;

	/* Completion is signalled by the DMA WRITE_INT_STATUS register
	 * (0x38004C) bit[ch]; bit[ch+16] indicates an abort/error.  We reap
	 * whenever the engine says a descriptor finished OR there is still
	 * pending work in the ring (the submit poll may have already cleared
	 * the INT bit, so gating only on it would leave slots marked busy). */
	int_status = readl(pcie->dbi_base + 0x38004C);
	if (!(int_status & ((1u << ch) | (1u << (ch + 16)))) &&
	    chan->cons_idx == chan->prod_idx)
		return 0;

	if (int_status & (1u << (ch + 16)))
		dev_err(pcie->dev, "dma ch%u ABORT (INT_STATUS=0x%08x ERR=0x%08x)\n",
			ch, int_status, readl(pcie->dbi_base + 0x38005C));

	if (int_status & ((1u << ch) | (1u << (ch + 16)))) {
		writel((1u << ch) | (1u << (ch + 16)), pcie->dbi_base + 0x380058);
		dmb(oshst);
	}

	spin_lock_irqsave(&chan->lock, flags);

	while (chan->cons_idx != chan->prod_idx) {
		u16 idx = chan->cons_idx;
		struct miop_dma_desc *desc = &chan->ring[idx];
		struct miop_dma_track *track = &chan->track[idx];
		dma_addr_t save_dma;
		u32 save_len;
		u64 save_cookie;
		void (*save_cb)(u64, u64);
		u32 save_status;

		save_dma    = track->dma;
		save_len    = track->len;
		save_cookie = track->cookie;
		save_cb     = track->cb;
		save_status = desc->status;

		/* Do NOT zero desc->status: the engine re-fetches the ring from
		 * its base on the next doorbell and walks the LLI chain, so the
		 * descriptors must KEEP their Cycle Bit.  Only the software
		 * tracking entry and busy marker are cleared. */
		memset(track, 0, sizeof(*track));
		chan->busy[idx] = 0;
		chan->cons_idx = (idx + 1) & (MIOP_DMA_RING_SIZE - 1);

		spin_unlock_irqrestore(&chan->lock, flags);

		if (save_cb) {
			dma_unmap_single(pcie->dev, save_dma, save_len,
					 DMA_TO_DEVICE);
			save_cb(save_cookie, save_status);
		}
		done++;

		spin_lock_irqsave(&chan->lock, flags);
	}

	spin_unlock_irqrestore(&chan->lock, flags);

	/* Clear the done + abort interrupt bits for this channel.  The next
	 * doorbell re-fetches the ring from its base; the descriptor Cycle
	 * Bits (alternating 1/0/1/0...) let the engine walk to the new
	 * terminator at prod_idx. */
	writel((1u << ch) | (1u << (ch + 16)), pcie->dbi_base + 0x380058);
	dmb(oshst);
	return done;
}

/*
 * miop_raise_peer_irq() — notify the RC that new data is available in our
 * descriptor ring. Writes a doorbell value to the RC-visible doorbell reg.
 * Translated from pcie_asm.S line 782.
 */
int miop_raise_peer_irq(struct device *dev, u32 peer_id, u32 vector)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;
	char __iomem *db;

	if (!pcie || peer_id >= 4 || !pcie->peer_db_base[peer_id]) {
		dev_info(pcie->dev, "raise_peer_irq peer=%u SKIP (base=%px)\n",
			 peer_id, pcie ? pcie->peer_db_base[peer_id] : NULL);
		return 0;
	}

	/* Write the doorbell vector into the *peer's* EP doorbell region (mapped
	 * by map_peer_bar to the peer's DBI/ELBI window).  This produces an
	 * inbound PCIe MemWr on the peer that asserts its RX doorbell interrupt.
	 * Transcribed from pcie_asm.S miop_raise_peer_irq: writes to
	 * peer_bar_base + peer_bar_phys. */
	db = (char __iomem *)pcie->peer_db_base[peer_id] + pcie->peer_db_off[peer_id];
	/* Doorbell value: bit[1] (0x2) = RX_DATA (miop_ep_handle_doorbell only
	 * calls on_rx when db_val & 2), bits[8:15] = source peer id (the peer
	 * decodes the sender from db_val>>8). */
	writel(0x2 | ((peer_id & 0xff) << 8), db);
	return 0;
}

/*
 * rk35_ep_interrupt() — EP interrupt handler. Reads APB status, handles
 * doorbells from the RC, and reaps completed DMA descriptors.
 * Translated from pcie_asm.S line 1208.
 */
/*
 * miop_ep_handle_doorbell() - process a peer doorbell (db_val) and the eDMA
 * completion status.  Shared by the GIC interrupt handler and the RX polling
 * work: on the RK35 the EP interrupt output to the GIC is unreliable, so the
 * factory uses a polling reap thread and we mirror that here.
 *
 * db_val layout (peer-written into our DBI doorbell @0x200e00):
 *   bit[0]   peer online
 *   bit[1]   RX ready  -> upper 16 bits are a local RX header pointer
 *   bit[2]   TX ready
 *   bit[3]   peer offline
 *   bits[8:15]  peer id
 */
static void miop_ep_handle_doorbell(struct miop_pcie *pcie, u32 db_val)
{
	struct miop_ep *ep = pcie->ep;
	struct miop_ep_net_driver *net = ep ? ep->net_drv : NULL;
	u32 peer = (db_val >> 8) & 0xff;

	if (net) {
		if (db_val & 1)
			net->on_peer_online(ep, peer);
		if (db_val & 2) {
			/* RX doorbell: upper 16 bits are the local RX header
			 * pointer the peer wrote before ringing the bell. */
			u32 hdr_addr = (db_val & 0xffff0000) |
				       (db_val & 0xffff);
			struct miop_rx_hdr *hdr =
				(struct miop_rx_hdr *)(unsigned long)hdr_addr;
			u32 len = 0;
			void *buf = NULL;

			if (hdr_addr) {
				len = hdr->len;
				buf = (void *)(unsigned long)hdr->buf_addr;
			}
			net->on_rx(ep, peer, buf, len);
		}
		if (db_val & 4)
			net->on_tx_ready(ep, peer);
		if (db_val & 8)
			net->on_peer_offline(ep, peer);
	}

	miop_dma_try_reap(pcie, 0);
	miop_dma_try_reap(pcie, 1);
}

/* Poll the local EP doorbell/APB status because the GIC interrupt (160) is not
 * reliably delivered on this platform (TX works via INT_STATUS polling; RX
 * depends on this).  Mirrors the factory's miop_dma_reap_thread.  We poll both
 * the APB interrupt status AND the DBI doorbell register directly, because the
 * inbound peer doorbell write may land in the DBI doorbell without the GIC
 * being asserted. */
static void miop_rx_poll_work_fn(struct work_struct *work)
{
	struct miop_pcie *pcie = container_of(work, struct miop_pcie,
					      rx_poll_work.work);
	u32 apb_st, db_val;

	apb_st = readl(pcie->apb_base + 0x10);
	db_val = rk35_pcie_readl_dbi(pcie->dbi_base, 0x200e00);

	if (db_val && db_val != pcie->last_doorbell) {
		pcie->last_doorbell = db_val;
		dev_info(pcie->dev, "RXpoll apb_st=0x%08x db_val=0x%08x\n",
			 apb_st, db_val);
		miop_ep_handle_doorbell(pcie, db_val);
		if (apb_st & (1u << 15))
			writel(apb_st, pcie->apb_base + 0x10);
		writel(0, pcie->dbi_base + 0x200e00);
	} else if (!db_val) {
		pcie->last_doorbell = 0;
	}

	schedule_delayed_work(&pcie->rx_poll_work, msecs_to_jiffies(2));
}

static irqreturn_t rk35_ep_interrupt(int irq, void *dev_id)
{
	struct miop_pcie *pcie = dev_id;
	u32 apb_st;

	if (!pcie || !pcie->apb_base)
		return IRQ_NONE;

	apb_st = readl(pcie->apb_base + 0x10);

	dev_info(pcie->dev, "IRQ apb_st=0x%08x\n", apb_st);

	if (apb_st & (1u << 15)) {
		u32 db_val = rk35_pcie_readl_dbi(pcie->dbi_base, 0x200e00);

		dev_info(pcie->dev, "IRQ doorbell db_val=0x%08x\n", db_val);
		miop_ep_handle_doorbell(pcie, db_val);
	}

	writel(apb_st, pcie->apb_base + 0x10);
	return IRQ_HANDLED;
}

/* ---- DMA helpers wired to the driver struct ---- */

static int miop_dma_list_is_full(struct device *dev, u32 channel)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;
	struct miop_pcie_channel *chan;

	if (channel >= MIOP_DMA_NUM_CH || !pcie)
		return 1;

	chan = &pcie->chan[channel];
	return (chan->ring[chan->prod_idx].status & 1) ? 1 : 0;
}

static void miop_dma_list_commit_pending(struct device *dev)
{
	/* With single-descriptor submission we have no batch to commit.
	 * rk35_dma_start_write was already called per submit.  The factory
	 * batch path (pcie_asm.S:2019) walks a pending list and programs the
	 * doorbell; for the non-batch path this is a no-op. */
}

/*
 * miop_elbi_enable_irq() / _disable_irq() - transcribe pcie_asm.S:100-145.
 *
 * Enables an EP->GIC interrupt *source* in the DesignWare ELBI block.  The
 * enable register group lives at DBI 0x838200 + group*4 (group = irq_idx>>4),
 * 32 bits per group; bit (irq_idx & 0xf) in the UPPER 16 bits is the enable
 * for that source.  Without this, an inbound peer doorbell write is absorbed
 * by the EP and never forwarded to the GIC, so the RX (and TX-ready) doorbell
 * interrupt never fires.
 */
static void miop_elbi_enable_irq(struct miop_pcie *pcie, u32 irq_idx)
{
	void __iomem *reg;
	u32 val;

	if (!pcie->dbi_base2)
		return;
	reg = pcie->dbi_base2 + 0x838200 + ((irq_idx >> 4) << 2);
	val = readl(reg);
	val |= (1u << (irq_idx & 0xf)) << 16;
	wmb();
	writel(val, reg);
	dev_info(pcie->dev, "ELBI enable irq_idx=%u reg=0x%lx val=0x%08x\n",
		 irq_idx, (unsigned long)(0x838200 + ((irq_idx >> 4) << 2)),
		 readl(reg));
}

static void miop_elbi_disable_irq(struct miop_pcie *pcie, u32 irq_idx)
{
	void __iomem *reg;
	u32 val;

	if (!pcie->dbi_base2)
		return;
	reg = pcie->dbi_base2 + 0x838200 + ((irq_idx >> 4) << 2);
	val = readl(reg);
	val &= ~((1u << (irq_idx & 0xf)) << 16);
	wmb();
	writel(val, reg);
}

/* miop_rk35_map_peer_bar() is provided by the factory pcie-ep-rk35.ko (see
 * miop.h).  It allocates one outbound iATU window per peer index and returns
 * the ioremap'd VA; *out_phys receives the window's fabric address. */

static void miop_rk35_unmap_peer_bar(struct device *dev, u32 peer)
{
}

static void *miop_rk35_map_rc_staging(struct device *dev, u64 phys,
				      u32 size, u32 dir)
{
	return NULL;
}

static void miop_rk35_unmap_rc_staging(struct device *dev, u32 dir)
{
}

static int miop_rk35_dma_submit_batch(struct device *dev, u32 ch,
				      void *batch, u32 count,
				      u64 comp, void *cb)
{
	return -EINVAL;
}

/*
 * miop_pcie_ep_probe() - RK35 EP bring-up, called by miop-ep.ko.
 *
 * Transcribed from pcie.S miop_pcie_ep_init: allocate the pcie private,
 * ioremap the DBI/APB windows, allocate the outbound-window bitmaps from the
 * EP window counts, carve out the TX/DMA coherent buffer, train the link, set
 * up the BARs and outbound/inbound ATU mappings, wire the EP IRQ, and run the
 * peer handshake (which calls net_drv->on_peer_online).  A deferred DMA
 * self-test validates the DesignWare eDMA write engine.
 */
static void miop_pcie_bar_check_work(struct work_struct *work)
{
	struct miop_pcie *pcie = container_of(work, struct miop_pcie,
					      bar_check_work.work);
	struct device *dev = pcie->dev;
	u32 bar_low, bar_high, peer_low, peer_hi;
	u64 bar0, peer_addr;

	bar_low = rk35_pcie_readl_dbi(pcie->dbi_base, 0x10);
	bar_high = rk35_pcie_readl_dbi(pcie->dbi_base, 0x14);
	bar0 = (u64)bar_high << 32 | bar_low;

	peer_low = readl(pcie->dbi_base + 0x154);
	peer_hi = readl(pcie->dbi_base + 0x158);
	peer_addr = (u64)peer_hi << 32 | peer_low;

	dev_info(dev, "BAR check: BAR0=0x%llx peer=0x%llx "
		 "0x150=0x%08x 0x154=0x%08x 0x158=0x%08x\n",
		 bar0, peer_addr,
		 readl(pcie->dbi_base + 0x150),
		 peer_low, peer_hi);

	/* DMA self-test using the interrupt-handler init sequence */
	{
		struct miop_dma_desc *d = pcie->chan[0].ring;
		u64 dest_addr;
		u32 r;
		int tries = 0;

		/* --- DMA self-test: one write-descriptor to the peer ---------
		 * Validates that the DesignWare eDMA write engine is correctly
		 * programmed and can move a descriptor to completion.  Uses the
		 * same LLI + Cycle Bit protocol as the production TX path. */
		if (peer_addr > 0x100000000ULL && peer_addr < 0x10000000000ULL)
			dest_addr = peer_addr;
		else
			dest_addr = 0x9000e0000ULL;

		memset(d, 0, sizeof(*d));
		d->len = 8;
		d->addr_low = (u32)pcie->dma_dma;
		d->addr_high = 0;
		*(u64 *)((char *)d + 16) = dest_addr;
		memset((char *)d + 24, 0, 24);  /* CB=0 terminator */
		wmb();
		d->status = 0x9;  /* CB=1 | LIE */
		wmb();

		*(u32 *)((char *)d +
			 MIOP_DMA_RING_SIZE * sizeof(struct miop_dma_desc)
			 + 4) = 1;
		wmb();

		/* Interrupt-handler init sequence (pcie_asm.S:1360-1483) */
		writel(1, pcie->dbi_base + 0x38000C);
		r = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380054);
		writel(r & ~3u, pcie->dbi_base + 0x380054);
		r = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380090);
		writel(r | 0x30000, pcie->dbi_base + 0x380090);
		writel(0x40000308, pcie->dbi_base + 0x380200);
		writel(0,          pcie->dbi_base + 0x380204);
		writel((u32)pcie->chan[0].ring_dma, pcie->dbi_base + 0x38021C);
		writel((u32)(pcie->chan[0].ring_dma >> 32),
		       pcie->dbi_base + 0x380220);
		writel(0x40000308, pcie->dbi_base + 0x380400);
		writel(0,          pcie->dbi_base + 0x380404);
		writel((u32)pcie->chan[0].ring_dma, pcie->dbi_base + 0x38041C);
		writel((u32)(pcie->chan[0].ring_dma >> 32),
		       pcie->dbi_base + 0x380420);
		writel(1, pcie->dbi_base + 0x38002C);
		writel(0x40000308, pcie->dbi_base + 0x380300);
		writel(0,          pcie->dbi_base + 0x380304);
		writel((u32)pcie->chan[0].ring_dma, pcie->dbi_base + 0x38031C);
		writel((u32)(pcie->chan[0].ring_dma >> 32),
		       pcie->dbi_base + 0x380320);
		r = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800A8);
		writel(r & ~1u, pcie->dbi_base + 0x3800A8);
		r = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800C4);
		writel(r | 0x10000, pcie->dbi_base + 0x3800C4);
		dmb(oshst);

		writel(0x10001, pcie->dbi_base + 0x380058);
		dmb(oshst);
		rk35_dma_start_write(pcie, 0);

		/* Poll INT_STATUS (the real completion signal) */
		tries = 0;
		while (tries < 100 &&
		       !(readl(pcie->dbi_base + 0x38004C) & 1)) {
			udelay(100);
			tries++;
		}

		if (readl(pcie->dbi_base + 0x38004C) & 1) {
			dev_info(dev, "DMA self-test: PASS (INT=0x%08x)\n",
				 readl(pcie->dbi_base + 0x38004C));
			writel(1, pcie->dbi_base + 0x380058);
			dmb(oshst);
		} else {
			dev_err(dev, "DMA self-test: FAIL (INT=0x%08x ERR=0x%08x)\n",
				readl(pcie->dbi_base + 0x38004C),
				readl(pcie->dbi_base + 0x38005C));
		}

		/* Self-test consumed channel 0; reset the ring tracking so the
		 * net driver starts with a clean, positional CB pattern. */
		pcie->chan[0].prod_idx = 0;
		pcie->chan[0].cons_idx = 0;
		memset(pcie->chan[0].busy, 0, sizeof(pcie->chan[0].busy));
	}
}

static int miop_pcie_ep_probe(struct device *dev)
{
	struct platform_device *pdev = to_platform_device(dev);
	struct miop_ep *ep = platform_get_drvdata(pdev);
	struct miop_pcie *pcie;
	void __iomem *dbi_base, *apb_base;
	int i;
	dma_addr_t dma_dma;
	void *dma_buf;

	if (!ep) {
		dev_err(dev, "miop_pcie_ep_probe: no ep context\n");
		return -ENODEV;
	}

	pcie = devm_kzalloc(dev, sizeof(*pcie), GFP_KERNEL);
	if (!pcie)
		return -ENOMEM;
	pcie->ep = ep;
	pcie->dev = dev;
	ep->pcie_priv = pcie;

	dbi_base = devm_ioremap_resource(dev, ep->hw.res_dbi);
	if (IS_ERR(dbi_base)) {
		dev_err(dev, "ioremap DBI failed\n");
		return PTR_ERR(dbi_base);
	}
	pcie->dbi_base = dbi_base;
	pcie->atu_base = (char __iomem *)dbi_base + 0x300000;

	/* The factory's ELBI block (DBI 0x838200) lives outside the 4 MiB DBI
	 * window.  The correct physical base must be derived from the factory
	 * pcie_ep_drv struct (ep_drv+8); the devicetree DBI aperture for
	 * fe150000.pcie is only a40000000-a403fffff, so a hardcoded 0xa40800000
	 * is outside the aperture and faults.  Leave dbi_base2 NULL for now so
	 * ELBI writes are skipped; revisit once the real base is known. */
	pcie->dbi_base2 = NULL;
	dev_warn(dev, "ELBI DBI2 window not mapped yet; ELBI disabled\n");

	apb_base = devm_ioremap_resource(dev, ep->hw.res_apb);
	if (IS_ERR(apb_base)) {
		dev_err(dev, "ioremap APB failed\n");
		return PTR_ERR(apb_base);
	}
	pcie->apb_base = apb_base;

	if (rk35_pcie_ep_window_map_init(pcie)) {
		dev_err(dev, "window map init failed\n");
		return -ENOMEM;
	}

	dma_buf = dmam_alloc_coherent(dev, 0x400000, &dma_dma, GFP_KERNEL);
	if (!dma_buf) {
		dev_err(dev, "tx/dma buffer alloc failed\n");
		rk35_pcie_ep_window_map_deinit(pcie);
		return -ENOMEM;
	}
	pcie->dma_buf = dma_buf;
	pcie->dma_dma = dma_dma;

	/* MIOP shared header at the start of the DMA buffer (peer handshake
	 * region). Mirrors pcie.S: hdr[0]="MIOP"+0x2, hdr[1]=serial,
	 * hdr[3]=0xffffffff, hdr[4]=1, hdr[5]=0. */
	pcie->serial = miop_ep_generate_serial();
	{
		u64 *hdr = dma_buf;

		hdr[0] = 0x00020000504f494dULL;       /* "MIOP" | 0x2 */
		hdr[1] = pcie->serial;
		*(u32 *)((char *)dma_buf + 12) = 0xffffffff;
		*(u64 *)((char *)dma_buf + 16) = 1;  /* low=1, high=0 */
		wmb();
	}

	/* Initialize DMA rings with trailer (in our 4 MiB coherent buffer).
	 * Per the factory, each ring has 128 × 24-byte descriptors followed
	 * by a 24-byte control trailer at offset 0xC00.  The trailer contains
	 * a magic byte at +0, the producer index at +4, and the ring's own
	 * bus address at +8 (used by the hardware to locate the ring when
	 * the doorbell is rung). */
	{
		int i;

		for (i = 0; i < MIOP_DMA_NUM_CH; i++) {
			struct miop_pcie_channel *ch = &pcie->chan[i];

			ch->ring = (struct miop_dma_desc *)
				((char *)dma_buf + 0x100000 +
				 i * MIOP_DMA_RING_STRIDE);
			ch->ring_dma = dma_dma + 0x100000 +
				i * MIOP_DMA_RING_STRIDE;
			ch->prod_idx = 0;
			ch->cons_idx = 0;
			memset(ch->busy, 0, sizeof(ch->busy));
			spin_lock_init(&ch->lock);

			/* Write ring bus address into trailer at +8 */
			*(u64 *)((char *)ch->ring +
				 MIOP_DMA_RING_SIZE *
				 sizeof(struct miop_dma_desc) + 8) =
				ch->ring_dma;
		}
	}

	/* Controller / DLL configuration (DBI/APB pokes). */
	miop_pcie_config_controller(pcie, ep);

	/* Program per-channel DMA ring address + descriptor config into the
	 * DBI APP region registers (pcie_asm.S interrupt handler lines 1389-1483).
	 * Both write-channel (0x200) and read-channel (0x300) ring addresses
	 * must be programmed for the engine to process descriptors. */
	{
		int i;
		u32 v;

		for (i = 0; i < MIOP_DMA_NUM_CH; i++) {
			u32 base = 0x380000 + i * 0x200;
			dma_addr_t dma = pcie->chan[i].ring_dma;

			/* Write channel (TX) */
			writel(0x40000308, pcie->dbi_base + base + 0x200);
			writel(0,          pcie->dbi_base + base + 0x204);
			writel((u32)dma,   pcie->dbi_base + base + 0x21C);
			writel((u32)(dma >> 32), pcie->dbi_base + base + 0x220);
			/* Read channel (RX) - same ring */
			writel(0x40000308, pcie->dbi_base + base + 0x300);
			writel(0,          pcie->dbi_base + base + 0x304);
			writel((u32)dma,   pcie->dbi_base + base + 0x31C);
			writel((u32)(dma >> 32), pcie->dbi_base + base + 0x320);
		}

		/* Enable per-channel interrupts in DBI+0x380090 (factory line 1031). */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380090);
		v |= 0x30000;
		writel(v, pcie->dbi_base + 0x380090);

		/* Clear any stale doorbell-pending bits at DBI+0x380054. */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380054);
		v &= ~3u;
		writel(v, pcie->dbi_base + 0x380054);
	}

	/* MIOP tag + ring flag written to DBI (pcie_asm.S:2702-2723). */
	writel(0x100000, pcie->dbi_base + 0x200e14);
	writel(0x504f494d, pcie->dbi_base + 0x200e10);

	/* Clear any stale APB interrupt status bits before IRQ is requested. */
	if (pcie->apb_base) {
		u32 st = readl(pcie->apb_base + 0x10);
		if (st)
			writel(st, pcie->apb_base + 0x10);
	}

	/* Discover the factory's ELBI base (ep_drv+8) to confirm which window
	 * 0x838200 lives in.  ep->pcie_ep_drv is the factory pcie_ep_drv
	 * pointer; *(u64*)(ep->pcie_ep_drv + 8) is the base the assembly uses. */
	{
		void *drv = ep->pcie_ep_drv;
		u64 drv_base = drv ? *(u64 *)((char *)drv + 8) : 0;

		dev_info(dev, "ELBI discover: dbi_base=%px dbi_base2=%px "
			 "apb_base=%px drv_base(ep_drv+8)=0x%llx\n",
			 pcie->dbi_base, pcie->dbi_base2, pcie->apb_base,
			 (unsigned long long)drv_base);
	}

	/* Enable the EP->GIC interrupt sources in the ELBI block.  This is what
	 * forwards an inbound peer doorbell write to the GIC; without it the RX
	 * (and TX-ready) doorbell interrupt never fires.  The doorbell sources
	 * are in the low ELBI groups; enable a generous range to cover all
	 * peer/source combinations (pcie_asm.S miop_elbi_enable_irq). */
	for (i = 0; i < 16; i++) {
		if (!pcie->dbi_base2)
			break;
		miop_elbi_enable_irq(pcie, i);
	}

	/* Per-peer TX data window + RX doorbell window, one per destination node.
	 * The factory encodes the address as 0x90000000 + (DEST_NODE<<24) +
	 * (SRC_NODE<<20) + offset, where SRC_NODE is THIS node's id.  A node
	 * listens for incoming data at 0x90<SRC_NODE>000000: node1->node2 data
	 * lands at 0x903000000, node2->node1 at 0x901000000, node3 receives at
	 * 0x903000000.  So node3 writing to node1 uses 0x903000000 and doorbell
	 * 0x9000c0000. */
	/* Per-peer window: ONE outbound iATU window per peer index (0..3),
	 * mirroring the factory's miop_rk35_map_peer_bar.  The factory maps the
	 * peer's listening region at target 0x90000000 + (peer<<25); we do the
	 * same (outbound iATU identity-map + ioremap) so a write into the window
	 * crosses the fabric to the peer's RX region.  Derive the RX doorbell
	 * (+0x20, from miop_raise_peer_irq) and TX data (+0x100000) from it. */
	dev_info(dev, "PEERMAP n_free=%lu n_win=%lu\n", ep->n_free, ep->n_win);

	for (i = 0; i < 4; i++) {
		u64 out_phys = 0;
		void *va;
		/* peer 0 is this node's own region; only TX to peers 1..3. */
		if (i == 0)
			continue;
		/* Node p listens for RX data at 0x90000000 + (p<<24) + (SRC<<20),
		 * where SRC is THIS node's id (3).  Confirmed by node1's factory
		 * boot: its TX to node2 (peer[1]) uses BAR window 0x903000000
		 * (= 0x90000000 + 2<<24 + 1<<20), i.e. the SENDER's id is in the
		 * +20 byte.  So node3(src=3) -> node1 = 0x901000000,
		 * node3 -> node2 = 0x902000000. */
		u64 data_target = 0x900000000ULL + ((u64)i << 24) + (3ULL << 20);
		/* RX doorbell register window: 0x90000000 + peer<<24 + 0x100000
		 * (node1's doorbell is 0x900080000, node2's 0x9000c0000). */
		u64 db_target = 0x90000000ULL + ((u64)i << 24) + 0x100000ULL;

		va = miop_map_peer_bar(pcie, data_target, 0x3000000, &out_phys);
		if (!va) {
			dev_warn(dev, "map_peer_bar peer=%d data failed\n", i);
			pcie->peer_data_base[i] = NULL;
			pcie->peer_data_dma[i] = 0;
		} else {
			pcie->peer_data_base[i] = (char __iomem *)va + 0x2000000;
			pcie->peer_data_dma[i]  = (dma_addr_t)(out_phys + 0x2000000);
		}

		/* Separate window for the RX doorbell register. */
		pcie->peer_db_base[i] = miop_map_peer_bar(pcie, db_target,
							  0x1000, &out_phys);
		pcie->peer_db_off[i]  = 0;

		dev_info(dev, "peer[%d] data=0x%llx db=0x%llx\n", i,
			 (unsigned long long)data_target,
			 (unsigned long long)db_target);
	}

	/* Request EP IRQ BEFORE the second APB write + link training poll,
	 * matching factory order (pcie_asm.S:2724-2735). */
	if (ep->hw.irq > 0) {
		int ret = devm_request_threaded_irq(dev, ep->hw.irq,
						     rk35_ep_interrupt,
						     NULL,
						     IRQF_SHARED,
						     "miop_ep_irq", pcie);
		if (ret)
			dev_warn(dev, "request IRQ %d failed (%d)\n",
				 ep->hw.irq, ret);
		else
			dev_info(dev, "requested EP IRQ %d\n", ep->hw.irq);
	}

	/* APB glue second write: after IRQ request, factory writes
	 * apb[0x180]=0x100010 apb[0]=0xf00000 apb[0]=0xc000c
	 * (pcie_asm.S:2742-2754).  These trigger link-training LTSSM. */
	if (pcie->apb_base) {
		writel(0x100010, pcie->apb_base + 0x180);
		writel(0xf00000, pcie->apb_base);
		writel(0xc000c,  pcie->apb_base);
		dev_info(pcie->dev,
			 "apb[0x180]=%08x apb[0]=%08x\n",
			 readl(pcie->apb_base + 0x180),
			 readl(pcie->apb_base));
	}

	/* Bounded link-training poll. */
	miop_pcie_link_train(pcie);

	/* DMA engine init after link training (factory does this in the
	 * interrupt handler). Keep the ring-address/DBI register writes
	 * before link training since the factory also programs those before. */
	{
		u32 v;

		writel(1, pcie->dbi_base + 0x38000C);
		writel(1, pcie->dbi_base + 0x38002C);
		writel(0x40000308, pcie->dbi_base + 0x380300);
		writel(0,          pcie->dbi_base + 0x380304);
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800A8);
		writel(v & ~1u, pcie->dbi_base + 0x3800A8);
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800C4);
		writel(v | 0x10000, pcie->dbi_base + 0x3800C4);

		/* APB master interrupt gate — verify writable */
		writel(0x80000000, pcie->apb_base + 0x24);
		v = readl(pcie->apb_base + 0x24);
		dev_info(pcie->dev,
			 "DMA init: buf=%p dma=%pad ring_dma[0]=%llx "
			 "dbi=0x%08x ch_st=0x%08x "
			 "0x21C=0x%08x 0x31C=0x%08x 0x200=0x%08x "
			 "0x0A8=0x%08x 0x0C4=0x%08x "
			 "apb=%p apb[0x10]=0x%08x apb[0x18]=0x%08x "
			 "apb[0x24]=0x%08x wr24=0x%08x\n",
			 pcie->dma_buf, &pcie->dma_dma,
			 (u64)pcie->chan[0].ring_dma,
			 readl(pcie->dbi_base + 0x38000C),
			 readl(pcie->dbi_base + 0x38004C),
			 readl(pcie->dbi_base + 0x38021C),
			 readl(pcie->dbi_base + 0x38031C),
			 readl(pcie->dbi_base + 0x380200),
			 readl(pcie->dbi_base + 0x3800A8),
			 readl(pcie->dbi_base + 0x3800C4),
			 pcie->apb_base,
			 readl(pcie->apb_base + 0x10),
			 readl(pcie->apb_base + 0x18),
			 readl(pcie->apb_base + 0x24),
			 v);
	}

	/* Read EP's BAR0 from DBI config space */
	{
		u32 bar_low = rk35_pcie_readl_dbi(pcie->dbi_base, 0x10);
		u32 bar_high = rk35_pcie_readl_dbi(pcie->dbi_base, 0x14);
		u64 bar0 = (u64)bar_high << 32 | bar_low;
		dev_info(dev, "BAR0 (DBI): low=0x%08x high=0x%08x => 0x%llx\n",
			 bar_low, bar_high, bar0);
	}

	dev_info(dev, "Mixtile RK35 EP probe: n_free=%u n_win=%u serial=%#x link=%s\n",
		 ep->n_free, ep->n_win, pcie->serial,
		 pcie->link_up ? "up" : "down");

	dev_info(dev, "DMA engine init OK (self-test deferred to 35s work)\n");

	g_pcie = pcie;

	INIT_DELAYED_WORK(&pcie->bar_check_work, miop_pcie_bar_check_work);
	schedule_delayed_work(&pcie->bar_check_work, 35 * HZ);

	INIT_DELAYED_WORK(&pcie->rx_poll_work, miop_rx_poll_work_fn);
	schedule_delayed_work(&pcie->rx_poll_work, msecs_to_jiffies(50));

	return 0;
}

static int miop_elbi_enable_irq_dev(struct device *dev, u32 irq_idx)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;

	miop_elbi_enable_irq(pcie, irq_idx);
	return 0;
}

static int miop_elbi_disable_irq_dev(struct device *dev, u32 irq_idx)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;

	miop_elbi_disable_irq(pcie, irq_idx);
	return 0;
}

static struct miop_pcie_ep_driver miop_pcie_driver = {
	.init                = miop_pcie_ep_probe,
	.deinit              = NULL,
	.machine_id          = miop_ep_machine_id,
	.elbi_enable_irq     = miop_elbi_enable_irq_dev,
	.elbi_disable_irq    = miop_elbi_disable_irq_dev,
	.raise_peer_irq      = miop_raise_peer_irq,
	.dma_list_is_full    = miop_dma_list_is_full,
	.dma_list_commit_pending = miop_dma_list_commit_pending,
	.map_peer_bar        = NULL,	/* probe maps peer windows directly */
	.unmap_peer_bar      = miop_rk35_unmap_peer_bar,
	.map_rc_staging      = miop_rk35_map_rc_staging,
	.unmap_rc_staging    = miop_rk35_unmap_rc_staging,
	.dma_submit          = miop_rk35_dma_submit,
	.dma_submit_batch    = miop_rk35_dma_submit_batch,
};

/* ---- debugfs raw register poke (for bringing up the doorbell target) ---- */
static ssize_t miop_dbg_write(struct file *file, const char __user *ubuf,
			      size_t count, loff_t *off)
{
	char buf[64];
	u64 addr, val;
	void __iomem *va;

	if (count >= sizeof(buf))
		return -EINVAL;
	if (copy_from_user(buf, ubuf, count))
		return -EFAULT;
	buf[count] = 0;
	if (sscanf(buf, "%llx %llx", &addr, &val) != 2)
		return -EINVAL;

	va = ioremap(addr, 4);
	if (IS_ERR_OR_NULL(va))
		return -ENOMEM;
	writel((u32)val, va);
	iounmap(va);
	pr_info("miop dbg: wrote 0x%llx -> 0x%llx\n", val, addr);
	return count;
}

static const struct file_operations miop_dbg_fops = {
	.owner = THIS_MODULE,
	.write = miop_dbg_write,
};

static struct dentry *miop_dbg_dir;

static int __init miop_pcie_ep_module_init(void)
{
	printk(KERN_ERR "MIOP_PCIE_INIT_ENTER\n");
	printk(KERN_INFO "Mixtile TCP/IP over PCIe RK35 EP driver\n");
	miop_register_pcie_ep_drv(&miop_pcie_driver);
	printk(KERN_ERR "MIOP_PCIE_INIT_AFTER_REG drv=%px\n", &miop_pcie_driver);
	miop_dbg_dir = debugfs_create_dir("miop", NULL);
	if (miop_dbg_dir)
		debugfs_create_file("poke", 0200, miop_dbg_dir, NULL,
				    &miop_dbg_fops);
	return 0;
}

static void __exit miop_pcie_ep_module_exit(void)
{
	if (g_pcie)
		cancel_delayed_work_sync(&g_pcie->rx_poll_work);
	if (miop_dbg_dir)
		debugfs_remove_recursive(miop_dbg_dir);
	/* miop_register_pcie_ep_drv(NULL) retrieves (does not clear) the stored
	 * pointer; there is no "unregister" primitive in the registry, so just
	 * announce teardown. miop-ep.ko is not re-probed on unload in practice. */
	miop_register_pcie_ep_drv(NULL);
	printk(KERN_INFO "Mixtile TCP/IP over PCIe RK35 EP driver exit\n");
}

module_init(miop_pcie_ep_module_init);
module_exit(miop_pcie_ep_module_exit);
