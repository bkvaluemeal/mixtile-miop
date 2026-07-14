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
