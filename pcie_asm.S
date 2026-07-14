.section .text
.global _text
_text:

.global readl
.type readl, @function
readl:
    paciasp  
    ldr      w0, [x0]
    dmb      oshld
    mov      w1, w0
    eor      x1, x1, x1
.Lreadl_14:
    cbnz     x1, .Lreadl_14
    autiasp  
    ret      

.global miop_rk35_dma_submit
.type miop_rk35_dma_submit, @function
miop_rk35_dma_submit:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-80]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w20, w1
    stp      x21, x22, [sp, #32]
    stp      x23, x24, [sp, #48]
    stp      x25, x26, [sp, #64]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #328]
    cmp      w20, #0x1
    b.hi     .Lmiop_rk35_dma_submit_13c
    mov      w21, #0x2038
    mov      x26, x3
    mov      x3, #0x2358
    mov      x23, x2
    umaddl   x21, w20, w21, x19
    mov      w22, w4
    mov      x24, x5
    mov      x25, x6
    add      x21, x21, x3
    mov      x0, x21
    bl       _raw_spin_lock_irqsave
    mov      x7, #0x2038
    mov      x1, x0
    mov      w2, #0x18
    madd     x7, x20, x7, x19
    ldr      x0, [x7, #824]
    add      x7, x7, #0x2, lsl #12
    ldrh     w8, [x7, #840]
    umull    x2, w8, w2
    ldrb     w2, [x0, x2]
    tbz      w2, #0, .Lmiop_rk35_dma_submit_b8
    add      w8, w8, #0x1
    and      w8, w8, #0x7f
    strh     w8, [x7, #840]
.Lmiop_rk35_dma_submit_b8:
    mov      x2, #0x2038
    mov      w3, #0x18
    mul      x20, x20, x2
    add      x2, x19, x20
    add      x2, x2, #0x2, lsl #12
    ldrh     w4, [x2, #840]
    umull    x4, w4, w3
    add      x5, x0, x4
    str      w22, [x5, #4]
    stp      x23, x26, [x5, #8]
    dsb      sy
    mov      w5, #0x1
    str      w5, [x0, x4]
    dsb      sy
    ldrh     w0, [x2, #840]
    mov      x2, #0x28
    madd     x0, x0, x2, x20
    add      x3, x19, x0
    mov      x0, x21
    add      x2, x3, #0x340
    strb     w5, [x3, #868]
    stp      x25, xzr, [x2]
    stp      x24, x23, [x2, #16]
    str      w22, [x3, #864]
    bl       _raw_spin_unlock_irqrestore
    mov      w0, #0x0
.Lmiop_rk35_dma_submit_120:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x29, x30, [sp], #80
    autiasp  
    ret      
.Lmiop_rk35_dma_submit_13c:
    mov      w0, #0xffffffea
    b        .Lmiop_rk35_dma_submit_120

.global miop_elbi_enable_irq
.type miop_elbi_enable_irq, @function
miop_elbi_enable_irq:
    nop      
    nop      
    ldr      x0, [x0, #120]
    paciasp  
    and      w3, w1, #0xf
    mov      x2, #0x1
    lsl      x2, x2, x3
    mov      w3, #0x382
    ldr      x0, [x0, #328]
    movk     w3, #0x8, lsl #16
    add      w1, w3, w1, lsr #4
    lsl      w2, w2, #16
    ldr      x0, [x0, #8]
    ubfiz    x1, x1, #2, #29
    add      x0, x0, x1
    dmb      oshst
    str      w2, [x0]
    autiasp  
    ret      

.global miop_elbi_disable_irq
.type miop_elbi_disable_irq, @function
miop_elbi_disable_irq:
    nop      
    nop      
    ldr      x0, [x0, #120]
    paciasp  
    and      w3, w1, #0xf
    mov      x2, #0x1
    lsl      x2, x2, x3
    mov      w3, #0x382
    ldr      x0, [x0, #328]
    movk     w3, #0x8, lsl #16
    add      w1, w3, w1, lsr #4
    add      w2, w2, w2, lsl #16
    ldr      x0, [x0, #8]
    ubfiz    x1, x1, #2, #29
    add      x0, x0, x1
    dmb      oshst
    str      w2, [x0]
    autiasp  
    ret      

.global find_first_zero_bit
.type find_first_zero_bit, @function
find_first_zero_bit:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      x29, sp
    bl       _find_first_zero_bit
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global ioremap
.type ioremap, @function
ioremap:
    paciasp  
    adrp     x2, arm64_use_ng_mappings
    stp      x29, x30, [sp, #-16]!
    mov      x29, sp
    ldrb     w4, [x2, :lo12:arm64_use_ng_mappings]
    mov      x2, #0x713
    movk     x2, #0x68, lsl #48
    add      x3, x2, #0x800
    tst      x4, #0x1
    csel     x2, x2, x3, eq
    bl       ioremap_prot
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global miop_intx_trigger_work
.type miop_intx_trigger_work, @function
miop_intx_trigger_work:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x3, #0xffffffffffffff80
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w1, #0x28
    ldur     w2, [x0, #-8]
    umsubl   x1, w2, w1, x3
    add      x19, x0, x1
    mov      x0, #0x1
    add      x20, x19, #0x8
    lsl      x0, x0, x2
    ldr      x1, [x19, #616]
    str      w0, [x1, #8]
    ldr      x0, [x20, #16]
    add      x0, x0, #0x34
    dmb      oshst
    mov      w1, #0x20002
    str      w1, [x0]
    mov      w2, #0x2
    mov      x1, #0x7d0
    mov      x0, #0x3e8
    bl       usleep_range_state
    ldr      x0, [x20, #16]
    add      x0, x0, #0x34
    dmb      oshst
    mov      w1, #0x20000
    str      w1, [x0]
    ldr      x0, [x19, #616]
    str      wzr, [x0, #8]
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global miop_ep_unmap_outbound_atu
.type miop_ep_unmap_outbound_atu, @function
miop_ep_unmap_outbound_atu:
    nop      
    nop      
    ldr      x2, [x0]
    paciasp  
    ldr      w4, [x2, #72]
    mov      x2, #0x0
.Lmiop_ep_unmap_outbound_atu_2d8:
    mov      w3, w2
    cmp      w4, w2
    b.hi     .Lmiop_ep_unmap_outbound_atu_2ec
.Lmiop_ep_unmap_outbound_atu_2e4:
    autiasp  
    ret      
.Lmiop_ep_unmap_outbound_atu_2ec:
    ldr      x5, [x0, #72]
    ldr      x5, [x5, x2, lsl #3]
    add      x2, x2, #0x1
    cmp      x5, x1
    b.ne     .Lmiop_ep_unmap_outbound_atu_2d8
    ldr      x1, [x0, #8]
    add      x1, x1, #0x900
    dmb      oshst
    str      w3, [x1]
    ldr      x1, [x0, #8]
    add      x1, x1, #0x908
    dmb      oshst
    mov      w2, #0x7fffffff
    str      w2, [x1]
    ldr      x1, [x0, #64]
    lsr      w2, w3, #6
    mov      x0, #0x1
    lsl      x0, x0, x3
    add      x5, x1, x2, lsl #3
    prfm     pstl1strm, [x5]
.Lmiop_ep_unmap_outbound_atu_33c:
    ldxr     x3, [x5]
    bic      x3, x3, x0
    stxr     w4, x3, [x5]
    cbnz     w4, .Lmiop_ep_unmap_outbound_atu_33c
    b        .Lmiop_ep_unmap_outbound_atu_2e4

.global miop_rk35_unmap_rc_staging
.type miop_rk35_unmap_rc_staging, @function
miop_rk35_unmap_rc_staging:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    stp      x21, x22, [sp, #32]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #328]
    tbz      w1, #0, .Lmiop_rk35_unmap_rc_staging_3bc
    ldr      x0, [x19, #776]
    add      x22, x19, #0x308
    add      x20, x19, #0x310
    add      x21, x19, #0x318
.Lmiop_rk35_unmap_rc_staging_388:
    cbz      x0, .Lmiop_rk35_unmap_rc_staging_3a8
    bl       iounmap
    ldr      x1, [x20]
    mov      x0, x19
    bl       miop_ep_unmap_outbound_atu
    str      xzr, [x22]
    str      xzr, [x20]
    str      wzr, [x21]
.Lmiop_rk35_unmap_rc_staging_3a8:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      
.Lmiop_rk35_unmap_rc_staging_3bc:
    ldr      x0, [x19, #800]
    add      x22, x19, #0x320
    add      x20, x19, #0x328
    add      x21, x19, #0x330
    b        .Lmiop_rk35_unmap_rc_staging_388

.global miop_rk35_unmap_peer_bar
.type miop_rk35_unmap_peer_bar, @function
miop_rk35_unmap_peer_bar:
    nop      
    nop      
    cmp      w1, #0x3
    b.hi     .Lmiop_rk35_unmap_peer_bar_440
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w20, w1
    str      x21, [sp, #32]
    ldr      x0, [x0, #120]
    ldr      x21, [x0, #328]
    add      x19, x21, w1, uxtw #3
    ldr      x0, [x19, #696]
    cbz      x0, .Lmiop_rk35_unmap_peer_bar_42c
    bl       iounmap
    add      x20, x21, x20, lsl #2
    ldr      x1, [x19, #728]
    mov      x0, x21
    bl       miop_ep_unmap_outbound_atu
    str      xzr, [x19, #696]
    str      xzr, [x19, #728]
    str      wzr, [x20, #760]
.Lmiop_rk35_unmap_peer_bar_42c:
    ldp      x19, x20, [sp, #16]
    ldr      x21, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      
.Lmiop_rk35_unmap_peer_bar_440:
    ret      

.global miop_ep_generate_serial
.type miop_ep_generate_serial, @function
miop_ep_generate_serial:
    nop      
    nop      
    adrp     x0, system_serial_low
    paciasp  
    autiasp  
    ldr      w3, [x0, :lo12:system_serial_low]
    adrp     x0, system_serial_high
    ldr      w2, [x0, :lo12:system_serial_high]
    mov      w0, #0xbef7
    movk     w0, #0xdead, lsl #16
    and      w1, w2, #0xffff00ff
    and      w2, w2, #0xff00
    add      w1, w1, w0
    add      w4, w0, w3, uxtb
    add      w1, w1, w2
    and      w2, w3, #0xffff0000
    add      w2, w2, w4
    and      w3, w3, #0xff00
    add      w2, w2, w3
    eor      w0, w1, w0
    ror      w3, w1, #18
    sub      w0, w0, w3
    eor      w2, w2, w0
    ror      w3, w0, #21
    sub      w2, w2, w3
    eor      w1, w1, w2
    ror      w3, w2, #7
    sub      w1, w1, w3
    eor      w0, w0, w1
    ror      w3, w1, #16
    sub      w0, w0, w3
    eor      w2, w2, w0
    ror      w3, w0, #28
    sub      w2, w2, w3
    eor      w1, w1, w2
    ror      w2, w2, #18
    sub      w1, w1, w2
    eor      w0, w0, w1
    ror      w1, w1, #8
    sub      w0, w0, w1
    ret      

.global miop_ep_machine_id
.type miop_ep_machine_id, @function
miop_ep_machine_id:
    nop      
    nop      
    ldr      x0, [x0, #120]
    ldr      x0, [x0, #328]
    cbz      x0, .Lmiop_ep_machine_id_504
    ldr      x0, [x0, #608]
    cbnz     x0, .Lmiop_ep_machine_id_520
.Lmiop_ep_machine_id_504:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      x29, sp
    bl       miop_ep_generate_serial
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.Lmiop_ep_machine_id_520:
    ldr      w0, [x0, #4]
    ret      

.global kmalloc_array.constprop.0
.type kmalloc_array.constprop.0, @function
kmalloc_array.constprop.0:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      w1, #0xdc0
    mov      x29, sp
    lsl      x0, x0, #3
    bl       __kmalloc
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global rk35_pcie_ep_set_bar.isra.0
.type rk35_pcie_ep_set_bar.isra.0, @function
rk35_pcie_ep_set_bar.isra.0:
    nop      
    nop      
    ldr      w5, [x0, #32]
    add      w4, w1, #0x4
    paciasp  
    lsl      w4, w4, #2
    add      w1, w5, w1, lsl #3
    ldr      x5, [x0]
    add      w7, w1, #0x4
    add      w6, w1, #0x8
    add      x5, x5, x7
    dmb      oshst
    str      wzr, [x5]
    ldr      x5, [x0]
    add      x6, x5, w6, uxtw
    mov      x5, #0xfffff
    cmp      x2, x5
    b.ls     .Lrk35_pcie_ep_set_bar_isra_0_638
    rbit     w5, w2
    clz      w5, w5
    sub      w5, w5, #0x14
    ubfiz    w5, w5, #8, #5
    dmb      oshst
    str      w5, [x6]
.Lrk35_pcie_ep_set_bar_isra_0_5ac:
    and      w6, w3, #0x4
    tbz      w3, #2, .Lrk35_pcie_ep_set_bar_isra_0_5f0
    ldr      x7, [x0, #8]
    add      w5, w4, #0x4
    add      x5, x7, w5, uxtw
    dmb      oshst
    str      wzr, [x5]
    ldr      x5, [x0]
    add      w7, w1, #0xc
    add      x5, x5, x7
    dmb      oshst
    str      wzr, [x5]
    ldr      x5, [x0]
    add      w1, w1, #0x10
    add      x1, x5, x1
    dmb      oshst
    str      wzr, [x1]
.Lrk35_pcie_ep_set_bar_isra_0_5f0:
    ldr      x1, [x0, #8]
    sxtw     x5, w4
    add      x1, x1, w4, sxtw
    cbnz     x2, .Lrk35_pcie_ep_set_bar_isra_0_644
    dmb      oshst
    str      wzr, [x1]
.Lrk35_pcie_ep_set_bar_isra_0_608:
    ldr      x1, [x0]
    add      x1, x1, x5
    dmb      oshst
    str      w3, [x1]
    cbz      w6, .Lrk35_pcie_ep_set_bar_isra_0_630
    ldr      x0, [x0]
    add      w4, w4, #0x4
    add      x4, x0, w4, uxtw
    dmb      oshst
    str      wzr, [x4]
.Lrk35_pcie_ep_set_bar_isra_0_630:
    autiasp  
    ret      
.Lrk35_pcie_ep_set_bar_isra_0_638:
    dmb      oshst
    str      wzr, [x6]
    b        .Lrk35_pcie_ep_set_bar_isra_0_5ac
.Lrk35_pcie_ep_set_bar_isra_0_644:
    sub      w2, w2, #0x1
    dmb      oshst
    str      w2, [x1]
    b        .Lrk35_pcie_ep_set_bar_isra_0_608

.global rk35_pcie_readl_dbi.isra.0
.type rk35_pcie_readl_dbi.isra.0, @function
rk35_pcie_readl_dbi.isra.0:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    add      x0, x0, w1, uxtw
    mov      x29, sp
    bl       readl
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global miop_dma_try_reap
.type miop_dma_try_reap, @function
miop_dma_try_reap:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-128]!
    mov      x1, #0x1740
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x20, x0
    add      x19, x0, x1
    stp      x21, x22, [sp, #32]
    mov      w21, #0x0
    stp      x23, x24, [sp, #48]
    stp      x25, x26, [sp, #64]
    stp      x27, x28, [sp, #80]
    mov      w28, #0x0
    ldr      x25, [x0, #48]
.Lmiop_dma_try_reap_6b4:
    add      x26, x19, #0xc18
    mov      x0, x26
    bl       _raw_spin_lock_irqsave
    ldrb     w27, [x19, #3085]
    str      x0, [sp, #104]
    tbnz     w27, #0, .Lmiop_dma_try_reap_710
    mov      x1, x0
    mov      x0, x26
    bl       _raw_spin_unlock_irqrestore
.Lmiop_dma_try_reap_6d8:
    mov      x0, #0x2038
    add      x19, x19, x0
    cbz      w21, .Lmiop_dma_try_reap_708
    ldp      x19, x20, [sp, #16]
    mov      w0, w28
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #128
    autiasp  
    ret      
.Lmiop_dma_try_reap_708:
    mov      w21, #0x1
    b        .Lmiop_dma_try_reap_6b4
.Lmiop_dma_try_reap_710:
    ldr      x0, [x20, #8]
    mov      w1, #0x4c
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w0, w0
    lsr      x0, x0, x21
    tbnz     w0, #0, .Lmiop_dma_try_reap_794
    adrp     x0, jiffies
    ldr      x1, [x19, #3088]
    ldr      x0, [x0, :lo12:jiffies]
    cmp      x1, x0
    b.mi     .Lmiop_dma_try_reap_804
    mov      w22, #0x0
    mov      w23, #0x0
.Lmiop_dma_try_reap_748:
    ldr      x1, [sp, #104]
    mov      x0, x26
    bl       _raw_spin_unlock_irqrestore
    tbz      w23, #0, .Lmiop_dma_try_reap_6d8
    cbz      w22, .Lmiop_dma_try_reap_6d8
    adrp     x1, _rodata
    add      x1, x1, :lo12:_rodata
    adrp     x0, _data
    add      x1, x1, #0x33
    add      x0, x0, :lo12:_data
    bl       ___ratelimit
    cbz      w0, .Lmiop_dma_try_reap_6d8
    mov      w3, w22
    mov      w2, w21
    mov      x0, x25
    adrp     x1, _rodata_str1_1+0x30
    add      x1, x1, :lo12:_rodata_str1_1+0x30
    bl       _dev_warn
    b        .Lmiop_dma_try_reap_6d8
.Lmiop_dma_try_reap_794:
    ldr      x1, [x20, #8]
    mov      x0, #0x1
    lsl      w0, w0, w21
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x58
    dmb      oshst
    str      w0, [x1]
    mov      w23, #0x0
.Lmiop_dma_try_reap_7b4:
    cmp      w23, #0x0
    mov      w0, #0xfffffffb
    csel     w0, w0, wzr, ne
    str      w0, [sp, #116]
    sxtw     x0, w21
    mov      x1, #0x2038
    mov      w22, #0x0
    mov      w24, #0x0
    mul      x28, x0, x1
.Lmiop_dma_try_reap_7d8:
    ldrh     w5, [x19, #3082]
    ldrh     w0, [x19, #3080]
    cmp      w0, w5
    b.ne     .Lmiop_dma_try_reap_874
    mov      x28, x19
    mov      w2, #0x0
    strb     wzr, [x19, #3085]
.Lmiop_dma_try_reap_7f4:
    cmp      w2, w24
    b.lt     .Lmiop_dma_try_reap_92c
    mov      w28, w27
    b        .Lmiop_dma_try_reap_748
.Lmiop_dma_try_reap_804:
    mov      x0, x25
    mov      w2, w21
    adrp     x1, _rodata_str1_1+0x6
    add      x1, x1, :lo12:_rodata_str1_1+0x6
    bl       _dev_err
    mov      x23, #0xc
    ldr      x0, [x20, #8]
    movk     x23, #0x38, lsl #16
    add      x0, x0, x23
    dmb      oshst
    str      wzr, [x0]
    mov      x22, #0x8958
    movk     x22, #0x41, lsl #16
.Lmiop_dma_try_reap_838:
    ldr      x0, [x20, #8]
    mov      w1, w23
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w28, w0
    mov      x0, x22
    bl       __const_udelay
    tbnz     w28, #0, .Lmiop_dma_try_reap_838
    ldr      x0, [x20, #8]
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0xc
    dmb      oshst
    mov      w1, #0x1
    str      w1, [x0]
    mov      w23, w27
    b        .Lmiop_dma_try_reap_7b4
.Lmiop_dma_try_reap_874:
    mov      x0, #0x28
    madd     x5, x5, x0, x28
    add      x5, x20, x5
    ldrb     w0, [x5, #868]
    tbz      w0, #0, .Lmiop_dma_try_reap_8f8
    ldr      x0, [x5, #848]
    cbz      x0, .Lmiop_dma_try_reap_8c0
    cmp      w24, #0x7f
    b.gt     .Lmiop_dma_try_reap_8c0
    mov      w0, #0x18
    ldr      x2, [x5, #832]
    smull    x1, w24, w0
    add      w24, w24, #0x1
    add      x0, x19, x1
    str      x2, [x19, x1]
    ldr      x1, [x5, #848]
    str      x1, [x0, #8]
    ldr      w1, [sp, #116]
    str      w1, [x0, #16]
.Lmiop_dma_try_reap_8c0:
    sub      x1, x19, #0x8, lsl #12
    ldrh     w0, [x19, #3082]
    mov      w2, #0x18
    ldr      x1, [x1, #27640]
    umaddl   x0, w0, w2, x1
    stp      xzr, xzr, [x0]
    str      xzr, [x0, #16]
    ldrh     w0, [x19, #3082]
    add      w0, w0, #0x1
    and      w0, w0, #0x7f
    strh     w0, [x19, #3082]
    and      w0, w23, #0x1
    add      w22, w22, w0
    b        .Lmiop_dma_try_reap_7d8
.Lmiop_dma_try_reap_8f8:
    ldr      x1, [x5, #856]
    mov      x0, x25
    ldr      w2, [x5, #864]
    mov      x4, #0x0
    mov      w3, #0x1
    str      x5, [sp, #120]
    bl       dma_unmap_page_attrs
    ldr      x5, [sp, #120]
    ldr      x1, [x5, #840]
    cbz      x1, .Lmiop_dma_try_reap_8c0
    ldr      x0, [x5, #832]
    blr      x1
    b        .Lmiop_dma_try_reap_8c0
.Lmiop_dma_try_reap_92c:
    ldr      x3, [x28, #8]
    str      w2, [sp, #116]
    ldr      w1, [x28, #16]
    ldr      x0, [x28], #24
    blr      x3
    ldr      w2, [sp, #116]
    add      w2, w2, #0x1
    b        .Lmiop_dma_try_reap_7f4

.global miop_dma_list_is_full
.type miop_dma_list_is_full, @function
miop_dma_list_is_full:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      w1, w1
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x2, #0x2038
    str      x21, [sp, #32]
    ldr      x0, [x0, #120]
    ldr      x0, [x0, #328]
    madd     x20, x1, x2, x0
    add      x21, x20, #0x2, lsl #12
    ldrh     w19, [x21, #840]
    bl       miop_dma_try_reap
    ldrb     w0, [x21, #845]
    tbnz     w0, #0, .Lmiop_dma_list_is_full_9c0
    mov      w0, #0x18
    ldr      x1, [x20, #824]
    umull    x0, w19, w0
    ldrb     w0, [x1, x0]
    tbz      w0, #0, .Lmiop_dma_list_is_full_9b0
    ldrh     w19, [x21, #840]
    add      w19, w19, #0x1
    and      w19, w19, #0x7f
.Lmiop_dma_list_is_full_9b0:
    mov      w0, #0x18
    umull    x19, w19, w0
    ldr      w0, [x1, x19]
    and      w0, w0, #0x1
.Lmiop_dma_list_is_full_9c0:
    ldp      x19, x20, [sp, #16]
    ldr      x21, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      

.global rk35_dma_start_write
.type rk35_dma_start_write, @function
rk35_dma_start_write:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    mov      w20, w1
    ldr      x0, [x0, #8]
    mov      w1, #0x10
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    and      w2, w0, #0xfffffff8
    ldr      x0, [x19, #8]
    orr      w1, w2, w20
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0x10
    dmb      oshst
    str      w1, [x0]
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global rk35_pcie_readw_dbi.isra.0
.type rk35_pcie_readw_dbi.isra.0, @function
rk35_pcie_readw_dbi.isra.0:
    paciasp  
    add      x0, x0, w1, uxtw
    ldrh     w0, [x0]
    and      x1, x0, #0xffff
    dmb      oshld
    eor      x1, x1, x1
.Lrk35_pcie_readw_dbi_isra_0_a48:
    cbnz     x1, .Lrk35_pcie_readw_dbi_isra_0_a48
    autiasp  
    ret      

.global miop_raise_peer_irq
.type miop_raise_peer_irq, @function
miop_raise_peer_irq:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    ldr      x0, [x0, #120]
    ldr      x20, [x0, #328]
    cmp      w2, #0x7
    b.ls     .Lmiop_raise_peer_irq_a9c
    ldr      x0, [x20, #48]
    adrp     x1, _rodata_str1_1+0x4c
    add      x1, x1, :lo12:_rodata_str1_1+0x4c
    bl       _dev_err
.Lmiop_raise_peer_irq_a8c:
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_raise_peer_irq_a9c:
    ldr      x0, [x20, #608]
    mov      w19, w2
    ldr      w2, [x0, #8]
    cmp      w1, w2
    b.ne     .Lmiop_raise_peer_irq_b10
    ldrb     w1, [x20, #86]
    tbz      w1, #0, .Lmiop_raise_peer_irq_af0
    ldr      x0, [x20, #8]
    tbz      w1, #1, .Lmiop_raise_peer_irq_ae8
    mov      w1, #0x5c
.Lmiop_raise_peer_irq_ac4:
    bl       rk35_pcie_readw_dbi.isra.0
    and      w0, w0, #0xffff
    ldr      x1, [x20, #88]
    orr      w0, w0, w19
    ldr      w2, [x20, #112]
    add      x1, x1, x2
.Lmiop_raise_peer_irq_adc:
    dmb      oshst
    str      w0, [x1]
    b        .Lmiop_raise_peer_irq_a8c
.Lmiop_raise_peer_irq_ae8:
    mov      w1, #0x58
    b        .Lmiop_raise_peer_irq_ac4
.Lmiop_raise_peer_irq_af0:
    mov      w0, #0x28
    umaddl   x2, w19, w0, x20
    adrp     x0, system_wq
    ldr      x1, [x0, :lo12:system_wq]
    add      x2, x2, #0x80
    mov      w0, #0x8
    bl       queue_work_on
    b        .Lmiop_raise_peer_irq_a8c
.Lmiop_raise_peer_irq_b10:
    cmn      w2, #0x1
    b.ne     .Lmiop_raise_peer_irq_b2c
    ldr      x0, [x20, #48]
    adrp     x1, _rodata_str1_1+0x67
    add      x1, x1, :lo12:_rodata_str1_1+0x67
    bl       _dev_err
    b        .Lmiop_raise_peer_irq_a8c
.Lmiop_raise_peer_irq_b2c:
    mov      x0, #0x1
    mov      w1, w1
    lsl      x19, x0, x19
    lsl      x0, x0, x2
    mov      x2, #0x28
    orr      w0, w19, w0, lsl #8
    madd     x1, x1, x2, x20
    orr      w0, w0, w0, lsl #16
    ldr      x1, [x1, #296]
    add      x1, x1, #0xe00
    b        .Lmiop_raise_peer_irq_adc

.global miop_rk35_dma_submit_batch
.type miop_rk35_dma_submit_batch, @function
miop_rk35_dma_submit_batch:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-96]!
    cmp      x2, #0x0
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    ccmp     w1, #0x1, #0x2, ne
    stp      x21, x22, [sp, #32]
    stp      x23, x24, [sp, #48]
    stp      x25, x26, [sp, #64]
    stp      x27, x28, [sp, #80]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #328]
    b.hi     .Lmiop_rk35_dma_submit_batch_e98
    sub      w27, w3, #0x1
    mov      w24, w3
    cmp      w27, #0x7e
    b.hi     .Lmiop_rk35_dma_submit_batch_e98
    mov      w20, w1
    mov      w21, #0x2038
    mov      x23, x2
    mov      x26, x4
    mov      x28, x5
    mov      x0, x19
    umaddl   x21, w20, w21, x19
    bl       miop_dma_try_reap
    mov      x2, #0x2358
    add      x21, x21, x2
    mov      x0, x21
    bl       _raw_spin_lock_irqsave
    mov      x22, x0
    mov      w0, w20
    mov      x1, #0x2038
    mul      x0, x0, x1
    add      x3, x19, x0
    add      x1, x3, #0x2, lsl #12
    ldrb     w2, [x1, #845]
    tbnz     w2, #0, .Lmiop_rk35_dma_submit_batch_e68
    ldrh     w2, [x1, #840]
    mov      w5, #0x18
    ldr      x6, [x3, #824]
    umull    x4, w2, w5
    ldrb     w4, [x6, x4]
    tbnz     w4, #0, .Lmiop_rk35_dma_submit_batch_e68
    ldrh     w1, [x1, #842]
    cmp      w1, w2
    b.ne     .Lmiop_rk35_dma_submit_batch_e68
    mov      w12, #0x1
    mov      x2, x23
    mov      w25, w12
    mov      w8, #0x0
    mov      w11, #0x0
    mov      x4, #0x28
    str      wzr, [x3, #9032]
.Lmiop_rk35_dma_submit_batch_c34:
    sxtw     x6, w11
    umull    x9, w11, w5
    ldr      x10, [x3, #824]
    madd     x7, x6, x4, x0
    add      x1, x10, x9
    add      x7, x19, x7
    add      x7, x7, #0x340
    stp      xzr, xzr, [x1]
    str      xzr, [x1, #16]
    stp      xzr, xzr, [x7]
    stp      xzr, xzr, [x7, #16]
    str      xzr, [x7, #32]
    ldr      w7, [x2, #16]
    str      w7, [x1, #4]
    ldr      x7, [x2]
    str      w7, [x1, #8]
    ldr      w7, [x2, #4]
    str      w7, [x1, #12]
    ldr      x7, [x2, #8]
    str      w7, [x1, #16]
    ldr      w7, [x2, #12]
    str      w7, [x1, #20]
    str      w12, [x10, x9]
    cmp      w27, w8
    b.ne     .Lmiop_rk35_dma_submit_batch_ca4
    ldrb     w1, [x10, x9]
    orr      w1, w1, #0x8
    strb     w1, [x10, x9]
.Lmiop_rk35_dma_submit_batch_ca4:
    madd     x6, x6, x4, x0
    cmp      w27, w8
    csel     x1, x26, xzr, eq
    add      w11, w11, #0x1
    add      x6, x19, x6
    add      w8, w8, #0x1
    and      w11, w11, #0x7f
    add      x2, x2, #0x18
    str      x28, [x6, #832]
    str      xzr, [x6, #840]
    str      x1, [x6, #848]
    ldur     x1, [x2, #-24]
    str      x1, [x6, #856]
    ldur     w1, [x2, #-8]
    str      w1, [x6, #864]
    strb     w25, [x6, #868]
    cmp      w24, w8
    b.ne     .Lmiop_rk35_dma_submit_batch_c34
    add      x0, x19, x0
    mov      w1, #0x18
    umull    x1, w11, w1
    ldr      x2, [x0, #824]
    add      x2, x2, x1
    stp      xzr, xzr, [x2]
    str      xzr, [x2, #16]
    ldr      x2, [x0, #824]
    str      wzr, [x2, x1]
    dsb      sy
    add      x1, x0, #0x2, lsl #12
    strh     w11, [x1, #840]
    strb     w25, [x1, #845]
    adrp     x1, jiffies
    ldr      x1, [x1, :lo12:jiffies]
    add      x1, x1, #0x12c
    str      x1, [x0, #9040]
    dmb      ishst
    mov      w1, #0x1c00
    add      w2, w20, w1
    ldr      x1, [x19, #8]
    lsl      w2, w2, #9
    ldr      x0, [x0, #9024]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0xc
    dmb      oshst
    mov      w3, #0x1
    str      w3, [x1]
    ldr      x3, [x19, #8]
    add      w1, w2, #0x200
    add      x1, x3, w1, uxtw
    dmb      oshst
    mov      w3, #0x308
    movk     w3, #0x400, lsl #16
    str      w3, [x1]
    ldr      x3, [x19, #8]
    add      w1, w2, #0x204
    add      x1, x3, w1, uxtw
    dmb      oshst
    str      wzr, [x1]
    ldr      x4, [x19, #8]
    add      w1, w2, #0x21c
    add      x1, x4, w1, uxtw
    dmb      oshst
    str      w0, [x1]
    ldr      x1, [x19, #8]
    add      w2, w2, #0x220
    lsr      x0, x0, #32
    add      x2, x1, w2, uxtw
    dmb      oshst
    str      w0, [x2]
    ldr      x0, [x19, #8]
    mov      w1, #0x54
    movk     w1, #0x38, lsl #16
    mov      x24, #0x1
    lsl      x23, x24, x20
    bl       rk35_pcie_readl_dbi.isra.0
    bic      w0, w0, w23
    ldr      x1, [x19, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x54
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    mov      w1, #0x90
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    add      w1, w20, #0x10
    lsl      x24, x24, x1
    orr      w0, w0, w24
    ldr      x1, [x19, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x90
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    add      w23, w23, w23, lsl #16
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0x58
    dmb      oshst
    str      w23, [x0]
    dmb      ishst
    mov      x0, x19
    mov      w1, w20
    bl       rk35_dma_start_write
    add      x0, x19, #0x4, lsl #12
    strb     w25, [x0, #952]
    ldr      x0, [x19, #17328]
    cbz      x0, .Lmiop_rk35_dma_submit_batch_e54
    bl       wake_up_process
.Lmiop_rk35_dma_submit_batch_e54:
    mov      x0, x21
    mov      x1, x22
    bl       _raw_spin_unlock_irqrestore
    mov      w0, #0x0
    b        .Lmiop_rk35_dma_submit_batch_e78
.Lmiop_rk35_dma_submit_batch_e68:
    mov      x0, x21
    mov      x1, x22
    bl       _raw_spin_unlock_irqrestore
    mov      w0, #0xfffffff0
.Lmiop_rk35_dma_submit_batch_e78:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #96
    autiasp  
    ret      
.Lmiop_rk35_dma_submit_batch_e98:
    mov      w0, #0xffffffea
    b        .Lmiop_rk35_dma_submit_batch_e78

.global miop_ep_map_outbound_atu
.type miop_ep_map_outbound_atu, @function
miop_ep_map_outbound_atu:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-80]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    mov      x20, x3
    stp      x21, x22, [sp, #32]
    mov      x22, x1
    stp      x23, x24, [sp, #48]
    mov      x23, x2
    stp      x25, x26, [sp, #64]
    ldr      x0, [x0]
    ldr      w1, [x0, #72]
    ldr      x0, [x19, #64]
    bl       find_first_zero_bit
    mov      x21, x0
    ldr      x0, [x19]
    ldr      w0, [x0, #72]
    cmp      w0, w21
    b.hi     .Lmiop_ep_map_outbound_atu_f28
    ldr      x0, [x19, #48]
    adrp     x1, _rodata_str1_1+0x83
    add      x1, x1, :lo12:_rodata_str1_1+0x83
    bl       _dev_err
    mov      w0, #0xffffffea
.Lmiop_ep_map_outbound_atu_f0c:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x29, x30, [sp], #80
    autiasp  
    ret      
.Lmiop_ep_map_outbound_atu_f28:
    ldr      x1, [x19, #32]
    lsl      w5, w21, #9
    sub      x0, x22, #0x1
    add      x2, x5, #0x8
    add      x3, x0, x20
    add      x1, x1, x2
    dmb      oshst
    str      w22, [x1]
    ldr      x0, [x19, #32]
    add      x2, x5, #0xc
    lsr      x1, x22, #32
    add      x0, x0, x2
    dmb      oshst
    str      w1, [x0]
    ldr      x0, [x19, #32]
    add      x2, x5, #0x10
    add      x0, x0, x2
    dmb      oshst
    str      w3, [x0]
    ldr      x0, [x19, #32]
    add      x1, x5, #0x20
    lsr      x3, x3, #32
    add      x0, x0, x1
    dmb      oshst
    str      w3, [x0]
    ldr      x1, [x19, #32]
    add      x2, x5, #0x14
    add      x1, x1, x2
    dmb      oshst
    str      w23, [x1]
    ldr      x0, [x19, #32]
    add      x2, x5, #0x18
    lsr      x1, x23, #32
    add      x0, x0, x2
    dmb      oshst
    str      w1, [x0]
    ldr      x0, [x19, #32]
    add      x0, x0, x5
    dmb      oshst
    str      wzr, [x0]
    ldr      x0, [x19, #32]
    add      x20, x5, #0x4
    add      x0, x0, x20
    dmb      oshst
    mov      w1, #0x80000000
    str      w1, [x0]
    mov      x26, #0x8958
    mov      w24, #0x5
    movk     x26, #0x41, lsl #16
.Lmiop_ep_map_outbound_atu_fec:
    ldr      x0, [x19, #32]
    add      x0, x0, x20
    bl       readl
    tbnz     w0, #31, .Lmiop_ep_map_outbound_atu_1028
    mov      x25, #0x9
.Lmiop_ep_map_outbound_atu_1000:
    mov      x0, x26
    bl       __const_udelay
    subs     x25, x25, #0x1
    b.ne     .Lmiop_ep_map_outbound_atu_1000
    subs     w24, w24, #0x1
    b.ne     .Lmiop_ep_map_outbound_atu_fec
    ldr      x0, [x19, #48]
    adrp     x1, _rodata_str1_1+0x9c
    add      x1, x1, :lo12:_rodata_str1_1+0x9c
    bl       _dev_err
.Lmiop_ep_map_outbound_atu_1028:
    ldr      x0, [x19, #48]
    mov      w2, w21
    mov      x4, x23
    mov      x3, x22
    adrp     x1, _rodata_str1_1+0xb8
    add      x1, x1, :lo12:_rodata_str1_1+0xb8
    bl       _dev_err
    ldr      x1, [x19, #64]
    lsr      w2, w21, #6
    mov      x0, #0x1
    lsl      x0, x0, x21
    add      x5, x1, x2, lsl #3
    prfm     pstl1strm, [x5]
.Lmiop_ep_map_outbound_atu_105c:
    ldxr     x3, [x5]
    orr      x3, x3, x0
    stxr     w4, x3, [x5]
    cbnz     w4, .Lmiop_ep_map_outbound_atu_105c
    ldr      x0, [x19, #72]
    str      x22, [x0, w21, uxtw #3]
    mov      w0, #0x0
    b        .Lmiop_ep_map_outbound_atu_f0c

.global rk35_ep_interrupt
.type rk35_ep_interrupt, @function
rk35_ep_interrupt:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-112]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    stp      x21, x22, [sp, #32]
    mov      x21, x1
    stp      x23, x24, [sp, #48]
    stp      x25, x26, [sp, #64]
    stp      x27, x28, [sp, #80]
    ldr      x19, [x1, #120]
    ldr      x26, [x19, #328]
    ldr      x0, [x26, #24]
    add      x0, x0, #0x10
    bl       readl
    str      w0, [sp, #96]
    ldr      x0, [sp, #96]
    tbz      w0, #15, .Lrk35_ep_interrupt_112c
    ldr      x0, [x26, #8]
    mov      w1, #0xe00
    ldr      x25, [x19, #16]
    movk     w1, #0x20, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w2, w0
    lsl      w1, w0, #16
    ldr      x0, [x26, #8]
    add      x0, x0, #0x200, lsl #12
    add      x0, x0, #0xe00
    dmb      oshst
    str      w1, [x0]
    cbz      w2, .Lrk35_ep_interrupt_112c
    ldr      x1, [x26, #608]
    ubfx     x19, x2, #8, #8
    ldr      w0, [x1, #12]
    tst      w19, w0
    b.eq     .Lrk35_ep_interrupt_112c
    rbit     w19, w19
    clz      w19, w19
    tbz      w2, #0, .Lrk35_ep_interrupt_116c
    ldr      x2, [x25, #32]
.Lrk35_ep_interrupt_1120:
    mov      w1, w19
    mov      x0, x21
    blr      x2
.Lrk35_ep_interrupt_112c:
    mov      x0, x26
    bl       miop_dma_try_reap
    ldr      x0, [x26, #24]
    add      x0, x0, #0x10
    dmb      oshst
    ldr      w1, [sp, #96]
    str      w1, [x0]
    ldp      x19, x20, [sp, #16]
    mov      w0, #0x1
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #112
    autiasp  
    ret      
.Lrk35_ep_interrupt_116c:
    tbz      w2, #1, .Lrk35_ep_interrupt_1178
    ldr      x2, [x25, #40]
    b        .Lrk35_ep_interrupt_1120
.Lrk35_ep_interrupt_1178:
    and      w23, w2, #0x4
    tbz      w2, #2, .Lrk35_ep_interrupt_1188
    ldr      x2, [x25, #48]
    b        .Lrk35_ep_interrupt_1120
.Lrk35_ep_interrupt_1188:
    tbz      w2, #3, .Lrk35_ep_interrupt_1764
    ldr      w0, [x1, #8]
    ldr      x20, [x26, #48]
    cmn      w0, #0x1
    b.ne     .Lrk35_ep_interrupt_11b0
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0xee
    add      x1, x1, :lo12:_rodata_str1_1+0xee
    bl       _dev_err
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_11b0:
    cmp      w0, w19
    mov      w24, w19
    b.ne     .Lrk35_ep_interrupt_161c
    mov      x0, #0x28
    add      x1, x1, x24, lsl #4
    mov      x3, #0x20000
    madd     x0, x24, x0, x26
    ldr      x2, [x1, #32]
    ldr      x1, [x0, #288]
    mov      x0, x26
    bl       miop_ep_map_outbound_atu
    mov      w22, w0
    cbz      w0, .Lrk35_ep_interrupt_11fc
    adrp     x1, _rodata_str1_1+0x10d
    mov      w2, w0
    add      x1, x1, :lo12:_rodata_str1_1+0x10d
.Lrk35_ep_interrupt_11f0:
    mov      x0, x20
.Lrk35_ep_interrupt_11f4:
    bl       _dev_err
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_11fc:
    ldr      x0, [x26, #608]
    ldr      x27, [x26, #48]
    ldr      w3, [x0, #8]
    mov      x0, #0x28
    madd     x0, x24, x0, x26
    ldr      x1, [x0, #280]
    ldr      w2, [x1]
    cmp      w2, #0x103
    b.eq     .Lrk35_ep_interrupt_1254
    mov      w22, #0xffffffea
    mov      x0, x27
    adrp     x1, _rodata_str1_1+0x127
    add      x1, x1, :lo12:_rodata_str1_1+0x127
    bl       _dev_err
.Lrk35_ep_interrupt_1234:
    mov      x0, x20
    mov      w2, w22
    adrp     x1, _rodata_str1_1+0x2ca
    add      x1, x1, :lo12:_rodata_str1_1+0x2ca
    bl       _dev_err
    mov      x0, #0x28
    madd     x0, x24, x0, x26
    b        .Lrk35_ep_interrupt_1794
.Lrk35_ep_interrupt_1254:
    str      x1, [x26, #616]
    ldr      w1, [x1, #4]
    str      w1, [x0, #312]
    str      w3, [x0, #316]
    mov      w1, #0x10
    ldp      x28, x0, [x26]
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w1, w0
    tbz      w0, #2, .Lrk35_ep_interrupt_1544
    ldr      x0, [x26, #8]
    and      x2, x1, #0xfffffffffffffff0
    mov      w1, #0x14
    str      x2, [sp, #104]
    bl       rk35_pcie_readl_dbi.isra.0
    ldr      x2, [sp, #104]
    orr      x0, x2, x0, lsl #32
.Lrk35_ep_interrupt_1294:
    str      x0, [x28, #88]
    adrp     x1, _rodata_str1_1+0x149
    add      x1, x1, :lo12:_rodata_str1_1+0x149
    ldr      x0, [x26]
    ldr      x2, [x0, #88]
    mov      x0, x27
    bl       _dev_info
    ldr      x0, [x26, #8]
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0xc
    dmb      oshst
    mov      w28, #0x1
    str      w28, [x0]
    ldr      x0, [x26, #8]
    mov      w1, #0x54
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xfffffffc
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x54
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x26, #8]
    mov      w1, #0x90
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    orr      w0, w0, #0x30000
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x90
    dmb      oshst
    str      w0, [x1]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x200
    dmb      oshst
    mov      w0, #0x308
    movk     w0, #0x400, lsl #16
    str      w0, [x1]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x204
    dmb      oshst
    str      wzr, [x1]
    ldr      x1, [x26, #8]
    ldr      w2, [x26, #9024]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x21c
    dmb      oshst
    str      w2, [x1]
    ldr      x1, [x26, #8]
    ldr      w2, [x26, #9028]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x220
    dmb      oshst
    str      w2, [x1]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x400
    dmb      oshst
    str      w0, [x1]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x404
    dmb      oshst
    str      wzr, [x1]
    ldr      x2, [x26, #8]
    ldr      x1, [x26, #17272]
    add      x2, x2, #0x380, lsl #12
    add      x2, x2, #0x41c
    dmb      oshst
    str      w1, [x2]
    ldr      x2, [x26, #8]
    ldr      x1, [x26, #17272]
    add      x2, x2, #0x380, lsl #12
    add      x2, x2, #0x420
    lsr      x1, x1, #32
    dmb      oshst
    str      w1, [x2]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x2c
    dmb      oshst
    str      w28, [x1]
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x300
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x26, #8]
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0x304
    dmb      oshst
    str      wzr, [x0]
    ldr      x0, [x26, #8]
    mov      w1, #0xa8
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xfffffffe
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0xa8
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x26, #8]
    mov      w1, #0xc4
    movk     w1, #0x38, lsl #16
    bl       rk35_pcie_readl_dbi.isra.0
    orr      w0, w0, #0x10000
    ldr      x1, [x26, #8]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0xc4
    dmb      oshst
    str      w0, [x1]
    ldr      x1, [x26, #8]
    ldr      x0, [x26, #17352]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x31c
    dmb      oshst
    str      w0, [x1]
    ldr      x1, [x26, #8]
    ldr      x0, [x26, #17352]
    add      x1, x1, #0x380, lsl #12
    add      x1, x1, #0x320
    lsr      x0, x0, #32
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x26, #8]
    mov      w1, #0x52
    bl       rk35_pcie_readw_dbi.isra.0
    tbz      w0, #0, .Lrk35_ep_interrupt_1554
    ldr      x0, [x26, #8]
    mov      w1, #0x52
    bl       rk35_pcie_readw_dbi.isra.0
    ubfx     x0, x0, #7, #1
    ldrb     w1, [x26, #86]
    bfi      w1, w0, #1, #1
    strb     w1, [x26, #86]
    ldr      x0, [x26, #8]
    mov      w1, #0x54
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w22, w0
    ldrb     w0, [x26, #86]
    tbz      w0, #1, .Lrk35_ep_interrupt_14e8
    ldr      x0, [x26, #8]
    mov      w1, #0x58
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w23, w0
.Lrk35_ep_interrupt_14e8:
    and      w0, w22, #0xffff
    and      x22, x22, #0xffff0000
    orr      x2, x22, x23, lsl #32
    str      x2, [x26, #104]
    str      w0, [x26, #112]
    cbz      x2, .Lrk35_ep_interrupt_154c
    ldr      x1, [x26, #96]
    mov      x0, x26
    mov      x3, #0x10000
    bl       miop_ep_map_outbound_atu
    mov      w22, w0
    cbz      w0, .Lrk35_ep_interrupt_15e8
.Lrk35_ep_interrupt_1518:
    ldr      x0, [x26, #48]
    adrp     x1, _rodata_str1_1+0x166
    mov      w2, w22
    add      x1, x1, :lo12:_rodata_str1_1+0x166
    bl       _dev_err
.Lrk35_ep_interrupt_152c:
    mov      w2, w22
    mov      x0, x27
    adrp     x1, _rodata_str1_1+0x2e5
    add      x1, x1, :lo12:_rodata_str1_1+0x2e5
    bl       _dev_err
    b        .Lrk35_ep_interrupt_1234
.Lrk35_ep_interrupt_1544:
    and      x0, x1, #0xfffffffffffffff0
    b        .Lrk35_ep_interrupt_1294
.Lrk35_ep_interrupt_154c:
    mov      w22, #0xffffffc3
    b        .Lrk35_ep_interrupt_1518
.Lrk35_ep_interrupt_1554:
    ldr      x0, [x26, #48]
    adrp     x1, _rodata_str1_1+0x17e
    add      x1, x1, :lo12:_rodata_str1_1+0x17e
    bl       _dev_info
    ldr      x23, [x26, #8]
    add      x23, x23, #0x3c
    ldrb     w23, [x23]
    and      x0, x23, #0xff
    mov      x2, x0
    dmb      oshld
    eor      x0, x0, x0
.Lrk35_ep_interrupt_1580:
    cbnz     x0, .Lrk35_ep_interrupt_1580
    ldr      x0, [x26, #48]
    cmp      w2, #0xff
    b.ne     .Lrk35_ep_interrupt_15a4
    adrp     x1, _rodata_str1_1+0x1ab
    mov      w22, #0xffffffc3
    add      x1, x1, :lo12:_rodata_str1_1+0x1ab
    bl       _dev_err
    b        .Lrk35_ep_interrupt_152c
.Lrk35_ep_interrupt_15a4:
    adrp     x1, _rodata_str1_1+0x1c3
    add      x1, x1, :lo12:_rodata_str1_1+0x1c3
    bl       _dev_info
    strb     w23, [x26, #116]
    adrp     x1, _text+0x230
    add      x0, x26, #0x88
    add      x1, x1, :lo12:_text+0x230
    mov      x2, #0xfffffffe0
.Lrk35_ep_interrupt_15c4:
    str      x0, [x0]
    stur     w22, [x0, #-16]
    add      w22, w22, #0x1
    stur     x2, [x0, #-8]
    str      x0, [x0, #8]
    add      x0, x0, #0x28
    stur     x1, [x0, #-24]
    cmp      w22, #0x4
    b.ne     .Lrk35_ep_interrupt_15c4
.Lrk35_ep_interrupt_15e8:
    mov      x0, #0x138
    mov      w2, #0x28
    ldr      x3, [x25, #16]
    smaddl   x2, w19, w2, x0
    ldr      x0, [x26, #608]
    add      x2, x26, x2
    ldr      w0, [x0, #8]
    cmp      w0, w19
    mov      x0, x21
    cset     w1, eq
    orr      w1, w19, w1, lsl #31
    blr      x3
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_161c:
    ldr      x2, [x26, #600]
    sxtw     x0, w19
    cbz      x2, .Lrk35_ep_interrupt_16c8
    add      x0, x2, x0, lsl #6
    add      x2, x2, x24, lsl #6
    ldr      w3, [x0, #72]
    ldr      w1, [x0, #68]
    ldr      x2, [x2, #88]
    and      w4, w3, #0x3
    cmp      w4, #0x1
    b.eq     .Lrk35_ep_interrupt_1660
    adrp     x1, _rodata_str1_1+0x1d1
    mov      w2, w19
    add      x1, x1, :lo12:_rodata_str1_1+0x1d1
.Lrk35_ep_interrupt_1654:
    mov      x0, x20
    bl       _dev_err
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_1660:
    cmp      x2, #0x0
    ccmp     w1, w19, #0x0, ne
    b.eq     .Lrk35_ep_interrupt_168c
    mov      x4, x2
    mov      w3, w1
    mov      w2, w19
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x1fd
    add      x1, x1, :lo12:_rodata_str1_1+0x1fd
    bl       _dev_err
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_168c:
    ldr      w3, [x0, #64]
    mov      x0, #0x28
    madd     x0, x24, x0, x26
    str      w1, [x0, #316]
    ldr      x1, [x0, #304]
    str      w3, [x0, #312]
    mov      x3, #0x20000
    mov      x0, x26
    bl       miop_ep_map_outbound_atu
    mov      w3, w0
    cbz      w0, .Lrk35_ep_interrupt_15e8
    adrp     x1, _rodata_str1_1+0x228
    mov      w2, w19
    add      x1, x1, :lo12:_rodata_str1_1+0x228
    b        .Lrk35_ep_interrupt_1654
.Lrk35_ep_interrupt_16c8:
    mov      x22, #0x28
    add      x23, x1, x0, lsl #4
    mov      x3, #0x20000
    mov      x0, x26
    madd     x22, x24, x22, x26
    ldr      x2, [x23, #32]
    ldr      x1, [x22, #288]
    bl       miop_ep_map_outbound_atu
    mov      w2, w0
    cbz      w0, .Lrk35_ep_interrupt_16fc
    adrp     x1, _rodata_str1_1+0x24a
    add      x1, x1, :lo12:_rodata_str1_1+0x24a
    b        .Lrk35_ep_interrupt_11f0
.Lrk35_ep_interrupt_16fc:
    ldr      x0, [x22, #280]
    ldr      w2, [x0]
    cmp      w2, #0x103
    b.eq     .Lrk35_ep_interrupt_172c
    adrp     x1, _rodata_str1_1+0x264
    add      x1, x1, :lo12:_rodata_str1_1+0x264
.Lrk35_ep_interrupt_1714:
    mov      x0, x20
    bl       _dev_err
    ldr      x1, [x22, #288]
.Lrk35_ep_interrupt_1720:
    mov      x0, x26
    bl       miop_ep_unmap_outbound_atu
    b        .Lrk35_ep_interrupt_112c
.Lrk35_ep_interrupt_172c:
    ldr      w1, [x0, #4]
    mov      x3, #0x20000
    str      w1, [x22, #312]
    ldr      x1, [x22, #304]
    ldr      w0, [x0, #8]
    str      w0, [x22, #316]
    mov      x0, x26
    ldr      x2, [x23, #40]
    bl       miop_ep_map_outbound_atu
    mov      w2, w0
    cbz      w0, .Lrk35_ep_interrupt_15e8
    adrp     x1, _rodata_str1_1+0x286
    add      x1, x1, :lo12:_rodata_str1_1+0x286
    b        .Lrk35_ep_interrupt_1714
.Lrk35_ep_interrupt_1764:
    tbz      w2, #4, .Lrk35_ep_interrupt_17b8
    ldr      x2, [x25, #24]
    mov      w1, w19
    mov      x0, x21
    blr      x2
    ldr      x0, [x26, #608]
    mov      x1, #0x28
    ldr      w0, [x0, #8]
    cmp      w0, w19
    b.ne     .Lrk35_ep_interrupt_179c
    mov      w0, w0
    madd     x0, x0, x1, x26
.Lrk35_ep_interrupt_1794:
    ldr      x1, [x0, #288]
    b        .Lrk35_ep_interrupt_1720
.Lrk35_ep_interrupt_179c:
    mov      w19, w19
    mov      x0, x26
    madd     x19, x19, x1, x26
    ldr      x1, [x19, #304]
    bl       miop_ep_unmap_outbound_atu
    ldr      x1, [x19, #288]
    b        .Lrk35_ep_interrupt_1720
.Lrk35_ep_interrupt_17b8:
    adrp     x1, _rodata_str1_1+0x2a6
    mov      x0, x21
    add      x1, x1, :lo12:_rodata_str1_1+0x2a6
    b        .Lrk35_ep_interrupt_11f4

.global miop_rk35_map_rc_staging
.type miop_rk35_map_rc_staging, @function
miop_rk35_map_rc_staging:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x70
    stp      x29, x30, [sp, #16]
    add      x29, sp, #0x10
    stp      x19, x20, [sp, #32]
    mov      x20, x0
    mrs      x0, sp_el0
    stp      x21, x22, [sp, #48]
    stp      x23, x24, [sp, #64]
    mov      x23, x1
    stp      x25, x26, [sp, #80]
    and      w25, w3, #0x1
    stp      x27, x28, [sp, #96]
    mov      w28, w2
    ldr      x1, [x0, #1336]
    str      x1, [sp, #8]
    mov      x1, #0x0
    ldr      x0, [x20, #120]
    ldr      x19, [x0, #328]
    tbz      w3, #0, .Lmiop_rk35_map_rc_staging_1888
    add      x24, x19, #0x308
    add      x27, x19, #0x310
    add      x26, x19, #0x318
    mov      x1, #0x9000000
.Lmiop_rk35_map_rc_staging_1830:
    movk     x1, #0x9, lsl #32
    str      x1, [sp]
    ldr      x22, [x24]
    cbz      x22, .Lmiop_rk35_map_rc_staging_189c
    cmp      w25, #0x0
    adrp     x0, _rodata_str1_1+0x2fa
    adrp     x2, _rodata_str1_1+0x300
    add      x0, x0, :lo12:_rodata_str1_1+0x2fa
    add      x2, x2, :lo12:_rodata_str1_1+0x300
    adrp     x1, _rodata_str1_1+0x308
    csel     x2, x2, x0, eq
    add      x1, x1, :lo12:_rodata_str1_1+0x308
    mov      x0, x20
    bl       _dev_warn
    ldr      x22, [x24]
.Lmiop_rk35_map_rc_staging_186c:
    mrs      x0, sp_el0
    ldr      x2, [sp, #8]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lmiop_rk35_map_rc_staging_1950
    bl       __stack_chk_fail
.Lmiop_rk35_map_rc_staging_1888:
    add      x24, x19, #0x320
    add      x27, x19, #0x328
    add      x26, x19, #0x330
    mov      x1, #0x9400000
    b        .Lmiop_rk35_map_rc_staging_1830
.Lmiop_rk35_map_rc_staging_189c:
    mov      x2, x23
    mov      w21, w28
    mov      x3, x21
    mov      x0, x19
    bl       miop_ep_map_outbound_atu
    mov      w2, w0
    cbz      w0, .Lmiop_rk35_map_rc_staging_18cc
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x32f
    add      x1, x1, :lo12:_rodata_str1_1+0x32f
    bl       _dev_err
    b        .Lmiop_rk35_map_rc_staging_186c
.Lmiop_rk35_map_rc_staging_18cc:
    ldr      x0, [sp]
    mov      x1, x21
    bl       ioremap
    mov      x21, x0
    cbnz     x0, .Lmiop_rk35_map_rc_staging_1900
    adrp     x1, _rodata_str1_1+0x358
    add      x1, x1, :lo12:_rodata_str1_1+0x358
    mov      x0, x20
    bl       _dev_err
    ldr      x1, [sp]
    mov      x0, x19
    bl       miop_ep_unmap_outbound_atu
    b        .Lmiop_rk35_map_rc_staging_186c
.Lmiop_rk35_map_rc_staging_1900:
    mov      x6, x0
    mov      x22, x0
    ldr      x0, [sp]
    str      x0, [x27]
    cmp      w25, #0x0
    str      w28, [x26]
    str      x21, [x24]
    adrp     x2, _rodata_str1_1+0x300
    adrp     x0, _rodata_str1_1+0x2fa
    add      x2, x2, :lo12:_rodata_str1_1+0x300
    add      x0, x0, :lo12:_rodata_str1_1+0x2fa
    mov      w5, w28
    csel     x2, x2, x0, eq
    mov      x4, x23
    mov      x3, sp
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x373
    add      x1, x1, :lo12:_rodata_str1_1+0x373
    bl       _dev_info
    b        .Lmiop_rk35_map_rc_staging_186c
.Lmiop_rk35_map_rc_staging_1950:
    ldp      x29, x30, [sp, #16]
    mov      x0, x22
    ldp      x19, x20, [sp, #32]
    ldp      x21, x22, [sp, #48]
    ldp      x23, x24, [sp, #64]
    ldp      x25, x26, [sp, #80]
    ldp      x27, x28, [sp, #96]
    add      sp, sp, #0x70
    autiasp  
    ret      

.global miop_rk35_map_peer_bar
.type miop_rk35_map_peer_bar, @function
miop_rk35_map_peer_bar:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x70
    stp      x29, x30, [sp, #16]
    add      x29, sp, #0x10
    stp      x19, x20, [sp, #32]
    mov      w19, w1
    mrs      x1, sp_el0
    stp      x21, x22, [sp, #48]
    stp      x23, x24, [sp, #64]
    mov      w23, w3
    stp      x25, x26, [sp, #80]
    str      x27, [sp, #96]
    ldr      x3, [x1, #1336]
    str      x3, [sp, #8]
    mov      x3, #0x0
    ldr      x1, [x0, #120]
    ldr      x25, [x1, #328]
    cmp      w19, #0x3
    b.ls     .Lmiop_rk35_map_peer_bar_19e4
    adrp     x1, _rodata_str1_1+0x3b0
    mov      w2, w19
    add      x1, x1, :lo12:_rodata_str1_1+0x3b0
    bl       _dev_err
.Lmiop_rk35_map_peer_bar_19dc:
    mov      x20, #0x0
    b        .Lmiop_rk35_map_peer_bar_1a18
.Lmiop_rk35_map_peer_bar_19e4:
    add      x24, x25, w19, uxtw #3
    mov      x22, x4
    mov      w27, w19
    ldr      x1, [x24, #696]
    cbz      x1, .Lmiop_rk35_map_peer_bar_1a34
    adrp     x1, _rodata_str1_1+0x3d7
    mov      w2, w19
    add      x1, x1, :lo12:_rodata_str1_1+0x3d7
    bl       _dev_warn
    cbz      x22, .Lmiop_rk35_map_peer_bar_1a14
    ldr      x0, [x24, #728]
    str      x0, [x22]
.Lmiop_rk35_map_peer_bar_1a14:
    ldr      x20, [x24, #696]
.Lmiop_rk35_map_peer_bar_1a18:
    mrs      x0, sp_el0
    ldr      x2, [sp, #8]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lmiop_rk35_map_peer_bar_1afc
    bl       __stack_chk_fail
.Lmiop_rk35_map_peer_bar_1a34:
    mov      x21, x0
    mov      w20, w23
    mov      x0, #0x1000000
    mov      x3, x20
    movk     x0, #0x9, lsl #32
    lsl      w1, w19, #25
    add      x1, x1, x0
    mov      x26, x2
    mov      x0, x25
    str      x1, [sp]
    bl       miop_ep_map_outbound_atu
    mov      w3, w0
    cbz      w0, .Lmiop_rk35_map_peer_bar_1a80
    mov      w2, w19
    mov      x0, x21
    adrp     x1, _rodata_str1_1+0x40f
    add      x1, x1, :lo12:_rodata_str1_1+0x40f
    bl       _dev_err
    b        .Lmiop_rk35_map_peer_bar_19dc
.Lmiop_rk35_map_peer_bar_1a80:
    ldr      x0, [sp]
    mov      x1, x20
    bl       ioremap
    mov      x20, x0
    cbnz     x0, .Lmiop_rk35_map_peer_bar_1ab8
    adrp     x1, _rodata_str1_1+0x436
    add      x1, x1, :lo12:_rodata_str1_1+0x436
    mov      x0, x21
    mov      w2, w19
    bl       _dev_err
    ldr      x1, [sp]
    mov      x0, x25
    bl       miop_ep_unmap_outbound_atu
    b        .Lmiop_rk35_map_peer_bar_19dc
.Lmiop_rk35_map_peer_bar_1ab8:
    add      x27, x25, x27, lsl #2
    ldr      x0, [sp]
    str      x0, [x24, #728]
    str      w23, [x27, #760]
    str      x20, [x24, #696]
    cbz      x22, .Lmiop_rk35_map_peer_bar_1ad4
    str      x0, [x22]
.Lmiop_rk35_map_peer_bar_1ad4:
    mov      x6, x20
    mov      w5, w23
    mov      x4, x26
    mov      x3, sp
    mov      w2, w19
    mov      x0, x21
    adrp     x1, _rodata_str1_1+0x462
    add      x1, x1, :lo12:_rodata_str1_1+0x462
    bl       _dev_info
    b        .Lmiop_rk35_map_peer_bar_1a18
.Lmiop_rk35_map_peer_bar_1afc:
    ldp      x29, x30, [sp, #16]
    mov      x0, x20
    ldp      x19, x20, [sp, #32]
    ldp      x21, x22, [sp, #48]
    ldp      x23, x24, [sp, #64]
    ldp      x25, x26, [sp, #80]
    ldr      x27, [sp, #96]
    add      sp, sp, #0x70
    autiasp  
    ret      

.global miop_dma_reap_thread
.type miop_dma_reap_thread, @function
miop_dma_reap_thread:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-64]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    stp      x21, x22, [sp, #32]
    add      x22, x0, #0x2, lsl #12
    str      x23, [sp, #48]
    mov      w23, #0x1
.Lmiop_dma_reap_thread_1b50:
    mrs      x21, sp_el0
.Lmiop_dma_reap_thread_1b54:
    bl       kthread_should_stop
    tbz      w0, #0, .Lmiop_dma_reap_thread_1b80
.Lmiop_dma_reap_thread_1b5c:
    mrs      x0, sp_el0
    str      wzr, [x0, #24]
    mov      w0, #0x0
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldr      x23, [sp, #48]
    ldp      x29, x30, [sp], #64
    autiasp  
    ret      
.Lmiop_dma_reap_thread_1b80:
    str      w23, [x21, #24]
    dmb      ish
    add      x20, x19, #0x4, lsl #12
    ldrb     w0, [x20, #952]
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1bf0
    ldrb     w0, [x22, #845]
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1bf0
    ldrb     w0, [x20, #901]
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1bf0
    bl       schedule
    str      wzr, [x21, #24]
.Lmiop_dma_reap_thread_1bac:
    bl       kthread_should_stop
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1b5c
    strb     wzr, [x20, #952]
.Lmiop_dma_reap_thread_1bb8:
    bl       kthread_should_stop
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1b54
    ldrb     w0, [x22, #845]
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1bd0
    ldrb     w0, [x20, #901]
    tbz      w0, #0, .Lmiop_dma_reap_thread_1b50
.Lmiop_dma_reap_thread_1bd0:
    mov      x0, x19
    bl       miop_dma_try_reap
    tbnz     w0, #0, .Lmiop_dma_reap_thread_1bb8
    mov      w2, #0x2
    mov      x1, #0xf
    mov      x0, #0x5
    bl       usleep_range_state
    b        .Lmiop_dma_reap_thread_1bb8
.Lmiop_dma_reap_thread_1bf0:
    mrs      x0, sp_el0
    str      wzr, [x0, #24]
    b        .Lmiop_dma_reap_thread_1bac

.global miop_dma_list_commit_pending
.type miop_dma_list_commit_pending, @function
miop_dma_list_commit_pending:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-144]!
    mov      x1, #0x4390
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x20, x0
    mov      x2, #0x234a
    stp      x21, x22, [sp, #32]
    adrp     x22, jiffies
    mov      w21, #0x0
    stp      x23, x24, [sp, #48]
    mov      w24, #0x18
    mov      x23, #0x2038
    stp      x25, x26, [sp, #64]
    mov      w25, #0x0
    stp      x27, x28, [sp, #80]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #328]
    ldr      x0, [x22, :lo12:jiffies]
    add      x26, x19, x1
    add      x27, x19, x2
    str      x0, [sp, #104]
    mov      x0, x19
    bl       miop_dma_try_reap
    mov      x3, #0x2358
    add      x0, x19, x3
    str      x0, [sp, #112]
    bl       _raw_spin_lock_irqsave
    str      x0, [sp, #120]
    mov      x0, x26
    bl       _raw_spin_lock_irqsave
    mov      x7, #0x28
    str      x0, [sp, #128]
.Lmiop_dma_list_commit_pending_1c88:
    ldrb     w0, [x27, #3]
    tbnz     w0, #0, .Lmiop_dma_list_commit_pending_1d1c
    ldurh    w2, [x27, #-2]
    sub      x3, x27, #0x2, lsl #12
    ldur     x1, [x3, #-18]
    umull    x0, w2, w24
    ldrb     w8, [x1, x0]
    tbnz     w8, #0, .Lmiop_dma_list_commit_pending_1cb4
    ldrh     w8, [x27]
    cmp      w8, w2
    b.eq     .Lmiop_dma_list_commit_pending_1d1c
.Lmiop_dma_list_commit_pending_1cb4:
    ldrb     w2, [x1, x0]
    orr      w2, w2, #0x8
    strb     w2, [x1, x0]
    ldurh    w0, [x27, #-2]
    add      w0, w0, #0x1
    and      w0, w0, #0x7f
    sturh    w0, [x27, #-2]
    ldur     x1, [x3, #-18]
    smull    x0, w0, w24
    str      wzr, [x1, x0]
    dsb      sy
    dmb      ishst
    mov      w8, w25
    ldrh     w28, [x27]
    mul      x8, x8, x23
.Lmiop_dma_list_commit_pending_1cf0:
    ldurh    w0, [x27, #-2]
    cmp      w0, w28
    b.ne     .Lmiop_dma_list_commit_pending_1dd8
    mov      w0, #0x1
    strb     w0, [x27, #3]
    ldr      x0, [x22, :lo12:jiffies]
    add      x0, x0, #0x12c
    stur     x0, [x27, #6]
    mov      x0, #0x1
    lsl      x0, x0, x25
    orr      w21, w21, w0
.Lmiop_dma_list_commit_pending_1d1c:
    add      x27, x27, x23
    cbz      w25, .Lmiop_dma_list_commit_pending_1dd0
    cbnz     w21, .Lmiop_dma_list_commit_pending_1e18
.Lmiop_dma_list_commit_pending_1d28:
    ldr      x1, [sp, #128]
    mov      x0, x26
    bl       _raw_spin_unlock_irqrestore
    ldp      x0, x1, [sp, #112]
    bl       _raw_spin_unlock_irqrestore
    cbz      w21, .Lmiop_dma_list_commit_pending_1d58
    add      x0, x19, #0x4, lsl #12
    mov      w1, #0x1
    strb     w1, [x0, #952]
    ldr      x0, [x19, #17328]
    cbz      x0, .Lmiop_dma_list_commit_pending_1d58
    bl       wake_up_process
.Lmiop_dma_list_commit_pending_1d58:
    ldr      x0, [sp, #104]
    ldr      x19, [x22, :lo12:jiffies]
    sub      x19, x19, x0
    cmp      x19, #0x3
    b.ls     .Lmiop_dma_list_commit_pending_1dac
    adrp     x1, _rodata
    adrp     x0, _data
    add      x1, x1, :lo12:_rodata
    add      x0, x0, :lo12:_data
    add      x1, x1, #0x45
    add      x0, x0, #0x38
    bl       ___ratelimit
    cbz      w0, .Lmiop_dma_list_commit_pending_1dac
    mov      x0, x19
    bl       jiffies_to_msecs
    adrp     x1, _rodata_str1_1+0x4b6
    mov      w3, w0
    mov      w2, w21
    add      x1, x1, :lo12:_rodata_str1_1+0x4b6
    mov      x0, x20
    bl       _dev_warn
.Lmiop_dma_list_commit_pending_1dac:
    ldp      x19, x20, [sp, #16]
    mov      w0, #0x0
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #144
    autiasp  
    ret      
.Lmiop_dma_list_commit_pending_1dd0:
    mov      w25, #0x1
    b        .Lmiop_dma_list_commit_pending_1c88
.Lmiop_dma_list_commit_pending_1dd8:
    sxtw     x0, w28
    madd     x0, x0, x7, x8
    add      x0, x19, x0
    ldrb     w1, [x0, #868]
    tbnz     w1, #0, .Lmiop_dma_list_commit_pending_1e0c
    ldr      x1, [x0, #856]
    mov      w3, #0x1
    ldr      w2, [x0, #864]
    mov      x0, x20
    str      x8, [sp, #136]
    bl       dma_sync_single_for_device
    ldr      x8, [sp, #136]
    mov      x7, #0x28
.Lmiop_dma_list_commit_pending_1e0c:
    add      w28, w28, #0x1
    and      w28, w28, #0x7f
    b        .Lmiop_dma_list_commit_pending_1cf0
.Lmiop_dma_list_commit_pending_1e18:
    mov      x0, #0x234c
    mov      w28, w21
    add      x23, x19, x0
    mov      w24, #0x0
    mov      x27, #0x2038
.Lmiop_dma_list_commit_pending_1e2c:
    lsr      x0, x28, x24
    tbz      w0, #0, .Lmiop_dma_list_commit_pending_1e64
    ldrb     w0, [x23]
    tbnz     w0, #0, .Lmiop_dma_list_commit_pending_1e58
    mov      x0, x20
    mov      w2, w24
    adrp     x1, _rodata_str1_1+0x49c
    add      x1, x1, :lo12:_rodata_str1_1+0x49c
    bl       _dev_info
    mov      w0, #0x1
    strb     w0, [x23]
.Lmiop_dma_list_commit_pending_1e58:
    mov      w1, w24
    mov      x0, x19
    bl       rk35_dma_start_write
.Lmiop_dma_list_commit_pending_1e64:
    add      x23, x23, x27
    cbnz     w24, .Lmiop_dma_list_commit_pending_1d28
    mov      w24, w25
    b        .Lmiop_dma_list_commit_pending_1e2c

.global my_dump
.type my_dump, @function
my_dump:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      x6, x2
    mov      x29, sp
    mov      x5, x1
    mov      x1, x0
    mov      w7, #0x1
    mov      w4, #0x1
    mov      w3, #0x10
    mov      w2, #0x2
    adrp     x0, _rodata_str1_1+0x4e2
    add      x0, x0, :lo12:_rodata_str1_1+0x4e2
    bl       print_hex_dump
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global rk35_pcie_ep_window_map_init
.type rk35_pcie_ep_window_map_init, @function
rk35_pcie_ep_window_map_init:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      w2, #0xdc0
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    mov      x1, #0x8
    ldr      x20, [x0]
    ldr      w0, [x20, #68]
    add      x0, x0, #0x3f
    lsr      x0, x0, #6
    bl       kmalloc_array.constprop.0
    str      x0, [x19, #56]
    cbnz     x0, .Lrk35_pcie_ep_window_map_init_1f10
.Lrk35_pcie_ep_window_map_init_1efc:
    mov      w0, #0xfffffff4
.Lrk35_pcie_ep_window_map_init_1f00:
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lrk35_pcie_ep_window_map_init_1f10:
    ldr      w0, [x20, #72]
    mov      w2, #0xdc0
    mov      x1, #0x8
    add      x0, x0, #0x3f
    lsr      x0, x0, #6
    bl       kmalloc_array.constprop.0
    str      x0, [x19, #64]
    cbz      x0, .Lrk35_pcie_ep_window_map_init_1efc
    ldr      w0, [x20, #72]
    mov      w2, #0xdc0
    mov      x1, #0x8
    bl       kmalloc_array.constprop.0
    str      x0, [x19, #72]
    cbz      x0, .Lrk35_pcie_ep_window_map_init_1efc
    mov      w0, #0x0
    b        .Lrk35_pcie_ep_window_map_init_1f00

.global miop_pcie_ep_init
.type miop_pcie_ep_init, @function
miop_pcie_ep_init:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x90
    mrs      x1, sp_el0
    stp      x29, x30, [sp, #48]
    add      x29, sp, #0x30
    stp      x19, x20, [sp, #64]
    stp      x21, x22, [sp, #80]
    stp      x23, x24, [sp, #96]
    stp      x25, x26, [sp, #112]
    stp      x27, x28, [sp, #128]
    ldr      x21, [x0, #120]
    ldr      x2, [x1, #1336]
    str      x2, [sp, #40]
    mov      x2, #0x0
    ldr      w2, [x21, #120]
    cmp      w2, #0x5f
    b.hi     .Lmiop_pcie_ep_init_1fc8
    adrp     x1, _rodata_str1_1+0x4e5
    add      x1, x1, :lo12:_rodata_str1_1+0x4e5
    bl       _dev_err
.Lmiop_pcie_ep_init_1fa8:
    mov      w21, #0xffffffea
.Lmiop_pcie_ep_init_1fac:
    mrs      x0, sp_el0
    ldr      x2, [sp, #40]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lmiop_pcie_ep_init_2bec
    bl       __stack_chk_fail
.Lmiop_pcie_ep_init_1fc8:
    mov      x20, x0
    mov      w1, #0xdc0
    mov      x0, #0x43d0
    bl       kmalloc_large
    mov      x19, x0
    cbz      x0, .Lmiop_pcie_ep_init_20ac
    add      x21, x21, #0x18
    str      x19, [x21, #304]
    str      x21, [x19]
    mov      x0, x20
    ldr      x1, [x21, #40]
    bl       devm_ioremap_resource
    str      x0, [x19, #8]
    mov      x21, x0
    cmn      x0, #0x1, lsl #12
    b.hi     .Lmiop_pcie_ep_init_1fac
    add      x0, x0, #0x100, lsl #12
    str      x0, [x19, #16]
    ldr      x0, [x19]
    add      x21, x21, #0x300, lsl #12
    str      x21, [x19, #32]
    ldr      x1, [x0, #48]
    mov      x0, x20
    bl       devm_ioremap_resource
    str      x0, [x19, #24]
    mov      x21, x0
    cmn      x0, #0x1, lsl #12
    b.hi     .Lmiop_pcie_ep_init_1fac
    str      x20, [x19, #48]
    mov      x0, x19
    bl       rk35_pcie_ep_window_map_init
    ldr      x0, [x20, #120]
    mov      w3, #0x1ffffff
    ldr      x25, [x0, #328]
    ldr      x23, [x25]
    ldr      w2, [x23, #96]
    cmp      w2, w3
    b.hi     .Lmiop_pcie_ep_init_2078
    add      w3, w3, #0x1
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x50a
    add      x1, x1, :lo12:_rodata_str1_1+0x50a
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_1fa8
.Lmiop_pcie_ep_init_2078:
    add      x2, sp, #0x10
    mov      x0, x20
    mov      x4, #0x0
    mov      w3, #0xcc0
    mov      x1, #0x400000
    bl       dma_alloc_attrs
    str      x0, [x25, #624]
    cbnz     x0, .Lmiop_pcie_ep_init_20b4
    adrp     x1, _rodata_str1_1+0x537
    mov      x0, x20
    add      x1, x1, :lo12:_rodata_str1_1+0x537
    mov      w2, #0x400000
    bl       _dev_err
.Lmiop_pcie_ep_init_20ac:
    mov      w21, #0xfffffff4
    b        .Lmiop_pcie_ep_init_1fac
.Lmiop_pcie_ep_init_20b4:
    ldr      x2, [sp, #16]
    ldr      x1, [x23, #80]
    str      x1, [sp, #24]
    cmp      x1, x2
    b.eq     .Lmiop_pcie_ep_init_2104
    add      x3, sp, #0x18
    add      x2, sp, #0x10
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x562
    add      x1, x1, :lo12:_rodata_str1_1+0x562
    bl       _dev_err
    ldr      x3, [sp, #16]
    mov      x0, x20
    ldr      x2, [x25, #624]
    mov      x4, #0x0
    mov      x1, #0x400000
    mov      w21, #0xfffffffb
    bl       dma_free_attrs
    str      xzr, [x25, #624]
    b        .Lmiop_pcie_ep_init_1fac
.Lmiop_pcie_ep_init_2104:
    mov      x2, #0x400000
    mov      w1, #0x0
    bl       memset
    add      x26, x25, #0x278
    ldr      x0, [x23, #288]
    cbz      x0, .Lmiop_pcie_ep_init_2124
    ldr      x0, [x23, #296]
    cbnz     x0, .Lmiop_pcie_ep_init_2194
.Lmiop_pcie_ep_init_2124:
    mov      w21, #0xffffffed
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x595
    add      x1, x1, :lo12:_rodata_str1_1+0x595
    bl       _dev_err
.Lmiop_pcie_ep_init_2138:
    mov      w22, #0x0
.Lmiop_pcie_ep_init_213c:
    ldr      x0, [x26]
    cbz      x0, .Lmiop_pcie_ep_init_2160
    ldr      x3, [x23, #296]
    mov      w2, w22
    mov      x1, x23
    mov      x0, x20
    blr      x3
    str      xzr, [x26]
    str      xzr, [x26, #32]
.Lmiop_pcie_ep_init_2160:
    add      w22, w22, #0x1
    add      x26, x26, #0x8
    cmp      w22, #0x4
    b.ne     .Lmiop_pcie_ep_init_213c
    ldr      x2, [x25, #624]
    cbz      x2, .Lmiop_pcie_ep_init_1fac
    ldr      x3, [x23, #80]
    mov      x0, x20
    mov      x4, #0x0
    mov      x1, #0x400000
    bl       dma_free_attrs
    str      xzr, [x25, #624]
    b        .Lmiop_pcie_ep_init_1fac
.Lmiop_pcie_ep_init_2194:
    adrp     x24, _rodata
    add      x28, x23, #0xa0
    add      x24, x24, :lo12:_rodata
    mov      x27, x26
    add      x0, x24, #0x98
    mov      x22, #0x0
    str      x0, [sp, #8]
.Lmiop_pcie_ep_init_21b0:
    ldr      x3, [x23, #288]
    mov      w2, w22
    mov      x1, x23
    mov      x0, x20
    blr      x3
    mov      w21, w0
    cbnz     w0, .Lmiop_pcie_ep_init_2138
    ldr      x0, [x28]
    str      x0, [x27]
    ldr      x1, [x28, #64]
    str      x1, [x27, #32]
    cbnz     x0, .Lmiop_pcie_ep_init_21fc
    mov      w2, w22
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x5c6
    mov      w21, #0xfffffff4
    add      x1, x1, :lo12:_rodata_str1_1+0x5c6
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_2138
.Lmiop_pcie_ep_init_21fc:
    ldr      x0, [sp, #8]
    ldr      w4, [x0, x22, lsl #2]
    ldr      x0, [x23, #80]
    add      x0, x0, w4, uxtw
    str      x0, [sp, #24]
    cmp      x1, x0
    b.eq     .Lmiop_pcie_ep_init_2234
    add      x0, x23, #0x80
    adrp     x1, _rodata_str1_1+0x5ed
    mov      w2, w22
    add      x1, x1, :lo12:_rodata_str1_1+0x5ed
    ldr      w3, [x0, x22, lsl #2]
    mov      x0, x20
    bl       _dev_warn
.Lmiop_pcie_ep_init_2234:
    add      x22, x22, #0x1
    add      x28, x28, #0x8
    add      x27, x27, #0x8
    cmp      x22, #0x4
    b.ne     .Lmiop_pcie_ep_init_21b0
    ldr      x22, [x25, #624]
    mov      x0, #0x494d
    movk     x0, #0x504f, lsl #16
    str      x22, [x23, #120]
    movk     x0, #0x2, lsl #48
    str      x0, [x22]
    bl       miop_ep_generate_serial
    str      w0, [x22, #8]
    mov      x1, #0x1
    mov      w0, #0xffffffff
    str      w0, [x22, #12]
    stp      x1, xzr, [x22, #16]
    dsb      st
    ldr      x0, [x25, #624]
    str      x22, [x25, #600]
    mov      w2, #0x103
    add      x0, x0, #0x100, lsl #12
    str      w2, [x0]
    ldr      w2, [x22, #8]
    str      w2, [x0, #4]
    mov      x2, #0xffffffff
    str      x2, [x0, #8]
    str      x0, [x25, #608]
    mov      w2, #0x800000
    ldr      w0, [x23, #128]
    str      w0, [x22, #4096]
    mov      w0, #0x400000
    str      w0, [x22, #4100]
    mov      x0, #0x10000
    str      w1, [x22, #4116]
    movk     x0, #0x40, lsl #32
    str      x0, [x22, #4104]
    ldr      w0, [x23, #132]
    str      w0, [x22, #4224]
    mov      x0, #0x10000
    str      w2, [x22, #4228]
    movk     x0, #0x80, lsl #32
    str      x0, [x22, #4232]
    str      w1, [x22, #4244]
    ldr      w3, [x23, #136]
    str      w3, [x22, #4352]
    str      w2, [x22, #4356]
    str      x0, [x22, #4360]
    str      w1, [x22, #4372]
    ldr      w3, [x23, #140]
    str      w3, [x22, #4480]
    str      w2, [x22, #4484]
    str      x0, [x22, #4488]
    str      w1, [x22, #4500]
    dsb      st
    ldr      x2, [x25, #624]
    mov      x22, x19
    ldp      w3, w4, [x23, #132]
    mov      x0, x20
    ldr      w5, [x23, #140]
    mov      w6, #0x100000
    adrp     x1, _rodata_str1_1+0x63b
    add      x1, x1, :lo12:_rodata_str1_1+0x63b
    bl       _dev_info
    ldr      x0, [x22], #8
    ldr      x1, [x22, #16]
    ldr      w23, [x0, #76]
    dmb      oshst
    mov      w0, #0x8000800
    str      w0, [x1]
    ldr      x0, [x22, #16]
    add      x0, x0, #0x24
    dmb      oshst
    mov      w1, #0x80000000
    str      w1, [x0]
    ldr      x0, [x19, #8]
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0x54
    dmb      oshst
    str      wzr, [x0]
    ldr      x0, [x19, #8]
    add      x0, x0, #0x380, lsl #12
    add      x0, x0, #0xa8
    dmb      oshst
    str      wzr, [x0]
    ldr      x0, [x19, #8]
    mov      w1, #0x710
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xffffff7f
    ldr      x1, [x19, #8]
    orr      w0, w0, #0x20
    add      x1, x1, #0x710
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    mov      w1, #0x710
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xffc0ffff
    cmp      w23, #0x4
    b.ne     .Lmiop_pcie_ep_init_23cc
    orr      w0, w0, #0x70000
    b        .Lmiop_pcie_ep_init_27b0
.Lmiop_pcie_ep_init_23cc:
    b.hi     .Lmiop_pcie_ep_init_27a0
    cmp      w23, #0x1
    b.eq     .Lmiop_pcie_ep_init_27ac
    orr      w0, w0, #0x30000
    cmp      w23, #0x2
.Lmiop_pcie_ep_init_23e0:
    b.eq     .Lmiop_pcie_ep_init_27b0
    ldr      x0, [x22, #40]
    adrp     x1, _rodata_str1_1+0x69b
    mov      w2, w23
    add      x1, x1, :lo12:_rodata_str1_1+0x69b
    bl       _dev_err
.Lmiop_pcie_ep_init_23f8:
    ldr      x0, [x19, #8]
    mov      w1, #0x8bc
    bl       rk35_pcie_readl_dbi.isra.0
    orr      w0, w0, #0x1
    ldr      x1, [x19, #8]
    add      x1, x1, #0x8bc
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    mov      w1, #0x100
    bl       rk35_pcie_readl_dbi.isra.0
    cbnz     w0, .Lmiop_pcie_ep_init_2870
.Lmiop_pcie_ep_init_2428:
    mov      w23, #0x0
.Lmiop_pcie_ep_init_242c:
    str      w23, [x22, #32]
    mov      x0, x22
    mov      w3, #0xc
    mov      x2, #0x2000000
    mov      w1, #0x0
    bl       rk35_pcie_ep_set_bar.isra.0
    mov      x0, x22
    mov      w3, #0x0
    mov      x2, #0x0
    mov      w1, #0x2
    bl       rk35_pcie_ep_set_bar.isra.0
    mov      x0, x22
    mov      w3, #0x0
    mov      x2, #0x0
    mov      w1, #0x3
    bl       rk35_pcie_ep_set_bar.isra.0
    mov      x0, x22
    mov      w3, #0xc
    mov      x2, #0x100000
    mov      w1, #0x4
    bl       rk35_pcie_ep_set_bar.isra.0
    ldr      x1, [x19, #8]
    dmb      oshst
    mov      w0, #0x4586
    strh     w0, [x1]
    ldr      x0, [x19, #8]
    add      x0, x0, #0x2
    dmb      oshst
    mov      w1, #0xffffb6f2
    strh     w1, [x0]
    ldr      x0, [x19, #8]
    add      x0, x0, #0xa
    dmb      oshst
    mov      w1, #0x280
    strh     w1, [x0]
    ldr      x0, [x19, #8]
    mov      w1, #0x8bc
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xfffffffe
    ldr      x1, [x19, #8]
    add      x1, x1, #0x8bc
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19]
    ldr      x25, [x0, #80]
    ldr      w1, [x0, #68]
    ldr      x0, [x19, #56]
    bl       find_first_zero_bit
    mov      x23, x0
    ldr      x0, [x19]
    ldr      w0, [x0, #68]
    cmp      w23, w0
    b.cc     .Lmiop_pcie_ep_init_287c
    adrp     x1, _rodata_str1_1+0x6b4
    add      x1, x1, :lo12:_rodata_str1_1+0x6b4
.Lmiop_pcie_ep_init_2508:
    ldr      x0, [x22, #40]
    bl       _dev_err
.Lmiop_pcie_ep_init_2510:
    mov      x23, #0x900000000
    str      x23, [x19, #96]
    mov      x0, x23
    mov      x1, #0x20000
    bl       ioremap
    str      x0, [x19, #88]
    cbnz     x0, .Lmiop_pcie_ep_init_295c
    adrp     x1, _rodata_str1_1+0x704
    mov      x0, x20
    add      x1, x1, :lo12:_rodata_str1_1+0x704
    bl       _dev_err
.Lmiop_pcie_ep_init_253c:
    ldr      x23, [x19, #48]
    mov      x7, #0x2340
    mov      x4, #0x0
    add      x2, x19, x7
    mov      x0, x23
    mov      w3, #0xcc0
    mov      x1, #0xc18
    bl       dma_alloc_attrs
    str      x0, [x19, #824]
    cbz      x0, .Lmiop_pcie_ep_init_2a08
    str      wzr, [x19, #9032]
    mov      w26, #0xfffffffa
    mov      w25, #0x5
    mov      x6, #0x4378
    ldrb     w1, [x0, #3072]
    add      x2, x19, x6
    mov      x4, #0x0
    mov      w3, #0xcc0
    and      w1, w1, w26
    orr      w1, w1, w25
    strb     w1, [x0, #3072]
    ldr      x1, [x19, #9024]
    str      w1, [x0, #3080]
    ldr      w1, [x19, #9028]
    str      w1, [x0, #3084]
    mov      x0, x23
    mov      x1, #0xc18
    bl       dma_alloc_attrs
    str      x0, [x19, #9072]
    cbnz     x0, .Lmiop_pcie_ep_init_2a10
    mov      w2, #0x1
.Lmiop_pcie_ep_init_25b8:
    adrp     x1, _rodata_str1_1+0x799
    mov      x0, x23
    add      x1, x1, :lo12:_rodata_str1_1+0x799
    bl       _dev_err
.Lmiop_pcie_ep_init_25c8:
    ldr      x0, [x19, #8]
    mov      x1, #0xe14
    movk     x1, #0x20, lsl #16
    add      x0, x0, x1
    dmb      oshst
    mov      w23, #0x100000
    str      w23, [x0]
    ldr      x0, [x19, #8]
    bl       rk35_pcie_readl_dbi.isra.0
    mov      w3, w0
    mov      w2, w23
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x7e4
    add      x1, x1, :lo12:_rodata_str1_1+0x7e4
    bl       _dev_info
    ldr      x0, [x19, #8]
    add      x0, x0, #0x200, lsl #12
    add      x0, x0, #0xe10
    dmb      oshst
    mov      w1, #0x494d
    movk     w1, #0x504f, lsl #16
    str      w1, [x0]
    ldr      x0, [x19]
    adrp     x5, _rodata_str1_1+0x811
    adrp     x2, _text+0x107c
    mov      x6, x20
    add      x5, x5, :lo12:_rodata_str1_1+0x811
    add      x2, x2, :lo12:_text+0x107c
    ldr      w25, [x0, #64]
    mov      x4, #0x80
    mov      x0, x20
    mov      x3, #0x0
    mov      w1, w25
    bl       devm_request_threaded_irq
    cbz      w0, .Lmiop_pcie_ep_init_2ac4
    adrp     x1, _rodata_str1_1+0x81b
    mov      x0, x20
    add      x1, x1, :lo12:_rodata_str1_1+0x81b
    bl       _dev_err
.Lmiop_pcie_ep_init_2664:
    ldr      x0, [x22, #16]
    add      x0, x0, #0x180
    dmb      oshst
    mov      w1, #0x100010
    str      w1, [x0]
    ldr      x1, [x22, #16]
    dmb      oshst
    mov      w0, #0xf00000
    str      w0, [x1]
    ldr      x1, [x22, #16]
    dmb      oshst
    mov      w0, #0xc000c
    str      w0, [x1]
    adrp     x22, _data
    add      x22, x22, :lo12:_data
    mov      w25, #0x3f
    mov      w26, #0x11
    add      x22, x22, #0xe0
    mov      w23, #0x0
    movk     w25, #0x3, lsl #16
    movk     w26, #0x3, lsl #16
.Lmiop_pcie_ep_init_26b8:
    ldr      x0, [x19, #24]
    add      x0, x0, #0x300
    bl       readl
    and      w0, w0, w25
    cmp      w0, w26
    b.ne     .Lmiop_pcie_ep_init_2b6c
    mov      w0, #0x7d0
    bl       msleep
    ldr      x0, [x19, #24]
    add      x0, x0, #0x300
    bl       readl
    adrp     x1, _rodata_str1_1+0x8b5
    mov      w2, w0
    add      x1, x1, :lo12:_rodata_str1_1+0x8b5
    mov      x0, x20
    bl       _dev_info
.Lmiop_pcie_ep_init_26f8:
    add      x24, x19, #0x4, lsl #12
    adrp     x23, _bss
    adrp     x22, _rodata_str1_1+0x904
    add      x23, x23, :lo12:_bss
    add      x22, x22, :lo12:_rodata_str1_1+0x904
    mov      x2, x23
    str      wzr, [x24, #936]
    mov      x1, x22
    mov      w3, #0x2
    mov      x0, #0x2358
    add      x0, x19, x0
    bl       __raw_spin_lock_init
    add      x0, x19, #0x2, lsl #12
    mov      x4, #0x4390
    mov      x2, x23
    mov      x1, x22
    mov      w3, #0x2
    strb     wzr, [x0, #845]
    add      x0, x19, x4
    str      xzr, [x19, #9040]
    bl       __raw_spin_lock_init
    strb     wzr, [x24, #901]
    str      xzr, [x19, #17288]
    mov      w2, #0xffffffff
    strb     wzr, [x24, #952]
    mov      x1, x19
    adrp     x3, _rodata_str1_1+0x920
    adrp     x0, _text+0x1b24
    add      x3, x3, :lo12:_rodata_str1_1+0x920
    add      x0, x0, :lo12:_text+0x1b24
    bl       kthread_create_on_node
    str      x0, [x19, #17328]
    mov      x2, x0
    cmn      x0, #0x1, lsl #12
    b.ls     .Lmiop_pcie_ep_init_2bcc
    str      xzr, [x19, #17328]
    mov      w21, w0
    adrp     x1, _rodata_str1_1+0x92d
    mov      x0, x20
    add      x1, x1, :lo12:_rodata_str1_1+0x92d
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_1fac
.Lmiop_pcie_ep_init_27a0:
    orr      w0, w0, #0xf0000
    cmp      w23, #0x8
    b        .Lmiop_pcie_ep_init_23e0
.Lmiop_pcie_ep_init_27ac:
    orr      w0, w0, #0x10000
.Lmiop_pcie_ep_init_27b0:
    ldr      x1, [x19, #8]
    add      x1, x1, #0x710
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    mov      w1, #0x80c
    bl       rk35_pcie_readl_dbi.isra.0
    and      w0, w0, #0xffffe0ff
    cmp      w23, #0x2
    b.eq     .Lmiop_pcie_ep_init_2820
    cmp      w23, #0x4
    b.eq     .Lmiop_pcie_ep_init_2830
    mov      w2, #0x100
    orr      w1, w0, #0x20000
    cmp      w23, #0x1
    movk     w2, #0x2, lsl #16
    orr      w0, w0, w2
    csel     w0, w0, w1, eq
.Lmiop_pcie_ep_init_27f8:
    ldr      x1, [x19, #8]
    add      x1, x1, #0x80c
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #8]
    add      x0, x0, #0x4
    dmb      oshst
    mov      w1, #0x6
    str      w1, [x0]
    b        .Lmiop_pcie_ep_init_23f8
.Lmiop_pcie_ep_init_2820:
    mov      w1, #0x200
.Lmiop_pcie_ep_init_2824:
    movk     w1, #0x2, lsl #16
    orr      w0, w0, w1
    b        .Lmiop_pcie_ep_init_27f8
.Lmiop_pcie_ep_init_2830:
    mov      w1, #0x400
    b        .Lmiop_pcie_ep_init_2824
.Lmiop_pcie_ep_init_2838:
    and      w1, w0, #0xffff
    cmp      w1, #0x15
    b.eq     .Lmiop_pcie_ep_init_242c
    lsr      w0, w0, #20
    and      w23, w0, #0xffc
    cmp      w23, #0xff
    b.ls     .Lmiop_pcie_ep_init_2428
    ldr      x0, [x19, #8]
    mov      w1, w23
    bl       rk35_pcie_readl_dbi.isra.0
    cbz      w0, .Lmiop_pcie_ep_init_2428
.Lmiop_pcie_ep_init_2864:
    subs     w25, w25, #0x1
    b.ne     .Lmiop_pcie_ep_init_2838
    b        .Lmiop_pcie_ep_init_2428
.Lmiop_pcie_ep_init_2870:
    mov      w25, #0x1e1
    mov      w23, #0x100
    b        .Lmiop_pcie_ep_init_2864
.Lmiop_pcie_ep_init_287c:
    ldr      x1, [x19, #32]
    lsl      w0, w23, #9
    orr      x0, x0, #0x100
    add      x3, x0, #0x14
    add      x1, x1, x3
    dmb      oshst
    str      w25, [x1]
    ldr      x1, [x19, #32]
    add      x2, x0, #0x18
    lsr      x25, x25, #32
    add      x1, x1, x2
    dmb      oshst
    str      w25, [x1]
    ldr      x1, [x19, #32]
    add      x1, x1, x0
    dmb      oshst
    str      wzr, [x1]
    add      x25, x0, #0x4
    ldr      x0, [x19, #32]
    add      x0, x0, x25
    dmb      oshst
    mov      w1, #0xc0080000
    str      w1, [x0]
    mov      x28, #0x8958
    mov      w26, #0x5
    movk     x28, #0x41, lsl #16
.Lmiop_pcie_ep_init_28e4:
    ldr      x0, [x19, #32]
    add      x0, x0, x25
    bl       readl
    tbnz     w0, #31, .Lmiop_pcie_ep_init_292c
    mov      x27, #0x9
.Lmiop_pcie_ep_init_28f8:
    mov      x0, x28
    bl       __const_udelay
    subs     x27, x27, #0x1
    b.ne     .Lmiop_pcie_ep_init_28f8
    subs     w26, w26, #0x1
    b.ne     .Lmiop_pcie_ep_init_28e4
    ldr      x0, [x22, #40]
    adrp     x1, _rodata_str1_1+0x6cc
    add      x1, x1, :lo12:_rodata_str1_1+0x6cc
    bl       _dev_err
    adrp     x1, _rodata_str1_1+0x6e7
    add      x1, x1, :lo12:_rodata_str1_1+0x6e7
    b        .Lmiop_pcie_ep_init_2508
.Lmiop_pcie_ep_init_292c:
    ldr      x1, [x19, #56]
    lsr      w2, w23, #6
    mov      x0, #0x1
    strb     w23, [x19, #80]
    lsl      x0, x0, x23
    add      x5, x1, x2, lsl #3
    prfm     pstl1strm, [x5]
.Lmiop_pcie_ep_init_2948:
    ldxr     x3, [x5]
    orr      x3, x3, x0
    stxr     w4, x3, [x5]
    cbnz     w4, .Lmiop_pcie_ep_init_2948
    b        .Lmiop_pcie_ep_init_2510
.Lmiop_pcie_ep_init_295c:
    add      x25, x19, #0x118
    add      x23, x23, #0x20, lsl #12
    mov      w26, #0x0
.Lmiop_pcie_ep_init_2968:
    str      x23, [x25, #8]
    mov      x0, x23
    mov      x1, #0x20000
    bl       ioremap
    str      x0, [x25]
    cbnz     x0, .Lmiop_pcie_ep_init_2998
    adrp     x1, _rodata_str1_1+0x72b
    mov      w2, w26
    add      x1, x1, :lo12:_rodata_str1_1+0x72b
.Lmiop_pcie_ep_init_298c:
    mov      x0, x20
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_253c
.Lmiop_pcie_ep_init_2998:
    add      x0, x23, #0x20, lsl #12
    str      x0, [x25, #24]
    mov      x1, #0x20000
    bl       ioremap
    str      x0, [x25, #16]
    cbnz     x0, .Lmiop_pcie_ep_init_29c0
    adrp     x1, _rodata_str1_1+0x74e
    mov      w2, w26
    add      x1, x1, :lo12:_rodata_str1_1+0x74e
    b        .Lmiop_pcie_ep_init_298c
.Lmiop_pcie_ep_init_29c0:
    ldr      x3, [x25, #8]
    mov      w2, w26
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x771
    add      x1, x1, :lo12:_rodata_str1_1+0x771
    add      x23, x23, #0x40, lsl #12
    bl       _dev_info
    add      x25, x25, #0x28
    ldur     x3, [x25, #-16]
    mov      w2, w26
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x785
    add      w26, w26, #0x1
    add      x1, x1, :lo12:_rodata_str1_1+0x785
    bl       _dev_info
    cmp      w26, #0x8
    b.ne     .Lmiop_pcie_ep_init_2968
    b        .Lmiop_pcie_ep_init_253c
.Lmiop_pcie_ep_init_2a08:
    mov      w2, #0x0
    b        .Lmiop_pcie_ep_init_25b8
.Lmiop_pcie_ep_init_2a10:
    add      x1, x19, #0x4, lsl #12
    mov      x5, #0x43c8
    mov      x4, #0x0
    add      x2, x19, x5
    mov      w3, #0xcc0
    str      wzr, [x1, #896]
    ldrb     w1, [x0, #3072]
    and      w1, w1, w26
    orr      w1, w1, w25
    strb     w1, [x0, #3072]
    ldr      x1, [x19, #17272]
    str      w1, [x0, #3080]
    ldr      x1, [x19, #17272]
    lsr      x1, x1, #32
    str      w1, [x0, #3084]
    mov      x0, x23
    mov      x1, #0xc18
    bl       dma_alloc_attrs
    str      x0, [x19, #17344]
    cbnz     x0, .Lmiop_pcie_ep_init_2a74
    mov      x0, x23
    adrp     x1, _rodata_str1_1+0x7c3
    add      x1, x1, :lo12:_rodata_str1_1+0x7c3
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_25c8
.Lmiop_pcie_ep_init_2a74:
    ldr      x1, [x19]
    ldr      x0, [x19, #17352]
    ldr      x1, [x1, #80]
    sub      w0, w0, w1
    ldr      x1, [x19, #8]
    add      x1, x1, #0x200, lsl #12
    add      x1, x1, #0xe18
    dmb      oshst
    str      w0, [x1]
    ldr      x0, [x19, #17344]
    add      x2, x0, #0xc00
    ldrb     w1, [x0, #3072]
    orr      w1, w1, #0x4
    strb     w1, [x0, #3072]
    ldr      x0, [x19, #17352]
    str      w0, [x2, #8]
    ldr      x0, [x19, #17352]
    lsr      x0, x0, #32
    str      w0, [x2, #12]
    b        .Lmiop_pcie_ep_init_25c8
.Lmiop_pcie_ep_init_2ac4:
    adrp     x23, nr_cpu_ids
    add      x0, sp, #0x20
    mov      w1, #0x0
    ldr      w26, [x23, :lo12:nr_cpu_ids]
    mov      w2, w26
    add      x2, x2, #0x3f
    lsr      x2, x2, #6
    lsl      x2, x2, #3
    bl       memset
    cmp      w26, #0x4
    b.ls     .Lmiop_pcie_ep_init_2b08
    add      x2, sp, #0x20
    prfm     pstl1strm, [x2]
.Lmiop_pcie_ep_init_2af8:
    ldxr     x0, [x2]
    orr      x0, x0, #0x10
    stxr     w1, x0, [x2]
    cbnz     w1, .Lmiop_pcie_ep_init_2af8
.Lmiop_pcie_ep_init_2b08:
    ldr      w3, [x23, :lo12:nr_cpu_ids]
    add      x1, sp, #0x20
    adrp     x2, __cpu_online_mask
    add      x2, x2, :lo12:__cpu_online_mask
    mov      x0, x1
    bl       __bitmap_and
    ldr      w26, [x23, :lo12:nr_cpu_ids]
    add      x0, sp, #0x20
    mov      x1, x26
    bl       _find_first_bit
    cmp      x26, x0
    b.eq     .Lmiop_pcie_ep_init_2b58
    ldr      w3, [x23, :lo12:nr_cpu_ids]
    add      x4, sp, #0x20
    mov      w2, w25
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x841
    add      x1, x1, :lo12:_rodata_str1_1+0x841
    bl       _dev_info
    b        .Lmiop_pcie_ep_init_2664
.Lmiop_pcie_ep_init_2b58:
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x87f
    add      x1, x1, :lo12:_rodata_str1_1+0x87f
    bl       _dev_warn
    b        .Lmiop_pcie_ep_init_2664
.Lmiop_pcie_ep_init_2b6c:
    add      x1, x24, #0xa8
    mov      x0, x22
    bl       ___ratelimit
    cbz      w0, .Lmiop_pcie_ep_init_2ba0
    ldr      x0, [x19, #24]
    add      x0, x0, #0x300
    bl       readl
    adrp     x1, _rodata_str1_1+0x8d2
    mov      w3, w0
    mov      w2, w23
    add      x1, x1, :lo12:_rodata_str1_1+0x8d2
    mov      x0, x20
    bl       _dev_info
.Lmiop_pcie_ep_init_2ba0:
    mov      w0, #0x14
    add      w23, w23, #0x1
    bl       msleep
    cmp      w23, #0x3e8
    b.ne     .Lmiop_pcie_ep_init_26b8
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x8f4
    mov      w21, #0xffffff92
    add      x1, x1, :lo12:_rodata_str1_1+0x8f4
    bl       _dev_err
    b        .Lmiop_pcie_ep_init_26f8
.Lmiop_pcie_ep_init_2bcc:
    bl       wake_up_process
    ldr      x0, [x19, #8]
    add      x0, x0, #0x200, lsl #12
    add      x0, x0, #0xe08
    dmb      oshst
    mov      w1, #0xffff0000
    str      w1, [x0]
    b        .Lmiop_pcie_ep_init_1fac
.Lmiop_pcie_ep_init_2bec:
    ldp      x29, x30, [sp, #48]
    mov      w0, w21
    ldp      x19, x20, [sp, #64]
    ldp      x21, x22, [sp, #80]
    ldp      x23, x24, [sp, #96]
    ldp      x25, x26, [sp, #112]
    ldp      x27, x28, [sp, #128]
    add      sp, sp, #0x90
    autiasp  
    ret      

.global rk35_pcie_ep_window_map_deinit
.type rk35_pcie_ep_window_map_deinit, @function
rk35_pcie_ep_window_map_deinit:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    str      x19, [sp, #16]
    mov      x19, x0
    ldr      x0, [x0, #56]
    cbz      x0, .Lrk35_pcie_ep_window_map_deinit_2c40
    bl       kfree
    str      xzr, [x19, #56]
.Lrk35_pcie_ep_window_map_deinit_2c40:
    ldr      x0, [x19, #64]
    cbz      x0, .Lrk35_pcie_ep_window_map_deinit_2c50
    bl       kfree
    str      xzr, [x19, #64]
.Lrk35_pcie_ep_window_map_deinit_2c50:
    ldr      x0, [x19, #72]
    cbz      x0, .Lrk35_pcie_ep_window_map_deinit_2c60
    bl       kfree
    str      xzr, [x19, #72]
.Lrk35_pcie_ep_window_map_deinit_2c60:
    ldr      x19, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global miop_pcie_ep_deinit
.type miop_pcie_ep_deinit, @function
miop_pcie_ep_deinit:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-80]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    stp      x21, x22, [sp, #32]
    mov      x21, x0
    stp      x23, x24, [sp, #48]
    str      x25, [sp, #64]
    ldr      x25, [x0, #120]
    ldr      x19, [x25, #328]
    ldr      x0, [x19, #8]
    add      x0, x0, #0x200, lsl #12
    add      x0, x0, #0xe08
    dmb      oshst
    mov      w1, #0xffffffff
    str      w1, [x0]
    ldr      x0, [x19, #17328]
    cbz      x0, .Lmiop_pcie_ep_deinit_2cc8
    bl       kthread_stop
    str      xzr, [x19, #17328]
.Lmiop_pcie_ep_deinit_2cc8:
    ldr      x0, [x19, #104]
    cbz      x0, .Lmiop_pcie_ep_deinit_2cdc
    ldr      x1, [x19, #96]
    mov      x0, x19
    bl       miop_ep_unmap_outbound_atu
.Lmiop_pcie_ep_deinit_2cdc:
    ldr      x1, [x19, #24]
    dmb      oshst
    mov      w0, #0xc0000
    str      w0, [x1]
    mov      x0, x19
    bl       rk35_pcie_ep_window_map_deinit
    ldr      x0, [x21, #120]
    mov      w24, #0x0
    ldr      x20, [x0, #328]
    add      x22, x20, #0x278
    ldr      x23, [x20]
.Lmiop_pcie_ep_deinit_2d08:
    ldr      x0, [x22]
    cbz      x0, .Lmiop_pcie_ep_deinit_2d30
    ldr      x3, [x23, #296]
    cbz      x3, .Lmiop_pcie_ep_deinit_2d28
    mov      w2, w24
    mov      x1, x23
    mov      x0, x21
    blr      x3
.Lmiop_pcie_ep_deinit_2d28:
    str      xzr, [x22]
    str      xzr, [x22, #32]
.Lmiop_pcie_ep_deinit_2d30:
    add      w24, w24, #0x1
    add      x22, x22, #0x8
    cmp      w24, #0x4
    b.ne     .Lmiop_pcie_ep_deinit_2d08
    ldr      x2, [x20, #624]
    cbz      x2, .Lmiop_pcie_ep_deinit_2d60
    ldr      x3, [x23, #80]
    mov      x0, x21
    mov      x4, #0x0
    mov      x1, #0x400000
    bl       dma_free_attrs
    str      xzr, [x20, #624]
.Lmiop_pcie_ep_deinit_2d60:
    str      xzr, [x23, #120]
    mov      x0, x19
    str      xzr, [x20, #600]
    str      xzr, [x20, #608]
    str      xzr, [x25, #328]
    bl       kfree
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldr      x25, [sp, #64]
    ldp      x29, x30, [sp], #80
    autiasp  
    ret      
    ldar     w0, [x0]
    ldarh    w0, [x0]
    ldarb    w23, [x23]

.global cleanup_module
.type cleanup_module, @function
cleanup_module:
    paciasp  
    sub      sp, sp, #0x50
    add      x3, sp, #0xc
    mrs      x0, sp_el0
    mov      x2, #0x2c
    stp      x29, x30, [sp, #64]
    add      x29, sp, #0x40
    ldr      x1, [x0, #1336]
    str      x1, [sp, #56]
    mov      x1, #0x0
    mov      x0, x3
    bl       memset
    adrp     x2, _rodata
    add      x2, x2, :lo12:_rodata
    mov      x3, x0
    add      x6, x2, #0x8
    add      x0, x2, #0x1
    mov      x1, #0x0
.Lcleanup_module_48:
    ldrb     w5, [x0]
    ldrb     w4, [x1, x6]
    eor      w4, w4, w5
    strb     w4, [x3, x1]
    ldrb     w4, [x0, #1]!
    add      x1, x1, #0x1
    cmp      w4, #0x0
    csel     x0, x0, x2, ne
    cmp      x1, #0x2b
    b.ne     .Lcleanup_module_48
    mov      x1, x3
    adrp     x0, _rodata_str1_1
    add      x0, x0, :lo12:_rodata_str1_1
    bl       _printk
    mrs      x0, sp_el0
    ldr      x2, [sp, #56]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lcleanup_module_9c
    bl       __stack_chk_fail
.Lcleanup_module_9c:
    ldp      x29, x30, [sp, #64]
    add      sp, sp, #0x50
    autiasp  
    ret      

.global init_module
.type init_module, @function
init_module:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x50
    add      x3, sp, #0x4
    mrs      x0, sp_el0
    mov      x2, #0x34
    stp      x29, x30, [sp, #64]
    add      x29, sp, #0x40
    ldr      x1, [x0, #1336]
    str      x1, [sp, #56]
    mov      x1, #0x0
    mov      x0, x3
    bl       memset
    adrp     x2, _rodata
    add      x2, x2, :lo12:_rodata
    mov      x3, x0
    add      x6, x2, #0x62
    add      x0, x2, #0x2
    mov      x1, #0x0
.Linit_module_50:
    ldrb     w5, [x0]
    ldrb     w4, [x1, x6]
    eor      w4, w4, w5
    strb     w4, [x3, x1]
    ldrb     w4, [x0, #1]!
    add      x1, x1, #0x1
    cmp      w4, #0x0
    csel     x0, x0, x2, ne
    cmp      x1, #0x33
    b.ne     .Linit_module_50
    mov      x1, x3
    adrp     x0, _rodata_str1_1
    add      x0, x0, :lo12:_rodata_str1_1
    bl       _printk
    adrp     x0, _data
    add      x0, x0, :lo12:_data
    add      x0, x0, #0x70
    bl       miop_register_pcie_ep_drv
    mrs      x0, sp_el0
    ldr      x2, [sp, #56]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Linit_module_b4
    bl       __stack_chk_fail
.Linit_module_b4:
    ldp      x29, x30, [sp, #64]
    mov      w0, #0x0
    add      sp, sp, #0x50
    autiasp  
    ret      

.section .rodata.str1.1
.global _rodata_str1_1
_rodata_str1_1:
    .byte 0x01, 0x36, 0x25, 0x73, 0x0a, 0x00, 0x44, 0x4d, 0x41, 0x20, 0x74, 0x69, 0x6d, 0x65, 0x6f, 0x75
    .byte 0x74, 0x20, 0x63, 0x68, 0x25, 0x75, 0x2c, 0x20, 0x72, 0x65, 0x73, 0x74, 0x61, 0x72, 0x74, 0x20
    .byte 0x44, 0x4d, 0x41, 0x20, 0x63, 0x6f, 0x6e, 0x74, 0x72, 0x6f, 0x6c, 0x6c, 0x65, 0x72, 0x0a, 0x00
    .byte 0x44, 0x4d, 0x41, 0x5f, 0x41, 0x42, 0x4f, 0x52, 0x54, 0x20, 0x63, 0x68, 0x3d, 0x25, 0x75, 0x20
    .byte 0x64, 0x72, 0x6f, 0x70, 0x70, 0x65, 0x64, 0x3d, 0x25, 0x64, 0x0a, 0x00, 0x6e, 0x6f, 0x20, 0x73
    .byte 0x75, 0x63, 0x68, 0x20, 0x4d, 0x53, 0x49, 0x20, 0x69, 0x6e, 0x74, 0x65, 0x72, 0x72, 0x75, 0x70
    .byte 0x74, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6e, 0x6f, 0x64, 0x65, 0x20, 0x73, 0x65, 0x6c, 0x66
    .byte 0x20, 0x69, 0x64, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x69, 0x6e, 0x69, 0x74, 0x69, 0x61, 0x6c, 0x65
    .byte 0x64, 0x0a, 0x00, 0x4e, 0x6f, 0x20, 0x66, 0x72, 0x65, 0x65, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f
    .byte 0x75, 0x6e, 0x64, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x0a, 0x00, 0x65, 0x6e, 0x61, 0x62
    .byte 0x6c, 0x65, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f, 0x75, 0x6e, 0x64, 0x20, 0x61, 0x74, 0x75, 0x20
    .byte 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x0a, 0x00, 0x6f, 0x75, 0x74, 0x62, 0x6f, 0x75, 0x6e, 0x64
    .byte 0x20, 0x66, 0x72, 0x65, 0x65, 0x5f, 0x77, 0x69, 0x6e, 0x3a, 0x20, 0x25, 0x64, 0x20, 0x70, 0x68
    .byte 0x79, 0x73, 0x5f, 0x61, 0x64, 0x64, 0x72, 0x3a, 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x70, 0x63
    .byte 0x69, 0x5f, 0x61, 0x64, 0x64, 0x72, 0x3a, 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x0a, 0x00, 0x6e, 0x6f
    .byte 0x64, 0x65, 0x20, 0x64, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x6f, 0x72, 0x20, 0x6e, 0x6f
    .byte 0x74, 0x20, 0x69, 0x6e, 0x69, 0x74, 0x69, 0x61, 0x6c, 0x65, 0x64, 0x0a, 0x00, 0x6d, 0x61, 0x70
    .byte 0x20, 0x68, 0x6f, 0x73, 0x74, 0x20, 0x64, 0x65, 0x73, 0x63, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65
    .byte 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x68, 0x6f, 0x73, 0x74, 0x20, 0x6c, 0x61, 0x79, 0x6f
    .byte 0x75, 0x74, 0x20, 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x20, 0x6d, 0x69, 0x73, 0x6d, 0x61
    .byte 0x74, 0x63, 0x68, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x44, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70
    .byte 0x74, 0x6f, 0x72, 0x20, 0x50, 0x43, 0x49, 0x20, 0x61, 0x64, 0x64, 0x72, 0x65, 0x73, 0x73, 0x3a
    .byte 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f, 0x20
    .byte 0x69, 0x6e, 0x69, 0x74, 0x20, 0x4d, 0x53, 0x49, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x4d, 0x53
    .byte 0x49, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x65, 0x6e, 0x61, 0x62, 0x6c, 0x65, 0x64, 0x2c, 0x20, 0x63
    .byte 0x68, 0x65, 0x63, 0x6b, 0x20, 0x6f, 0x6e, 0x20, 0x6c, 0x65, 0x67, 0x61, 0x63, 0x79, 0x20, 0x69
    .byte 0x6e, 0x74, 0x65, 0x72, 0x72, 0x75, 0x70, 0x74, 0x2e, 0x0a, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65
    .byte 0x64, 0x20, 0x74, 0x6f, 0x20, 0x67, 0x65, 0x74, 0x20, 0x69, 0x72, 0x71, 0x20, 0x6c, 0x69, 0x6e
    .byte 0x65, 0x0a, 0x00, 0x69, 0x72, 0x71, 0x20, 0x6c, 0x69, 0x6e, 0x65, 0x3a, 0x20, 0x25, 0x64, 0x0a
    .byte 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74
    .byte 0x72, 0x6c, 0x20, 0x65, 0x6e, 0x74, 0x72, 0x79, 0x20, 0x69, 0x6e, 0x76, 0x61, 0x6c, 0x69, 0x64
    .byte 0x20, 0x66, 0x6c, 0x61, 0x67, 0x73, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x0a, 0x00, 0x70, 0x65, 0x65
    .byte 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x62, 0x61, 0x64, 0x20, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74
    .byte 0x72, 0x6c, 0x20, 0x6e, 0x6f, 0x64, 0x65, 0x3d, 0x25, 0x75, 0x20, 0x63, 0x74, 0x72, 0x6c, 0x3d
    .byte 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x0a, 0x00, 0x6d, 0x61, 0x70, 0x20, 0x70, 0x65, 0x65, 0x72
    .byte 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x65, 0x6c, 0x62, 0x69, 0x20, 0x72, 0x65, 0x67, 0x20, 0x66, 0x61
    .byte 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6d, 0x61, 0x70, 0x20, 0x70, 0x65
    .byte 0x65, 0x72, 0x20, 0x64, 0x65, 0x73, 0x63, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20
    .byte 0x25, 0x64, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x20, 0x6c, 0x61, 0x79, 0x6f, 0x75, 0x74, 0x20
    .byte 0x76, 0x65, 0x72, 0x73, 0x69, 0x6f, 0x6e, 0x20, 0x6d, 0x69, 0x73, 0x6d, 0x61, 0x74, 0x63, 0x68
    .byte 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6d, 0x61, 0x70, 0x20, 0x72, 0x65, 0x6d, 0x6f, 0x74, 0x65
    .byte 0x20, 0x65, 0x6c, 0x62, 0x69, 0x20, 0x72, 0x65, 0x67, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64
    .byte 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x65, 0x70, 0x5f, 0x65, 0x6c
    .byte 0x62, 0x69, 0x5f, 0x69, 0x6e, 0x74, 0x28, 0x29, 0x20, 0x75, 0x6e, 0x6b, 0x6e, 0x6f, 0x77, 0x6e
    .byte 0x20, 0x69, 0x72, 0x71, 0x3a, 0x20, 0x25, 0x78, 0x0a, 0x00, 0x62, 0x69, 0x6e, 0x64, 0x20, 0x68
    .byte 0x6f, 0x73, 0x74, 0x20, 0x6e, 0x6f, 0x64, 0x65, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x3a
    .byte 0x20, 0x25, 0x64, 0x0a, 0x00, 0x69, 0x72, 0x71, 0x20, 0x69, 0x6e, 0x69, 0x74, 0x20, 0x66, 0x61
    .byte 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x74, 0x6f, 0x5f, 0x65, 0x70, 0x00
    .byte 0x66, 0x72, 0x6f, 0x6d, 0x5f, 0x65, 0x70, 0x00, 0x52, 0x43, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69
    .byte 0x6e, 0x67, 0x20, 0x28, 0x25, 0x73, 0x29, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x20, 0x61
    .byte 0x6c, 0x72, 0x65, 0x61, 0x64, 0x79, 0x20, 0x6d, 0x61, 0x70, 0x70, 0x65, 0x64, 0x0a, 0x00, 0x52
    .byte 0x43, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f, 0x75
    .byte 0x6e, 0x64, 0x20, 0x41, 0x54, 0x55, 0x20, 0x70, 0x72, 0x6f, 0x67, 0x20, 0x66, 0x61, 0x69, 0x6c
    .byte 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x52, 0x43, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69
    .byte 0x6e, 0x67, 0x20, 0x69, 0x6f, 0x72, 0x65, 0x6d, 0x61, 0x70, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65
    .byte 0x64, 0x0a, 0x00, 0x52, 0x43, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x20, 0x28, 0x25
    .byte 0x73, 0x29, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x3a, 0x20, 0x70, 0x68, 0x79, 0x73, 0x3d
    .byte 0x25, 0x70, 0x61, 0x20, 0x70, 0x63, 0x69, 0x3d, 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x73
    .byte 0x69, 0x7a, 0x65, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x20, 0x76, 0x61, 0x3d, 0x25, 0x70, 0x0a, 0x00
    .byte 0x6d, 0x61, 0x70, 0x5f, 0x70, 0x65, 0x65, 0x72, 0x5f, 0x62, 0x61, 0x72, 0x3a, 0x20, 0x70, 0x65
    .byte 0x65, 0x72, 0x5f, 0x69, 0x64, 0x20, 0x25, 0x75, 0x20, 0x6f, 0x75, 0x74, 0x20, 0x6f, 0x66, 0x20
    .byte 0x72, 0x61, 0x6e, 0x67, 0x65, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20
    .byte 0x42, 0x41, 0x52, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x20, 0x61, 0x6c, 0x72, 0x65, 0x61
    .byte 0x64, 0x79, 0x20, 0x6d, 0x61, 0x70, 0x70, 0x65, 0x64, 0x2c, 0x20, 0x72, 0x65, 0x74, 0x75, 0x72
    .byte 0x6e, 0x69, 0x6e, 0x67, 0x20, 0x65, 0x78, 0x69, 0x73, 0x74, 0x69, 0x6e, 0x67, 0x0a, 0x00, 0x70
    .byte 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f, 0x75, 0x6e, 0x64
    .byte 0x20, 0x41, 0x54, 0x55, 0x20, 0x70, 0x72, 0x6f, 0x67, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64
    .byte 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x69
    .byte 0x6f, 0x72, 0x65, 0x6d, 0x61, 0x70, 0x20, 0x6f, 0x66, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f, 0x75
    .byte 0x6e, 0x64, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64
    .byte 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x42, 0x41, 0x52, 0x20, 0x77
    .byte 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x3a, 0x20, 0x70, 0x68, 0x79, 0x73, 0x3d, 0x25, 0x70, 0x61, 0x20
    .byte 0x70, 0x63, 0x69, 0x3d, 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x73, 0x69, 0x7a, 0x65, 0x3d
    .byte 0x30, 0x78, 0x25, 0x78, 0x20, 0x76, 0x61, 0x3d, 0x25, 0x70, 0x0a, 0x00, 0x54, 0x58, 0x20, 0x44
    .byte 0x4d, 0x41, 0x20, 0x63, 0x68, 0x61, 0x6e, 0x6e, 0x65, 0x6c, 0x20, 0x25, 0x64, 0x20, 0x61, 0x63
    .byte 0x74, 0x69, 0x76, 0x65, 0x0a, 0x00, 0x44, 0x4d, 0x41, 0x5f, 0x43, 0x4f, 0x4d, 0x4d, 0x49, 0x54
    .byte 0x5f, 0x53, 0x4c, 0x4f, 0x57, 0x20, 0x6d, 0x61, 0x73, 0x6b, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x20
    .byte 0x64, 0x74, 0x3d, 0x25, 0x75, 0x20, 0x6d, 0x73, 0x20, 0x61, 0x73, 0x79, 0x6e, 0x63, 0x3d, 0x31
    .byte 0x0a, 0x00, 0x01, 0x36, 0x00, 0x49, 0x6e, 0x73, 0x75, 0x66, 0x66, 0x69, 0x63, 0x65, 0x6e, 0x74
    .byte 0x20, 0x69, 0x6e, 0x62, 0x6f, 0x75, 0x6e, 0x64, 0x20, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x20
    .byte 0x73, 0x69, 0x7a, 0x65, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x69, 0x62, 0x5f, 0x6d, 0x65, 0x6d
    .byte 0x5f, 0x73, 0x69, 0x7a, 0x65, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x20, 0x3c, 0x20, 0x4d, 0x49, 0x4f
    .byte 0x50, 0x5f, 0x42, 0x41, 0x52, 0x5f, 0x54, 0x4f, 0x54, 0x41, 0x4c, 0x5f, 0x53, 0x49, 0x5a, 0x45
    .byte 0x3d, 0x30, 0x78, 0x25, 0x78, 0x0a, 0x00, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74, 0x72, 0x6c, 0x3a
    .byte 0x20, 0x64, 0x6d, 0x61, 0x5f, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x5f, 0x63, 0x6f, 0x68, 0x65, 0x72
    .byte 0x65, 0x6e, 0x74, 0x28, 0x30, 0x78, 0x25, 0x78, 0x29, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64
    .byte 0x0a, 0x00, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74, 0x72, 0x6c, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x61
    .byte 0x74, 0x20, 0x70, 0x6f, 0x6f, 0x6c, 0x20, 0x62, 0x61, 0x73, 0x65, 0x3a, 0x20, 0x67, 0x6f, 0x74
    .byte 0x20, 0x25, 0x70, 0x61, 0x64, 0x20, 0x65, 0x78, 0x70, 0x65, 0x63, 0x74, 0x65, 0x64, 0x20, 0x25
    .byte 0x70, 0x61, 0x64, 0x0a, 0x00, 0x72, 0x78, 0x5f, 0x72, 0x65, 0x67, 0x69, 0x6f, 0x6e, 0x20, 0x61
    .byte 0x6c, 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, 0x20, 0x63, 0x61, 0x6c, 0x6c, 0x62, 0x61, 0x63
    .byte 0x6b, 0x73, 0x20, 0x61, 0x72, 0x65, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x61, 0x76, 0x61, 0x69, 0x6c
    .byte 0x61, 0x62, 0x6c, 0x65, 0x0a, 0x00, 0x72, 0x78, 0x5f, 0x72, 0x65, 0x67, 0x69, 0x6f, 0x6e, 0x5b
    .byte 0x25, 0x64, 0x5d, 0x20, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, 0x20, 0x72, 0x65
    .byte 0x74, 0x75, 0x72, 0x6e, 0x65, 0x64, 0x20, 0x4e, 0x55, 0x4c, 0x4c, 0x0a, 0x00, 0x72, 0x78, 0x5f
    .byte 0x72, 0x65, 0x67, 0x69, 0x6f, 0x6e, 0x5b, 0x25, 0x64, 0x5d, 0x20, 0x61, 0x74, 0x20, 0x6e, 0x6f
    .byte 0x6e, 0x2d, 0x63, 0x61, 0x6e, 0x6f, 0x6e, 0x69, 0x63, 0x61, 0x6c, 0x20, 0x6f, 0x66, 0x66, 0x73
    .byte 0x65, 0x74, 0x20, 0x30, 0x78, 0x25, 0x78, 0x20, 0x28, 0x63, 0x61, 0x6e, 0x6f, 0x6e, 0x69, 0x63
    .byte 0x61, 0x6c, 0x20, 0x30, 0x78, 0x25, 0x78, 0x29, 0x20, 0xe2, 0x80, 0x94, 0x20, 0x75, 0x73, 0x69
    .byte 0x6e, 0x67, 0x20, 0x61, 0x63, 0x74, 0x75, 0x61, 0x6c, 0x0a, 0x00, 0x62, 0x61, 0x72, 0x20, 0x6c
    .byte 0x61, 0x79, 0x6f, 0x75, 0x74, 0x3a, 0x20, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74, 0x72, 0x6c, 0x40
    .byte 0x2b, 0x30, 0x20, 0x28, 0x25, 0x70, 0x29, 0x3b, 0x20, 0x72, 0x78, 0x5f, 0x72, 0x65, 0x67, 0x69
    .byte 0x6f, 0x6e, 0x20, 0x6f, 0x66, 0x66, 0x73, 0x65, 0x74, 0x73, 0x3a, 0x20, 0x5b, 0x31, 0x5d, 0x3d
    .byte 0x30, 0x78, 0x25, 0x78, 0x20, 0x5b, 0x32, 0x5d, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x20, 0x5b, 0x33
    .byte 0x5d, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x3b, 0x20, 0x63, 0x6f, 0x6d, 0x70, 0x61, 0x74, 0x5f, 0x64
    .byte 0x65, 0x73, 0x63, 0x40, 0x2b, 0x30, 0x78, 0x25, 0x78, 0x0a, 0x00, 0x27, 0x6e, 0x75, 0x6d, 0x2d
    .byte 0x6c, 0x61, 0x6e, 0x65, 0x73, 0x27, 0x20, 0x69, 0x6e, 0x76, 0x61, 0x6c, 0x69, 0x64, 0x3a, 0x20
    .byte 0x25, 0x75, 0x0a, 0x00, 0x4e, 0x6f, 0x20, 0x66, 0x72, 0x65, 0x65, 0x20, 0x69, 0x6e, 0x62, 0x6f
    .byte 0x75, 0x6e, 0x64, 0x20, 0x77, 0x69, 0x6e, 0x64, 0x6f, 0x77, 0x0a, 0x00, 0x65, 0x6e, 0x61, 0x62
    .byte 0x6c, 0x65, 0x20, 0x69, 0x6e, 0x62, 0x6f, 0x75, 0x6e, 0x64, 0x20, 0x61, 0x74, 0x75, 0x20, 0x66
    .byte 0x61, 0x69, 0x6c, 0x65, 0x64, 0x0a, 0x00, 0x46, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f
    .byte 0x20, 0x70, 0x72, 0x6f, 0x67, 0x72, 0x61, 0x6d, 0x20, 0x49, 0x42, 0x20, 0x77, 0x69, 0x6e, 0x64
    .byte 0x6f, 0x77, 0x0a, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f, 0x20, 0x61, 0x6c
    .byte 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x65, 0x20, 0x6d, 0x73, 0x69, 0x20, 0x6f, 0x75, 0x74, 0x62, 0x6f
    .byte 0x75, 0x6e, 0x64, 0x20, 0x73, 0x70, 0x61, 0x63, 0x65, 0x0a, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65
    .byte 0x64, 0x20, 0x74, 0x6f, 0x20, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x65, 0x20, 0x64, 0x65
    .byte 0x73, 0x63, 0x20, 0x73, 0x70, 0x61, 0x63, 0x65, 0x5b, 0x25, 0x64, 0x5d, 0x0a, 0x00, 0x66, 0x61
    .byte 0x69, 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f, 0x20, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x65
    .byte 0x20, 0x63, 0x74, 0x72, 0x6c, 0x20, 0x73, 0x70, 0x61, 0x63, 0x65, 0x5b, 0x25, 0x64, 0x5d, 0x0a
    .byte 0x00, 0x50, 0x45, 0x45, 0x52, 0x5f, 0x44, 0x45, 0x53, 0x43, 0x5b, 0x25, 0x64, 0x5d, 0x3a, 0x20
    .byte 0x25, 0x6c, 0x6c, 0x78, 0x00, 0x50, 0x45, 0x45, 0x52, 0x5f, 0x45, 0x4c, 0x42, 0x49, 0x5b, 0x25
    .byte 0x64, 0x5d, 0x3a, 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20
    .byte 0x74, 0x6f, 0x20, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x61, 0x74, 0x65, 0x20, 0x74, 0x78, 0x5f, 0x64
    .byte 0x6d, 0x61, 0x5f, 0x64, 0x65, 0x73, 0x63, 0x73, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x63, 0x68, 0x25
    .byte 0x75, 0x0a, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f, 0x20, 0x61, 0x6c, 0x6c
    .byte 0x6f, 0x63, 0x61, 0x74, 0x65, 0x20, 0x72, 0x78, 0x5f, 0x64, 0x6d, 0x61, 0x5f, 0x64, 0x65, 0x73
    .byte 0x63, 0x73, 0x0a, 0x00, 0x45, 0x4c, 0x42, 0x49, 0x5b, 0x44, 0x45, 0x53, 0x43, 0x5f, 0x4f, 0x46
    .byte 0x46, 0x53, 0x45, 0x54, 0x5d, 0x20, 0x77, 0x72, 0x69, 0x74, 0x65, 0x20, 0x30, 0x78, 0x25, 0x78
    .byte 0x3b, 0x20, 0x72, 0x65, 0x61, 0x64, 0x62, 0x61, 0x63, 0x6b, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x0a
    .byte 0x00, 0x6d, 0x69, 0x6f, 0x70, 0x2d, 0x70, 0x63, 0x69, 0x65, 0x00, 0x66, 0x61, 0x69, 0x6c, 0x65
    .byte 0x64, 0x20, 0x74, 0x6f, 0x20, 0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x20, 0x50, 0x43, 0x49
    .byte 0x65, 0x20, 0x73, 0x75, 0x62, 0x73, 0x79, 0x73, 0x74, 0x65, 0x6d, 0x20, 0x49, 0x52, 0x51, 0x0a
    .byte 0x00, 0x6d, 0x69, 0x6f, 0x70, 0x2d, 0x70, 0x63, 0x69, 0x65, 0x20, 0x69, 0x72, 0x71, 0x3d, 0x25
    .byte 0x64, 0x20, 0x64, 0x65, 0x73, 0x69, 0x72, 0x65, 0x64, 0x20, 0x61, 0x66, 0x66, 0x69, 0x6e, 0x69
    .byte 0x74, 0x79, 0x3d, 0x25, 0x2a, 0x70, 0x62, 0x20, 0x28, 0x62, 0x69, 0x6e, 0x64, 0x20, 0x66, 0x72
    .byte 0x6f, 0x6d, 0x20, 0x75, 0x73, 0x65, 0x72, 0x73, 0x70, 0x61, 0x63, 0x65, 0x29, 0x0a, 0x00, 0x6d
    .byte 0x69, 0x6f, 0x70, 0x2d, 0x70, 0x63, 0x69, 0x65, 0x20, 0x69, 0x72, 0x71, 0x20, 0x61, 0x66, 0x66
    .byte 0x69, 0x6e, 0x69, 0x74, 0x79, 0x20, 0x6d, 0x61, 0x73, 0x6b, 0x20, 0x65, 0x6d, 0x70, 0x74, 0x79
    .byte 0x2c, 0x20, 0x73, 0x6b, 0x69, 0x70, 0x20, 0x61, 0x75, 0x74, 0x6f, 0x20, 0x62, 0x69, 0x6e, 0x64
    .byte 0x69, 0x6e, 0x67, 0x0a, 0x00, 0x50, 0x43, 0x49, 0x65, 0x20, 0x4c, 0x69, 0x6e, 0x6b, 0x20, 0x75
    .byte 0x70, 0x2c, 0x20, 0x4c, 0x54, 0x53, 0x53, 0x4d, 0x20, 0x69, 0x73, 0x20, 0x30, 0x78, 0x25, 0x78
    .byte 0x0a, 0x00, 0x50, 0x43, 0x49, 0x65, 0x20, 0x4c, 0x69, 0x6e, 0x6b, 0x69, 0x6e, 0x67, 0x2e, 0x2e
    .byte 0x2e, 0x25, 0x64, 0x2c, 0x20, 0x4c, 0x54, 0x53, 0x53, 0x4d, 0x20, 0x69, 0x73, 0x20, 0x30, 0x78
    .byte 0x25, 0x78, 0x0a, 0x00, 0x50, 0x43, 0x49, 0x65, 0x20, 0x4c, 0x69, 0x6e, 0x6b, 0x20, 0x46, 0x61
    .byte 0x69, 0x6c, 0x0a, 0x00, 0x26, 0x70, 0x72, 0x69, 0x76, 0x2d, 0x3e, 0x74, 0x78, 0x5f, 0x64, 0x6d
    .byte 0x61, 0x5b, 0x72, 0x65, 0x74, 0x72, 0x69, 0x65, 0x73, 0x5d, 0x2e, 0x6c, 0x6f, 0x63, 0x6b, 0x00
    .byte 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x74, 0x78, 0x5f, 0x72, 0x65, 0x61, 0x70, 0x00, 0x66, 0x61, 0x69
    .byte 0x6c, 0x65, 0x64, 0x20, 0x74, 0x6f, 0x20, 0x63, 0x72, 0x65, 0x61, 0x74, 0x65, 0x20, 0x74, 0x78
    .byte 0x20, 0x72, 0x65, 0x61, 0x70, 0x20, 0x6b, 0x74, 0x68, 0x72, 0x65, 0x61, 0x64, 0x3a, 0x20, 0x25
    .byte 0x64, 0x0a, 0x00

.section .rodata
.align 3
.global _rodata
_rodata:
    .byte 0x10, 0x1b, 0xca, 0x0a, 0xa3, 0x19, 0x0d, 0x00, 0x56, 0xa3, 0x72, 0xd7, 0x70, 0x61, 0x75, 0x3b
    .byte 0x9e, 0x49, 0xf3, 0x36, 0x44, 0x40, 0x3b, 0xa5, 0x7c, 0xc6, 0x6b, 0x2d, 0x40, 0x58, 0x83, 0x6f
    .byte 0x83, 0x7d, 0x68, 0x66, 0x72, 0xa9, 0x6f, 0x83, 0x7d, 0x7f, 0x79, 0x6d, 0xaf, 0x78, 0x83, 0x7c
    .byte 0x75, 0x79, 0x6f, 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x64, 0x6d, 0x61, 0x5f, 0x74, 0x72, 0x79, 0x5f
    .byte 0x72, 0x65, 0x61, 0x70, 0x00, 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x64, 0x6d, 0x61, 0x5f, 0x6c, 0x69
    .byte 0x73, 0x74, 0x5f, 0x63, 0x6f, 0x6d, 0x6d, 0x69, 0x74, 0x5f, 0x70, 0x65, 0x6e, 0x64, 0x69, 0x6e
    .byte 0x67, 0x00, 0x87, 0x63, 0xdb, 0x6d, 0x64, 0x7c, 0x7e, 0xea, 0x5e, 0xe0, 0x49, 0x22, 0x59, 0x4b
    .byte 0xea, 0x65, 0xd5, 0x7c, 0x7f, 0x30, 0x4b, 0x89, 0x43, 0xc6, 0x39, 0x69, 0x75, 0x6d, 0xa3, 0x69
    .byte 0xc6, 0x39, 0x69, 0x62, 0x72, 0xbc, 0x6f, 0xd1, 0x39, 0x64, 0x7e, 0x72, 0xbe, 0x63, 0xc2, 0x75
    .byte 0x64, 0x6a, 0x72, 0xa4, 0x6d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x80, 0x00
    .byte 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x80, 0x01, 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x70, 0x63, 0x69
    .byte 0x65, 0x5f, 0x65, 0x70, 0x5f, 0x69, 0x6e, 0x69, 0x74, 0x00

.section .rodata
.align 3
driver_name_str:
    .asciz "pcie-ep-rk35"

.section .data
.align 3
.global _data
_data:
    // Offset 0x00 to 0x6F: Struct prefix and mutexes
    .byte 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde
    .byte 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    .byte 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    // Offset 0x70 to 0xDF: struct pci_epc_ops (14 Hardware Function Pointers)
    .quad miop_pcie_ep_init
    .quad miop_pcie_ep_deinit
    .quad miop_ep_machine_id
    .quad miop_elbi_enable_irq
    .quad miop_elbi_disable_irq
    .quad miop_raise_peer_irq
    .quad miop_dma_list_is_full
    .quad miop_dma_list_commit_pending
    .quad miop_rk35_map_peer_bar
    .quad miop_rk35_unmap_peer_bar
    .quad miop_rk35_map_rc_staging
    .quad miop_rk35_unmap_rc_staging
    .quad miop_rk35_dma_submit
    .quad miop_rk35_dma_submit_batch

    // Native State Variables and Bitmasks
    .byte 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .bss
.align 3
.global _bss
_bss:
