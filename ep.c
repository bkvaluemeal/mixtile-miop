// SPDX-License-Identifier: GPL-2.0
//
// miop-ep: top-level PCIe endpoint platform driver for the Mixtile TCP/IP
// over PCIe driver stack.
//
// This is the C reimplementation of the original ep.S (decompiled from the
// vendor .ko). It is the "glue" layer: its probe() blocks until both lower
// layers (pcie-ep-rk35.ko and miop-ep-net.ko) have registered their driver
// structs in the miop-reg registry, then pulls them out, allocates the
// per-blade struct miop_ep, wires the two driver structs in, asks the net
// layer to initialise itself, and finally walks the device-tree to set up the
// PCIe EP hardware resources (DBI/APB registers, reset GPIO, clocks, PHY,
// resets and the reserved-memory regions). The RX ring alloc/free helpers are
// published to the lower layers through struct miop_ep_hw.func_a/func_b.

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/platform_device.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/of_reserved_mem.h>
#include <linux/reset.h>
#include <linux/regulator/consumer.h>
#include <linux/phy/phy.h>
#include <linux/clk.h>
#include <linux/gpio/consumer.h>
#include <linux/dma-mapping.h>
#include <linux/slab.h>
#include <linux/delay.h>

#include "miop.h"

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Mixtile TCP/IP over PCIe EP platform driver");

/* Expected per-index offset of each RX ring inside the inbound (memory-region)
 * window. The original binary carried this table inline and only emitted a
 * (harmless) dev_warn when the allocator did not hand the ring back at exactly
 * this offset. */
static const u32 miop_rx_region_offset[4] = {
	0x400000, 0x800000, 0x1000000, 0x1800000
};

/**
 * miop_pcie_rx_region_alloc() - allocate one RX ring inside the inbound window.
 * @dev:  the endpoint struct device (passed by the caller in pcie-ep-rk35.ko).
 * @hw:   the per-blade hardware context (struct miop_ep_hw).
 * @idx:  ring index, 0..3.
 *
 * Allocates a coherent DMA buffer of 4 MiB for ring 0 and 8 MiB for rings
 * 1..3, from inside the reserved memory-region window (so that its bus address
 * falls within [region_start, region_start + region_size]). The CPU virtual
 * address is recorded in hw->rx_region_vaddr[idx] and the bus address in
 * hw->rx_region_dma[idx]; both are later consumed by pcie-ep-rk35.ko to
 * program the PCIe inbound ATU and the DMA engine.
 *
 * Return: 0 on success, or a negative errno on failure.
 */
int miop_pcie_rx_region_alloc(struct device *dev, struct miop_ep_hw *hw,
			      unsigned int idx)
{
	size_t size;
	dma_addr_t dma_handle;
	void *cpu_addr;

	/* Only four rings are supported. */
	if (idx > 3)
		return -EINVAL;

	/* Ring 0 is 4 MiB, the rest are 8 MiB each. */
	size = (idx == 0) ? 0x400000 : 0x800000;

	/* Already allocated (e.g. re-probe): nothing to do. */
	if (hw->rx_region_vaddr[idx])
		return 0;

	cpu_addr = dma_alloc_noncoherent(dev, size, &dma_handle,
					 DMA_BIDIRECTIONAL, GFP_KERNEL);
	if (!cpu_addr) {
		dev_err(dev,
			"rx_region[%u]: dma_alloc_noncoherent(0x%x) failed\n",
			idx, (u32)size);
		return -ENOMEM;
	}

	/* The ring must live inside the inbound memory-region window, otherwise
	 * the PCIe RC cannot reach it. */
	if (dma_handle < hw->region_start ||
	    dma_handle > hw->region_start + hw->region_size - size) {
		dev_err(dev,
			"rx_region[%u] dma %pad outside inbound range [%pad, 0x%llx)\n",
			idx, &dma_handle, &hw->region_start,
			hw->region_start + hw->region_size);
		dma_free_noncoherent(dev, size, cpu_addr, dma_handle,
				     DMA_BIDIRECTIONAL);
		return -EFAULT;
	}

	hw->rx_region_vaddr[idx] = cpu_addr;
	hw->rx_region_dma[idx] = dma_handle;
	hw->rx_region_size[idx] = (u32)(dma_handle - hw->region_start);

	/* The original only warned when the allocator returned the ring at a
	 * non-canonical offset (which is harmless); keep the warning for
	 * parity with the vendor behaviour. */
	if (dma_handle != hw->region_start + miop_rx_region_offset[idx]) {
		dev_warn(dev,
			 "rx_region[%u] at non-canonical offset 0x%x (canonical 0x%x), using actual\n",
			 idx, hw->rx_region_size[idx],
			 miop_rx_region_offset[idx]);
	}

	memset(cpu_addr, 0, size);
	dma_sync_single_for_device(dev, dma_handle, size, DMA_BIDIRECTIONAL);
	return 0;
}
EXPORT_SYMBOL(miop_pcie_rx_region_alloc);

/**
 * miop_pcie_rx_region_free() - free one RX ring allocated above.
 * @dev:  the endpoint struct device.
 * @hw:   the per-blade hardware context.
 * @idx:  ring index, 0..3.
 *
 * Releases the DMA buffer and clears the bookkeeping so a later re-alloc starts
 * clean. The original reconstructed the underlying page from the encoded CPU
 * virtual address; using the standard non-coherent free with the stored
 * cpu_addr/bus address is equivalent.
 */
void miop_pcie_rx_region_free(struct device *dev, struct miop_ep_hw *hw,
			      unsigned int idx)
{
	size_t size;

	if (idx > 3)
		return;
	if (!hw->rx_region_vaddr[idx])
		return;

	size = (idx == 0) ? 0x400000 : 0x800000;

	dma_free_noncoherent(dev, size, hw->rx_region_vaddr[idx],
			     hw->rx_region_dma[idx], DMA_BIDIRECTIONAL);

	hw->rx_region_vaddr[idx] = NULL;
	hw->rx_region_dma[idx] = 0;
	hw->rx_region_size[idx] = 0;
}
EXPORT_SYMBOL(miop_pcie_rx_region_free);

/**
 * miop_pcie_ep_resource_setup() - parse DT and map the EP hardware resources.
 * @pdev: the endpoint platform device.
 * @hw:   the &struct miop_ep_hw to populate.
 *
 * Maps the "pcie-dbi" and "pcie-apb" register windows, requests the optional
 * "reset" GPIO, reads the num-ib/ob-windows and num-lanes properties, resolves
 * the "memory-region" and optional "miop,tx-staging-region" reserved regions,
 * attaches the reserved-memory pool and fetches the "sys" IRQ. Finally it
 * publishes miop_pcie_rx_region_alloc / _free through hw->func_a / hw->func_b
 * for the lower layers.
 *
 * Return: 0 on success, or a negative errno on failure.
 */
int miop_pcie_ep_resource_setup(struct platform_device *pdev,
				struct miop_ep_hw *hw)
{
	struct device *dev = &pdev->dev;
	struct device_node *np = dev->of_node;
	struct resource res;
	struct device_node *node;
	int ret;

	/* DBI register window. */
	hw->res_dbi = platform_get_resource_byname(pdev, IORESOURCE_MEM,
						   "pcie-dbi");
	if (!hw->res_dbi) {
		dev_err(dev, "get pcie-dbi failed\n");
		return -ENODEV;
	}

	/* APB register window. */
	hw->res_apb = platform_get_resource_byname(pdev, IORESOURCE_MEM,
						   "pcie-apb");
	if (!hw->res_apb) {
		dev_err(dev, "get pcie-apb failed\n");
		return -ENODEV;
	}

	/* Optional reset GPIO (asserted active-high by the vendor DT). */
	hw->reset_gpio = devm_gpiod_get_optional(dev, "reset", GPIOD_OUT_HIGH);
	if (IS_ERR(hw->reset_gpio))
		return PTR_ERR(hw->reset_gpio);

	/* Number of inbound iATU windows (must be <= 256). */
	ret = of_property_read_u32(np, "num-ib-windows", &hw->num_ib_windows);
	if (ret < 0) {
		dev_err(dev, "unable to read *num-ib-windows* property\n");
		return ret;
	}
	if (hw->num_ib_windows > 0x100) {
		dev_err(dev, "Invalid *num-ib-windows*\n");
		return -EINVAL;
	}

	/* Number of outbound iATU windows (must be <= 256). */
	ret = of_property_read_u32(np, "num-ob-windows", &hw->num_ob_windows);
	if (ret < 0) {
		dev_err(dev, "unable to read *num-ob-windows* property\n");
		return ret;
	}
	if (hw->num_ob_windows > 0x100) {
		dev_err(dev, "Invalid *num-ob-windows*\n");
		return -EINVAL;
	}

	/* Number of PCIe lanes. */
	ret = of_property_read_u32(np, "num-lanes", &hw->num_lanes);
	if (ret < 0) {
		dev_err(dev, "unable to read *num-lanes* property\n");
		return ret;
	}

	/* Resolve the inbound "memory-region" reserved window. */
	node = of_parse_phandle(np, "memory-region", 0);
	if (!node) {
		dev_err(dev, "Invalid *memory-region* property\n");
		return -ENODEV;
	}
	ret = of_address_to_resource(node, 0, &res);
	of_node_put(node);
	if (ret < 0) {
		dev_err(dev, "Invalid *memory-region* property\n");
		return -ENODEV;
	}
	hw->region_start = res.start;
	hw->region_size = res.end - res.start + 1;
	/* The vendor binary guarded this with a slightly mis-compiled bounds
	 * check; the working intent is a minimum size of 32 MiB. Reject only
	 * regions that are too small to hold the RX rings. */
	if (hw->region_size < 0x2000000) {
		dev_err(dev, "Invalid *memory-region* size, minimum is %x\n",
			hw->region_size);
		return -EINVAL;
	}

	/* Optional TX-staging reserved region. */
	node = of_parse_phandle(np, "miop,tx-staging-region", 0);
	if (node) {
		ret = of_address_to_resource(node, 0, &res);
		of_node_put(node);
		if (ret < 0) {
			dev_err(dev, "Invalid *miop,tx-staging-region* property\n");
			return -ENODEV;
		}
		hw->has_tx_staging = 1;
		hw->tx_staging_start = res.start;
		hw->tx_staging_size = res.end - res.start + 1;
		dev_info(dev, "tx staging reserved memory: %pR\n", &res);
	}

	/* Attach the reserved-memory pool to this device. */
	ret = of_reserved_mem_device_init_by_idx(dev, np, 0);
	if (ret) {
		dev_err(dev, "init reserved memory failed\n");
		return -ENOMEM;
	}

	/* "sys" interrupt. */
	hw->irq = platform_get_irq_byname(pdev, "sys");
	if (hw->irq < 0) {
		dev_err(dev, "missing sys IRQ resource\n");
		return -EINVAL;
	}

	/* Publish the RX ring helpers to the lower layers. */
	hw->func_a = miop_pcie_rx_region_alloc;
	hw->func_b = miop_pcie_rx_region_free;
	return 0;
}
EXPORT_SYMBOL(miop_pcie_ep_resource_setup);

/**
 * miop_ep_probe() - bind the endpoint platform device.
 * @pdev: the endpoint platform device.
 *
 * Waits (up to ~6 s) for both lower-layer drivers to register in the miop-reg
 * registry, allocates the &struct miop_ep, retrieves the two driver structs,
 * runs the net layer's init, then brings up the EP hardware in the usual
 * regulator -> clocks -> phy -> resets -> lower-layer-probe order.
 *
 * Return: 0 on success, or a negative errno.
 */
static int miop_ep_probe(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct miop_ep_net_driver *net_drv;
	struct miop_pcie_ep_driver *pcie_drv;
	struct miop_ep *ep;
	struct miop_ep_hw *hw;
	int retries = 6;
	int ret;

	printk(KERN_INFO "Mixtile TCP/IP over PCIe EP driver probe\n");

	/* Block until the two lower layers have registered their driver
	 * structs, polling once per second for up to six seconds. */
	while (!miop_register_is_ready()) {
		if (--retries == 0) {
			dev_err(dev, "Sub-drivers are not ready, exit\n");
			return -EPROBE_DEFER;
		}
		dev_warn(dev, "Sub-drivers are not ready, waiting...\n");
		msleep(1000);
	}

	/* The original binary allocates the ep struct zeroed (kzalloc); several
	 * fields (e.g. the pointer chain that miop_ep_machine_id walks via
	 * ep+0x148) must start as NULL or the machine-id lookup dereferences
	 * uninitialised garbage. */
	ep = devm_kzalloc(dev, sizeof(*ep), GFP_KERNEL);
	if (!ep)
		return -ENOMEM;

	ep->pdev = pdev;

	/* Pull the two lower-layer driver structs out of the registry. */
	ep->pcie_ep_drv = miop_register_pcie_ep_drv(NULL);
	ep->net_drv = miop_register_ep_net_drv(NULL);
	net_drv = ep->net_drv;
	pcie_drv = ep->pcie_ep_drv;

	/* The original binary stashes the ep pointer at pdev+0x88 so that
	 * miop_ep_net_init() can recover it via (dev+0x78).  platform_set_drvdata
	 * lands at a different offset in this kernel, so replicate the binary. */
	*(void **)((char *)pdev + 0x88) = ep;

	/* Let the network layer initialise itself (allocates the netdev, etc.). */
	ret = net_drv->init(dev);
	if (ret)
		return ret;

	hw = &ep->hw;

	/* Parse the device tree and map the hardware resources. */
	ret = miop_pcie_ep_resource_setup(pdev, hw);
	if (ret)
		goto err_net;

	/* Optional 3.3V PCIe supply. */
	hw->regulator = devm_regulator_get_optional(dev, "vpcie3v3");
	if (IS_ERR(hw->regulator)) {
		if (PTR_ERR(hw->regulator) == -ENODEV) {
			dev_info(dev, "no vpcie3v3 regulator found\n");
			hw->regulator = NULL;
		} else {
			ret = PTR_ERR(hw->regulator);
			goto err_net;
		}
	} else {
		ret = regulator_enable(hw->regulator);
		if (ret) {
			dev_err(dev, "fail to enable vpcie3v3 regulator\n");
			goto err_net;
		}
	}

	/* Clocks. */
	ret = devm_clk_bulk_get_all(dev, &hw->clks);
	if (ret < 0)
		goto err_reg;
	hw->clk_count = ret;
	ret = clk_bulk_prepare(hw->clk_count, hw->clks);
	if (ret)
		goto err_reg;
	ret = clk_bulk_enable(hw->clk_count, hw->clks);
	if (ret)
		goto err_clk_prep;

	/* PHY. */
	hw->phy = devm_phy_get(dev, "pcie-phy");
	if (IS_ERR(hw->phy)) {
		ret = PTR_ERR(hw->phy);
		dev_err(dev, "missing phy\n");
		goto err_clk;
	}
	ret = phy_init(hw->phy);
	if (ret)
		goto err_clk;
	ret = phy_power_on(hw->phy);
	if (ret)
		goto err_phy_exit;

	/* Resets. */
	hw->reset = devm_reset_control_array_get(dev, false, false);
	if (IS_ERR(hw->reset)) {
		ret = PTR_ERR(hw->reset);
		dev_err(dev, "failed to get reset lines\n");
		goto err_phy_exit;
	}
	ret = reset_control_deassert(hw->reset);
	if (ret)
		goto err_phy_exit;

	/* Finally, hand control to the lower-layer (RK35) EP driver. */
	ret = pcie_drv->probe(dev);
	if (ret)
		goto err_phy_exit;

	return 0;

err_phy_exit:
	phy_exit(hw->phy);
	phy_power_off(hw->phy);
err_clk:
	clk_bulk_disable(hw->clk_count, hw->clks);
err_clk_prep:
	clk_bulk_unprepare(hw->clk_count, hw->clks);
err_reg:
	if (hw->regulator && !IS_ERR(hw->regulator))
		regulator_disable(hw->regulator);
err_net:
	if (net_drv)
		net_drv->remove(dev);
	return ret;
}

/**
 * miop_ep_remove() - unbind the endpoint platform device.
 * @pdev: the endpoint platform device.
 *
 * Tears the endpoint down in the reverse order of probe: net layer, PHY,
 * clocks and regulator.
 *
 * Return: 0.
 */
static int miop_ep_remove(struct platform_device *pdev)
{
	struct device *dev = &pdev->dev;
	struct miop_ep *ep = platform_get_drvdata(pdev);
	struct miop_ep_hw *hw = &ep->hw;
	struct miop_ep_net_driver *net_drv = ep->net_drv;

	dev_info(dev, "Mixtile TCP/IP over PCIe EP driver remove\n");

	if (net_drv && net_drv->remove)
		net_drv->remove(dev);

	if (hw->phy) {
		phy_exit(hw->phy);
		phy_power_off(hw->phy);
	}
	clk_bulk_disable(hw->clk_count, hw->clks);
	clk_bulk_unprepare(hw->clk_count, hw->clks);
	if (hw->regulator && !IS_ERR(hw->regulator))
		regulator_disable(hw->regulator);

	return 0;
}

static const struct of_device_id miop_ep_of_match[] = {
	{ .compatible = "mixtile,miop-ep-rk3588" },
	{ }
};
MODULE_DEVICE_TABLE(of, miop_ep_of_match);

static struct platform_driver miop_ep_driver = {
	.probe = miop_ep_probe,
	.remove = miop_ep_remove,
	.driver = {
		.name = "miop-ep",
		.of_match_table = miop_ep_of_match,
	},
};

module_platform_driver(miop_ep_driver);
