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

#include "miop.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe RK35 EP driver (thin C pass)");

/*
 * miop_pcie_ep_probe() - EP controller bring-up, called by miop-ep.ko.
 * @dev: the endpoint struct device (pdev+0x10, as passed by miop-ep.ko).
 *
 * The original binary, here, initialised the RK3588 PCIe EP controller,
 * trained the link to the peer blade, programmed the outbound iATU windows
 * (the "outbound free_win" messages), set up MSI/legacy IRQs, started the
 * peer handshake and flipped the net carrier once the peer came online.
 *
 * Thin pass: do none of that. Return success so miop-ep.ko's probe() can
 * complete; the link simply will not come up until the real logic lands.
 *
 * Return: 0.
 */
static int miop_pcie_ep_probe(struct device *dev)
{
	return 0;
}

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
