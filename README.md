# Mixtile Blade 3 — miop driver stack (C reimplementation)

This repository contains a **source-level C reimplementation** of the four
kernel modules that drive the Mixtile Blade 3 TCP/IP-over-PCIe fabric. The
original modules were shipped as closed-source `.ko` files; this project
replaces them with clean, readable C.

**Current status:** Fully translated and working. The PCIe link trains to
L0, the `pci0` network interface comes up, and ping across the PCIe fabric
works node-to-node in both directions (0% loss). The driver is 100% C — the
original ARM64 disassembly was reference material only and has been removed.

## Modules

| Module | File | Role |
|--------|------|------|
| `miop-reg.ko` | `reg.c` | Static registry: stores lower-driver struct pointers |
| `miop-ep.ko` | `ep.c` | Top-level platform driver; allocates `struct miop_ep`, manages PHY/clocks/resets |
| `miop-ep-net.ko` | `net.c` | Network layer: allocates `pci0` netdev, RX/TX callbacks |
| `pcie-ep-rk35.ko` | `pcie.c` | Low-level controller: ioremap DBI/APB, link training, iATU, DMA, IRQ |

## Build & Deploy

The build happens on **node3** (the RK3588 target). `build.sh` tarballs the
**local** source tree and `scp`s it to node3 (it does NOT `git clone`, so
local edits are preserved), then cross-compiles the four `.ko` modules there.
`deploy.sh` copies the `.ko` files to `/lib/miop/` on node3. A **full
power-cycle is required** for the new modules to take effect (no hot-reload).

```sh
cd /root/miop           # x86 dev VM / repo root
git pull                # confirm remote HEAD (repo auto-commits)
./build.sh              # tarball local src -> node3 -> cross-compile
./deploy.sh             # copy .ko to /lib/miop/ on node3
./power-cycle.sh        # reboot cluster (controllers + blades)
```

## State of the art (2026-07-14)

- PCIe link trains to L0: `apb+0x300 = 0x230011`
- `pci0: <BROADCAST,MULTICAST,UP,LOWER_UP>` with IP `10.20.0.x/24`
- `on_peer_online` calls `netif_carrier_on()` without crashing
- Ping to management ethernet (192.168.0.x) works
- **Ping across the PCIe fabric works node-to-node (0% loss)**
- Driver is 100% C; the original disassembly (`*_asm.S`) has been removed

## Documentation

- `docs/ARCHITECTURE.md` — system architecture, struct layouts, probe flow
- `docs/STATUS.md` — translation progress and TODO list
- `docs/TROUBLESHOOTING.md` — debugging guide and known issues
