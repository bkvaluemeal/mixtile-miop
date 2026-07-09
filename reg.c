#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/dma-mapping.h>
#include <linux/skbuff.h>
#include <linux/printk.h>

MODULE_LICENSE("GPL");

#ifdef EXPORT_REG_SYMBOLS
extern void *miop_register_pcie_ep_drv(void *ptr);
extern void *miop_register_ep_net_drv(void *ptr);
extern bool miop_register_is_ready(void);
extern void miop_free_dma_skb_head(struct device *dev, struct sk_buff *skb, size_t size, dma_addr_t dma_handle);

EXPORT_SYMBOL(miop_register_pcie_ep_drv);
EXPORT_SYMBOL(miop_register_ep_net_drv);
EXPORT_SYMBOL(miop_register_is_ready);
#endif

static DEFINE_MUTEX(miop_reg_mutex);
static void *miop_pcie_ep_drv_ptr = NULL;
static void *miop_ep_net_drv_ptr = NULL;

/**
 * miop_register_pcie_ep_drv() - Registers the PCIe endpoint driver.
 * @ptr: Pointer to the driver structure. If NULL, returns the currently registered driver.
 *
 * Returns: The currently registered driver structure.
 */
void *miop_register_pcie_ep_drv(void *ptr)
{
    void *ret;
    mutex_lock(&miop_reg_mutex);
    if (ptr) {
        miop_pcie_ep_drv_ptr = ptr;
    }
    ret = miop_pcie_ep_drv_ptr;
    mutex_unlock(&miop_reg_mutex);
    return ret;
}

/**
 * miop_register_ep_net_drv() - Registers the network endpoint driver.
 * @ptr: Pointer to the network driver structure. If NULL, returns the currently registered driver.
 *
 * Returns: The currently registered network driver structure.
 */
void *miop_register_ep_net_drv(void *ptr)
{
    void *ret;
    mutex_lock(&miop_reg_mutex);
    if (ptr) {
        miop_ep_net_drv_ptr = ptr;
    }
    ret = miop_ep_net_drv_ptr;
    mutex_unlock(&miop_reg_mutex);
    return ret;
}

/**
 * miop_register_is_ready() - Checks if both endpoint and network drivers are registered.
 *
 * Returns: True if both drivers are registered, False otherwise.
 */
bool miop_register_is_ready(void)
{
    bool ready;
    mutex_lock(&miop_reg_mutex);
    ready = (miop_pcie_ep_drv_ptr != NULL) && (miop_ep_net_drv_ptr != NULL);
    mutex_unlock(&miop_reg_mutex);
    return ready;
}

/**
 * miop_free_dma_skb_head() - Frees the DMA mapping and page associated with an skb head.
 * @dev: The device performing the DMA.
 * @skb: The socket buffer whose head was mapped.
 * @size: The size of the allocation.
 * @dma_handle: The DMA address to unmap.
 */
void miop_free_dma_skb_head(struct device *dev, struct sk_buff *skb, size_t size, dma_addr_t dma_handle)
{
    // The original code calculated the virt_to_page manually and passed it as the 3rd argument to dma_free_pages.
    // However, dma_free_pages isn't standard exported kernel API across the board, or its signature varies.
    // It's likely using dma_free_coherent or similar, but the original used dma_free_pages.
    // Since we're translating to C, we can just use the standard Linux kernel DMA API.
    // Actually, it calls dma_free_pages directly, which might be an internal rockchip patch or wrapper.
    // Let's declare it.
    extern void dma_free_pages(struct device *dev, size_t size, struct page *page, dma_addr_t dma_handle, enum dma_data_direction dir);

    // We will leave the original assembly logic encapsulated or just use virt_to_page
    dma_free_pages(dev, size, virt_to_page(skb->head), dma_handle, DMA_BIDIRECTIONAL);
}

static int __init miop_reg_init(void)
{
    pr_info("Mixtile TCP/IP over PCIe device driver registry\n");
    return 0;
}

static void __exit miop_reg_exit(void)
{
    pr_info("Mixtile TCP/IP over PCIe device driver registry exit\n");
}

module_init(miop_reg_init);
module_exit(miop_reg_exit);
