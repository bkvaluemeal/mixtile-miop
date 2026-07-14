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

#include "miop.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe RK35 EP driver (thin C pass)");

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

	dev_info(dev, "Mixtile RK35 EP probe: n_free=%u n_win=%u\n",
		 ep->n_free, ep->n_win);

	return 0;
}

static struct miop_pcie_ep_driver miop_pcie_driver = {
	.probe = miop_pcie_ep_probe,
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
