# Troubleshooting

Field notes on cluster/hardware quirks encountered while bringing the
Mixtile Blade 3 PCIe TCP/IP stack back up with our C modules.

## 1. A blade is "dead" after a cluster power cycle — no switch link, no boot

### Symptom
A blade (e.g. node2) shows **no link activity on the switch**, does not
answer ping, and its serial console is silent. The other blades (node1,
node3) may come back fine on their own.

### Diagnosis
From the controller (`192.168.0.200`, `mixtile`/`mixtile`, passwordless
`sudo`):

- `nodectl poweron -n N` / `nodectl reboot -n N` return `done` but the
  blade still does not power on — no serial, no ping.
- `nodectl list` only enumerates blades whose PCIe link is *detected*
  (`lspci | grep "^03\|^04\|^05\|^06"`); a blade in this stuck state is
  absent, which can mask the real problem.
- Serial (`nodectl console -n N`) shows nothing but the picocom banner.

This is **not** an OS problem. The board has entered a stuck power state
that the soft power-management path (`nodectl` → GPIO/MCU) cannot clear.

### Fix — hard power cycle the blade
Physically **unplug and replug the blade's power** (or reseat it). This
clears the stuck state; link activity returns and the blade boots
normally. After replugging, `ping 192.168.0.20X` and the serial console
come back within ~15–30 s.

### Do NOT reflash the OS
The OS lives on the persistent eMMC and our custom `/lib/miop/*.ko`
modules survive both soft and hard power cycles (there is no controller
master copy that would overwrite them — this was verified). A reflash is
unnecessary and would *lose* the custom modules. The power issue is purely
a hardware power-state problem.

### How this scenario arises
A full cluster power cycle where the controller is rebooted while the
blades were shut down (or their power sequencing gets out of sync) can
leave a blade stuck. `nodectl` soft power control does not always recover
it; only a hard power removal does.

## 2. Capturing a blade's serial console

`nodectl console -n N` runs `picocom -b 1500000 /dev/ttyCH343USB< N-1 >`.

- picocom **exits immediately** ("STDIN is not a TTY ... read zero bytes
  from stdin") unless it is given a pseudo-terminal. When driving it
  remotely, force a PTY with `ssh -tt` from a host that has OpenSSH:
  `ssh -tt controller 'nodectl console -n 2' > serial.log 2>&1 &`.
- The controller's BusyBox is minimal: it lacks `nohup`, `timeout`,
  `setsid`, `script`, and `stty`. Do **not** rely on them; keep the capture
  alive by running it as a background job in your own persistent shell
  instead, and `kill` the ssh process when done.
- The controller's `ping` needs root (`ping: permission denied` as
  `mixtile`); use `echo mixtile | sudo -S ping ...` or ping from your dev
  box instead.
- `nodectl rescan` writes `/sys/bus/pci/rescan`, which needs root:
  `echo mixtile | sudo -S nodectl rescan`.

## 3. `nodectl list` is not a full inventory

It only reports blades detectable on the PCIe fabric (buses 03–06). A blade
with a downed link (power off, or EP not training) will be missing even
though the board may simply be off. Use ping + serial to confirm true
state.

## 4. Current bring-up state (our C modules)

With our modules loaded, node2 boots and the EP driver probes, but the
PCIe link **training times out** and no `pci0` interface appears. The MIOP
shared-header exchange and the outbound ATU programming to the discovered
peer BAR target are not yet implemented (see `STATUS.md`).

## 5. PCIe link won't train — node2's switch port is disabled (NOT our driver)

### Symptom
node2 boots, our `pcie-ep-rk35.ko` loads and probes, but the link never
leaves LTSSM Detect: `dbi_base+0x100 == 0x14820001` (low-16 = 0x1, Detect),
`apb_base+0x300 == 0x0`. No `pci0` appears.

### Diagnosis
From the controller, `lspci -tv` shows bus **05 (node2's slot) EMPTY** — the
ASM2824 switch port to node2 is disabled and is not bringing the link up.
This is **environmental, not a bug in our C reimplementation**: the EP sits
in Detect waiting for the switch (RC) to initiate training, and the switch
port simply isn't enabled.

**Proof it is not our module:** temporarily copying the **factory** modules
(from node3's `/lib/miop`) onto node2 and rebooting produced the *exact same*
result (bus05 empty, link in Detect). So whether the EP is driven by our code
or the vendor's original, the switch port stays down.

### What does NOT fix it (tried)
- `nodectl poweron` / `poweroff` / `reboot -n 2` (the MCU power control does
  not actually cycle node2's power in this state).
- Controller `reboot` (resets the ASM2824 switch — bus05 still empty).
- Secondary-bus reset of the downstream port `0000:02:08.0` on the controller
  (`echo 1 > /sys/bus/pci/devices/0000:02:08.0/reset`).
- Swapping in factory modules.

### What DOES enable the port
The earlier "factory works / `pci0` UP" result came from a specific **full
cluster power cycle** (all blades shut down, then controller rebooted) which
left node2's switch port enabled. A hard blade power-cycle that the
controller's blade manager observes (e.g. physically unplug/replug node2, or
a full cluster power cycle) is what re-enables the port. Once the port is up,
our link-training kthread detects link-up and runs the (still-TODO) MIOP
handshake.

### Tip
To watch the link while it comes up, capture node2's serial (see §2) and/or
`dmesg | grep -iE "miop|pcie|link"`. Our kthread logs `PCIe Link up` when the
switch finally trains the link.

## 6. Kernel oops on `rmmod` (net-stack use-after-free)

Unloading `miop-ep-net.ko` while a `sudo`/`ip`/rtnl query runs concurrently
can oops in `dev_get_phys_port_id` / `rtnl_fill_ifinfo` — a use-after-free as
the `pci0` netdev is torn down under a racing netlink dump. **Workaround:**
avoid running `ip`/`sudo ip`/`ethtool` against the interfaces during module
unload. A proper `remove`/netdev-unregister ordering in `net.c` is still TODO.
