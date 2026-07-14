# Mixtile Blade 3 — miop driver stack (C reimplementation)

This repository contains a **source-level C reimplementation** of the four
kernel modules that drive the Mixtile Blade 3 TCP/IP-over-PCIe fabric. The
original modules were shipped as closed-source `.ko` files; this project
replaces them with clean, readable C built from the ARM64 disassembly
(`pcie_asm.S`).

**Current status:** The PCIe link trains to L0, the `pci0` network interface
comes up with an IP address and carrier, but the data-path (TX/RX DMA rings,
IRQ completion reap) is still stub code — ping via the PCIe fabric fails with
`Destination Host Unreachable`.

## Modules

| Module | File | Role |
|--------|------|------|
| `miop-reg.ko` | `reg.c` | Static registry: stores lower-driver struct pointers |
| `miop-ep.ko` | `ep.c` | Top-level platform driver; allocates `struct miop_ep`, manages PHY/clocks/resets |
| `miop-ep-net.ko` | `net.c` | Network layer: allocates `pci0` netdev, RX/TX callbacks |
| `pcie-ep-rk35.ko` | `pcie.c` | Low-level controller: ioremap DBI/APB, link training, iATU, DMA, IRQ |

## Build & Deploy

The build happens on **node3** (the RK3588 target) via `git clone` from
GitHub. The x86 dev VM (`node1`) pushes changes and orchestrates.

```sh
cd /root/miop           # x86 dev VM
git add -A && git commit && git push
bash /tmp/opencode/miop_build.sh    # clone + build on node3
bash /tmp/opencode/miop_deploy.sh   # copy .ko to /lib/miop/ on node3
# Hard power-cycle node3 to test
```

## State of the art (2026-07-12)

- PCIe link trains to L0: `apb+0x300 = 0x230011`
- `pci0: <BROADCAST,MULTICAST,UP,LOWER_UP>` with IP `10.20.0.4/24`
- `on_peer_online` calls `netif_carrier_on()` without crashing
- Ping to management ethernet (192.168.0.x) works
- Ping to PCIe fabric (10.20.0.x) fails — TX descriptor ring not implemented

## Documentation

- `docs/ARCHITECTURE.md` — system architecture, struct layouts, probe flow
- `docs/STATUS.md` — translation progress and TODO list
- `docs/TROUBLESHOOTING.md` — debugging guide and known issues
