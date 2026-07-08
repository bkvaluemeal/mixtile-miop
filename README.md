# Mixtile Blade 3 PCIe TCP/IP Driver Stack Reconstruction

This repository contains a fully reconstructed, linkable, and source-compiled
driver stack for the Mixtile Blade 3 TCP/IP over PCIe architecture.

This project was built by reverse-engineering the original closed-source,
proprietary `.ko` files. It bridges the gap between raw ARM64 assembly dumps
and the Linux kernel module loader by manually rebuilding static kernel structs,
synthesizing uninitialized memory allocations, and utilizing a binary stripping
technique to completely bypass `CONFIG_MODVERSIONS` CRC linking rejections.

## The Driver Stack

The stack consists of four interdependent kernel modules that must be loaded
together to expose the `pci0` network interface:

1. **`miop-reg.ko` (Registry):** The core tracking module. Initializes a static
   mutex and `.bss` storage to hold the registered endpoints.
2. **`miop-ep.ko` (Endpoint):** The primary PCIe endpoint platform driver.
3. **`miop-ep-net.ko` (Network):** The network operations driver. Contains a
   manually mapped `struct net_device_ops` to handle traffic transmission.
4. **`pcie-ep-rk35.ko` (Hardware):** The low-level Rockchip controller driver
   housing the `struct pci_epc_ops` hardware mapping pointers.

## Prerequisites

This project is configured to compile directly on the target ARM64 hardware
(Rockchip RK3588) running Linux 6.1.x.

* **GNU Make**
* **GCC Toolchain** (`aarch64-linux-gnu-`)
* **Binutils** (Specifically `objcopy` for post-build binary stripping)
* **Linux Kernel Headers** matching your current `uname -r`

## Directory Structure

Ensure your working directory matches this layout before compiling. The assembly
files (`*.S`) must include the `.data`, `.bss`, and `.text.unlikely` fixes
discussed during the extraction process.

```text
.
├── Makefile                # Unified build system and deb packager
├── meta.c                  # Shared C definitions and EXPORT_SYMBOL macros
├── ep.S                    # Cleaned assembly for miop-ep
├── reg.S                   # Cleaned assembly for miop-reg
├── net.S                   # Cleaned assembly for miop-ep-net
├── pcie.S                  # Cleaned assembly for pcie-ep-rk35
├── miop-driver.service     # Systemd service unit file
└── miop-driver-loader.sh   # Bash script to handle safe loading/unloading
```

## Build Instructions
Because these modules share `mod_meta.c` but require different compilation
flags, the unified Makefile dynamically generates symlinks for the C source
during the build phase.

You have three primary build targets available:

- `make all`: Compiles the entire stack simuiltaneously and automatically
  strips the CRC versioning tables.

- `sudo make install`: Compiles the stack, installs the `.ko` modules to
  `/lib/miop/`, copies the loader script to `/usr/local/bin/`, installs the
  systemd service, and reloads the daemon.

- `make deb`: Compiles the stack and packages all modules, scripts, and
  services into a redistributable Debian package (`.deb`).


## Deployment & Load Order

Loading order is critical. The dependent modules will fail to initialize if the
registry module is not loaded first to provide the shared `.bss` pointer space.

### Option 1: Manual Load

1. Clean up any existing state:

```sh
sudo rmmod pcie_ep_rk35 miop_ep_net miop_ep miop_reg 2>/dev/null || true
sudo dmesg -c > /dev/null
```

2. Insert the modules in dependency order:

```sh
./miop-driver-loader.sh
```

### Option 2: Systemd Service (Recommended)

If you ran `sudo make install` or installed the `.deb` package, the driver stack
is safely managed by systemd.

Once loaded via either method, check `dmesg`. You should see
`miop_register_is_ready` successfully break its initialization loop, followed by
the creation of the `pci0` network interface.

## Technical Notes: The CRC Bypass

The Linux kernel enforces strict CRC symbol versioning (`CONFIG_MODVERSIONS`).
Because we do not have the proprietary C headers, `modpost` generates invalid
CRC hashes for our exported functions, which causes the dependent modules to
throw an `err -22` (Invalid Argument) and refuse to link.

To bypass this, the Makefile relies on a highly specific kernel fallback loop.
Immediately after compilation, it executes:

```sh
objcopy --remove-section __kcrctab --remove-section __kcrctab_gpl module.ko
```

By surgically removing the checksum tables while leaving the exported names
intact, the kernel loader sees the exported symbols but finds no hashes to
compare them against. It throws a harmless "no symbol version" warning, flags
the kernel as tainted, and allows the memory pointers to successfully link to
the raw assembly.
