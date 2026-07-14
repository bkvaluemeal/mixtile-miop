// SPDX-License-Identifier: GPL-2.0
//
// miop-ep-net: network-layer driver for the Mixtile TCP/IP-over-PCIe stack.
//
// This is the C reimplementation of the original net.S (decompiled from the
// vendor .ko). It is the "glue" layer of the network side: miop-ep.ko calls
// miop_ep_net_init() to allocate and register the pci0 netdev, and the lower
// layer (pcie-ep-rk35.ko) invokes the on_peer_*/on_rx/on_tx_ready callbacks to
// drive the peer/link handshake and data path.
//
// This is the FIRST, intentionally-thin pass: the module registers the same
// driver interface and netdev as the original, and establishes the ABI-critical
// linkages (the net priv is a fixed 0x2c68-byte area addressed by absolute
// offset, with ep+0x150 -> priv and priv+8 -> ep). The data-path callbacks are
// safe stubs; the RX/TX ring + DMA logic is filled in in a later pass.

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/ethtool.h>
#include <linux/skbuff.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <linux/string.h>

#include "miop.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe EP network driver (thin C pass)");

/*
 * The factory binary allocates the netdev with a 0x2c68-byte private area and
 * addresses its own fields by absolute offset from (netdev + 0xa00). We keep
 * the same size/offset so the factory pcie-ep-rk35.ko (which writes into this
 * area during link-up) stays ABI-compatible.
 */
#define MIOP_NET_PRIV_SIZE	0x2c68
#define MIOP_NET_PRIV_BASE	0xa00

/* TODO(thin pass): the factory derives the MAC from miop_ep_machine_id()
 * (in pcie-ep-rk35.ko, not exported). For this first pass we derive a stable
 * locally-administered address from the ep pointer instead. */
static void miop_net_derive_mac(struct miop_ep *ep, u8 mac[ETH_ALEN])
{
	u64 v = (u64)(unsigned long)ep;

	mac[0] = 0x02;	/* locally administered */
	mac[1] = (v >> 28) & 0xff;
	mac[2] = (v >> 20) & 0xff;
	mac[3] = (v >> 12) & 0xff;
	mac[4] = (v >> 4) & 0xff;
	mac[5] = (v << 4) & 0xff;
}

/* The registry (miop_register_ep_net_drv / miop_register_is_ready) lives in
 * miop-reg.ko and is declared in miop.h; we just call into it here. */

/* ---- net priv helpers -----------------------------------------------------
 * The "priv" base used throughout is (netdev + MIOP_NET_PRIV_BASE). The asm
 * stores the ep pointer at priv+8 and the netdev pointer at priv+48, and the
 * ep stores the priv back-pointer at ep+0x150 (hw.net_priv).
 */
static inline void **miop_priv_ep_slot(void *mpriv)
{
	return (void **)((char *)mpriv + 8);
}
static inline struct net_device **miop_priv_netdev_slot(void *mpriv)
{
	return (struct net_device **)((char *)mpriv + 48);
}

/* ---- thin netdev ops ------------------------------------------------------ */
static int miop_ndo_open(struct net_device *dev)
{
	/* Bring the queue up; carrier is flipped on by the link handshake. */
	netif_carrier_on(dev);
	return 0;
}

static int miop_ndo_stop(struct net_device *dev)
{
	netif_carrier_off(dev);
	return 0;
}

static netdev_tx_t miop_ndo_start_xmit(struct sk_buff *skb,
				       struct net_device *dev)
{
	/* Thin pass: the TX ring/DMA path is not implemented yet. Drop safely. */
	dev_kfree_skb_any(skb);
	return NETDEV_TX_OK;
}

static int miop_ndo_change_mtu(struct net_device *dev, int new_mtu)
{
	if (new_mtu < 68 || new_mtu > 65535)
		return -EINVAL;
	dev->mtu = new_mtu;
	return 0;
}

static const struct net_device_ops miop_netdev_ops = {
	.ndo_open = miop_ndo_open,
	.ndo_stop = miop_ndo_stop,
	.ndo_start_xmit = miop_ndo_start_xmit,
	.ndo_change_mtu = miop_ndo_change_mtu,
};

/* ---- thin peer/data-path callbacks (safe stubs) --------------------------- */
static int miop_on_peer_online(struct miop_ep *ep, int peer)
{
	/* Factory sets up the peer's TX/RX rings + flips carrier here. Thin pass
	 * leaves it to a later increment; return success so the handshake
	 * proceeds. */
	return 0;
}

static int miop_on_peer_offline(struct miop_ep *ep, int peer)
{
	return 0;
}

static int miop_on_rx(struct miop_ep *ep, int peer, void *buf, int len)
{
	return 0;
}

static int miop_on_tx_ready(struct miop_ep *ep, int peer)
{
	return 0;
}

static int miop_on_rx_full(struct miop_ep *ep, int peer)
{
	return 0;
}

/* Forward declarations (defined below) so the struct initializer can reference
 * them. */
int miop_ep_net_init(struct device *dev);
int miop_ep_net_deinit(struct device *dev);

static struct miop_ep_net_driver miop_net_driver = {
	.init = miop_ep_net_init,
	.remove = miop_ep_net_deinit,
	.on_peer_online = miop_on_peer_online,
	.on_peer_offline = miop_on_peer_offline,
	.on_rx = miop_on_rx,
	.on_tx_ready = miop_on_tx_ready,
	.on_rx_full = miop_on_rx_full,
};

/* ---- init / deinit ------------------------------------------------------- */
int miop_ep_net_init(struct device *dev)
{
	struct miop_ep *ep;
	struct net_device *netdev;
	void *mpriv;
	u8 mac[ETH_ALEN];

	/* ep.c stored the ep pointer at pdev+0x88; dev is pdev+0x10. */
	ep = *(struct miop_ep **)((char *)dev + 0x78);
	if (!ep)
		return -EINVAL;

	netdev = alloc_etherdev_mqs(MIOP_NET_PRIV_SIZE, 4, 4);
	if (!netdev)
		return -ENOMEM;

	mpriv = (char *)netdev + MIOP_NET_PRIV_BASE;
	*miop_priv_ep_slot(mpriv) = ep;		/* priv+8 = ep */
	*miop_priv_netdev_slot(mpriv) = netdev;	/* priv+48 = netdev */
	ep->hw.net_priv = mpriv;			/* ep+0x150 = priv */

	netdev->netdev_ops = &miop_netdev_ops;

	/* Derive a stable locally-administered MAC (placeholder for the real
	 * miop_ep_machine_id serial derivation). */
	miop_net_derive_mac(ep, mac);
	eth_hw_addr_set(netdev, mac);

	if (register_netdev(netdev)) {
		free_netdev(netdev);
		return -ENOMEM;
	}

	netif_carrier_off(netdev);
	return 0;
}
EXPORT_SYMBOL(miop_ep_net_init);

int miop_ep_net_deinit(struct device *dev)
{
	struct miop_ep *ep;
	struct net_device *netdev;
	void *mpriv;

	ep = *(struct miop_ep **)((char *)dev + 0x78);
	if (!ep || !ep->hw.net_priv)
		return 0;

	mpriv = ep->hw.net_priv;
	netdev = *miop_priv_netdev_slot(mpriv);
	if (netdev) {
		unregister_netdev(netdev);
		free_netdev(netdev);
	}
	ep->hw.net_priv = NULL;
	return 0;
}
EXPORT_SYMBOL(miop_ep_net_deinit);

/* ---- module init/exit: publish the driver struct ---------------- */
static int __init miop_ep_net_module_init(void)
{
	printk(KERN_INFO "Mixtile TCP/IP over PCIe EP network driver\n");
	miop_register_ep_net_drv(&miop_net_driver);
	return 0;
}

static void __exit miop_ep_net_module_exit(void)
{
	miop_register_ep_net_drv(NULL);
}

module_init(miop_ep_net_module_init);
module_exit(miop_ep_net_module_exit);
