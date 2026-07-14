# Troubleshooting

## 1. pci0 ping fails with "Destination Host Unreachable"

**Cause:** The TX data path is a stub. `miop_ndo_start_xmit()` calls
`pcie_drv->dma_submit()` which is NULL — the skb is silently dropped.
No ARP request ever reaches the peer, so the local kernel returns
unreachable.

**Fix:** Implement `miop_rk35_dma_submit()` — the DMA descriptor write
and doorbell trigger — then `miop_raise_peer_irq()` to notify the RC.

**Workaround (for now):** The management ethernet interface (`bond0`) on
`192.168.0.x` works. Only the PCIe fabric (`10.20.0.x`) is broken.

## 2. PCIe link won't train (LTSSM = 0x0)

**Symptoms:**
- `apb+0x300 = 0x0` (Detect.Quiet)
- `dmesg` shows "PCIe Link training timed out"
- `pci0` does not appear, or appears without LOWER_UP

**Diagnosis:**
1. `busybox devmem 0xfe150300 32` — if 0, the link is in Detect.Quiet,
   meaning the PHY never started transmitting training sequences.
2. Check `dmesg | grep -i "apb\["` — if the APB trigger writes show
   `apb[0x180]=00000000` or `apb[0]=00000000`, the trigger writes aren't
   reaching the APB registers.
3. Verify the struct offsets: the factory init writes to `pcie_priv+24`
   which is `apb_base` in both structs. If you're targeting `dbi_base2`
   (+16), the writes go to the wrong address.

**History:** On 2026-07-12, the link stayed in Detect.Quiet because our
code wrote the APB glue and training triggers to `dbi_base2` (offset +16)
instead of `apb_base` (offset +24). The fix was changing all
`pcie->dbi_base2` references to `pcie->apb_base`.

## 3. Kernel Oops on boot (on_peer_online crash)

**Symptom:** `Internal error: Oops: 96000004 [#1] SMP` at
`netif_carrier_on+0x14/0x90`, called from `miop_on_peer_online`.

**Cause:** `miop_on_peer_online` reads the `net_device *` from a wrong
offset inside `miop_net_priv`. The netdev field is at +16 (`priv->netdev`),
but the code was reading +48 (which is the spinlock).

**Fix:** Use `struct miop_net_priv *priv = ep->hw.net_priv;` then
`priv->netdev` instead of raw offset arithmetic.

## 4. No clean live-reload (rmmod segfaults)

**Symptom:** `rmmod pcie_ep_rk35` (or any miop module) causes a kernel
panic, oops, or hang. Only a hard power-cycle recovers.

**Cause:** The probe does not have a proper `remove()` callback, and
the IRQ handler / DMA structures are not torn down cleanly. The factory
modules also exhibit this behavior (cannot unload and reload).

**Workaround:** Always do a hard power-cycle to test new module builds.
Never `rmmod` on a live system.

## 5. Blade doesn't boot after power cycle

**Symptom:** Blade shows no serial output, no ping response, and is
absent from `nodectl list`.

**Cause:** The blade has entered a stuck power state that the MCU's
soft power management cannot clear.

**Fix:** Physically unplug and replug the blade's power. This clears
the stuck state and the blade boots normally.

## 6. Controller reboot required for link training

After a single-blade reboot, the blade's switch port stays disabled even
though the blade itself boots and runs our driver. The ASM2824 NTB switch
does not retrain the link without a full controller reset.

**Fix:** Reboot the cluster controller (`192.168.0.200`). This resets the
switch and triggers link training. The controller's boot script
(`blade3-boot`) runs `nodectl reboot --all` to power-cycle all blades,
which brings the fabric up.

## 7. "compiler differs from the one used to build the kernel" warning

This is benign. The kernel was built with GCC 11.4.0 (Ubuntu 22.04) and
node3 has GCC 13.3.0 (Ubuntu 24.04). The module loads and functions
correctly despite the warning.

## 8. Module loading fails with "Invalid argument" (-22)

**Cause:** `CONFIG_MODVERSIONS` CRC mismatch. The `objcopy --remove-section
__kcrctab` step in the Makefile strips the CRC tables. If this step failed
or was skipped, the module will fail to load.

**Fix:** Run `objcopy --remove-section __kcrctab --remove-section
__kcrctab_gpl` on each `.ko` file after build. The build script does this
automatically; verify the `.ko` files are post-processed.

## 9. Useful debug commands

```sh
# Check PCIe link LTSSM state (0x230011 = L0)
busybox devmem 0xfe150300 32

# Check APB trigger register values
busybox devmem 0xfe150000 32    # APB+0 (control)
busybox devmem 0xfe150180 32    # APB+0x180 (trigger)
busybox devmem 0xfe150300 32    # APB+0x300 (LTSSM)

# Check DBI registers
busybox devmem 0xa40000000 32   # DBI+0 (Vendor/Device ID)
busybox devmem 0xa4000100 32    # DBI+0x100 (link status)

# View driver messages
dmesg | grep -iE "miop|pcie|link|apb|carrier|pci0|Oops|Internal error"

# Network interface
ip -s link show pci0
```
