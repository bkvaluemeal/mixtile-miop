#!/bin/bash
set -e
NODE3=192.168.0.203
NUSER=mixtile
NPASS=mixtile
SRC=/root/miop

sudo3() {
  printf '%s\n%s\n' "$NPASS" "$1" | \
    sshpass -p "$NPASS" ssh -o StrictHostKeyChecking=no "$NUSER@$NODE3" "sudo -S sh"
}

echo "==> copy .ko to node3:/lib/miop/ =="
for ko in miop-reg.ko miop-ep.ko miop-ep-net.ko pcie-ep-rk35.ko; do
  sshpass -p "$NPASS" scp -o StrictHostKeyChecking=no "$SRC/$ko" "$NUSER@$NODE3:/tmp/"
done
sudo3 "cp /tmp/miop-reg.ko /tmp/miop-ep.ko /tmp/miop-ep-net.ko /tmp/pcie-ep-rk35.ko /lib/miop/"

echo "==> verify =="
sudo3 "ls -la /lib/miop/*.ko"
echo ""
echo "Ready! Power-cycle node3 to test."