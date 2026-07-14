// SPDX-License-Identifier: GPL-2.0
//
// miop-ep-net: network-layer driver for the Mixtile TCP/IP-over-PCIe stack.

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/netdevice.h>
#include <linux/etherdevice.h>
#include <linux/ethtool.h>
#include <linux/skbuff.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <linux/string.h>
#include <linux/dma-mapping.h>

#include "miop.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe EP network driver");

#define MIOP_NET_PRIV_SIZE  0x2c68
#define MIOP_NET_PRIV_BASE  0xa00

struct miop_net_priv {
	struct miop_ep *ep;
	struct miop_pcie_ep_driver *pcie_drv;
	struct net_device *netdev;
	struct device *dev;
	void *tx_ring;
	dma_addr_t tx_ring_dma;
	spinlock_t tx_lock;
};

static struct miop_net_priv *miop_net_priv(struct net_device *dev)
{
	return (struct miop_net_priv *)((char *)dev + MIOP_NET_PRIV_BASE);
}

static void miop_net_derive_mac(struct miop_ep *ep, u8 mac[ETH_ALEN])
{
	u64 v = (u64)(unsigned long)ep;
	mac[0] = 0x02;
	mac[1] = (v >> 28) & 0xff;
	mac[2] = (v >> 20) & 0xff;
	mac[3] = (v >> 12) & 0xff;
	mac[4] = (v >> 4) & 0xff;
	mac[5] = (v << 4) & 0xff;
}

static int miop_ndo_open(struct net_device *dev)
{
	netif_tx_start_all_queues(dev);
	return 0;
}

static int miop_ndo_stop(struct net_device *dev)
{
	netif_tx_stop_all_queues(dev);
	return 0;
}

static void miop_tx_complete(u64 cookie, u64 status)
{
	struct sk_buff *skb = (struct sk_buff *)(unsigned long)cookie;

	if (skb) {
		struct net_device *ndev = skb->dev;
		if (ndev)
			ndev->stats.tx_packets++;
		dev_kfree_skb_any(skb);
	}
}

static netdev_tx_t miop_ndo_start_xmit(struct sk_buff *skb,
				       struct net_device *dev)
{
	struct miop_net_priv *priv = miop_net_priv(dev);
	struct miop_pcie_ep_driver *pdrv = priv->pcie_drv;
	struct device *pdev = priv->dev;
	dma_addr_t dma;
	int ret;

	if (!pdrv || !pdrv->dma_submit || !pdev) {
		dev_kfree_skb_any(skb);
		return NETDEV_TX_OK;
	}

	dma = dma_map_single(pdev, skb->data, skb->len, DMA_TO_DEVICE);
	if (dma_mapping_error(pdev, dma)) {
		dev->stats.tx_dropped++;
		dev_kfree_skb_any(skb);
		return NETDEV_TX_OK;
	}

	ret = pdrv->dma_submit(pdev, 0, dma, 0, skb->len,
			       (u64)(unsigned long)skb, miop_tx_complete);
	if (ret) {
		dma_unmap_single(pdev, dma, skb->len, DMA_TO_DEVICE);
		dev->stats.tx_dropped++;
		dev_kfree_skb_any(skb);
		return NETDEV_TX_OK;
	}

	dev->stats.tx_bytes += skb->len;
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

static int miop_on_peer_online(struct miop_ep *ep, int peer)
{
	struct miop_net_priv *priv =
		(struct miop_net_priv *)ep->hw.net_priv;

	if (priv && priv->netdev)
		netif_carrier_on(priv->netdev);
	return 0;
}

static int miop_on_peer_offline(struct miop_ep *ep, int peer)
{
	return 0;
}

static int miop_on_rx(struct miop_ep *ep, int peer, void *buf, int len)
{
	struct miop_net_priv *priv;
	struct net_device *netdev;
	struct sk_buff *skb;

	if (!ep || !ep->hw.net_priv)
		return 0;

	priv = (struct miop_net_priv *)ep->hw.net_priv;
	netdev = priv->netdev;
	if (!netdev)
		return 0;

	skb = netdev_alloc_skb(netdev, len + NET_IP_ALIGN);
	if (!skb) {
		netdev->stats.rx_dropped++;
		return 0;
	}

	skb_reserve(skb, NET_IP_ALIGN);
	skb_put_data(skb, buf, len);
	skb->protocol = eth_type_trans(skb, netdev);
	skb->dev = netdev;

	netdev->stats.rx_packets++;
	netdev->stats.rx_bytes += len;

	netif_receive_skb(skb);
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

int miop_ep_net_init(struct device *dev)
{
	struct miop_ep *ep;
	struct net_device *netdev;
	struct miop_net_priv *priv;
	u8 mac[ETH_ALEN];

	ep = *(struct miop_ep **)((char *)dev + 0x78);
	if (!ep) {
		dev_err(dev, "net_init: no ep at dev+0x78\n");
		return -EINVAL;
	}

	netdev = alloc_etherdev_mqs(MIOP_NET_PRIV_SIZE, 4, 4);
	if (!netdev) {
		dev_err(dev, "net_init: alloc_etherdev failed\n");
		return -ENOMEM;
	}

	priv = miop_net_priv(netdev);
	priv->ep = ep;
	priv->netdev = netdev;
	priv->dev = dev;
	priv->pcie_drv = ep->pcie_ep_drv;
	spin_lock_init(&priv->tx_lock);

	ep->hw.net_priv = (void *)((char *)netdev + MIOP_NET_PRIV_BASE);

	strscpy(netdev->name, "pci0", sizeof(netdev->name));
	netdev->netdev_ops = &miop_netdev_ops;

	miop_net_derive_mac(ep, mac);
	eth_hw_addr_set(netdev, mac);

	if (register_netdev(netdev)) {
		dev_err(dev, "net_init: register_netdev failed\n");
		free_netdev(netdev);
		return -ENOMEM;
	}

	dev_info(dev, "net_init: registered %s\n", netdev->name);
	netif_carrier_off(netdev);
	return 0;
}
EXPORT_SYMBOL(miop_ep_net_init);

int miop_ep_net_deinit(struct device *dev)
{
	struct miop_ep *ep;
	struct miop_net_priv *priv;
	struct net_device *netdev;

	ep = *(struct miop_ep **)((char *)dev + 0x78);
	if (!ep || !ep->hw.net_priv)
		return 0;

	priv = (struct miop_net_priv *)ep->hw.net_priv;
	netdev = priv->netdev;
	if (netdev) {
		unregister_netdev(netdev);
		free_netdev(netdev);
	}
	ep->hw.net_priv = NULL;
	return 0;
}
EXPORT_SYMBOL(miop_ep_net_deinit);

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
