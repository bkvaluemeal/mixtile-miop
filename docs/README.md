# Mixtile Blade 3 — PCIe TCP/IP Driver Stack (`miop`)

This document is the working reference for the reconstructed Mixtile Blade 3
PCIe networking driver stack. It collects everything known about the
software, the hardware/cluser it runs on, how to build and deploy it, and
how to debug it.

---

## 1. What this software is

A set of Linux kernel modules that turn each Mixtile Blade 3 (Rockchip
RK3588) into a **PCIe endpoint** and networks the blades together across the
backplane, exposing a virtual `pci0` TCP/IP interface on each blade. The
vendor name for the fabric is **`miop`**.

The stack was originally shipped as opaque/proprietary `.ko` files. This
repository contains a **reconstruction from disassembly** that is
functionally identical (all code/data sections byte-identical to the
originals) and, crucially, **buildable from source**.

---

## 2. Components

### On each blade (aarch64 Linux, kernel `6.1.0-1027-rockchip`)
| Module | Role |
|--------|------|
| `miop-reg.ko` | Register/resource base module (`-DEXPORT_REG_SYMBOLS`); other modules depend on it. |
| `pcie-ep-rk35.ko` | RK3588 **PCIe Endpoint controller** driver. Sets up the EP, its BARs, and link training. This is the largest and most critical module — a missing/mismatched copy breaks the link/handshake. |
| `miop-ep.ko` | `miop` endpoint core: peer discovery, the one-shot handshake, DMA rings, prints `Node online`. |
| `miop-ep-net.ko` | Network side: creates/configures the `pci0` virtual network interface. |

Load order (see `miop-driver-loader.sh`): `miop-reg` → `pcie-ep-rk35` →
`miop-ep-net` → `miop-ep`.

### On the cluster controller (OpenWrt/musl MIPS, kernel `5.15.150`)
| Component | Role |
|-----------|------|
| `miop.ko` (kernel module) | The PCIe **Root Complex manager** for the blades. Probes each blade EP, reads its `machine_id` from BAR0, maps it to a MIOP node id, and brings each `MIOP node[N] on bus:XX is online`. It sets up the RC↔EP DMA rings. **This module is what actually establishes the blade-to-blade P2P fabric** — without it, no blade can peer. |
| `nodectl` | Userspace tool for power control (`poweron`/`poweroff`/`reboot`), firmware `flash`, serial `console`, and `rescan`. Drives blade power via GPIO sysfs. |

---

## 3. Cluster architecture

```
              Cluster Controller (192.168.0.200)
              OpenWrt/MIPS, kernel 5.15.150
              runs: miop.ko (RC manager) + nodectl
                        |
                   Root Complex
                        |
              ASMedia ASM2824 PCIe Gen3 switch
              (downstream ports 00.0/04.0/08.0/0c.0)
                 |        |        |
              bus 03   bus 05   bus 06      (bus 04 empty)
                 |        |        |
              Blade3   Blade2   Blade1      (RK3588, each a PCIe EP)
              (node3)  (node2)  (node1, link DEAD)
```

* Each blade's RK3588 PCIe (`fe150000.pcie`) is configured as an **Endpoint**
  (not a host). The EP presents itself to the switch as
  `"Mixtile Limited Blade 3"`.
* The controller's `miop` RC module scans the buses, reads each blade's
  `machine_id` out of its EP BAR0, and brings each node "online".
* Blade↔blade traffic is peer-to-peer through the ASM2824 switch, with the
  controller's `miop` manager having set up the forwarding/DMA paths.
* On each blade, the `miop-ep` driver performs peer discovery + handshake.
  Once the controller has the peer online, the blade logs
  `Node online: N` and `peer[N] new-arch init`, and `pci0` comes **UP**
  with an IP (e.g. `10.20.0.x`).

---

## 4. Node / addressing map

Management (eth) IPs and `pci0` (fabric) IPs:

| Node | Mgmt IP | pci0 IP | PCIe bus | MIOP node id |
|------|---------|---------|----------|--------------|
| node1 | 192.168.0.201 | — | **bus 06 (absent)** | 0 |
| node2 | 192.168.0.202 | 10.20.0.3 | bus 05 | 1 |
| node3 (reference) | 192.168.0.203 | 10.20.0.4 | bus 03 | 2 |

* Mapping comes from `/etc/miop_nodes.txt` on the controller:
  `3=2 5=1 6=0 4=3` (bus → node id; bus 04 is the empty slot).
* **node1 = bus 06** has a **dead PCIe EP link to the switch** (bus 06 is
  absent from the controller's `lspci`). It therefore **cannot be a PCIe
  peer** and is used only as the build host.
* **node3 is the unmodified reference** (original modules), used as the
  validation peer.
* Correlation trick: the blade `machine_id` the controller reads from the EP
  BAR0 appears byte-reversed in the blade's `pci0` MAC
  (e.g. bus05 `machine_id=0x960eaf9a` ↔ node2 MAC `…9a:af:0e:96…`), which
  is how each bus was mapped to a physical node.

---

## 5. Building

Source (canonical, kept on the build VM in `/root/miop`):

* `reg.S`, `ep.S`, `net.S`, `pcie.S` — assembly reconstructed from dumps.
* `meta.c` — C metadata, compiled four ways via symlinks
  `meta_ep.c` / `meta_net.c` / `meta_pcie.c` / `meta_reg.c`.
* `Makefile`, `miop-driver-loader.sh`, `miop-driver.service`, `README.md`.

**Build host: node1** (has kernel headers at
`/lib/modules/$(uname -r)/build`, same `6.1.0-1027-rockchip` as runtime).
node1 allows **direct `root:root` login** (also `mixtile`/`mixtile`).
Because `/root` is not writable by `mixtile`, build in a writable dir such as
`~/miop`.

```
make
```

`make` runs `make shared_c` (creates the `meta_*.c` symlinks) then
`make -C $(KDIR) M=$(PWD) modules`, then `objcopy --remove-section
__kcrctab --remove-section __kcrctab_gpl` on each `.ko` (drops the
modversion tables so the modules load regardless of kernel modversions).

Output: `miop-reg.ko`, `pcie-ep-rk35.ko`, `miop-ep.ko`, `miop-ep-net.ko`.

---

## 6. Deploying / loading

* Copy the four `.ko` into `/lib/miop/` on the target blade. **Use `*.ko`,
  not `miop-*.ko`** when copying — the glob `miop-*.ko` misses
  `pcie-ep-rk35.ko` (it starts with `pcie`), which would leave a mismatched
  driver and break the link.
* `miop-driver-loader.sh` (invoked by `miop-driver.service` at boot,
  `After=sysinit.target Before=network.target`) insmods in order
  `miop-reg` → `pcie-ep-rk35` → `miop-ep-net` → `miop-ep`, then tries to
  bind the `miop-pcie` IRQ affinity to CPU 10 (silently ignored on 8-CPU
  blades).

---

## 7. Cluster bring-up (CRITICAL)

The blade↔blade fabric only works when the controller's `miop` RC manager
has brought each blade "online".

* **Reliable path: reboot the controller** (`sudo reboot` on
  `192.168.0.200`). At controller boot, `miop` probes all *present* blades
  (bus03 + bus05) and brings them online; the blades auto-power-on and
  handshake → `pci0` UP. This is the normal operation (the controller's
  `blade3-boot` init runs `nodectl reboot --all`).
* Rebooting a **single** blade drops it from the controller's "online" list
  (no PCIe hotplug re-probe). To recover, reboot the controller; or reload
  `miop` (`unbind` the devices in `/sys/bus/pci/drivers/miop/`, `rmmod
  miop`, `insmod /lib/modules/5.15.150/miop.ko`) — but reloading
  immediately after a blade reboot can fail with `-22` until the blade EP is
  ready. **Controller reboot is the dependable method.**

### `nodectl` quick reference (run on the controller, needs `sudo`)
* `nodectl list` — show blades seen on the PCIe buses (03/04/05/06).
* `nodectl poweron|poweroff|reboot (--all|-n N)` — power control. `-n N`
  is a GPIO index (1–4) selecting a blade (confirmed `-n 2`→node2,
  `-n 3`→node3).
* `nodectl flash (--all|-n N) -f /path/firmware.img` — firmware flash
  (**under active development**).
* `nodectl console -n N` — serial console via `picocom -b 1500000
  /dev/ttyCH343USB%N`.
* `nodectl rescan` — `echo 1 > /sys/bus/pci/rescan` (needs `sudo`).
* All `nodectl` ops require `sudo` on the controller
  (`echo mixtile | sudo -S -k ...`). `poweroff`/`reboot` are **hard** (no
  ACPI) — prefer `shutdown -hP now` on the blade first. **Blades
  auto-power-on when the controller reboots.**

### `miop.ko` failure modes (controller `dmesg | grep miop`)
* A blade whose EP isn't ready at probe → `pci_iomap() BAR0 failed`,
  `not all nodes are offline`, probe error `-12` or `-22`.
* A node only comes `online` when its EP is visible and ready at probe
  time.

---

## 8. Debugging `pci0` DOWN / NO-CARRIER

* `pci0` shows `NO-CARRIER` with `PCIe Link up, LTSSM is 0x230011` but no
  `Node online` ⇒ the peer handshake did not complete ⇒ almost always the
  **controller `miop` manager has not onlined the node(s)**. Fix: reboot
  the controller.
* `pci0` MAC is `02:xx:…`; the EP link-training message is local. NO-CARRIER
  means the *peer* wasn't found (fabric/P2P not established), not a local
  link fault — *unless* the blade's bus is absent from the controller's
  `lspci` (then the EP link itself is down, e.g. node1/bus06).
* `cma: cma_alloc ... req-size: 1 pages, ret: -12` at driver load is
  **benign** (also seen on the working reference).
* `rmmod` of the miop modules can **segfault** if the EP is in a bad state;
  only a reboot recovers. Avoid `rmmod`-ing live miop modules.
* node1's bus06 EP link is genuinely down (absent from controller `lspci`)
  — node1 cannot be a PCIe peer; it is build-only.

---

## 9. Validation (known-working reference)

* Built the modules from source on node1, deployed to node2, rebooted the
  controller.
* node2 (our rebuilt modules) + node3 (unmodified reference):
  * `pci0` **UP** at `10.20.0.3` / `10.20.0.4`.
  * `Node online: 2` / `Node online: 1`, `peer[N] new-arch init`.
  * `ping 10.20.0.4` from node2 = **0% packet loss** (~0.8 ms RTT).
* The rebuilt modules are functionally identical to the originals
  (`.text`/`.data`/`.rodata`/`.bss` byte-identical). The originals fail
  identically when the controller hasn't onlined the nodes, confirming the
  earlier `pci0` outages were never a module-code defect.

---

## 10. Known issues / TODO

* **node1 (bus06) PCIe EP link is dead** → node1 cannot peer; it is the
  build-only host. Possibly recoverable via a graceful reboot; may be
  hardware.
* `nodectl flash` is marked "under active development".
* Reloading the controller `miop` module immediately after a blade reboot
  can error `-22` until the blade EP is ready.
