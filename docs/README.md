# Documentation

These documents cover the Mixtile Blade 3 TCP/IP-over-PCIe driver stack.

| Document | Contents |
|----------|----------|
| `ARCHITECTURE.md` | Hardware topology, software architecture (4 modules, registry, probe flow), critical data structures (struct layouts with offsets), DMA ring architecture, factory assembly function catalog, current status summary, and build/deploy workflow. |
| `STATUS.md` | Detailed per-module and per-function translation status, known bugs fixed, prioritized TODO list, and test instructions. |
| `TROUBLESHOOTING.md` | Debugging guide covering all known failure modes (link won't train, stub TX crash, rmmod segfault, blade stuck after power cycle, kernel compiler mismatch, modversions error) with diagnosis steps and command snippets. |
| `README.md` (above) | Concise top-level entry point for new readers. |
