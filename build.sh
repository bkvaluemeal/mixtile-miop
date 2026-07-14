#!/bin/bash
set -e
NODE3=192.168.0.203
NUSER=mixtile
NPASS=mixtile

sudo3() {
  printf '%s\n%s\n' "$NPASS" "$1" | \
    sshpass -p "$NPASS" ssh -o StrictHostKeyChecking=no "$NUSER@$NODE3" "sudo -S sh"
}

echo "==> git clone on node3 =="
sudo3 "\
  cd /root && \
  rm -rf miop && \
  git clone https://github.com/bkvaluemeal/mixtile-miop.git miop"

echo "==> build on node3 =="
sudo3 "cd /root/miop && make clean 2>/dev/null; make 2>&1 | tail -40"

echo "==> pull .ko back =="
sudo3 "cp /root/miop/*.ko /tmp/ && chown $NUSER:$NUSER /tmp/*.ko"
for ko in miop-ep miop-ep-net miop-reg pcie-ep-rk35; do
  sshpass -p "$NPASS" scp -o StrictHostKeyChecking=no "$NUSER@$NODE3:/tmp/${ko}.ko" /root/miop/
done

echo "==> built:"
ls -la /root/miop/*.ko