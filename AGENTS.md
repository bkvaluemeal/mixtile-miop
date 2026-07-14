# MiOP RK35 PCIe EP driver — build & test notes

## Build / deploy
- `./build.sh` — cross-compiles the four `.ko` modules on the build host and
  pulls them back into `/root/miop`. NOTE: it tars the LOCAL source tree and
  `scp`s it to node3 (it does NOT `git clone` upstream) — do not reintroduce a
  `git clone`, or local edits will be overwritten.
- `./deploy.sh` — copies the `.ko` files to node3:/lib/miop/.
- `./power-cycle.sh` — shuts down blades 201/202/203, reboots controller 200,
  waits for the cluster to come back. A full power-cycle is REQUIRED for the
  new modules to take effect (no hot-reload).
- Node3 is `mixtile@192.168.0.203` (password `mixtile`). Use `sshpass -p mixtile`.

## Verifying DMA / network
- `dmesg | grep -i "self-test: PASS"` — eDMA write-engine self-test passed.
- `ping -I bond0 <peer-ip>` from any node reaches the others over the PCIe
  fabric (`pci0` device, enslaved in `bond0`). 0% loss = DMA TX path healthy.

## Key DMA (eDMA) facts (DesignWare eDMA legacy register map @ 0x380000)
- 0x38000C = WRITE_ENGINE_EN, 0x38002C = READ_ENGINE_EN
- 0x380010 = WRITE_DOORBELL (channel in bits[2:0]); 0x380058 = clear/arm
  (write `(1<<ch)|(1<<(ch+16))` to clear done/abort)
- 0x38004C = WRITE_INT_STATUS (bit[ch]=done, bit[ch+16]=abort) — this is the
  REAL completion signal; hardware never writes back the descriptor control
  field.
- Channel context: 0x380200 CH_CONTROL1, 0x38021C/0x220 = LLP (ring base).
- Cycle Bit (CB) in descriptor control is POSITIONAL (slot0=1, slot1=0, ...):
  the engine resets CB to 1 at the ring base on every doorbell re-fetch.
- The engine re-fetches from the ring base and walks the LLI chain until it
  hits a CB-mismatched terminator; reap must NOT zero the descriptor control
  field (only the software tracking/busy flag), or re-fetch stalls.
