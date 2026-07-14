#!/bin/bash
# Power-cycle the MIOP cluster:
#   1. shutdown -hP now on all blades
#   2. wait 10+ seconds
#   3. reboot the controller
#   4. wait 30+ seconds for boot

set -e
PASS=mixtile
USER=mixtile
CTRL=192.168.0.200
NODES=(192.168.0.201 192.168.0.202 192.168.0.203)

ssh_node() {
  sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$1" \
    "echo '$PASS' | sudo -S shutdown -hP now" 2>&1 || true
}

echo "=== Shutting down blades ==="
for n in "${NODES[@]}"; do
  echo "  $n ..."
  ssh_node "$n" &
done
wait
echo "  all blades commanded to shut down"

echo "=== Waiting 15 seconds ==="
sleep 15

echo "=== Rebooting controller $CTRL ==="
sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$CTRL" \
  "echo '$PASS' | sudo -S reboot" 2>&1 || true

echo "=== Waiting 45 seconds for controller + blades to boot ==="
sleep 45

echo "=== Checking status ==="
for n in "${NODES[@]}"; do
  if sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$n" \
    "uname -n" 2>&1; then
    echo "  $n: UP"
  else
    echo "  $n: DOWN (retrying...)"
    sleep 10
    sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$USER@$n" \
      "uname -n" 2>&1 && echo "  $n: UP" || echo "  $n: STILL DOWN"
  fi
done

echo "=== Power cycle complete ==="
