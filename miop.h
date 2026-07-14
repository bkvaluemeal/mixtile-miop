/* SPDX-License-Identifier: GPL-2.0 */
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

struct miop_ep;
struct miop_pcie;

#define MIOP_DMA_RING_SIZE 128
#define MIOP_DMA_NUM_CH 2

struct miop_pcie_ep_driver {
	int (*init)(struct device *dev);
	int (*deinit)(struct device *dev);
	u32 (*machine_id)(struct miop_ep *ep);
	int (*elbi_enable_irq)(struct device *dev, u32 irq_idx);
	int (*elbi_disable_irq)(struct device *dev, u32 irq_idx);
	int (*raise_peer_irq)(struct device *dev, u32 peer_id, u32 vector);
	int (*dma_list_is_full)(struct device *dev, u32 channel);
	void (*dma_list_commit_pending)(struct device *dev);
	void *(*map_peer_bar)(struct device *dev, u32 peer, u64 phys, u32 size, u64 *out_phys);
	void (*unmap_peer_bar)(struct device *dev, u32 peer);
	void *(*map_rc_staging)(struct device *dev, u64 phys, u32 size, u32 dir);
	void (*unmap_rc_staging)(struct device *dev, u32 dir);
	int (*dma_submit)(struct device *dev, u32 ch, u64 data, u64 ext, u32 len, u64 cookie, void *cb);
	int (*dma_submit_batch)(struct device *dev, u32 ch, void *batch, u32 count, u64 comp, void *cb);
};

struct miop_ep_net_driver {
	int (*init)(struct device *dev);
	int (*remove)(struct device *dev);
	int (*on_peer_online)(struct miop_ep *ep, int peer);
	int (*on_peer_offline)(struct miop_ep *ep, int peer);
	int (*on_rx)(struct miop_ep *ep, int peer, void *buf, int len);
	int (*on_tx_ready)(struct miop_ep *ep, int peer);
	int (*on_rx_full)(struct miop_ep *ep, int peer);
};

struct miop_ep_hw {
	struct phy *phy;
	struct clk_bulk_data *clks;
	u32 clk_count;
	u32 _pad0[1];
	struct reset_control *reset;
	struct regulator *regulator;
	struct resource *res_dbi;
	struct resource *res_apb;
	struct gpio_desc *reset_gpio;
	int irq;
	u32 num_ib_windows;
	u32 num_ob_windows;
	u32 num_lanes;
	phys_addr_t region_start;
	u64 _pad_region;
	u32 region_size;
	u8 has_tx_staging;
	u8 _pad2[3];
	phys_addr_t tx_staging_start;
	phys_addr_t tx_staging_size;
	u64 rx_region_ctx;
	u32 rx_region_size[4];
	u64 _pad_90[4];
	void *rx_region_vaddr[4];
	u64 _pad_c0[4];
	dma_addr_t rx_region_dma[4];
	u64 _pad_100[4];
	void *func_a;
	void *func_b;
	u64 _pad130;
	void *net_priv;
};

/* DMA descriptor: 24 bytes */
struct miop_dma_desc {
	u32 status;
	u32 len;
	u32 addr_low;
	u32 addr_high;
	u16 meta_len;
	u16 meta;
	u32 meta2;
};

/* Shadow tracking per descriptor */
struct miop_dma_track {
	u64 cookie;
	void (*cb)(u64 cookie, u64 status);
	dma_addr_t dma;
	u32 len;
};

#define MIOP_DMA_DESC_SIZE sizeof(struct miop_dma_desc)

struct miop_pcie_channel {
	struct miop_dma_desc *ring;
	dma_addr_t ring_dma;
	u16 prod_idx;
	u16 cons_idx;
	spinlock_t lock;
	struct miop_dma_track track[MIOP_DMA_RING_SIZE];
};

struct miop_pcie {
	struct miop_ep *ep;
	void __iomem *dbi_base;
	void __iomem *dbi_base2;
	void __iomem *apb_base;
	void __iomem *atu_base;
	struct device *dev;
	unsigned long *map1;
	unsigned long *map2;
	u64 *addrs;
	void *dma_buf;
	dma_addr_t dma_dma;
	void __iomem *peer_bar_base;
	u64 peer_bar_phys;
	int link_slot;
	u32 serial;
	int link_up;
	struct task_struct *link_task;
	struct timer_list reap_timer;
	struct delayed_work bar_check_work;
	struct miop_pcie_channel chan[MIOP_DMA_NUM_CH];
};

struct miop_ep {
	struct platform_device *pdev;
	void *pcie_ep_drv;
	void *net_drv;
	u32 n_free;
	u32 n_win;
	struct miop_ep_hw hw;
	struct miop_pcie *pcie_priv;
};

/* Registry API */
void *miop_register_pcie_ep_drv(void *drv);
void *miop_register_ep_net_drv(void *drv);
int miop_register_is_ready(void);
void miop_free_dma_skb_head(struct device *dev, struct sk_buff *skb, size_t size);

int miop_pcie_ep_resource_setup(struct platform_device *pdev, struct miop_ep_hw *hw);
int miop_pcie_rx_region_alloc(struct device *dev, struct miop_ep_hw *hw, unsigned int idx);
void miop_pcie_rx_region_free(struct device *dev, struct miop_ep_hw *hw, unsigned int idx);

#endif /* MIOP_H */
