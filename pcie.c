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

#include "miop.h"

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
 * iATU window. `target` is the low 32 bits of the peer target address, `size`
 * the window size, `extra` an added offset folded into the limit register.
 * Returns 0 on success, -EINVAL if no free window.
 */
int miop_ep_map_outbound_atu(struct miop_pcie *pcie, u32 target, u32 size, u32 extra)
{
	struct miop_ep *ep = pcie->ep;
	unsigned long n_win = ep->n_win;
	unsigned long bit;
	void *win;
	int tries = 5;

	bit = find_first_zero_bit(pcie->map2, n_win);
	if (bit >= n_win) {
		dev_err(pcie->dev, "outbound free_win exhausted\n");
		return -EINVAL;
	}

	win = (char *)pcie->atu_base + (bit << 9);
	writel(target, (char *)win + 0x8);
	writel(0, (char *)win + 0xc);
	writel(target - 1 + extra, (char *)win + 0x10);
	writel(size, (char *)win + 0x14);
	writel(0, (char *)win + 0x18);
	writel(0, (char *)win + 0x0);
	writel(0x80000000, (char *)win + 0x4);

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
	dev_err(pcie->dev, "outbound free_win %lu target %#x size %#x\n",
		bit, target, size);

	set_bit(bit, pcie->map2);
	pcie->addrs[bit] = target;
	return 0;
}
EXPORT_SYMBOL(miop_ep_map_outbound_atu);

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

	/* APB glue — factory writes to apb_base three times at probe:
	 *   apb[0x180] = 0x100010   — APB control
	 *   apb[0]     = 0xf00000   — APB glue (first)
	 *   apb[0]     = 0xc000c    — APB glue (second, overwrites first)
	 * Bits 2/3 in 0xc000c likely enable DMA channel completion IRQs. */
	writel(0x100010, apb + 0x180);
	writel(0xf00000, apb);
	writel(0xc000c,  apb);

	/* Enable all interrupt sources (DMA completion, doorbell, etc.)
	 * on the APB interrupt enable register (DWC standard: +0x18). */
	writel(0x0000ffff, apb + 0x18);

	writel(0x80000000, apb + 0x24);

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
	miop_pcie_ep_set_bar(pcie, 0, 0x2000000, 0xc);
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
static void miop_pcie_peer_online(struct miop_pcie *pcie)
{
	struct miop_ep *ep = pcie->ep;
	struct miop_ep_net_driver *net = ep->net_drv;
	int ret;

	if (!net || !net->on_peer_online)
		return;
	/* TODO: target = peer BAR base from MIOP header; then
	 * miop_ep_map_outbound_atu(pcie, target, size, extra). */
	ret = net->on_peer_online(ep, 0);
	dev_info(pcie->dev,
		 "peer online -> net_drv->on_peer_online(peer=0) = %d\n", ret);
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
	u32 v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380010);

	dev_info(pcie->dev, "DMA doorbell: read 0x%08x write ch=%u 0x%08x\n",
		 v, ch, (v & ~7) | ch);
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

	if (ch >= MIOP_DMA_NUM_CH)
		return -EINVAL;

	chan = &pcie->chan[ch];
	spin_lock_irqsave(&chan->lock, flags);

	idx = chan->prod_idx;
	desc = &chan->ring[idx];
	track = &chan->track[idx];

	if (desc->status & 1) {
		dev_err(pcie->dev, "dma_submit: ring[%u] full, advancing\n", idx);
		idx = (idx + 1) & (MIOP_DMA_RING_SIZE - 1);
		chan->prod_idx = idx;
		desc = &chan->ring[idx];
		track = &chan->track[idx];
	}

	desc->len       = len;
	desc->addr_low  = (u32)data;
	desc->addr_high = (u32)(data >> 32);
	desc->meta_len  = (u16)ext;
	desc->meta      = (u16)(ext >> 16);
	desc->meta2     = (u32)(ext >> 32);

	track->cookie = cookie;
	track->cb     = cb;
	track->dma    = (dma_addr_t)data;
	track->len    = len;

	wmb();
	desc->status = 1;
	wmb();

	chan->prod_idx = (idx + 1) & (MIOP_DMA_RING_SIZE - 1);

	spin_unlock_irqrestore(&chan->lock, flags);

	dev_info(pcie->dev, "dma_submit ch=%u prod=%u len=%u dma=%llx desc[%u].status=%u\n",
		 ch, chan->prod_idx, len, data, idx, desc->status);
	rk35_dma_start_write(pcie, ch);
	if (miop_dma_try_reap(pcie, ch))
		dev_info(pcie->dev, "try_reap after submit: reaped on ch%u\n", ch);
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

		if (desc->status & 1)
			break;

		save_dma    = track->dma;
		save_len    = track->len;
		save_cookie = track->cookie;
		save_cb     = track->cb;
		save_status = desc->status;

		memset(desc, 0, sizeof(*desc));
		memset(track, 0, sizeof(*track));
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
	return done;
}

/*
 * miop_raise_peer_irq() — notify the RC that new data is available in our
 * descriptor ring. Writes a doorbell value to the RC-visible doorbell reg.
 * Translated from pcie_asm.S line 782.
 */
static int miop_raise_peer_irq(struct device *dev, u32 peer_id, u32 vector)
{
	struct miop_ep *ep = *(struct miop_ep **)((char *)dev + 0x78);
	struct miop_pcie *pcie = ep->pcie_priv;

	if (!pcie->dbi_base)
		return 0;

	/* write vector to the doorbell register the RC monitors */
	writel(vector, pcie->dbi_base + 0x200e00);
	return 0;
}

/*
 * rk35_ep_interrupt() — EP interrupt handler. Reads APB status, handles
 * doorbells from the RC, and reaps completed DMA descriptors.
 * Translated from pcie_asm.S line 1208.
 */
static irqreturn_t rk35_ep_interrupt(int irq, void *dev_id)
{
	struct miop_pcie *pcie = dev_id;
	struct miop_ep *ep;
	struct miop_ep_net_driver *net;
	u32 apb_st;

	if (!pcie || !pcie->apb_base)
		return IRQ_NONE;

	apb_st = readl(pcie->apb_base + 0x10);

	dev_info(pcie->dev, "IRQ apb_st=0x%08x\n", apb_st);

	if (apb_st & (1u << 15)) {
		u32 db_val = rk35_pcie_readl_dbi(pcie->dbi_base, 0x200e00);
		u32 peer = (db_val >> 8) & 0xff;

		dev_info(pcie->dev, "IRQ doorbell db_val=0x%08x peer=%u\n",
			 db_val, peer);

		ep = pcie->ep;
		net = ep ? ep->net_drv : NULL;

		if (net) {
			if (db_val & 1)
				net->on_peer_online(ep, peer);
			if (db_val & 2)
				net->on_rx(ep, peer, NULL, 0);
			if (db_val & 4)
				net->on_tx_ready(ep, peer);
			if (db_val & 8)
				net->on_peer_offline(ep, peer);
		}
	}

	{
		int reaped = miop_dma_try_reap(pcie, 0);
		if (reaped)
			dev_info(pcie->dev, "IRQ reaped %d on ch0\n", reaped);
	}
	{
		int reaped = miop_dma_try_reap(pcie, 1);
		if (reaped)
			dev_info(pcie->dev, "IRQ reaped %d on ch1\n", reaped);
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

static int miop_elbi_enable_irq(struct device *dev, u32 irq_idx)
{
	return 0;
}

static int miop_elbi_disable_irq(struct device *dev, u32 irq_idx)
{
	return 0;
}

static void *miop_rk35_map_peer_bar(struct device *dev, u32 peer,
				    u64 phys, u32 size, u64 *out_phys)
{
	return NULL;
}

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
 * Early/structural bring-up transcribed from pcie.S miop_pcie_ep_init:
 * allocate the pcie private, ioremap the DBI/APB windows, allocate the
 * outbound-window bitmaps from the EP window counts, and carve out the TX/DMA
 * coherent buffer. Link training, BAR setup, the outbound ATU mappings, IRQ
 * wiring and the peer handshake (which calls net_drv->on_peer_online) are
 * still to be wired in later passes; returning success here keeps the module
 * loadable so this structural setup can be verified without touching the link.
 */
static int miop_pcie_ep_probe(struct device *dev)
{
	struct platform_device *pdev = to_platform_device(dev);
	struct miop_ep *ep = platform_get_drvdata(pdev);
	struct miop_pcie *pcie;
	void __iomem *dbi_base, *apb_base;
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
	pcie->dbi_base2 = (char __iomem *)dbi_base + 0x100000;
	pcie->atu_base = (char __iomem *)dbi_base + 0x300000;

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

	/* Initialize DMA rings (in our 4 MiB coherent buffer).
	 * Per the factory, each ring has 128 × 24-byte descriptors followed
	 * by a 24-byte control trailer at offset 0xC00.  The trailer contains
	 * a magic byte at +0 and the ring's own bus address at +8 (used by
	 * the hardware to locate the ring when the doorbell is rung). */
	{
		int i;

		for (i = 0; i < MIOP_DMA_NUM_CH; i++) {
			struct miop_pcie_channel *ch = &pcie->chan[i];
			size_t ring_sz = MIOP_DMA_RING_SIZE *
					 sizeof(struct miop_dma_desc);
			u8 *ctrl;
			int j;

			ch->ring = (struct miop_dma_desc *)((char *)dma_buf +
							    0x100000 + i * ring_sz);
			ch->ring_dma = dma_dma + 0x100000 + i * ring_sz;
			ch->prod_idx = 0;
			ch->cons_idx = 0;
			spin_lock_init(&ch->lock);

			/* Control trailer at ring + 0xC00 */
			ctrl = (u8 *)ch->ring + ring_sz;
			ctrl[0] = 0x05;
			*(u32 *)(ctrl + 8) = (u32)ch->ring_dma;
			*(u32 *)(ctrl + 12) = 0;
			for (j = 1; j < 8; j++)
				ctrl[j] = 0;
			dmb(oshst);
		}
	}

	/* Controller / DLL configuration (DBI/APB pokes). */
	miop_pcie_config_controller(pcie, ep);

	/* Program per-channel DMA ring address + descriptor config into the
	 * DBI APP region registers (pcie_asm.S batch-submit path lines 995-1014).
	 * Without this the DMA engine cannot locate the descriptor ring. */
	{
		int i;
		u32 v;

		for (i = 0; i < MIOP_DMA_NUM_CH; i++) {
			u32 base = 0x380000 + i * 0x200;
			dma_addr_t dma = pcie->chan[i].ring_dma;

			writel(0x40000308, pcie->dbi_base + base + 0x200);
			writel(0,          pcie->dbi_base + base + 0x204);
			writel((u32)dma,   pcie->dbi_base + base + 0x21C);
			writel((u32)(dma >> 32), pcie->dbi_base + base + 0x220);
		}

		/* Enable per-channel interrupts in DBI+0x380090 (factory line 1031). */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380090);
		for (i = 0; i < MIOP_DMA_NUM_CH; i++)
			v |= (1u << (16 + i));
		writel(v, pcie->dbi_base + 0x380090);

		/* Clear any stale doorbell-pending bits at DBI+0x380054. */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x380054);
		for (i = 0; i < MIOP_DMA_NUM_CH; i++)
			v &= ~(1u << i);
		writel(v, pcie->dbi_base + 0x380054);

		/* Enable DMA engine (factory batch path line 990 / irq init line 1367). */
		writel(1, pcie->dbi_base + 0x38000C);
		/* Per-channel enable (factory irq init line 1438). */
		writel(1, pcie->dbi_base + 0x38002C);
		/* Descriptor config at ch0+0x100 offset (factory irq init line 1441). */
		writel(0x40000308, pcie->dbi_base + 0x380300);
		writel(0,          pcie->dbi_base + 0x380304);
		/* Clear bit 0 of 0x3800A8 (factory irq init line 1451). */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800A8);
		writel(v & ~1u, pcie->dbi_base + 0x3800A8);
		/* Set bit 16 of 0x3800C4 (factory irq init line 1461). */
		v = rk35_pcie_readl_dbi(pcie->dbi_base, 0x3800C4);
		writel(v | 0x10000, pcie->dbi_base + 0x3800C4);
		/* Arm both channels (factory batch path line 1044, arm value
		 * computed as (1 << ch) * 0x10001 = 0x10001 << ch). */
		for (i = 0; i < MIOP_DMA_NUM_CH; i++)
			writel(0x10001 << i, pcie->dbi_base + 0x380058);

		dev_info(pcie->dev,
			 "DMA init: buf=%p dma=%pad ring_dma[0]=%llx dbi=0x%08x\n",
			 pcie->dma_buf, &pcie->dma_dma,
			 (u64)pcie->chan[0].ring_dma,
			 readl(pcie->dbi_base + 0x38000C));
	}

	/* MIOP tag + ring flag written to DBI (pcie_asm.S:2702-2723). */
	writel(0x100000, pcie->dbi_base + 0x200e14);
	writel(0x504f494d, pcie->dbi_base + 0x200e10);

	/* Trigger link training: three writes to apb_base (pcie_asm.S:2742-2754). */
	if (pcie->apb_base) {
		writel(0xf00000, pcie->apb_base);
		writel(0xc000c,  pcie->apb_base);
		dev_info(pcie->dev,
			 "apb[0x180]=%08x apb[0]=%08x\n",
			 readl(pcie->apb_base + 0x180),
			 readl(pcie->apb_base));
	}

	/* Bounded link-training poll. */
	miop_pcie_link_train(pcie);

	/* Request the EP IRQ — rk35_ep_interrupt reaps DMA completions
	 * and handles doorbells from the RC. */
	if (ep->hw.irq > 0) {
		int ret = devm_request_threaded_irq(dev, ep->hw.irq,
						     rk35_ep_interrupt,
						     rk35_ep_interrupt,
						     IRQF_SHARED,
						     "miop_ep_irq", pcie);
		if (ret)
			dev_warn(dev, "request IRQ %d failed (%d)\n",
				 ep->hw.irq, ret);
		else
			dev_info(dev, "requested EP IRQ %d\n", ep->hw.irq);
	}

	dev_info(dev, "Mixtile RK35 EP probe: n_free=%u n_win=%u serial=%#x link=%s\n",
		 ep->n_free, ep->n_win, pcie->serial,
		 pcie->link_up ? "up" : "down");

	return 0;
}

static struct miop_pcie_ep_driver miop_pcie_driver = {
	.init                = miop_pcie_ep_probe,
	.deinit              = NULL,
	.machine_id          = miop_ep_machine_id,
	.elbi_enable_irq     = miop_elbi_enable_irq,
	.elbi_disable_irq    = miop_elbi_disable_irq,
	.raise_peer_irq      = miop_raise_peer_irq,
	.dma_list_is_full    = miop_dma_list_is_full,
	.dma_list_commit_pending = miop_dma_list_commit_pending,
	.map_peer_bar        = miop_rk35_map_peer_bar,
	.unmap_peer_bar      = miop_rk35_unmap_peer_bar,
	.map_rc_staging      = miop_rk35_map_rc_staging,
	.unmap_rc_staging    = miop_rk35_unmap_rc_staging,
	.dma_submit          = miop_rk35_dma_submit,
	.dma_submit_batch    = miop_rk35_dma_submit_batch,
};

/* ---- module init/exit: publish the driver struct ---------------- */
static int __init miop_pcie_ep_module_init(void)
{
	printk(KERN_INFO "Mixtile TCP/IP over PCIe RK35 EP driver\n");
	miop_register_pcie_ep_drv(&miop_pcie_driver);
	return 0;
}

static void __exit miop_pcie_ep_module_exit(void)
{
	/* miop_register_pcie_ep_drv(NULL) retrieves (does not clear) the stored
	 * pointer; there is no "unregister" primitive in the registry, so just
	 * announce teardown. miop-ep.ko is not re-probed on unload in practice. */
	miop_register_pcie_ep_drv(NULL);
	printk(KERN_INFO "Mixtile TCP/IP over PCIe RK35 EP driver exit\n");
}

module_init(miop_pcie_ep_module_init);
module_exit(miop_pcie_ep_module_exit);
