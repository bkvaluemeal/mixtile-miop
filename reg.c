// SPDX-License-Identifier: GPL-2.0
//
// miop-reg: cross-module registry for the Mixtile TCP/IP-over-PCIe driver stack.
//
// The stack is layered: pcie-ep-rk35.ko provides the low-level RK35 PCIe
// endpoint + DMA engine, miop-ep-net.ko provides the network layer, and
// miop-ep.ko is the top-level endpoint driver. The two lower layers publish
// their driver structs here via miop_register_pcie_ep_drv() /
// miop_register_ep_net_drv(); miop-ep.ko's probe() blocks in
// miop_register_is_ready() until both have registered, then pulls them out
// and wires them into its struct miop_ep.
//
// This file is the C reimplementation of the original reg.S (decompiled from
// the vendor .ko). Behaviour is identical to the original.

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/mutex.h>
#include <linux/dma-mapping.h>
#include <linux/skbuff.h>

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe device driver registry");

/*
 * Guards the shared registry below. The original binary used a struct mutex
 * laid out in its .data section; DEFINE_MUTEX gives the same semantics.
 */
static DEFINE_MUTEX(miop_reg_lock);

/* The two driver structs published by the lower layers. */
struct miop_registry {
	const void *pcie_ep_drv;	/* from pcie-ep-rk35.ko */
	const void *ep_net_drv;		/* from miop-ep-net.ko */
};

static struct miop_registry miop_reg;

/**
 * miop_register_pcie_ep_drv() - register or fetch the PCIe EP driver struct.
 * @drv: driver struct pointer, or NULL to retrieve the current one.
 *
 * Getter/setter used by the lower layers to publish their driver struct into
 * the shared registry. Passing a non-NULL @drv stores it; passing NULL returns
 * the currently registered pointer (used by miop-ep.ko's probe to retrieve
 * what pcie-ep-rk35.ko registered).
 *
 * Return: the registered driver struct pointer.
 */
void *miop_register_pcie_ep_drv(void *drv)
{
	mutex_lock(&miop_reg_lock);
	if (drv)
		miop_reg.pcie_ep_drv = drv;
	else
		drv = (void *)miop_reg.pcie_ep_drv;
	mutex_unlock(&miop_reg_lock);
	return drv;
}
EXPORT_SYMBOL(miop_register_pcie_ep_drv);

/**
 * miop_register_ep_net_drv() - register or fetch the EP net driver struct.
 * @drv: driver struct pointer, or NULL to retrieve the current one.
 *
 * Symmetric to miop_register_pcie_ep_drv(), for the network-layer driver
 * struct published by miop-ep-net.ko.
 *
 * Return: the registered driver struct pointer.
 */
void *miop_register_ep_net_drv(void *drv)
{
	mutex_lock(&miop_reg_lock);
	if (drv)
		miop_reg.ep_net_drv = drv;
	else
		drv = (void *)miop_reg.ep_net_drv;
	mutex_unlock(&miop_reg_lock);
	return drv;
}
EXPORT_SYMBOL(miop_register_ep_net_drv);

/**
 * miop_register_is_ready() - report whether both drivers have registered.
 *
 * miop-ep.ko's probe() polls this (with a 1s sleep, up to 6 times) before it
 * will proceed. It returns true only once BOTH the PCIe EP driver and the EP
 * net driver have published their structs.
 *
 * Return: 1 if both drivers are registered, otherwise 0.
 */
int miop_register_is_ready(void)
{
	int ready = 0;

	mutex_lock(&miop_reg_lock);
	if (miop_reg.pcie_ep_drv && miop_reg.ep_net_drv)
		ready = 1;
	mutex_unlock(&miop_reg_lock);
	return ready;
}
EXPORT_SYMBOL(miop_register_is_ready);

/**
 * miop_free_dma_skb_head() - free the DMA-mapped backing pages of an skb head.
 * @dev:  the device the pages were mapped for.
 * @skb:  the socket buffer whose head region was DMA-mapped.
 * @size: size of the mapped region.
 *
 * Reconstructs the CPU virtual address of the dma-mapped skb head from a value
 * stashed at skb+200 (a packed form of the DMA address) and frees the backing
 * pages. This path is only exercised on teardown / error recovery.
 */
void miop_free_dma_skb_head(struct device *dev, struct sk_buff *skb, size_t size)
{
	/* Recover the CPU virtual address from the packed DMA handle stored at
	 * skb+200. The encoding is: add the high bit pattern, drop the low 12
	 * bits (page offset), then place it in the kernel direct/VM map region. */
	unsigned long v = *(unsigned long *)((unsigned char *)skb + 200);

	v += 0x1000000000000UL;
	v >>= 12;
	dma_free_pages(dev, size,
		       (struct page *)(0xfffffc0000000000UL + (v << 6)),
		       DMA_BIDIRECTIONAL, 2);
}
EXPORT_SYMBOL(miop_free_dma_skb_head);

/* Module init/exit merely announce presence in the kernel log. */
static int __init miop_reg_init(void)
{
	printk(KERN_INFO "Mixtile TCP/IP over PCIe device driver registry\n");
	return 0;
}

static void __exit miop_reg_exit(void)
{
	printk(KERN_INFO "Mixtile TCP/IP over PCIe device driver registry exit\n");
}

module_init(miop_reg_init);
module_exit(miop_reg_exit);
