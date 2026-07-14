#!/bin/bash

bind_miop_pcie_irq_to_cpu4() {
    irq=$(grep 'miop-pcie' /proc/interrupts | awk '{print $1}' | tr -d ':')
    irq=${irq:-141}
    echo 10 | tee /proc/irq/"$irq"/smp_affinity >/dev/null
}

if [ -d /lib/miop ]; then
    pushd /lib/miop/ >/dev/null
    insmod miop-reg.ko
    insmod pcie-ep-rk35.ko
    insmod miop-ep-net.ko
    insmod miop-ep.ko
    bind_miop_pcie_irq_to_cpu4
    popd >/dev/null
fi
