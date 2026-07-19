#!/bin/bash
set -e
NODE3=192.168.0.203
NUSER=mixtile
NPASS=mixtile

sudo3() {
  printf '%s\n%s\n' "$NPASS" "$1" | \
    sshpass -p "$NPASS" ssh -o StrictHostKeyChecking=no "$NUSER@$NODE3" "sudo -S sh"
}

echo "==> tar source, push via sudo =="
# Create tarball locally (use * instead of . to avoid --exclude='.*' matching the root)
cd /root/miop
tar czf /tmp/miop_src.tar.gz \
  --exclude='*.ko' --exclude='*.o' --exclude='.*' --exclude='*.mod*' \
  --exclude='Module.symvers' --exclude='modules.order' --exclude='*.cmd' \
  * 2>&1 | tail -3
cd /root
# Push tarball as normal user to /tmp
sshpass -p "$NPASS" scp -o StrictHostKeyChecking=no \
  /tmp/miop_src.tar.gz "$NUSER@$NODE3:/tmp/"
# Extract as root on node3
sudo3 "rm -rf /root/miop && mkdir -p /root/miop && tar xzf /tmp/miop_src.tar.gz -C /root/miop && chown -R root:root /root/miop && rm -f /tmp/miop_src.tar.gz"
rm -f /tmp/miop_src.tar.gz

echo "==> build on node3 =="
sudo3 "cd /root/miop && make clean 2>/dev/null; make 2>&1 | tail -40"

echo "==> pull .ko back =="
sudo3 "cp /root/miop/*.ko /tmp/ && chown $NUSER:$NUSER /tmp/*.ko"
for ko in miop-ep miop-ep-net miop-reg pcie-ep-rk35; do
  sshpass -p "$NPASS" scp -o StrictHostKeyChecking=no "$NUSER@$NODE3:/tmp/${ko}.ko" /root/miop/
done

echo "==> built:"
ls -la /root/miop/*.ko
