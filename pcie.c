// SPDX-License-Identifier: GPL-2.0
//
// pcie-ep-rk35: low-level RK35 PCIe endpoint + DMA driver for the Mixtile
// TCP/IP-over-PCIe stack.
//
// This is the C reimplementation of the original pcie.S (decompiled from the
// vendor .ko). It is the lowest layer of the stack: it owns the RK3588 PCIe EP
// controller, trains the link against the peer blade, programs the inbound/
// outbound iATU windows, wires up the MSI/legacy IRQ and runs the peer/link
// handshake that eventually drives miop-ep-net.ko's on_peer_* callbacks.
//
// This is the FIRST, intentionally-thin pass. The module registers the same
// driver struct with miop-reg.ko (so miop-ep.ko's probe() will proceed and
// hand control here via ->probe), but the real EP/link/DMA logic is stubbed:
// miop_pcie_ep_probe() returns success without training the link. The link
// therefore does not come up (expected for this pass); the RX/TX/ATU/IRQ logic
// is filled in in a later pass. The RX ring alloc/free helpers used by this
// layer live in ep.c (published through struct miop_ep_hw.func_a/func_b).

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

	/* APB glue. */
	writel(0x8000800, apb);
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
 * miop_ep_irq_stub() - minimal IRQ handler. The vendor's real handler
 * (rk35_ep_interrupt) reaps the DMA rings and drives the peer handshake; that
 * is wired in a later pass. Here we clear the APB status register
 * (apb+0x10, written back to clear) so a level-triggered line cannot storm,
 * and report handled.
 */
static irqreturn_t miop_ep_irq_stub(int irq, void *dev_id)
{
	struct miop_pcie *pcie = dev_id;

	if (pcie && pcie->apb_base) {
		u32 st = readl(pcie->apb_base + 0x10);

		writel(st, pcie->apb_base + 0x10);
	}
	return IRQ_HANDLED;
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

	/* Controller / DLL configuration (DBI/APB pokes). */
	miop_pcie_config_controller(pcie, ep);

	/* Trigger link training: three writes to dbi_base2 (pcie_asm.S:2742-2754).
	 * Factory struct has dbi_base2 at +16, apb_base at +24; in our struct
	 * the offsets are swapped, so target pcie->dbi_base2 explicitly. */
	if (pcie->dbi_base2) {
		writel(0x100010, pcie->dbi_base2 + 0x180);
		writel(0xf00000, pcie->dbi_base2);
		writel(0xc000c,  pcie->dbi_base2);
	}

	/* Bounded link-training poll. */
	miop_pcie_link_train(pcie);

	/* Request the EP "sys" IRQ with a stub handler (clears status). The real
	 * DMA-reap / peer-handshake handler is wired in a later pass. */
	if (ep->hw.irq > 0) {
		int ret = devm_request_threaded_irq(dev, ep->hw.irq,
						     miop_ep_irq_stub,
						     miop_ep_irq_stub,
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
	.init = miop_pcie_ep_probe,
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
