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

.global netif_tx_start_all_queues
.type netif_tx_start_all_queues, @function
netif_tx_start_all_queues:
    mov      w2, #0x0
    mov      w4, #0x140
    mov      x3, #0x1
    paciasp  
.Lnetif_tx_start_all_queues_30:
    ldr      w1, [x0, #968]
    cmp      w1, w2
    b.hi     .Lnetif_tx_start_all_queues_44
    autiasp  
    ret      
.Lnetif_tx_start_all_queues_44:
    ldr      x1, [x0, #960]
    umaddl   x1, w2, w4, x1
    add      x1, x1, #0xa8
    prfm     pstl1strm, [x1]
.Lnetif_tx_start_all_queues_54:
    ldxr     x5, [x1]
    bic      x5, x5, x3
    stxr     w6, x5, [x1]
    cbnz     w6, .Lnetif_tx_start_all_queues_54
    add      w2, w2, #0x1
    b        .Lnetif_tx_start_all_queues_30

.global miop_peer_rxq_read_cons
.type miop_peer_rxq_read_cons, @function
miop_peer_rxq_read_cons:
    nop      
    nop      
    ldr      x1, [x0, #896]
    cbz      x1, .Lmiop_peer_rxq_read_cons_b4
    ldrb     w2, [x0, #872]
    tbz      w2, #0, .Lmiop_peer_rxq_read_cons_94
    ldr      x0, [x0, #880]
    cbz      x0, .Lmiop_peer_rxq_read_cons_b4
    ldr      w0, [x0, #56]
    ret      
.Lmiop_peer_rxq_read_cons_94:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    add      x0, x1, #0x24
    mov      x29, sp
    bl       readl
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.Lmiop_peer_rxq_read_cons_b4:
    mov      w0, #0x0
    ret      

.global miop_stat_add_ns
.type miop_stat_add_ns, @function
miop_stat_add_ns:
    ldr      x3, [x0]
    paciasp  
    add      x3, x3, x2
    str      x3, [x0]
    ldr      x0, [x1]
    cmp      x0, x2
    b.cs     .Lmiop_stat_add_ns_dc
    str      x2, [x1]
.Lmiop_stat_add_ns_dc:
    autiasp  
    ret      

.global miop_new_tx_active_entries
.type miop_new_tx_active_entries, @function
miop_new_tx_active_entries:
    nop      
    nop      
    mov      x2, x0
    ldrb     w0, [x0, #976]
    paciasp  
    tbz      w0, #0, .Lmiop_new_tx_active_entries_11c
    ldrh     w1, [x2, #984]
    and      w0, w1, #0xffff
.Lmiop_new_tx_active_entries_104:
    ldrb     w1, [x2, #1528]
    tbz      w1, #0, .Lmiop_new_tx_active_entries_114
    ldrh     w1, [x2, #1536]
    add      w0, w0, w1, uxth
.Lmiop_new_tx_active_entries_114:
    autiasp  
    ret      
.Lmiop_new_tx_active_entries_11c:
    mov      w0, #0x0
    b        .Lmiop_new_tx_active_entries_104

.global miop_on_rx_full
.type miop_on_rx_full, @function
miop_on_rx_full:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x2, #0xae8
    mov      x29, sp
    str      x19, [sp, #16]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #336]
    mov      w0, w1
    madd     x0, x0, x2, x19
    ldr      x3, [x0, #1032]
    cbz      x3, .Lmiop_on_rx_full_188
    ldr      x3, [x0, #1040]
    cbz      x3, .Lmiop_on_rx_full_188
    mov      w3, #0x1
    strb     w3, [x0, #1060]
    mov      x0, #0xd0
    umaddl   x1, w1, w2, x0
    add      x19, x19, x1
    mov      x0, x19
    bl       napi_schedule_prep
    tbz      w0, #0, .Lmiop_on_rx_full_188
    mov      x0, x19
    bl       __napi_schedule
.Lmiop_on_rx_full_188:
    ldr      x19, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global miop_ndo_stop
.type miop_ndo_stop, @function
miop_ndo_stop:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    str      x19, [sp, #16]
    mov      x19, x0
    bl       netif_carrier_off
    mov      x0, x19
    bl       netif_tx_stop_all_queues
    ldr      x19, [sp, #16]
    mov      w0, #0x0
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global miop_wait_tx_work_idle
.type miop_wait_tx_work_idle, @function
miop_wait_tx_work_idle:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    str      x19, [sp, #16]
    mov      x19, x0
.Lmiop_wait_tx_work_idle_1f0:
    ldr      x0, [x19, #2072]
    tbnz     w0, #0, .Lmiop_wait_tx_work_idle_210
    ldrb     w0, [x19, #2104]
    tbnz     w0, #0, .Lmiop_wait_tx_work_idle_210
    ldr      x19, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_wait_tx_work_idle_210:
    mov      w0, #0x1
    bl       msleep
    b        .Lmiop_wait_tx_work_idle_1f0

.global miop_ndo_change_mtu
.type miop_ndo_change_mtu, @function
miop_ndo_change_mtu:
    nop      
    nop      
    mov      w2, #0xfeb0
    cmp      w1, w2
    b.eq     .Lmiop_ndo_change_mtu_260
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      w3, w1
    mov      x29, sp
    ldr      x0, [x0, #1416]
    adrp     x1, _rodata_str1_1+0x6
    add      x1, x1, :lo12:_rodata_str1_1+0x6
    bl       _dev_err
    mov      w0, #0xffffffea
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.Lmiop_ndo_change_mtu_260:
    mov      w0, #0x0
    ret      

.global miop_new_tx_batch_reset
.type miop_new_tx_batch_reset, @function
miop_new_tx_batch_reset:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x2, #0x228
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    mov      w1, #0x0
    str      x21, [sp, #32]
    ldr      x21, [x0]
    ldrb     w20, [x0, #11]
    bl       memset
    str      x21, [x19]
    strb     w20, [x19, #11]
    ldp      x19, x20, [sp, #16]
    ldr      x21, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      

.global miop_now_ns
.type miop_now_ns, @function
miop_now_ns:
    paciasp  
    sub      sp, sp, #0x30
    mrs      x0, sp_el0
    stp      x29, x30, [sp, #32]
    add      x29, sp, #0x20
    ldr      x1, [x0, #1336]
    str      x1, [sp, #24]
    mov      x1, #0x0
    add      x0, sp, #0x8
    bl       ktime_get_raw_ts64
    ldp      x0, x1, [sp, #8]
    mov      x2, #0xca00
    movk     x2, #0x3b9a, lsl #16
    madd     x0, x0, x2, x1
    mrs      x1, sp_el0
    ldr      x3, [sp, #24]
    ldr      x2, [x1, #1336]
    subs     x3, x3, x2
    mov      x2, #0x0
    b.eq     .Lmiop_now_ns_30c
    bl       __stack_chk_fail
.Lmiop_now_ns_30c:
    ldp      x29, x30, [sp, #32]
    add      sp, sp, #0x30
    autiasp  
    ret      

.global miop_ep_poll
.type miop_ep_poll, @function
miop_ep_poll:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-176]!
    mov      x29, sp
    stp      x25, x26, [sp, #64]
    sub      x25, x0, #0x8
    stp      x19, x20, [sp, #16]
    mov      x19, x0
    stp      x21, x22, [sp, #32]
    stp      x23, x24, [sp, #48]
    stp      x27, x28, [sp, #80]
    ldr      x0, [x25, #832]
    str      x0, [sp, #112]
    str      w1, [sp, #148]
    cbz      x0, .Lmiop_ep_poll_908
    ldr      x0, [x25, #840]
    str      x0, [sp, #96]
    cbz      x0, .Lmiop_ep_poll_908
    ldr      w0, [x25, #816]
    mov      w1, #0xae8
    mov      x2, #0xffffffffffffff30
    umsubl   x0, w0, w1, x2
    add      x20, x19, x0
    ldr      x24, [x19, x0]
    ldr      x0, [x20, #8]
    ldr      x22, [x20, #48]
    ldr      x0, [x0, #8]
    str      x0, [sp, #104]
    bl       miop_now_ns
    str      x0, [sp, #152]
    ldr      w0, [x25, #824]
    str      w0, [sp, #120]
    ldr      w0, [x25, #856]
    str      w0, [sp, #124]
    ldr      x0, [x25, #2616]
    ldr      w1, [x20, #112]
    add      x0, x0, #0x1
    str      x0, [x25, #2616]
    ldr      x0, [sp, #112]
    ldr      w0, [x0, #32]
    str      w0, [sp, #144]
    ldr      w0, [sp, #124]
    ldr      w2, [sp, #144]
    cmp      w0, w2
    b.ne     .Lmiop_ep_poll_438
    ldrb     w0, [x25, #860]
    tbz      w0, #0, .Lmiop_ep_poll_3f8
    ldr      x0, [sp, #104]
    strb     wzr, [x25, #860]
    ldr      w1, [x25, #816]
    mov      w2, #0x1
    ldr      x3, [x0, #40]
    mov      x0, x24
    blr      x3
.Lmiop_ep_poll_3f8:
    bl       miop_now_ns
    ldr      x1, [sp, #152]
    sub      x2, x0, x1
    add      x1, x19, #0xa60
    add      x0, x19, #0xa58
    bl       miop_stat_add_ns
    mov      w1, #0x0
    mov      x0, x19
    bl       napi_complete_done
    ldr      x0, [sp, #104]
    mov      w1, #0x0
    ldr      x2, [x0, #24]
    mov      x0, x24
    blr      x2
.Lmiop_ep_poll_430:
    mov      w0, #0x0
    b        .Lmiop_ep_poll_6a8
.Lmiop_ep_poll_438:
    dmb      oshld
    cmp      w1, #0x1
    b.eq     .Lmiop_ep_poll_6e0
    add      x0, x19, #0xa78
    mov      w21, #0x0
    str      x0, [sp, #160]
.Lmiop_ep_poll_450:
    ldr      w0, [sp, #124]
    add      w27, w0, w21
    ldr      w0, [sp, #144]
    cmp      w0, w27
    ldr      w0, [sp, #148]
    ccmp     w21, w0, #0x2, ne
    b.cs     .Lmiop_ep_poll_62c
    ldr      w0, [sp, #120]
    mov      w3, #0x2
    ldr      w1, [sp, #120]
    mov      x2, #0x40
    udiv     w0, w27, w0
    msub     w26, w0, w1, w27
    ldr      x0, [x25, #848]
    lsl      w28, w26, #16
    add      x0, x28, x0
    str      x0, [sp, #128]
    ldr      x0, [sp, #96]
    ldr      x1, [sp, #128]
    add      x0, x0, x28
    str      x0, [sp, #136]
    mov      x0, x24
    bl       dma_sync_single_for_cpu
    ldr      x0, [sp, #96]
    ldr      w23, [x0, x28]
    ldr      x0, [sp, #136]
    ldrh     w0, [x0, #4]
    and      w0, w0, #0xffff
    cbnz     w23, .Lmiop_ep_poll_6f0
.Lmiop_ep_poll_4c4:
    ldr      x0, [x25, #2632]
    add      x0, x0, #0x1
    str      x0, [x25, #2632]
.Lmiop_ep_poll_4d0:
    cbnz     w21, .Lmiop_ep_poll_630
    b        .Lmiop_ep_poll_66c
.Lmiop_ep_poll_4d8:
    tbz      w0, #0, .Lmiop_ep_poll_5ec
    mov      w0, #0xffc0
    cmp      w4, w0
    b.ls     .Lmiop_ep_poll_6c8
    adrp     x1, _rodata
    adrp     x0, _data
    add      x1, x1, :lo12:_rodata
    add      x0, x0, :lo12:_data
    add      x1, x1, #0x8
    add      x0, x0, #0x38
    str      w4, [sp, #168]
    bl       ___ratelimit
    ldr      w4, [sp, #168]
    cbz      w0, .Lmiop_ep_poll_528
    ldr      w2, [x25, #816]
    adrp     x1, _rodata_str1_1+0x27
    ldr      w3, [sp, #128]
    add      x1, x1, :lo12:_rodata_str1_1+0x27
    mov      x0, x24
    bl       _dev_err
.Lmiop_ep_poll_528:
    ldr      x0, [x22, #336]
    add      x0, x0, #0x1
    str      x0, [x22, #336]
    ldr      x0, [x22, #352]
    add      x0, x0, #0x1
    str      x0, [x22, #352]
    ldr      x0, [x25, #2648]
    add      x0, x0, #0x1
    str      x0, [x25, #2648]
.Lmiop_ep_poll_54c:
    ldr      x0, [sp, #96]
    add      w21, w21, #0x1
    ldr      x1, [sp, #136]
    mov      w3, #0x2
    str      wzr, [x0, x26]
    mov      x2, #0x40
    ldr      x0, [sp, #160]
    strh     wzr, [x0, #4]
    mov      x0, x24
    bl       dma_sync_single_for_device
.Lmiop_ep_poll_574:
    ldr      w0, [sp, #124]
    add      w27, w0, w21
    ldr      w0, [sp, #144]
    cmp      w0, w27
    ldr      w0, [sp, #148]
    ccmp     w21, w0, #0x2, ne
    b.cs     .Lmiop_ep_poll_5f8
    ldr      w0, [sp, #120]
    mov      w3, #0x2
    ldr      w1, [sp, #120]
    mov      x2, #0x40
    udiv     w0, w27, w0
    msub     w0, w0, w1, w27
    str      w0, [sp, #128]
    lsl      w26, w0, #16
    ldr      x0, [x25, #848]
    add      x0, x26, x0
    str      x0, [sp, #136]
    ldr      x0, [sp, #96]
    ldr      x1, [sp, #136]
    add      x0, x0, x26
    str      x0, [sp, #160]
    mov      x0, x24
    bl       dma_sync_single_for_cpu
    ldr      x0, [sp, #96]
    ldr      w4, [x0, x26]
    ldr      x0, [sp, #160]
    ldrh     w0, [x0, #4]
    and      w0, w0, #0xffff
    cbnz     w4, .Lmiop_ep_poll_4d8
.Lmiop_ep_poll_5ec:
    ldr      x0, [x25, #2632]
    add      x0, x0, #0x1
    str      x0, [x25, #2632]
.Lmiop_ep_poll_5f8:
    cbz      w23, .Lmiop_ep_poll_62c
    add      x2, x20, #0xa8
    prfm     pstl1strm, [x2]
.Lmiop_ep_poll_604:
    ldxr     x0, [x2]
    add      x0, x0, x23
    stxr     w1, x0, [x2]
    cbnz     w1, .Lmiop_ep_poll_604
    add      x2, x20, #0xb0
    prfm     pstl1strm, [x2]
.Lmiop_ep_poll_61c:
    ldxr     x0, [x2]
    add      x0, x0, x28
    stxr     w1, x0, [x2]
    cbnz     w1, .Lmiop_ep_poll_61c
.Lmiop_ep_poll_62c:
    cbz      w21, .Lmiop_ep_poll_660
.Lmiop_ep_poll_630:
    ldr      x0, [sp, #112]
    str      w27, [x25, #856]
    str      w27, [x0, #36]
    ldrb     w0, [x25, #860]
    tbz      w0, #0, .Lmiop_ep_poll_660
    ldr      x0, [sp, #104]
    strb     wzr, [x25, #860]
    ldr      w1, [x25, #816]
    mov      w2, #0x1
    ldr      x3, [x0, #40]
    mov      x0, x24
    blr      x3
.Lmiop_ep_poll_660:
    ldr      w0, [sp, #148]
    cmp      w21, w0
    b.cs     .Lmiop_ep_poll_68c
.Lmiop_ep_poll_66c:
    mov      w1, w21
    mov      x0, x19
    bl       napi_complete_done
    ldr      x0, [sp, #104]
    mov      w1, #0x0
    ldr      x2, [x0, #24]
    mov      x0, x24
    blr      x2
.Lmiop_ep_poll_68c:
    bl       miop_now_ns
    ldr      x1, [sp, #152]
    sub      x2, x0, x1
    add      x0, x19, #0xa58
    add      x1, x19, #0xa60
    bl       miop_stat_add_ns
    mov      w0, w21
.Lmiop_ep_poll_6a8:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #176
    autiasp  
    ret      
.Lmiop_ep_poll_6c8:
    ldr      x0, [x25, #2624]
    add      w23, w23, #0x1
    add      x28, x28, w4, uxtw
    add      x0, x0, #0x1
    str      x0, [x25, #2624]
    b        .Lmiop_ep_poll_54c
.Lmiop_ep_poll_6e0:
    mov      x28, #0x0
    mov      x23, #0x0
    mov      w21, #0x0
    b        .Lmiop_ep_poll_574
.Lmiop_ep_poll_6f0:
    tbz      w0, #0, .Lmiop_ep_poll_4c4
    mov      w0, #0xffc0
    cmp      w23, w0
    b.ls     .Lmiop_ep_poll_78c
    adrp     x1, _rodata
    adrp     x0, _data
    add      x1, x1, :lo12:_rodata
    add      x0, x0, :lo12:_data
    add      x1, x1, #0x8
    add      x0, x0, #0x70
    bl       ___ratelimit
    cbz      w0, .Lmiop_ep_poll_73c
    ldr      w2, [x25, #816]
    adrp     x1, _rodata_str1_1+0x27
    mov      w4, w23
    mov      w3, w26
    add      x1, x1, :lo12:_rodata_str1_1+0x27
    mov      x0, x24
    bl       _dev_err
.Lmiop_ep_poll_73c:
    ldr      x0, [x22, #336]
    add      x0, x0, #0x1
    str      x0, [x22, #336]
    ldr      x0, [x22, #352]
    add      x0, x0, #0x1
    str      x0, [x22, #352]
    ldr      x0, [x25, #2648]
    add      x0, x0, #0x1
    str      x0, [x25, #2648]
.Lmiop_ep_poll_760:
    ldr      x0, [sp, #96]
    add      w21, w21, #0x1
    ldr      x1, [sp, #128]
    mov      w3, #0x2
    str      wzr, [x0, x28]
    mov      x2, #0x40
    ldr      x0, [sp, #136]
    strh     wzr, [x0, #4]
    mov      x0, x24
    bl       dma_sync_single_for_device
    b        .Lmiop_ep_poll_450
.Lmiop_ep_poll_78c:
    dmb      oshld
    ldr      x1, [sp, #128]
    mov      x0, x24
    add      w2, w23, #0x40
    mov      w3, #0x2
    bl       dma_sync_single_for_cpu
    ldr      w0, [x20, #112]
    cmp      w0, #0x1
    b.ne     .Lmiop_ep_poll_7e8
    add      x2, x20, #0xa8
    prfm     pstl1strm, [x2]
.Lmiop_ep_poll_7b8:
    ldxr     x0, [x2]
    add      x0, x0, #0x1
    stxr     w1, x0, [x2]
    cbnz     w1, .Lmiop_ep_poll_7b8
    mov      w23, w23
    add      x2, x20, #0xb0
    prfm     pstl1strm, [x2]
.Lmiop_ep_poll_7d4:
    ldxr     x0, [x2]
    add      x0, x0, x23
    stxr     w1, x0, [x2]
    cbnz     w1, .Lmiop_ep_poll_7d4
    b        .Lmiop_ep_poll_760
.Lmiop_ep_poll_7e8:
    bl       miop_now_ns
    mov      x3, x0
    mov      w1, w23
    mov      w2, #0xa20
    mov      x0, x19
    str      x3, [sp, #168]
    bl       __napi_alloc_skb
    mov      x26, x0
    bl       miop_now_ns
    ldp      x1, x3, [sp, #160]
    sub      x2, x0, x3
    add      x0, x19, #0xa70
    bl       miop_stat_add_ns
    cbnz     x26, .Lmiop_ep_poll_83c
    ldr      x0, [x22, #352]
    add      x0, x0, #0x1
    str      x0, [x22, #352]
    ldr      x0, [x25, #2640]
    add      x0, x0, #0x1
    str      x0, [x25, #2640]
    b        .Lmiop_ep_poll_4d0
.Lmiop_ep_poll_83c:
    ldr      x0, [x25, #2672]
    add      x0, x0, #0x1
    str      x0, [x25, #2672]
    bl       miop_now_ns
    mov      x27, x0
    mov      w1, w23
    mov      x0, x26
    bl       skb_put
    mov      w23, w23
    ldr      x1, [sp, #136]
    mov      x2, x23
    add      x1, x1, #0x40
    bl       memcpy
    bl       miop_now_ns
    sub      x2, x0, x27
    add      x1, x19, #0xa98
    add      x0, x19, #0xa90
    bl       miop_stat_add_ns
    ldr      x0, [x25, #2696]
    mov      x1, x22
    add      x0, x0, #0x1
    str      x0, [x25, #2696]
    ldr      x0, [x25, #2704]
    add      x0, x0, x23
    str      x0, [x25, #2704]
    mov      x0, x26
    bl       eth_type_trans
    strh     w0, [x26, #180]
    bl       miop_now_ns
    mov      x27, x0
    mov      x1, x26
    mov      x0, x19
    bl       napi_gro_receive
    bl       miop_now_ns
    sub      x2, x0, x27
    add      x1, x19, #0xab0
    add      x0, x19, #0xaa8
    bl       miop_stat_add_ns
    ldr      x0, [x25, #2728]
    add      x0, x0, #0x1
    str      x0, [x25, #2728]
    ldr      x0, [x22, #304]
    add      x0, x0, #0x1
    str      x0, [x22, #304]
    ldr      x0, [x22, #320]
    add      x0, x0, x23
    str      x0, [x22, #320]
    ldr      x0, [x25, #2624]
    add      x0, x0, #0x1
    str      x0, [x25, #2624]
    b        .Lmiop_ep_poll_760
.Lmiop_ep_poll_908:
    mov      x0, x19
    mov      w1, #0x0
    bl       napi_complete_done
    b        .Lmiop_ep_poll_430

.global miop_ndo_open
.type miop_ndo_open, @function
miop_ndo_open:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    str      x19, [sp, #16]
    mov      x19, x0
    ldr      x1, [x0, #1416]
    cbz      x1, .Lmiop_ndo_open_944
    ldr      x1, [x1, #120]
    cbnz     x1, .Lmiop_ndo_open_968
.Lmiop_ndo_open_944:
    adrp     x1, _rodata_str1_1+0x4f
    mov      x0, x19
    add      x1, x1, :lo12:_rodata_str1_1+0x4f
.Lmiop_ndo_open_950:
    bl       netdev_err
.Lmiop_ndo_open_954:
    ldr      x19, [sp, #16]
    mov      w0, #0x0
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_ndo_open_968:
    ldr      x1, [x1, #336]
    cbnz     x1, .Lmiop_ndo_open_97c
    adrp     x1, _rodata_str1_1+0x81
    add      x1, x1, :lo12:_rodata_str1_1+0x81
    b        .Lmiop_ndo_open_950
.Lmiop_ndo_open_97c:
    ldrb     w1, [x1, #20]
    tbz      w1, #0, .Lmiop_ndo_open_954
    bl       netif_tx_start_all_queues
    mov      x0, x19
    bl       netif_carrier_on
    b        .Lmiop_ndo_open_954

.global netif_queue_stopped.isra.0
.type netif_queue_stopped.isra.0, @function
netif_queue_stopped.isra.0:
    ldr      x0, [x0, #168]
    paciasp  
    autiasp  
    and      w0, w0, #0x1
    ret      

.global miop_queue_tx_work
.type miop_queue_tx_work, @function
miop_queue_tx_work:
    nop      
    nop      
    ldr      w1, [x0, #816]
    mov      w2, #0xae8
    mov      x3, #0xffffffffffffff38
    umsubl   x1, w1, w2, x3
    add      x1, x0, x1
    ldrb     w1, [x1, #192]
    tbnz     w1, #0, .Lmiop_queue_tx_work_a1c
    adrp     x2, nr_cpu_ids
    paciasp  
    stp      x29, x30, [sp, #-16]!
    adrp     x1, system_wq
    mov      x29, sp
    ldr      w2, [x2, :lo12:nr_cpu_ids]
    ldr      x1, [x1, :lo12:system_wq]
    cmp      w2, #0x5
    add      x2, x0, #0x818
    b.ls     .Lmiop_queue_tx_work_a14
    adrp     x0, __cpu_online_mask
    ldr      x0, [x0, :lo12:__cpu_online_mask]
    tbz      w0, #5, .Lmiop_queue_tx_work_a14
    mov      w0, #0x5
.Lmiop_queue_tx_work_a04:
    bl       queue_work_on
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.Lmiop_queue_tx_work_a14:
    mov      w0, #0x8
    b        .Lmiop_queue_tx_work_a04
.Lmiop_queue_tx_work_a1c:
    ret      

.global miop_tx_coalesce_timer_handler
.type miop_tx_coalesce_timer_handler, @function
miop_tx_coalesce_timer_handler:
    nop      
    nop      
    mov      x1, x0
    sub      x0, x0, #0x840
    ldr      x2, [x0, #2424]
    add      x2, x2, #0x1
    str      x2, [x0, #2424]
    add      x2, x1, #0x28
    ldr      x1, [x1, #40]
    cmp      x1, x2
    b.eq     .Lmiop_tx_coalesce_timer_handler_a68
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      x29, sp
    bl       miop_queue_tx_work
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.Lmiop_tx_coalesce_timer_handler_a68:
    ret      

.global miop_xmit_done_cb_new
.type miop_xmit_done_cb_new, @function
miop_xmit_done_cb_new:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    ldr      x20, [x0]
    cbz      x20, .Lmiop_xmit_done_cb_new_a98
    mov      x19, x0
    ldrb     w0, [x0, #8]
    tbnz     w0, #0, .Lmiop_xmit_done_cb_new_aac
.Lmiop_xmit_done_cb_new_a98:
    brk      #0x800
.Lmiop_xmit_done_cb_new_a9c:
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_xmit_done_cb_new_aac:
    cmp      w1, #0x0
    cset     w0, ne
    strb     w0, [x19, #10]
    bl       miop_now_ns
    str      x0, [x19, #32]
    dmb      ishst
    mov      w0, #0x1
    strb     w0, [x19, #9]
    mov      x0, x20
    bl       miop_queue_tx_work
    b        .Lmiop_xmit_done_cb_new_a9c

.global miop_on_tx_ready
.type miop_on_tx_ready, @function
miop_on_tx_ready:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-64]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w19, w1
    stp      x21, x22, [sp, #32]
    mov      x22, x0
    mov      w21, #0xae8
    str      x23, [sp, #48]
    umull    x21, w19, w21
    ldr      x0, [x0, #120]
    ldr      x20, [x0, #336]
    ldr      x0, [x20, #48]
    ldr      x0, [x0, #960]
    bl       netif_queue_stopped.isra.0
    add      x1, x21, #0xc8
    mov      w2, #0x1
    add      x23, x20, x1
    str      w2, [x20, x1]
    mov      x1, #0xae8
    madd     x1, x19, x1, x20
    strb     wzr, [x1, #1154]
    tbz      w0, #0, .Lmiop_on_tx_ready_b68
    adrp     x2, __dyndbg
    add      x0, x2, :lo12:__dyndbg
    ldrb     w1, [x0, #35]
    tbz      w1, #0, .Lmiop_on_tx_ready_b5c
    adrp     x2, _rodata_str1_1+0x176
    mov      x1, x22
    add      x2, x2, :lo12:_rodata_str1_1+0x176
    bl       __dynamic_dev_dbg
.Lmiop_on_tx_ready_b5c:
    ldr      x0, [x20, #48]
    ldr      x0, [x0, #960]
    bl       netif_tx_wake_queue
.Lmiop_on_tx_ready_b68:
    mov      x1, #0xae8
    add      x0, x21, #0x930
    add      x0, x20, x0
    madd     x19, x19, x1, x20
    ldr      x1, [x19, #2352]
    cmp      x1, x0
    b.eq     .Lmiop_on_tx_ready_b98
    add      x0, x21, #0x908
    add      x0, x20, x0
    bl       del_timer_sync
    mov      x0, x23
    bl       miop_queue_tx_work
.Lmiop_on_tx_ready_b98:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldr      x23, [sp, #48]
    ldp      x29, x30, [sp], #64
    autiasp  
    ret      

.global miop_xmit_to_peer_new
.type miop_xmit_to_peer_new, @function
miop_xmit_to_peer_new:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x2
    mov      w2, #0xffc0
    str      x21, [sp, #32]
    ldr      w3, [x0, #112]
    cmp      w3, w2
    b.ls     .Lmiop_xmit_to_peer_new_bfc
    ldr      x2, [x1, #344]
    add      x2, x2, #0x1
    str      x2, [x1, #344]
    mov      w1, #0x1
    bl       __dev_kfree_skb_any
.Lmiop_xmit_to_peer_new_bf4:
    mov      w0, #0x0
    b        .Lmiop_xmit_to_peer_new_c3c
.Lmiop_xmit_to_peer_new_bfc:
    add      x21, x19, #0x868
    mov      x20, x0
    ldr      w0, [x21, #16]
    cmp      w0, #0xff
    b.ls     .Lmiop_xmit_to_peer_new_c50
    ldr      x0, [x1, #960]
    add      x0, x0, #0xa8
    prfm     pstl1strm, [x0]
.Lmiop_xmit_to_peer_new_c1c:
    ldxr     x1, [x0]
    orr      x1, x1, #0x1
    stxr     w2, x1, [x0]
    cbnz     w2, .Lmiop_xmit_to_peer_new_c1c
    ldr      x0, [x19, #2256]
    add      x0, x0, #0x1
    str      x0, [x19, #2256]
    mov      w0, #0x10
.Lmiop_xmit_to_peer_new_c3c:
    ldp      x19, x20, [sp, #16]
    ldr      x21, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      
.Lmiop_xmit_to_peer_new_c50:
    mov      x1, x20
    mov      x0, x21
    bl       skb_queue_tail
    bl       miop_now_ns
    str      x0, [x20, #40]
    ldr      x0, [x19, #2248]
    ldr      x2, [x19, #2264]
    add      x0, x0, #0x1
    str      x0, [x19, #2248]
    ldr      w0, [x21, #16]
    mov      w1, w0
    cmp      x2, w0, uxtw
    b.cs     .Lmiop_xmit_to_peer_new_c94
    str      x1, [x19, #2264]
.Lmiop_xmit_to_peer_new_c88:
    mov      x0, x19
    bl       miop_queue_tx_work
    b        .Lmiop_xmit_to_peer_new_bf4
.Lmiop_xmit_to_peer_new_c94:
    cbz      w0, .Lmiop_xmit_to_peer_new_bf4
    b        .Lmiop_xmit_to_peer_new_c88

.global miop_new_arch_work_fn
.type miop_new_arch_work_fn, @function
miop_new_arch_work_fn:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x90
    stp      x29, x30, [sp, #16]
    add      x29, sp, #0x10
    stp      x19, x20, [sp, #32]
    sub      x19, x0, #0xac0
    stp      x21, x22, [sp, #48]
    mov      x22, x0
    mov      x0, #0xffffffffffffff38
    stp      x23, x24, [sp, #64]
    stp      x25, x26, [sp, #80]
    mov      w26, #0xae8
    stp      x27, x28, [sp, #96]
    ldr      w21, [x19, #816]
    umsubl   x26, w21, w26, x0
    mov      w0, #0x1
    strb     w0, [x22, #32]
    add      x25, x19, x26
    ldrb     w1, [x22, #33]
    ldr      x20, [x19, x26]
    ldr      x0, [x25, #8]
    tbz      w1, #0, .Lmiop_new_arch_work_fn_12fc
    ldr      x5, [x25, #40]
    ldr      x1, [x0, #8]
    str      x1, [sp, #120]
    ldr      x1, [x0, #328]
    cbz      x5, .Lmiop_new_arch_work_fn_e44
    mov      w6, w21
    add      x2, x5, x6, lsl #6
    ldr      w0, [x2, #72]
    and      w24, w0, #0x1
    tbz      w0, #0, .Lmiop_new_arch_work_fn_e44
    ldr      w28, [x2, #68]
    ldr      x2, [x2, #80]
    cmp      w21, w28
    b.eq     .Lmiop_new_arch_work_fn_da8
    mov      w23, #0xffffffea
    mov      w4, w21
    mov      w3, w28
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x185
    add      x1, x1, :lo12:_rodata_str1_1+0x185
    bl       _dev_warn
.Lmiop_new_arch_work_fn_d54:
    add      w1, w23, #0x1c
    mov      x0, #0x200
    movk     x0, #0x1000, lsl #16
    lsr      x0, x0, x1
    tbnz     w0, #0, .Lmiop_new_arch_work_fn_d80
    ldr      x0, [x19, x26]
    adrp     x1, _rodata_str1_1+0x432
    mov      w3, w23
    mov      w2, w21
    add      x1, x1, :lo12:_rodata_str1_1+0x432
    bl       _dev_warn
.Lmiop_new_arch_work_fn_d80:
    strb     wzr, [x22, #32]
    ldp      x29, x30, [sp, #16]
    ldp      x19, x20, [sp, #32]
    ldp      x21, x22, [sp, #48]
    ldp      x23, x24, [sp, #64]
    ldp      x25, x26, [sp, #80]
    ldp      x27, x28, [sp, #96]
    add      sp, sp, #0x90
    autiasp  
    ret      
.Lmiop_new_arch_work_fn_da8:
    and      w7, w0, #0x2
    tbnz     w0, #1, .Lmiop_new_arch_work_fn_ddc
    ldr      w3, [x25, #16]
    mov      w23, w24
    mov      w0, #0x0
.Lmiop_new_arch_work_fn_dbc:
    cmp      w3, w0
    b.eq     .Lmiop_new_arch_work_fn_dd0
    cmp      w21, w0
    b.eq     .Lmiop_new_arch_work_fn_de8
    add      w23, w23, #0x1
.Lmiop_new_arch_work_fn_dd0:
    add      w0, w0, #0x1
    cmp      w0, #0x4
    b.ne     .Lmiop_new_arch_work_fn_dbc
.Lmiop_new_arch_work_fn_ddc:
    mov      w23, #0x0
    mov      w0, #0x40
    b        .Lmiop_new_arch_work_fn_df8
.Lmiop_new_arch_work_fn_de8:
    cmp      w23, #0x0
    mov      w0, #0x40
    mov      w3, #0x80
    csel     w0, w0, w3, eq
.Lmiop_new_arch_work_fn_df8:
    str      w23, [x19, #820]
    str      w0, [x19, #824]
    mov      w0, w23
    add      x3, x0, #0x20
    ldr      x4, [x25, #40]
    add      x1, x1, x0, lsl #3
    add      x3, x4, x3, lsl #7
    str      x3, [x19, #832]
    ldr      x3, [x1, #632]
    str      x3, [x19, #840]
    ldr      x1, [x1, #664]
    str      x1, [x19, #848]
    cbnz     x3, .Lmiop_new_arch_work_fn_e4c
    adrp     x1, _rodata_str1_1+0x1b9
    mov      w3, w23
    mov      w2, w21
    add      x1, x1, :lo12:_rodata_str1_1+0x1b9
    mov      x0, x20
    bl       _dev_err
.Lmiop_new_arch_work_fn_e44:
    mov      w23, #0xffffffed
    b        .Lmiop_new_arch_work_fn_d54
.Lmiop_new_arch_work_fn_e4c:
    add      x0, x4, x0, lsl #7
    str      wzr, [x19, #856]
    strb     wzr, [x19, #860]
    str      w21, [x0, #4112]
    ldr      x0, [x19, #832]
    str      wzr, [x0, #32]
    ldr      x0, [x19, #832]
    str      wzr, [x0, #36]
    ldr      x0, [x19, #832]
    str      wzr, [x0, #40]
    ldr      x0, [x19, #832]
    str      wzr, [x0, #44]
    dsb      st
    cmp      w7, #0x0
    cset     w0, ne
    strb     w0, [x19, #872]
    b.eq     .Lmiop_new_arch_work_fn_fb8
    add      x0, x5, x6, lsl #6
    mov      w1, #0x3fffff
    ldr      x3, [x0, #104]
    ldr      w4, [x0, #112]
    cmp      x3, #0x0
    ccmp     w4, w1, #0x0, ne
    b.hi     .Lmiop_new_arch_work_fn_ed4
    mov      w23, #0xffffffea
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x1e1
    add      x1, x1, :lo12:_rodata_str1_1+0x1e1
    bl       _dev_err
.Lmiop_new_arch_work_fn_ec4:
    str      xzr, [x19, #832]
    str      xzr, [x19, #840]
    str      xzr, [x19, #848]
    b        .Lmiop_new_arch_work_fn_d54
.Lmiop_new_arch_work_fn_ed4:
    add      x1, x6, #0x1
    mov      w2, #0x40
    str      xzr, [x19, #864]
    mov      w24, #0x0
    add      x1, x5, x1, lsl #6
    str      x1, [x19, #880]
    str      x3, [x19, #888]
    mov      x3, #0x0
    str      x1, [x19, #896]
    str      w2, [x19, #912]
    str      wzr, [x19, #916]
    str      wzr, [x0, #116]
    str      wzr, [x0, #120]
    str      wzr, [x0, #124]
    str      wzr, [x19, #920]
.Lmiop_new_arch_work_fn_f10:
    str      x3, [x19, #904]
    add      x3, x19, #0x3a4
    add      x4, x19, #0x3b8
    strh     wzr, [x19, #952]
    strb     wzr, [x19, #954]
    and      w0, w21, #0x1
    stp      wzr, wzr, [x3, #-8]
    mov      x2, #0x450
    stp      wzr, wzr, [x3]
    mov      w1, #0x0
    str      wzr, [x19, #940]
    sub      x28, x22, #0x228
    stp      wzr, wzr, [x4, #-8]
    stp      w0, wzr, [x4, #4]
    sub      x0, x22, #0x6f8
    str      x6, [sp, #128]
    bl       memset
    str      x19, [x19, #968]
    mov      w0, #0x1
    str      x19, [x19, #1520]
    strb     w0, [x19, #1531]
    ldr      w27, [x19, #912]
    ldr      x0, [x20, #120]
    stp      xzr, xzr, [x28]
    stp      xzr, xzr, [x28, #16]
    add      x2, x0, #0x18
    stp      xzr, xzr, [x28, #32]
    ldrb     w0, [x0, #124]
    ldr      x6, [sp, #128]
    tbnz     w0, #0, .Lmiop_new_arch_work_fn_10d0
    mov      w23, #0xffffffed
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x269
    add      x1, x1, :lo12:_rodata_str1_1+0x269
    bl       _dev_err
.Lmiop_new_arch_work_fn_f9c:
    mov      w3, w23
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x456
    add      x1, x1, :lo12:_rodata_str1_1+0x456
    bl       _dev_err
    b        .Lmiop_new_arch_work_fn_1090
.Lmiop_new_arch_work_fn_fb8:
    ldr      x0, [sp, #120]
    sub      x4, x22, #0x748
    mov      w1, w21
    mov      w3, #0x2000000
    str      x6, [sp, #128]
    ldr      x5, [x0, #64]
    mov      x0, x20
    blr      x5
    str      x0, [x19, #864]
    ldr      x6, [sp, #128]
    cbnz     x0, .Lmiop_new_arch_work_fn_1000
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x217
    mov      w23, #0xfffffffb
    add      x1, x1, :lo12:_rodata_str1_1+0x217
    bl       _dev_err
    b        .Lmiop_new_arch_work_fn_ec4
.Lmiop_new_arch_work_fn_1000:
    ldr      w2, [x25, #16]
    mov      w1, #0x0
.Lmiop_new_arch_work_fn_1008:
    cmp      w28, w1
    b.eq     .Lmiop_new_arch_work_fn_101c
    cmp      w2, w1
    b.eq     .Lmiop_new_arch_work_fn_102c
    add      w24, w24, #0x1
.Lmiop_new_arch_work_fn_101c:
    add      w1, w1, #0x1
    cmp      w1, #0x4
    b.ne     .Lmiop_new_arch_work_fn_1008
    mov      w24, #0x0
.Lmiop_new_arch_work_fn_102c:
    cmp      w24, #0x0
    mov      w2, #0x40
    mov      w1, #0x80
    csel     w1, w1, w2, ne
    str      w1, [x19, #912]
    ubfiz    x1, x24, #7, #32
    add      x1, x1, #0x1, lsl #12
    str      w24, [x19, #916]
    add      x0, x0, x1
    str      x0, [x19, #896]
    str      x6, [sp, #128]
    bl       readl
    mov      w3, w0
    str      w3, [x19, #920]
    sub      w1, w0, #0x1
    ldr      x6, [sp, #128]
    mov      w0, #0x1fffffe
    cmp      w1, w0
    b.ls     .Lmiop_new_arch_work_fn_10c4
    mov      w23, #0xffffffea
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x235
    add      x1, x1, :lo12:_rodata_str1_1+0x235
    bl       _dev_err
.Lmiop_new_arch_work_fn_1090:
    ldrb     w0, [x19, #872]
    tbnz     w0, #0, .Lmiop_new_arch_work_fn_10ac
    ldr      x0, [sp, #120]
    mov      w1, w21
    ldr      x2, [x0, #72]
    mov      x0, x20
    blr      x2
.Lmiop_new_arch_work_fn_10ac:
    add      x2, x19, #0x370
    str      xzr, [x19, #864]
    strb     wzr, [x19, #872]
    stp      xzr, xzr, [x2]
    stp      xzr, xzr, [x2, #16]
    b        .Lmiop_new_arch_work_fn_ec4
.Lmiop_new_arch_work_fn_10c4:
    ldr      x0, [x19, #864]
    add      x3, x0, w3, uxtw
    b        .Lmiop_new_arch_work_fn_f10
.Lmiop_new_arch_work_fn_10d0:
    sub      w0, w27, #0x1
    cmp      w0, #0x7f
    b.ls     .Lmiop_new_arch_work_fn_10f8
    mov      w2, w27
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x295
    mov      w23, #0xffffffea
    add      x1, x1, :lo12:_rodata_str1_1+0x295
    bl       _dev_err
    b        .Lmiop_new_arch_work_fn_f9c
.Lmiop_new_arch_work_fn_10f8:
    ldr      x5, [x2, #112]
    ubfiz    x25, x27, #16, #32
    lsl      x3, x6, #23
    add      x6, x25, x6, lsl #23
    mov      w0, w27
    cmp      x6, x5
    b.ls     .Lmiop_new_arch_work_fn_1134
    mov      x4, x25
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x2b8
    mov      w23, #0xffffffe4
    add      x1, x1, :lo12:_rodata_str1_1+0x2b8
    bl       _dev_err
    b        .Lmiop_new_arch_work_fn_f9c
.Lmiop_new_arch_work_fn_1134:
    lsl      x0, x0, #4
    mov      w1, #0xdc0
    stp      x3, x2, [sp, #128]
    bl       __kmalloc
    str      x0, [x28]
    cbz      x0, .Lmiop_new_arch_work_fn_1458
    ldp      x3, x2, [sp, #128]
    ldr      x0, [x2, #104]
    add      x3, x3, x0
    adrp     x0, memstart_addr
    ldr      x2, [x0, :lo12:memstart_addr]
    str      x3, [x28, #24]
    str      w25, [x28, #32]
    sub      x2, x3, x2
    orr      x1, x2, #0xffff000000000000
    str      x1, [x28, #8]
    mov      x0, x1
    stp      x1, x2, [sp, #128]
    bl       is_vmalloc_addr
    ldp      x1, x2, [sp, #128]
    tbz      w0, #0, .Lmiop_new_arch_work_fn_1208
    adrp     x0, _data_once
    ldrb     w1, [x0, :lo12:_data_once]
    tbz      w1, #0, .Lmiop_new_arch_work_fn_11d4
.Lmiop_new_arch_work_fn_1194:
    mov      x0, #0xffffffffffffffff
    str      x0, [x28, #16]
.Lmiop_new_arch_work_fn_119c:
    mov      x4, x25
    sub      x3, x22, #0x210
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x340
    add      x1, x1, :lo12:_rodata_str1_1+0x340
    bl       _dev_err
    mov      w23, #0xfffffffb
    ldr      x0, [x28]
    bl       kfree
    stp      xzr, xzr, [x28]
    stp      xzr, xzr, [x28, #16]
    stp      xzr, xzr, [x28, #32]
    b        .Lmiop_new_arch_work_fn_f9c
.Lmiop_new_arch_work_fn_11d4:
    mov      w1, #0x1
    strb     w1, [x0, :lo12:_data_once]
    mov      x0, x20
    bl       dev_driver_string
    mov      x1, x0
    ldr      x2, [x20, #80]
    cbnz     x2, .Lmiop_new_arch_work_fn_11f4
    ldr      x2, [x20]
.Lmiop_new_arch_work_fn_11f4:
    adrp     x0, _rodata_str1_1+0x314
    add      x0, x0, :lo12:_rodata_str1_1+0x314
    bl       __warn_printk
    brk      #0x800
    b        .Lmiop_new_arch_work_fn_1194
.Lmiop_new_arch_work_fn_1208:
    mov      x0, #0x1000000000000
    add      x1, x1, x0
    mov      x0, #0xfffffc0000000000
    mov      x3, x25
    lsr      x1, x1, #12
    and      x2, x2, #0xfff
    mov      x5, #0x0
    mov      w4, #0x1
    add      x1, x0, x1, lsl #6
    mov      x0, x20
    bl       dma_map_page_attrs
    str      x0, [x28, #16]
    cmn      x0, #0x1
    b.eq     .Lmiop_new_arch_work_fn_119c
    mov      x0, #0x0
    stp      w27, wzr, [x28, #36]
    str      wzr, [x28, #44]
.Lmiop_new_arch_work_fn_124c:
    ldp      x3, x1, [x28]
    lsl      x2, x0, #4
    add      x1, x1, x0, lsl #16
    str      x1, [x3, x2]
    ldr      x1, [x28]
    add      x1, x1, x2
    ldr      x2, [x28, #16]
    add      x2, x2, x0, lsl #16
    add      x0, x0, #0x1
    str      x2, [x1, #8]
    cmp      w27, w0
    b.hi     .Lmiop_new_arch_work_fn_124c
    ldr      x0, [x28, #8]
    mov      x2, x25
    mov      w1, #0x0
    bl       memset
    ldr      x1, [x28, #16]
    mov      x2, x25
    mov      x0, x20
    mov      w3, #0x1
    bl       dma_sync_single_for_device
    ldr      x5, [x28, #8]
    sub      x4, x22, #0x218
    ldp      w6, w7, [x28, #32]
    sub      x3, x22, #0x210
    mov      w2, w21
    mov      x0, x20
    adrp     x1, _rodata_str1_1+0x382
    add      x1, x1, :lo12:_rodata_str1_1+0x382
    bl       _dev_info
    sub      x0, x22, #0x748
    str      x0, [sp]
    mov      w3, w23
    mov      w5, w24
    ldr      x7, [x19, #864]
    mov      w2, w21
    ldr      w4, [x19, #824]
    mov      x0, x20
    ldr      w6, [x19, #912]
    adrp     x1, _rodata_str1_1+0x3ce
    mov      w23, #0x0
    add      x1, x1, :lo12:_rodata_str1_1+0x3ce
    bl       _dev_info
    b        .Lmiop_new_arch_work_fn_d54
.Lmiop_new_arch_work_fn_12fc:
    ldr      x24, [x0, #8]
    ldr      x0, [x19, #832]
    cbz      x0, .Lmiop_new_arch_work_fn_d80
    str      wzr, [x0, #20]
    dsb      st
    ldr      x0, [x19, #864]
    cbnz     x0, .Lmiop_new_arch_work_fn_1320
    ldrb     w0, [x19, #872]
    tbz      w0, #0, .Lmiop_new_arch_work_fn_13f8
.Lmiop_new_arch_work_fn_1320:
    ldrb     w0, [x19, #976]
    sub      x25, x22, #0x6f8
    tbz      w0, #0, .Lmiop_new_arch_work_fn_1360
    sub      x26, x22, #0x6d0
    mov      x23, #0x0
.Lmiop_new_arch_work_fn_1334:
    ldrh     w0, [x19, #984]
    cmp      w0, w23
    b.ls     .Lmiop_new_arch_work_fn_1360
    lsl      x0, x23, #4
    ldr      x0, [x26, x0]
    cbnz     x0, .Lmiop_new_arch_work_fn_1354
.Lmiop_new_arch_work_fn_134c:
    add      x23, x23, #0x1
    b        .Lmiop_new_arch_work_fn_1334
.Lmiop_new_arch_work_fn_1354:
    mov      w1, #0x1
    bl       __dev_kfree_skb_any
    b        .Lmiop_new_arch_work_fn_134c
.Lmiop_new_arch_work_fn_1360:
    mov      x0, x25
    mov      x2, #0x228
    mov      w1, #0x0
    bl       memset
    ldrb     w0, [x19, #1528]
    sub      x25, x22, #0x4d0
    str      x19, [x19, #968]
    tbz      w0, #0, .Lmiop_new_arch_work_fn_1394
    sub      x26, x22, #0x4a8
    mov      x23, #0x0
.Lmiop_new_arch_work_fn_1388:
    ldrh     w0, [x19, #1536]
    cmp      w0, w23
    b.hi     .Lmiop_new_arch_work_fn_1408
.Lmiop_new_arch_work_fn_1394:
    mov      w1, #0x0
    mov      x0, x25
    mov      x2, #0x228
    bl       memset
    add      x1, x19, #0x3a4
    mov      w0, #0x1
    strb     w0, [x19, #1531]
    sub      x23, x22, #0x228
    stp      wzr, wzr, [x1, #-8]
    stp      wzr, wzr, [x1]
    str      wzr, [x19, #960]
    str      x19, [x19, #1520]
    ldr      x0, [x23]
    cbnz     x0, .Lmiop_new_arch_work_fn_1424
.Lmiop_new_arch_work_fn_13cc:
    ldrb     w0, [x19, #872]
    tbnz     w0, #0, .Lmiop_new_arch_work_fn_13e4
    ldr      x2, [x24, #72]
    mov      w1, w21
    mov      x0, x20
    blr      x2
.Lmiop_new_arch_work_fn_13e4:
    add      x0, x19, #0x370
    str      xzr, [x19, #864]
    strb     wzr, [x19, #872]
    stp      xzr, xzr, [x0]
    stp      xzr, xzr, [x0, #16]
.Lmiop_new_arch_work_fn_13f8:
    str      xzr, [x19, #832]
    str      xzr, [x19, #840]
    str      xzr, [x19, #848]
    b        .Lmiop_new_arch_work_fn_d80
.Lmiop_new_arch_work_fn_1408:
    lsl      x0, x23, #4
    ldr      x0, [x26, x0]
    cbz      x0, .Lmiop_new_arch_work_fn_141c
    mov      w1, #0x1
    bl       __dev_kfree_skb_any
.Lmiop_new_arch_work_fn_141c:
    add      x23, x23, #0x1
    b        .Lmiop_new_arch_work_fn_1388
.Lmiop_new_arch_work_fn_1424:
    ldr      x1, [x23, #16]
    mov      x0, x20
    ldr      w2, [x23, #32]
    mov      x4, #0x0
    mov      w3, #0x1
    bl       dma_unmap_page_attrs
    ldr      x0, [x23]
    bl       kfree
    stp      xzr, xzr, [x23]
    stp      xzr, xzr, [x23, #16]
    stp      wzr, wzr, [x23, #32]
    stp      wzr, wzr, [x23, #40]
    b        .Lmiop_new_arch_work_fn_13cc
.Lmiop_new_arch_work_fn_1458:
    mov      w23, #0xfffffff4
    b        .Lmiop_new_arch_work_fn_f9c

.global miop_process_tx_new
.type miop_process_tx_new, @function
miop_process_tx_new:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-96]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x19, x1
    stp      x21, x22, [sp, #32]
    stp      x23, x24, [sp, #48]
    stp      x25, x26, [sp, #64]
    mov      x26, x0
    mrs      x0, sp_el0
    stp      x27, x28, [sp, #80]
    sub      sp, sp, #0x510
    ldr      x1, [x0, #1336]
    str      x1, [sp, #1288]
    mov      x1, #0x0
    ldr      x0, [x19, #48]
    str      x0, [sp, #8]
    ldr      x0, [x19]
    str      x0, [sp, #16]
    ldr      x0, [x19, #8]
    ldr      x0, [x0, #8]
    str      x0, [sp, #24]
    bl       miop_now_ns
    str      x0, [sp, #56]
    ldr      x0, [x26, #864]
    cbnz     x0, .Lmiop_process_tx_new_14d8
    ldrb     w0, [x26, #872]
    tbz      w0, #0, .Lmiop_process_tx_new_1fac
.Lmiop_process_tx_new_14d8:
    ldr      x0, [x26, #896]
    cbz      x0, .Lmiop_process_tx_new_1fac
    ldr      x0, [x26, #2200]
    cbz      x0, .Lmiop_process_tx_new_1fac
    ldr      x0, [sp, #24]
    ldr      x0, [x0, #104]
    cbz      x0, .Lmiop_process_tx_new_1fac
    ldr      x0, [x26, #2272]
    mov      w28, #0x0
    add      x0, x0, #0x1
    str      x0, [x26, #2272]
    ldp      x23, x0, [x19]
    ldr      x24, [x19, #48]
    ldr      x0, [x0, #8]
    str      x0, [sp, #48]
    add      x0, x26, #0xa20
    str      x0, [sp, #80]
    add      x0, x26, #0xa18
    str      x0, [sp, #88]
.Lmiop_process_tx_new_1524:
    bl       miop_now_ns
    str      x0, [sp, #64]
    ldrb     w1, [x26, #976]
    ldr      w0, [x26, #924]
    tbnz     w1, #0, .Lmiop_process_tx_new_1690
.Lmiop_process_tx_new_1538:
    ldrb     w1, [x26, #1528]
    tbnz     w1, #0, .Lmiop_process_tx_new_18a4
.Lmiop_process_tx_new_1540:
    add      x22, x26, #0x868
    cbz      w28, .Lmiop_process_tx_new_1650
    ldrb     w0, [x26, #976]
    ldrb     w2, [x26, #1528]
    ldr      w1, [x26, #932]
    ldr      w3, [x26, #936]
    and      w2, w2, #0x1
    add      w2, w2, w0, uxtb
    subs     w3, w1, w3
    b.eq     .Lmiop_process_tx_new_1620
    ldr      w4, [x22, #16]
    ldr      w1, [x26, #928]
    ldr      w5, [x26, #940]
    ldr      w0, [x26, #2236]
    cmp      w3, #0x7
    b.hi     .Lmiop_process_tx_new_15ac
    sub      w1, w1, w5
    cmp      w1, w0
    csel     w1, w1, w0, ls
    sub      w1, w0, w1
    lsr      w0, w0, #3
    cmp      w0, #0x0
    csinc    w0, w0, wzr, ne
    cmp      w1, w0
    b.ls     .Lmiop_process_tx_new_15ac
    orr      w0, w2, w4
    cbnz     w0, .Lmiop_process_tx_new_1620
.Lmiop_process_tx_new_15ac:
    bl       miop_now_ns
    ldr      w21, [x26, #932]
    mov      x20, x0
    dsb      st
    ldrb     w0, [x26, #872]
    tbz      w0, #0, .Lmiop_process_tx_new_1910
    ldr      x0, [x26, #880]
    str      w21, [x0, #52]
    ldr      x0, [x26, #880]
    ldr      w1, [x26, #944]
    add      w1, w1, #0x1
    str      w1, [x26, #944]
    str      w1, [x0, #60]
.Lmiop_process_tx_new_15e0:
    dsb      st
    ldr      x0, [sp, #48]
    mov      w2, #0x0
    ldr      w1, [x26, #816]
    ldr      x3, [x0, #40]
    mov      x0, x23
    blr      x3
    str      w21, [x26, #936]
    ldr      x0, [x26, #2440]
    add      x0, x0, #0x1
    str      x0, [x26, #2440]
    bl       miop_now_ns
    sub      x2, x0, x20
    add      x1, x26, #0xa30
    add      x0, x26, #0xa28
    bl       miop_stat_add_ns
.Lmiop_process_tx_new_1620:
    strb     wzr, [x26, #954]
    dmb      ish
    ldr      x0, [x19, #48]
    ldr      x19, [x0, #960]
    mov      x0, x19
    bl       netif_queue_stopped.isra.0
    tbz      w0, #0, .Lmiop_process_tx_new_1650
    mov      x0, x19
    bl       netif_tx_wake_queue
    ldr      x0, [x26, #2448]
    add      x0, x0, #0x1
    str      x0, [x26, #2448]
.Lmiop_process_tx_new_1650:
    ldr      x0, [x26, #2152]
    cmp      x22, x0
    b.ne     .Lmiop_process_tx_new_1940
.Lmiop_process_tx_new_165c:
    bl       miop_now_ns
    ldr      x1, [sp, #56]
    sub      x2, x0, x1
    add      x1, x26, #0xa08
    add      x0, x26, #0xa00
    bl       miop_stat_add_ns
.Lmiop_process_tx_new_1674:
    mrs      x0, sp_el0
    ldr      x2, [sp, #1288]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lmiop_process_tx_new_1fb4
    bl       __stack_chk_fail
.Lmiop_process_tx_new_1690:
    ldrb     w1, [x26, #977]
    tst      w1, #0xff
    b.eq     .Lmiop_process_tx_new_1538
    dmb      ishld
    ldr      w1, [x26, #980]
    cmp      w0, w1
    b.ne     .Lmiop_process_tx_new_1538
    add      x27, x26, #0x3c8
.Lmiop_process_tx_new_16b0:
    cbz      x27, .Lmiop_process_tx_new_1540
    ldrb     w0, [x27, #10]
    ldrh     w20, [x27, #16]
    cmp      w20, #0x0
    csinc    w20, w20, wzr, ne
    cbz      w0, .Lmiop_process_tx_new_17c4
    adrp     x0, _data
    adrp     x21, _rodata
    add      x0, x0, :lo12:_data
    add      x21, x21, :lo12:_rodata
    str      x0, [sp, #32]
    add      x0, x21, #0x19
    str      x0, [sp, #40]
    mov      w25, #0x0
    ldr      x0, [sp, #32]
    add      x0, x0, #0x160
    str      x0, [sp, #72]
.Lmiop_process_tx_new_16f4:
    ldr      w0, [x27, #12]
    mov      w3, #0x1
    ldr      w1, [x26, #2236]
    mov      x2, #0x40
    add      w0, w25, w0
    ldr      x8, [x26, #2200]
    str      x8, [sp, #112]
    udiv     w22, w0, w1
    msub     w22, w22, w1, w0
    mov      x0, x23
    ubfiz    x21, x22, #4, #32
    add      x9, x8, x21
    ldr      x5, [x8, x21]
    stp      x5, x9, [sp, #96]
    ldr      x1, [x9, #8]
    bl       dma_sync_single_for_cpu
    ldr      x5, [sp, #96]
    mov      w0, #0xffc0
    ldr      w5, [x5]
    cmp      w5, w0
    b.hi     .Lmiop_process_tx_new_18c8
    ldr      x0, [x26, #904]
    cbz      x0, .Lmiop_process_tx_new_18c8
    ldr      x9, [sp, #104]
    add      w2, w5, #0x40
    mov      x0, x23
    mov      w3, #0x1
    str      x2, [sp, #96]
    ldr      x1, [x9, #8]
    bl       dma_sync_single_for_cpu
    ldr      x8, [sp, #112]
    lsl      w0, w22, #16
    ldr      x2, [sp, #96]
    ldr      x1, [x8, x21]
    ldr      x3, [x26, #904]
    add      x0, x3, x0
    bl       __memcpy_toio
    dsb      st
    ldp      x0, x1, [sp, #32]
    add      x0, x0, #0x128
    bl       ___ratelimit
    cbz      w0, .Lmiop_process_tx_new_17b8
    ldrb     w3, [x27, #10]
    adrp     x1, _rodata_str1_1+0x481
    ldr      w2, [x26, #816]
    mov      w4, w22
    add      x1, x1, :lo12:_rodata_str1_1+0x481
    mov      x0, x23
    bl       _dev_warn
.Lmiop_process_tx_new_17b8:
    add      w25, w25, #0x1
    cmp      w20, w25
    b.ne     .Lmiop_process_tx_new_16f4
.Lmiop_process_tx_new_17c4:
    mov      x21, x27
    mov      w22, w20
    add      x25, x27, w20, uxtw #4
.Lmiop_process_tx_new_17d0:
    ldr      x0, [x21, #40]
    cbz      x0, .Lmiop_process_tx_new_1804
    ldr      x0, [x24, #312]
    add      x0, x0, #0x1
    str      x0, [x24, #312]
    ldr      x0, [x24, #328]
    ldr      w1, [x21, #48]
    add      x0, x0, x1
    str      x0, [x24, #328]
    mov      w1, #0x0
    ldr      x0, [x21, #40]
    bl       __dev_kfree_skb_any
    str      xzr, [x21, #40]
.Lmiop_process_tx_new_1804:
    add      x21, x21, #0x10
    cmp      x25, x21
    b.ne     .Lmiop_process_tx_new_17d0
    ldr      w0, [x26, #2244]
    ldr      w3, [x26, #2236]
    add      w0, w20, w0
    udiv     w2, w0, w3
    msub     w0, w2, w3, w0
    str      w0, [x26, #2244]
    ldr      w0, [x26, #924]
    add      w0, w0, w20
    str      w0, [x26, #924]
    ldr      w0, [x26, #932]
    add      w0, w0, w20
    str      w0, [x26, #932]
    ldr      x0, [x26, #2432]
    add      x0, x0, x22
    str      x0, [x26, #2432]
    ldrb     w0, [x27, #11]
    cmp      w0, #0x1
    b.hi     .Lmiop_process_tx_new_1868
    add      x0, x26, w0, uxtb #3
    ldr      x1, [x0, #2408]
    add      x1, x1, x22
    str      x1, [x0, #2408]
.Lmiop_process_tx_new_1868:
    mov      x0, x27
    bl       miop_new_tx_batch_reset
    mov      x0, x26
    bl       miop_new_tx_active_entries
    str      w0, [x26, #960]
    add      w28, w28, w20
    ldr      x0, [x26, #2576]
    add      x0, x0, #0x1
    str      x0, [x26, #2576]
    bl       miop_now_ns
    ldr      x1, [sp, #64]
    sub      x2, x0, x1
    ldp      x1, x0, [sp, #80]
    bl       miop_stat_add_ns
    b        .Lmiop_process_tx_new_1524
.Lmiop_process_tx_new_18a4:
    ldrb     w1, [x26, #1529]
    tst      w1, #0xff
    b.eq     .Lmiop_process_tx_new_1540
    dmb      ishld
    ldr      w1, [x26, #1532]
    cmp      w0, w1
    b.ne     .Lmiop_process_tx_new_1540
    add      x27, x26, #0x5f0
    b        .Lmiop_process_tx_new_16b0
.Lmiop_process_tx_new_18c8:
    ldr      x1, [sp, #40]
    str      w5, [sp, #96]
    ldr      x0, [sp, #72]
    bl       ___ratelimit
    ldr      w5, [sp, #96]
    cbz      w0, .Lmiop_process_tx_new_18fc
    ldrb     w3, [x27, #10]
    adrp     x1, _rodata_str1_1+0x4ba
    ldr      w2, [x26, #816]
    mov      w4, w22
    add      x1, x1, :lo12:_rodata_str1_1+0x4ba
    mov      x0, x23
    bl       _dev_err
.Lmiop_process_tx_new_18fc:
    ldr      x1, [x19, #48]
    ldr      x0, [x1, #344]
    add      x0, x0, #0x1
    str      x0, [x1, #344]
    b        .Lmiop_process_tx_new_17b8
.Lmiop_process_tx_new_1910:
    ldr      x0, [x26, #896]
    add      x0, x0, #0x20
    dmb      oshst
    str      w21, [x0]
    ldr      x0, [x26, #896]
    ldr      w1, [x26, #944]
    add      x0, x0, #0x28
    add      w1, w1, #0x1
    str      w1, [x26, #944]
    dmb      oshst
    str      w1, [x0]
    b        .Lmiop_process_tx_new_15e0
.Lmiop_process_tx_new_1940:
    ldr      w1, [x26, #940]
    add      x24, x26, #0x898
    ldr      w0, [x26, #928]
    ldr      w21, [x24, #36]
    sub      w0, w0, w1
    cmp      w21, w0
    csel     w1, w21, w0, ls
    sub      w1, w21, w1
    cmp      w1, #0x10
    b.hi     .Lmiop_process_tx_new_1988
    mov      x0, x26
    bl       miop_peer_rxq_read_cons
    ldr      w1, [x26, #928]
    str      w0, [x26, #940]
    sub      w0, w1, w0
    ldr      x1, [x26, #2296]
    add      x1, x1, #0x1
    str      x1, [x26, #2296]
.Lmiop_process_tx_new_1988:
    cmp      w0, w21
    b.cc     .Lmiop_process_tx_new_1a30
    mov      x0, x26
    bl       miop_peer_rxq_read_cons
    ldr      w1, [x26, #928]
    str      w0, [x26, #940]
    sub      w0, w1, w0
    cmp      w21, w0
    b.hi     .Lmiop_process_tx_new_1a30
    ldr      x0, [x26, #2304]
    add      x0, x0, #0x1
    str      x0, [x26, #2304]
    mov      w0, #0x1
    strb     w0, [x26, #954]
    ldr      x0, [sp, #8]
    ldr      x0, [x0, #960]
    add      x0, x0, #0xa8
    prfm     pstl1strm, [x0]
.Lmiop_process_tx_new_19d0:
    ldxr     x1, [x0]
    orr      x1, x1, #0x1
    stxr     w2, x1, [x0]
    cbnz     w2, .Lmiop_process_tx_new_19d0
    ldr      x0, [sp, #24]
    mov      w2, #0x2
    ldr      w1, [x26, #816]
    ldr      x3, [x0, #40]
    ldr      x0, [sp, #16]
    blr      x3
    ldr      x0, [x26, #2120]
    cbnz     x0, .Lmiop_process_tx_new_165c
    mov      x0, #0x3ffffffffffffffe
    bl       jiffies_to_usecs
    adrp     x1, jiffies
    cmp      w0, #0x31
    add      x19, x26, #0x840
    mov      x0, #0x3ffffffffffffffe
    ldr      x1, [x1, :lo12:jiffies]
    csinc    x0, x0, xzr, ls
    add      x1, x0, x1
    mov      x0, x19
    bl       mod_timer
    b        .Lmiop_process_tx_new_165c
.Lmiop_process_tx_new_1a30:
    ldrb     w0, [x26, #954]
    tbz      w0, #0, .Lmiop_process_tx_new_1a3c
    strb     wzr, [x26, #954]
.Lmiop_process_tx_new_1a3c:
    ldr      w0, [x26, #956]
    str      xzr, [sp, #40]
    and      w0, w0, #0x1
    str      w0, [sp, #128]
    eor      w0, w0, #0x1
    str      w0, [sp, #132]
    add      x0, x26, #0x9c8
    str      x0, [sp, #96]
    add      x0, x26, #0x9c0
    str      x0, [sp, #104]
.Lmiop_process_tx_new_1a64:
    ldr      x0, [x22]
    cmp      x22, x0
    b.ne     .Lmiop_process_tx_new_1ac0
.Lmiop_process_tx_new_1a70:
    ldr      x0, [sp, #8]
    ldr      x19, [x0, #960]
    mov      x0, x19
    bl       netif_queue_stopped.isra.0
    tbz      w0, #0, .Lmiop_process_tx_new_165c
    ldrb     w0, [x26, #954]
    tbnz     w0, #0, .Lmiop_process_tx_new_165c
    ldr      w0, [x22, #16]
    cmp      w0, #0x7f
    b.hi     .Lmiop_process_tx_new_165c
    ldrb     w0, [x26, #976]
    tbnz     w0, #0, .Lmiop_process_tx_new_165c
    ldrb     w0, [x26, #1528]
    tbnz     w0, #0, .Lmiop_process_tx_new_165c
    mov      x0, x19
    bl       netif_tx_wake_queue
    ldr      x0, [x26, #2448]
    add      x0, x0, #0x1
    str      x0, [x26, #2448]
    b        .Lmiop_process_tx_new_165c
.Lmiop_process_tx_new_1ac0:
    ldr      x0, [sp, #40]
    add      x1, sp, #0x80
    ldr      w20, [x22, #16]
    ldr      w0, [x1, x0, lsl #2]
    mov      x1, #0x228
    str      w0, [sp, #32]
    mov      w0, w0
    str      x0, [sp, #48]
    madd     x0, x0, x1, x26
    ldrb     w0, [x0, #976]
    tbnz     w0, #0, .Lmiop_process_tx_new_1b30
    ldr      x0, [sp, #24]
    ldr      w1, [sp, #32]
    ldr      x2, [x0, #48]
    ldr      x0, [sp, #16]
    blr      x2
    tbz      w0, #0, .Lmiop_process_tx_new_1b44
    ldr      x0, [x26, #2280]
    add      x0, x0, #0x1
    str      x0, [x26, #2280]
    ldr      x0, [x26, #2320]
    add      x0, x0, #0x1
    str      x0, [x26, #2320]
    ldr      x0, [sp, #48]
    add      x1, x26, x0, lsl #3
    ldr      x0, [x1, #2392]
    add      x0, x0, #0x1
    str      x0, [x1, #2392]
.Lmiop_process_tx_new_1b30:
    ldr      x0, [sp, #40]
    cbnz     x0, .Lmiop_process_tx_new_1a70
    mov      x0, #0x1
    str      x0, [sp, #40]
    b        .Lmiop_process_tx_new_1a64
.Lmiop_process_tx_new_1b44:
    cbz      w20, .Lmiop_process_tx_new_1f3c
    ldr      w1, [sp, #40]
    sub      w20, w20, #0x1
    mov      w0, #0x2
    sub      w0, w0, w1
    add      w20, w20, w0
    udiv     w20, w20, w0
    mov      w0, #0x20
    cmp      w20, #0x0
    csinc    w20, w20, wzr, ne
    cmp      w20, #0x20
    csel     w20, w20, w0, ls
.Lmiop_process_tx_new_1b74:
    ldr      w0, [x26, #928]
    mov      w19, #0x0
    ldr      w1, [x26, #940]
    sub      w0, w0, w1
    cmp      w21, w0
    b.ls     .Lmiop_process_tx_new_1b30
    add      x0, x26, #0x9a8
    str      x0, [sp, #80]
    add      x0, x26, #0x9a0
    str      x0, [sp, #88]
.Lmiop_process_tx_new_1b9c:
    mov      x0, x22
    bl       skb_dequeue
    mov      x27, x0
    cbz      x0, .Lmiop_process_tx_new_1c2c
    ldr      x23, [x0, #40]
    cbz      x23, .Lmiop_process_tx_new_1bd0
    bl       miop_now_ns
    sub      x2, x0, x23
    ldp      x1, x0, [sp, #80]
    bl       miop_stat_add_ns
    ldr      x0, [x26, #2456]
    add      x0, x0, #0x1
    str      x0, [x26, #2456]
.Lmiop_process_tx_new_1bd0:
    ldr      w23, [x27, #112]
    mov      w0, #0xffc0
    cmp      w23, w0
    b.ls     .Lmiop_process_tx_new_1da8
.Lmiop_process_tx_new_1be0:
    ldr      x0, [sp, #8]
    ldr      x1, [sp, #8]
    ldr      x0, [x0, #344]
    add      x0, x0, #0x1
    str      x0, [x1, #344]
    mov      x0, x27
    mov      w1, #0x1
    bl       __dev_kfree_skb_any
.Lmiop_process_tx_new_1c00:
    ldr      x0, [x26, #2288]
    add      x0, x0, #0x1
    str      x0, [x26, #2288]
    cmp      w19, w20
    b.cs     .Lmiop_process_tx_new_1c30
    ldr      w0, [x26, #928]
    ldr      w1, [x26, #940]
    sub      w0, w0, w1
    add      w0, w0, w19
    cmp      w0, w21
    b.cc     .Lmiop_process_tx_new_1b9c
.Lmiop_process_tx_new_1c2c:
    cbz      w19, .Lmiop_process_tx_new_1b30
.Lmiop_process_tx_new_1c30:
    ldr      w1, [sp, #32]
    mov      w0, #0x228
    mov      x25, #0x228
    umull    x23, w1, w0
    add      x20, x23, #0x3c8
    add      x20, x26, x20
    mov      x0, x20
    bl       miop_new_tx_batch_reset
    ldr      x0, [sp, #48]
    madd     x25, x0, x25, x26
    mov      w0, #0x1
    strb     w0, [x25, #976]
    ldr      w0, [x26, #928]
    str      w0, [x25, #980]
    strh     w19, [x25, #984]
    bl       miop_now_ns
    add      x2, sp, #0x208
    add      x4, sp, #0x88
    str      x0, [x25, #992]
    add      x0, x26, x23
    add      x25, sp, #0x108
    mov      x23, x2
    mov      x1, #0x0
.Lmiop_process_tx_new_1c8c:
    ldr      x3, [x25, x1, lsl #3]
    str      x3, [x0, #1008]
    ldr      w3, [x4, x1, lsl #2]
    add      x1, x1, #0x1
    str      w3, [x0, #1016]
    add      x2, x2, #0x18
    ldur     w3, [x2, #-8]
    add      x0, x0, #0x10
    str      w3, [x0, #1004]
    cmp      w19, w1
    b.hi     .Lmiop_process_tx_new_1c8c
    ldr      w0, [x24, #40]
    add      w0, w19, w0
    udiv     w1, w0, w21
    msub     w0, w1, w21, w0
    str      w0, [x24, #40]
    ldr      w0, [x26, #928]
    add      w0, w19, w0
    str      w0, [x26, #928]
    mov      x0, x26
    bl       miop_new_tx_active_entries
    str      w0, [x26, #960]
    bl       miop_now_ns
    mov      x7, x0
    ldr      x0, [sp, #24]
    mov      x2, x23
    ldr      w1, [sp, #32]
    mov      x5, x20
    mov      w3, w19
    adrp     x4, _text+0xa6c
    ldr      x8, [x0, #104]
    add      x4, x4, :lo12:_text+0xa6c
    ldr      x0, [sp, #16]
    str      x7, [sp, #64]
    blr      x8
    mov      w23, w0
    bl       miop_now_ns
    ldr      x7, [sp, #64]
    add      x1, x26, #0x9f8
    sub      x2, x0, x7
    add      x0, x26, #0x9f0
    bl       miop_stat_add_ns
    ldr      x0, [x26, #2536]
    add      x0, x0, #0x1
    str      x0, [x26, #2536]
    cbz      w23, .Lmiop_process_tx_new_1f44
    ldr      w0, [x26, #928]
    sub      w23, w19, #0x1
    sub      w0, w0, w19
    str      w0, [x26, #928]
    add      x23, x25, x23, lsl #3
    ldr      w0, [x24, #40]
    add      w0, w21, w0
    sub      w0, w0, w19
    udiv     w1, w0, w21
    msub     w0, w1, w21, w0
    str      w0, [x24, #40]
.Lmiop_process_tx_new_1d70:
    ldr      x1, [x23], #-8
    sub      w19, w19, #0x1
    mov      x0, x22
    bl       skb_queue_head
    cbnz     w19, .Lmiop_process_tx_new_1d70
    mov      x0, x20
    bl       miop_new_tx_batch_reset
    mov      x0, x26
    bl       miop_new_tx_active_entries
    str      w0, [x26, #960]
    ldr      x0, [x26, #2328]
    add      x0, x0, #0x1
    str      x0, [x26, #2328]
    b        .Lmiop_process_tx_new_1b30
.Lmiop_process_tx_new_1da8:
    ldr      w0, [x26, #928]
    mov      x2, #0x38
    ldr      x5, [x24]
    add      w0, w19, w0
    str      x5, [sp, #112]
    udiv     w1, w0, w21
    msub     w0, w1, w21, w0
    mov      w1, #0x0
    str      w0, [sp, #64]
    ldr      x0, [sp, #64]
    ubfiz    x3, x0, #4, #32
    str      x3, [sp, #120]
    add      x0, x5, x3
    str      x0, [sp, #72]
    ldr      x25, [x5, x3]
    add      x0, x25, #0x8
    bl       memset
    mov      w0, #0x1
    movk     w0, #0x40, lsl #16
    stp      w23, w0, [x25]
    ldrh     w0, [x26, #952]
    add      w1, w0, #0x1
    strh     w1, [x26, #952]
    str      w0, [x25, #8]
    bl       miop_now_ns
    str      x0, [x25, #16]
    bl       miop_now_ns
    mov      x25, x0
    ldp      x5, x3, [sp, #112]
    ldp      w1, w2, [x27, #112]
    sub      w1, w1, w2
    ldr      x0, [x5, x3]
    add      x0, x0, #0x40
    cmp      w23, w1
    b.hi     .Lmiop_process_tx_new_1f20
    ldr      x1, [x27, #208]
    mov      w2, w23
    bl       memcpy
    mov      w3, #0x0
.Lmiop_process_tx_new_1e44:
    str      w3, [sp, #112]
    bl       miop_now_ns
    sub      x2, x0, x25
    ldp      x1, x0, [sp, #96]
    bl       miop_stat_add_ns
    ldr      w3, [sp, #112]
    cbnz     w3, .Lmiop_process_tx_new_1be0
    ldr      x0, [x26, #2480]
    add      x0, x0, #0x1
    str      x0, [x26, #2480]
    ldr      x0, [x26, #2488]
    add      x0, x0, w23, uxtw
    str      x0, [x26, #2488]
    bl       miop_now_ns
    mov      x25, x0
    ldr      x0, [sp, #72]
    add      w5, w23, #0x40
    add      w2, w23, #0x40
    mov      w3, #0x1
    str      w5, [sp, #112]
    ldr      x1, [x0, #8]
    ldr      x0, [sp, #16]
    bl       dma_sync_single_for_device
    bl       miop_now_ns
    sub      x2, x0, x25
    add      x1, x26, #0x9e0
    add      x0, x26, #0x9d8
    bl       miop_stat_add_ns
    add      x1, sp, #0x208
    ldr      x0, [x26, #2512]
    mov      w3, w19
    ldr      w5, [sp, #112]
    add      w19, w19, #0x1
    add      x0, x0, #0x1
    str      x0, [x26, #2512]
    ldr      x0, [sp, #72]
    ldr      x2, [x0, #8]
    mov      x0, #0x18
    mul      x0, x3, x0
    str      x2, [x1, x0]
    ldr      x2, [x26, #888]
    ldr      w1, [x26, #920]
    add      x1, x1, x2
    ldr      w2, [sp, #64]
    lsl      w2, w2, #16
    add      x1, x1, x2
    add      x2, sp, #0x210
    str      x1, [x2, x0]
    add      x1, sp, #0x218
    str      w5, [x1, x0]
    add      x0, sp, #0x108
    str      x27, [x0, x3, lsl #3]
    add      x0, sp, #0x88
    str      w23, [x0, x3, lsl #2]
    b        .Lmiop_process_tx_new_1c00
.Lmiop_process_tx_new_1f20:
    mov      w3, w23
    mov      x2, x0
    mov      w1, #0x0
    mov      x0, x27
    bl       skb_copy_bits
    mov      w3, w0
    b        .Lmiop_process_tx_new_1e44
.Lmiop_process_tx_new_1f3c:
    mov      w20, #0x20
    b        .Lmiop_process_tx_new_1b74
.Lmiop_process_tx_new_1f44:
    ldr      x0, [x26, #2312]
    mov      w1, w19
    add      x0, x0, w19, uxtw
    str      x0, [x26, #2312]
    ldr      x0, [sp, #48]
    add      x27, x26, x0, lsl #3
    ldr      x0, [x27, #2360]
    add      x0, x0, w19, uxtw
    str      x0, [x27, #2360]
    ldr      x0, [x26, #2336]
    add      x0, x0, #0x1
    str      x0, [x26, #2336]
    ldr      x0, [x27, #2376]
    add      x0, x0, #0x1
    str      x0, [x27, #2376]
    ldr      x0, [x26, #2344]
    cmp      x0, w19, uxtw
    b.cs     .Lmiop_process_tx_new_1f90
    str      x1, [x26, #2344]
.Lmiop_process_tx_new_1f90:
    cmp      w19, #0x20
    b.ne     .Lmiop_process_tx_new_1fa4
    ldr      x0, [x26, #2352]
    add      x0, x0, #0x1
    str      x0, [x26, #2352]
.Lmiop_process_tx_new_1fa4:
    add      w28, w28, w19
    b        .Lmiop_process_tx_new_1b30
.Lmiop_process_tx_new_1fac:
    mov      w28, #0x0
    b        .Lmiop_process_tx_new_1674
.Lmiop_process_tx_new_1fb4:
    add      sp, sp, #0x510
    mov      w0, w28
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x25, x26, [sp, #64]
    ldp      x27, x28, [sp, #80]
    ldp      x29, x30, [sp], #96
    autiasp  
    ret      

.global miop_tx_work_fn
.type miop_tx_work_fn, @function
miop_tx_work_fn:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x3, #0xffffffffffffff38
    mov      x29, sp
    str      x19, [sp, #16]
    mov      x19, x0
    sub      x0, x0, #0x818
    mov      w2, #0xae8
    ldr      w1, [x0, #816]
    umsubl   x1, w1, w2, x3
    mov      w2, #0x1
    strb     w2, [x19, #32]
    add      x1, x0, x1
    bl       miop_process_tx_new
    strb     wzr, [x19, #32]
    ldr      x19, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      

.global miop_ep_tx_poll_new
.type miop_ep_tx_poll_new, @function
miop_ep_tx_poll_new:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      w2, #0xae8
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x20, x0
    sub      x0, x0, #0x198
    str      x21, [sp, #32]
    mov      w21, w1
    mov      x3, #0xffffffffffffff38
    ldr      w1, [x0, #816]
    umsubl   x1, w1, w2, x3
    add      x1, x0, x1
    bl       miop_process_tx_new
    mov      w19, w0
    cmp      w0, w21
    b.ge     .Lmiop_ep_tx_poll_new_2088
    mov      w1, w0
    mov      x0, x20
    bl       napi_complete_done
.Lmiop_ep_tx_poll_new_2088:
    ldr      x21, [sp, #32]
    mov      w0, w19
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      

.global miop_ep_net_init
.type miop_ep_net_init, @function
miop_ep_net_init:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x90
    mov      w2, #0x4
    stp      x29, x30, [sp, #48]
    add      x29, sp, #0x30
    stp      x19, x20, [sp, #64]
    stp      x21, x22, [sp, #80]
    mov      x21, x0
    mrs      x0, sp_el0
    stp      x23, x24, [sp, #96]
    stp      x25, x26, [sp, #112]
    stp      x27, x28, [sp, #128]
    ldr      x1, [x0, #1336]
    str      x1, [sp, #40]
    mov      x1, #0x0
    mov      w0, #0x2c68
    ldr      x23, [x21, #120]
    mov      w1, #0x1
    bl       alloc_etherdev_mqs
    cbnz     x0, .Lmiop_ep_net_init_2128
    mov      w20, #0xfffffff4
    mov      x0, x21
    adrp     x1, _rodata_str1_1+0x4f3
    add      x1, x1, :lo12:_rodata_str1_1+0x4f3
    bl       _dev_err
.Lmiop_ep_net_init_210c:
    mrs      x0, sp_el0
    ldr      x2, [sp, #40]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lmiop_ep_net_init_23e4
    bl       __stack_chk_fail
.Lmiop_ep_net_init_2128:
    mov      x19, x0
    add      x22, x0, #0xa00
    mov      w0, #0xffffffff
    adrp     x24, _bss
    adrp     x1, _rodata_str1_1+0x510
    add      x1, x1, :lo12:_rodata_str1_1+0x510
    str      x21, [x19, #2560]
    adrp     x28, _text+0x31c
    str      x23, [x22, #8]
    adrp     x27, _text+0x2030
    str      w0, [x22, #16]
    add      x0, x24, :lo12:_bss
    strb     wzr, [x22, #20]
    mov      x2, x0
    str      xzr, [x22, #40]
    adrp     x26, _text+0xc9c
    str      x0, [sp, #8]
    add      x0, x19, #0xa38
    bl       __mutex_init
    str      xzr, [x19, #2672]
    mov      x0, #0xfeb0
    str      x0, [x19, #2680]
    str      x22, [x23, #336]
    add      x20, x19, #0xad0
    str      x21, [x19, #1416]
    add      x28, x28, :lo12:_text+0x31c
    str      x19, [x22, #48]
    add      x26, x26, :lo12:_text+0xc9c
    ldr      x0, [x22, #8]
    adrp     x25, _text+0xa20
    mov      w24, #0x0
    ldr      x0, [x0, #8]
    ldr      x1, [x0, #16]
    ldr      x0, [x19, #2560]
    blr      x1
    add      x2, sp, #0x22
    mov      w1, #0x2
    mov      x3, #0x6
    stur     w0, [sp, #35]
    mov      w0, #0xa
    strb     w1, [sp, #34]
    mov      w1, #0x0
    strb     w0, [sp, #39]
    mov      x0, x19
    bl       dev_addr_mod
    mov      x0, x19
    adrp     x1, _rodata_str1_1+0x522
    add      x1, x1, :lo12:_rodata_str1_1+0x522
    bl       strcpy
    adrp     x0, _rodata
    add      x0, x0, :lo12:_rodata
    add      x0, x0, #0x30
    str      x0, [x19, #208]
    ldr      x0, [x19, #232]
    orr      x0, x0, #0x1
    str      x0, [x19, #232]
    ldr      x0, [x19, #240]
    orr      x0, x0, #0x1
    str      x0, [x19, #240]
    add      x0, x27, :lo12:_text+0x2030
    str      x0, [sp, #16]
    add      x0, x25, :lo12:_text+0xa20
    str      x0, [sp, #24]
.Lmiop_ep_net_init_2224:
    str      w24, [x20, #808]
    mov      x2, x28
    mov      x1, x20
    mov      x0, x19
    mov      w3, #0x40
    bl       netif_napi_add_weight
    ldr      x2, [sp, #16]
    add      x25, x20, #0x190
    mov      x1, x25
    mov      x0, x19
    mov      w3, #0x40
    mov      x27, #0xfffffffe0
    bl       netif_napi_add_weight
    str      x27, [x20, #2744]
    add      x0, x20, #0xac0
    mov      x4, #0x0
    ldr      x1, [sp, #24]
    mov      x3, #0x0
    str      x0, [x0]
    mov      w2, #0x0
    str      x0, [x0, #8]
    add      x0, x20, #0x838
    str      x26, [x20, #2768]
    add      w24, w24, #0x1
    bl       init_timer_key
    str      x27, [x20, #2064]
    add      x0, x20, #0x818
    adrp     x1, _rodata_str1_1+0x528
    ldr      x2, [sp, #8]
    add      x1, x1, :lo12:_rodata_str1_1+0x528
    str      x0, [x0]
    add      x27, x20, #0x860
    str      x0, [x0, #8]
    adrp     x0, _text+0x1fdc
    add      x0, x0, :lo12:_text+0x1fdc
    str      x0, [x20, #2088]
    mov      w3, #0x2
    add      x0, x20, #0x878
    bl       __raw_spin_lock_init
    str      x27, [x20, #2144]
    str      x27, [x20, #2152]
    mov      x0, x20
    str      wzr, [x20, #2160]
    add      x20, x20, #0xae8
    bl       napi_enable
    mov      x0, x25
    bl       napi_enable
    cmp      w24, #0x4
    b.ne     .Lmiop_ep_net_init_2224
    mov      x0, #0xfeb0
    mov      w1, #0x1
    movk     x0, #0xfeb0, lsl #32
    str      x0, [x19, #288]
    mov      w0, #0xfeb0
    str      w0, [x19, #224]
    mov      x0, x19
    bl       netif_set_real_num_tx_queues
    mov      w20, w0
    cbz      w0, .Lmiop_ep_net_init_2394
    adrp     x1, _rodata_str1_1+0x534
    mov      w2, w0
    add      x1, x1, :lo12:_rodata_str1_1+0x534
.Lmiop_ep_net_init_231c:
    mov      x0, x21
    bl       _dev_err
    mov      w0, #0x1
    mov      x1, #0x3ea8
    add      x24, x19, x1
    strb     w0, [x19, #2752]
    mov      x0, #0x1308
    add      x21, x19, x0
.Lmiop_ep_net_init_233c:
    mov      x0, x21
    bl       del_timer_sync
    sub      x0, x21, #0x840
    bl       miop_wait_tx_work_idle
    sub      x0, x21, #0x6a8
    bl       __netif_napi_del
    bl       synchronize_net
    sub      x0, x21, #0x838
    bl       __netif_napi_del
    bl       synchronize_net
    add      x0, x21, #0x28
    add      x21, x21, #0xae8
    bl       skb_queue_purge
    cmp      x24, x21
    b.ne     .Lmiop_ep_net_init_233c
    ldr      x0, [x23, #336]
    cmp      x0, x22
    b.ne     .Lmiop_ep_net_init_2388
    str      xzr, [x23, #336]
.Lmiop_ep_net_init_2388:
    mov      x0, x19
    bl       free_netdev
    b        .Lmiop_ep_net_init_210c
.Lmiop_ep_net_init_2394:
    mov      w1, w24
    mov      x0, x19
    bl       netif_set_real_num_rx_queues
    mov      w20, w0
    cbz      w0, .Lmiop_ep_net_init_23b8
    adrp     x1, _rodata_str1_1+0x55f
    mov      w2, w0
    add      x1, x1, :lo12:_rodata_str1_1+0x55f
    b        .Lmiop_ep_net_init_231c
.Lmiop_ep_net_init_23b8:
    mov      x0, x19
    bl       register_netdev
    mov      w20, w0
    tbz      w0, #31, .Lmiop_ep_net_init_23d8
    adrp     x1, _rodata_str1_1+0x58a
    mov      w2, w0
    add      x1, x1, :lo12:_rodata_str1_1+0x58a
    b        .Lmiop_ep_net_init_231c
.Lmiop_ep_net_init_23d8:
    mov      x0, x19
    bl       netif_carrier_off
    b        .Lmiop_ep_net_init_210c
.Lmiop_ep_net_init_23e4:
    ldp      x29, x30, [sp, #48]
    mov      w0, w20
    ldp      x19, x20, [sp, #64]
    ldp      x21, x22, [sp, #80]
    ldp      x23, x24, [sp, #96]
    ldp      x25, x26, [sp, #112]
    ldp      x27, x28, [sp, #128]
    add      sp, sp, #0x90
    autiasp  
    ret      

.global miop_ep_net_deinit
.type miop_ep_net_deinit, @function
miop_ep_net_deinit:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    stp      x21, x22, [sp, #32]
    ldr      x0, [x0, #120]
    ldr      x19, [x0, #336]
    mov      w0, #0x1
    add      x22, x19, #0x38
    strb     w0, [x19, #192]
    mov      x0, x22
    ldr      x21, [x19, #48]
    bl       mutex_lock
    ldr      x20, [x19, #128]
    str      xzr, [x19, #128]
    mov      x0, x22
    bl       mutex_unlock
    cbz      x20, .Lmiop_ep_net_deinit_2464
    mov      x0, x20
    bl       kthread_stop
.Lmiop_ep_net_deinit_2464:
    mov      x1, #0x2c68
    add      x20, x19, #0xc8
    add      x22, x19, x1
.Lmiop_ep_net_deinit_2470:
    ldr      x0, [x20, #2752]
    tbnz     w0, #0, .Lmiop_ep_net_deinit_2500
    ldrb     w0, [x20, #2784]
    tbnz     w0, #0, .Lmiop_ep_net_deinit_2500
    add      x20, x20, #0xae8
    cmp      x20, x22
    b.ne     .Lmiop_ep_net_deinit_2470
    mov      x0, x21
    bl       unregister_netdev
    mov      x0, #0x34a8
    add      x20, x19, #0x908
    add      x22, x19, x0
.Lmiop_ep_net_deinit_24a0:
    mov      x0, x20
    bl       del_timer_sync
    sub      x0, x20, #0x840
    bl       miop_wait_tx_work_idle
    sub      x0, x20, #0x6a8
    bl       __netif_napi_del
    bl       synchronize_net
    sub      x0, x20, #0x838
    bl       __netif_napi_del
    bl       synchronize_net
    add      x0, x20, #0x28
    add      x20, x20, #0xae8
    bl       skb_queue_purge
    cmp      x22, x20
    b.ne     .Lmiop_ep_net_deinit_24a0
    ldr      x0, [x19, #8]
    str      xzr, [x0, #336]
    mov      x0, x21
    bl       free_netdev
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      
.Lmiop_ep_net_deinit_2500:
    mov      w0, #0x1
    bl       msleep
    b        .Lmiop_ep_net_deinit_2470

.global miop_on_rx
.type miop_on_rx, @function
miop_on_rx:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w19, w1
    str      x21, [sp, #32]
    mov      x21, #0xae8
    ldr      x1, [x0, #120]
    ldr      x20, [x1, #336]
    ldr      x2, [x1, #8]
    mov      w1, w19
    madd     x1, x1, x21, x20
    ldr      x3, [x1, #1032]
    cbz      x3, .Lmiop_on_rx_2580
    ldr      x1, [x1, #1040]
    cbz      x1, .Lmiop_on_rx_2580
    ldr      x2, [x2, #32]
    mov      w1, #0x0
    blr      x2
    mov      x0, #0xd0
    umaddl   x19, w19, w21, x0
    add      x20, x20, x19
    mov      x0, x20
    bl       napi_schedule_prep
    tbz      w0, #0, .Lmiop_on_rx_2580
    mov      x0, x20
    bl       __napi_schedule
.Lmiop_on_rx_2580:
    ldp      x19, x20, [sp, #16]
    ldr      x21, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      

.global miop_ndo_start_xmit
.type miop_ndo_start_xmit, @function
miop_ndo_start_xmit:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-64]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      x20, x0
    stp      x21, x22, [sp, #32]
    stp      x23, x24, [sp, #48]
    ldr      x23, [x1, #1416]
    ldr      x0, [x23, #120]
    ldr      x19, [x0, #336]
    ldr      w0, [x20, #112]
    cbnz     w0, .Lmiop_ndo_start_xmit_25e0
.Lmiop_ndo_start_xmit_25cc:
    mov      x0, x20
    mov      w1, #0x1
    bl       kfree_skb_reason
    mov      w0, #0x0
    b        .Lmiop_ndo_start_xmit_2690
.Lmiop_ndo_start_xmit_25e0:
    ldr      x2, [x20, #200]
    mov      x22, x1
    ldrh     w0, [x20, #186]
    add      x1, x2, x0
    ldr      w2, [x2, x0]
    tbnz     w2, #0, .Lmiop_ndo_start_xmit_26e0
    ldrh     w0, [x1, #4]
    orr      w0, w0, w2
    cbz      w0, .Lmiop_ndo_start_xmit_25cc
    add      x4, x19, #0x3f0
    ldur     w2, [x1, #1]
    mov      x0, #0x0
    mov      x1, #0xae8
.Lmiop_ndo_start_xmit_2614:
    mul      x3, x0, x1
    ldr      x3, [x4, x3]
    cbz      x3, .Lmiop_ndo_start_xmit_2650
    ldr      w3, [x3]
    cmp      w2, w3
    b.ne     .Lmiop_ndo_start_xmit_2650
    mov      x3, #0xc8
    smaddl   x0, w0, w1, x3
    adds     x19, x19, x0
    b.ne     .Lmiop_ndo_start_xmit_2660
.Lmiop_ndo_start_xmit_263c:
    mov      x0, x23
    adrp     x1, _rodata_str1_1+0x5a8
    add      x1, x1, :lo12:_rodata_str1_1+0x5a8
    bl       _dev_err
    b        .Lmiop_ndo_start_xmit_25cc
.Lmiop_ndo_start_xmit_2650:
    add      x0, x0, #0x1
    cmp      x0, #0x4
    b.ne     .Lmiop_ndo_start_xmit_2614
    b        .Lmiop_ndo_start_xmit_263c
.Lmiop_ndo_start_xmit_2660:
    ldr      x0, [x19, #864]
    cbnz     x0, .Lmiop_ndo_start_xmit_2670
    ldrb     w0, [x19, #872]
    tbz      w0, #0, .Lmiop_ndo_start_xmit_26a8
.Lmiop_ndo_start_xmit_2670:
    ldr      x0, [x19, #896]
    cbz      x0, .Lmiop_ndo_start_xmit_26a8
    ldr      x0, [x19, #2200]
    cbz      x0, .Lmiop_ndo_start_xmit_26a8
    mov      x2, x19
    mov      x1, x22
    mov      x0, x20
    bl       miop_xmit_to_peer_new
.Lmiop_ndo_start_xmit_2690:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x23, x24, [sp, #48]
    ldp      x29, x30, [sp], #64
    autiasp  
    ret      
.Lmiop_ndo_start_xmit_26a8:
    adrp     x1, _rodata
    adrp     x0, _data
    add      x1, x1, :lo12:_rodata
    add      x0, x0, :lo12:_data
    add      x1, x1, #0x2a8
    add      x0, x0, #0x198
    bl       ___ratelimit
    cbz      w0, .Lmiop_ndo_start_xmit_25cc
    ldr      w2, [x19, #816]
    mov      x0, x23
    adrp     x1, _rodata_str1_1+0x5cc
    add      x1, x1, :lo12:_rodata_str1_1+0x5cc
    bl       _dev_warn
    b        .Lmiop_ndo_start_xmit_25cc
.Lmiop_ndo_start_xmit_26e0:
    add      x21, x19, #0xc8
    mov      x0, #0x2c68
    add      x19, x19, x0
.Lmiop_ndo_start_xmit_26ec:
    ldr      x0, [x21, #864]
    cbnz     x0, .Lmiop_ndo_start_xmit_26fc
    ldrb     w0, [x21, #872]
    tbz      w0, #0, .Lmiop_ndo_start_xmit_2750
.Lmiop_ndo_start_xmit_26fc:
    ldr      x0, [x21, #896]
    cbz      x0, .Lmiop_ndo_start_xmit_2750
    ldr      x0, [x21, #2200]
    cbz      x0, .Lmiop_ndo_start_xmit_2750
    mov      x0, x20
    mov      w1, #0xa20
    bl       skb_clone
    mov      x24, x0
    cbnz     x0, .Lmiop_ndo_start_xmit_2734
    mov      x0, x23
    adrp     x1, _rodata_str1_1+0x5f3
    add      x1, x1, :lo12:_rodata_str1_1+0x5f3
    bl       _dev_err
    b        .Lmiop_ndo_start_xmit_25cc
.Lmiop_ndo_start_xmit_2734:
    mov      x2, x21
    mov      x1, x22
    bl       miop_xmit_to_peer_new
    cbz      w0, .Lmiop_ndo_start_xmit_2750
    mov      x0, x24
    mov      w1, #0x1
    bl       kfree_skb_reason
.Lmiop_ndo_start_xmit_2750:
    add      x21, x21, #0xae8
    cmp      x21, x19
    b.ne     .Lmiop_ndo_start_xmit_26ec
    b        .Lmiop_ndo_start_xmit_25cc

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
    adrp     x0, _rodata_str1_1+0x607
    add      x0, x0, :lo12:_rodata_str1_1+0x607
    bl       print_hex_dump
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
    ldar     w0, [x0]

.global cleanup_module
.type cleanup_module, @function
cleanup_module:
    paciasp  
    sub      sp, sp, #0x50
    mrs      x0, sp_el0
    mov      x2, #0x38
    stp      x29, x30, [sp, #64]
    add      x29, sp, #0x40
    ldr      x1, [x0, #1336]
    str      x1, [sp, #56]
    mov      x1, #0x0
    mov      x0, sp
    bl       memset
    adrp     x2, _rodata
    add      x2, x2, :lo12:_rodata
    adrp     x4, _data
    add      x0, x2, #0x6
    add      x4, x4, :lo12:_data
    mov      x1, #0x0
.Lcleanup_module_44:
    ldrb     w5, [x0]
    ldrb     w3, [x1, x4]
    eor      w3, w3, w5
    strb     w3, [sp, x1]
    ldrb     w3, [x0, #1]!
    add      x1, x1, #0x1
    cmp      w3, #0x0
    csel     x0, x0, x2, ne
    cmp      x1, #0x37
    b.ne     .Lcleanup_module_44
    mov      x1, sp
    adrp     x0, _rodata_str1_1
    add      x0, x0, :lo12:_rodata_str1_1
    bl       _printk
    mrs      x0, sp_el0
    ldr      x2, [sp, #56]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Lcleanup_module_98
    bl       __stack_chk_fail
.Lcleanup_module_98:
    ldp      x29, x30, [sp, #64]
    add      sp, sp, #0x50
    autiasp  
    ret      

.section .text.unlikely
.global _text_unlikely
_text_unlikely:

.global miop_on_peer_online
.type miop_on_peer_online, @function
miop_on_peer_online:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-64]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w20, w1
    stp      x21, x22, [sp, #32]
    mov      x21, x0
    mov      x22, x2
    str      x23, [sp, #48]
    ldr      x23, [x0, #120]
    ldr      x19, [x23, #336]
    ldr      x0, [x19, #40]
    cbnz     x0, .Lmiop_on_peer_online_78
    ldr      x0, [x19, #8]
    ldr      x2, [x0, #144]
    cbz      x2, .Lmiop_on_peer_online_78
    str      x2, [x19, #40]
    mov      x4, x19
    add      x3, x19, #0x18
    ldr      x1, [x0, #104]
    str      x1, [x19, #24]
    ldr      x1, [x0, #112]
    str      x1, [x4, #32]!
    adrp     x1, _rodata_str1_1+0x99
    add      x1, x1, :lo12:_rodata_str1_1+0x99
    ldr      w5, [x0, #120]
    ldr      x0, [x19]
    bl       _dev_info
.Lmiop_on_peer_online_78:
    mov      w2, w20
    cbnz     x22, .Lmiop_on_peer_online_a8
    adrp     x1, _rodata_str1_1+0xcb
    mov      x0, x21
    add      x1, x1, :lo12:_rodata_str1_1+0xcb
    bl       _dev_err
.Lmiop_on_peer_online_90:
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldr      x23, [sp, #48]
    ldp      x29, x30, [sp], #64
    autiasp  
    ret      
.Lmiop_on_peer_online_a8:
    adrp     x1, _rodata_str1_1+0xe6
    mov      x0, x21
    add      x1, x1, :lo12:_rodata_str1_1+0xe6
    bl       _dev_info
    tbz      w20, #31, .Lmiop_on_peer_online_14c
    and      w20, w20, #0xff
    mov      w0, #0x1
    str      w20, [x19, #16]
    mov      w2, w20
    strb     w0, [x19, #20]
    adrp     x1, _rodata_str1_1+0xf6
    add      x1, x1, :lo12:_rodata_str1_1+0xf6
    ldr      x3, [x23, #104]
    str      x3, [x19, #24]
    ldr      x0, [x23, #112]
    str      x0, [x19, #32]
    mov      x0, x21
    bl       _dev_info
    ldr      x3, [x19, #32]
    mov      x0, x21
    mov      w2, w20
    adrp     x1, _rodata_str1_1+0x117
    add      x1, x1, :lo12:_rodata_str1_1+0x117
    bl       _dev_info
    ldr      x0, [x19, #40]
    cbz      x0, .Lmiop_on_peer_online_124
    str      w20, [x0, #12]
    mov      w1, #0x2
    ldr      x0, [x19, #40]
    str      w1, [x0, #16]
    dsb      st
.Lmiop_on_peer_online_124:
    mov      w23, #0x1
.Lmiop_on_peer_online_128:
    ldr      w3, [x22, #4]
    cmp      w3, w20
    b.eq     .Lmiop_on_peer_online_154
    mov      w2, w20
    mov      x0, x21
    adrp     x1, _rodata_str1_1+0x138
    add      x1, x1, :lo12:_rodata_str1_1+0x138
    bl       _dev_err
    b        .Lmiop_on_peer_online_90
.Lmiop_on_peer_online_14c:
    mov      w23, #0x0
    b        .Lmiop_on_peer_online_128
.Lmiop_on_peer_online_154:
    mov      w2, #0xae8
    umull    x2, w20, w2
    add      x0, x2, #0xc8
    add      x2, x2, #0xb88
    add      x2, x19, x2
    str      wzr, [x19, x0]
    mov      x0, #0xae8
    madd     x20, x20, x0, x19
    mov      w0, #0x1
    strb     w0, [x20, #2985]
    adrp     x0, system_wq
    str      x22, [x20, #1008]
    ldr      x1, [x0, :lo12:system_wq]
    mov      w0, #0x8
    bl       queue_work_on
    ldr      x0, [x19, #40]
    cbz      x0, .Lmiop_on_peer_online_1b4
    ldr      w3, [x22, #4]
    mov      x2, #0x1
    ldr      w1, [x0, #20]
    lsl      x2, x2, x3
    orr      w1, w1, w2
    str      w1, [x0, #20]
    dsb      st
.Lmiop_on_peer_online_1b4:
    cbz      w23, .Lmiop_on_peer_online_90
    ldr      x0, [x19, #48]
    bl       _text+0x20
    ldr      x0, [x19, #48]
    bl       netif_carrier_on
    b        .Lmiop_on_peer_online_90

.global miop_on_peer_offline
.type miop_on_peer_offline, @function
miop_on_peer_offline:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-48]!
    mov      w2, w1
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    mov      w20, #0xae8
    stp      x21, x22, [sp, #32]
    umull    x20, w1, w20
    mov      w21, w1
    ldr      x1, [x0, #120]
    add      x22, x20, #0xc8
    ldr      x19, [x1, #336]
    adrp     x1, _rodata_str1_1+0x165
    add      x1, x1, :lo12:_rodata_str1_1+0x165
    bl       _dev_info
    add      x22, x19, x22
    ldr      w0, [x19, #16]
    cmp      w0, w21
    b.ne     .Lmiop_on_peer_offline_230
    ldr      x0, [x19, #48]
    bl       netif_tx_stop_all_queues
    ldr      x0, [x19, #48]
    bl       netif_carrier_off
.Lmiop_on_peer_offline_230:
    add      x0, x20, #0xd0
    add      x0, x19, x0
    bl       napi_disable
    add      x0, x20, #0x260
    add      x0, x19, x0
    bl       napi_disable
    add      x0, x20, #0x908
    add      x0, x19, x0
    bl       del_timer_sync
    mov      x0, x22
    bl       _text+0x1d4
    add      x0, x20, #0x930
    mov      w22, w21
    add      x0, x19, x0
    bl       skb_queue_purge
    mov      x0, #0xae8
    add      x2, x20, #0xb88
    add      x2, x19, x2
    madd     x0, x22, x0, x19
    strb     wzr, [x0, #2985]
    adrp     x0, system_wq
    ldr      x1, [x0, :lo12:system_wq]
    mov      w0, #0x8
    bl       queue_work_on
    ldr      x1, [x19, #40]
    cbz      x1, .Lmiop_on_peer_offline_2b0
    ldr      w2, [x1, #20]
    mov      x0, #0x1
    lsl      x0, x0, x21
    bic      w0, w2, w0
    str      w0, [x1, #20]
    dsb      st
.Lmiop_on_peer_offline_2b0:
    mov      x0, #0xae8
    madd     x22, x22, x0, x19
    str      xzr, [x22, #1008]
    ldp      x19, x20, [sp, #16]
    ldp      x21, x22, [sp, #32]
    ldp      x29, x30, [sp], #48
    autiasp  
    ret      

.global init_module
.type init_module, @function
init_module:
    nop      
    nop      
    paciasp  
    sub      sp, sp, #0x70
    add      x3, sp, #0x8
    mrs      x0, sp_el0
    mov      x2, #0x40
    stp      x29, x30, [sp, #80]
    add      x29, sp, #0x50
    str      x19, [sp, #96]
    adrp     x19, _data
    add      x19, x19, :lo12:_data
    ldr      x1, [x0, #1336]
    str      x1, [sp, #72]
    mov      x1, #0x0
    mov      x0, x3
    bl       memset
    mov      x3, x0
    adrp     x1, _rodata
    add      x1, x1, :lo12:_rodata
    add      x6, x19, #0xa8
    mov      x4, x1
    mov      x2, #0x0
.Linit_module_5c:
    ldrb     w5, [x1]
    ldrb     w0, [x2, x6]
    eor      w0, w0, w5
    strb     w0, [x3, x2]
    ldrb     w0, [x1, #1]!
    add      x2, x2, #0x1
    cmp      w0, #0x0
    csel     x1, x1, x4, ne
    cmp      x2, #0x3f
    b.ne     .Linit_module_5c
    mov      x1, x3
    adrp     x0, _rodata_str1_1
    add      x0, x0, :lo12:_rodata_str1_1
    bl       _printk
    add      x0, x19, #0xe8
    bl       miop_register_ep_net_drv
    mrs      x0, sp_el0
    ldr      x2, [sp, #72]
    ldr      x1, [x0, #1336]
    subs     x2, x2, x1
    mov      x1, #0x0
    b.eq     .Linit_module_b8
    bl       __stack_chk_fail
.Linit_module_b8:
    ldp      x29, x30, [sp, #80]
    mov      w0, #0x0
    ldr      x19, [sp, #96]
    add      sp, sp, #0x70
    autiasp  
    ret      

.section .rodata.str1.1
.global _rodata_str1_1
_rodata_str1_1:
    .byte 0x01, 0x36, 0x25, 0x73, 0x0a, 0x00, 0x66, 0x69, 0x78, 0x65, 0x64, 0x20, 0x6d, 0x74, 0x75, 0x20
    .byte 0x25, 0x64, 0x20, 0x6f, 0x6e, 0x6c, 0x79, 0x2c, 0x20, 0x72, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74
    .byte 0x65, 0x64, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x52, 0x58, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x73, 0x6c
    .byte 0x6f, 0x74, 0x20, 0x25, 0x75, 0x3a, 0x20, 0x62, 0x6f, 0x67, 0x75, 0x73, 0x20, 0x6c, 0x65, 0x6e
    .byte 0x3d, 0x25, 0x75, 0x2c, 0x20, 0x64, 0x72, 0x6f, 0x70, 0x70, 0x69, 0x6e, 0x67, 0x0a, 0x00, 0x6f
    .byte 0x70, 0x65, 0x6e, 0x3a, 0x20, 0x64, 0x72, 0x69, 0x76, 0x65, 0x72, 0x5f, 0x70, 0x72, 0x69, 0x76
    .byte 0x20, 0x4e, 0x55, 0x4c, 0x4c, 0x20, 0xe2, 0x80, 0x94, 0x20, 0x70, 0x72, 0x6f, 0x62, 0x65, 0x20
    .byte 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x65, 0x61, 0x72, 0x6c, 0x69, 0x65, 0x72, 0x3f, 0x0a
    .byte 0x00, 0x6f, 0x70, 0x65, 0x6e, 0x3a, 0x20, 0x65, 0x70, 0x5f, 0x6e, 0x65, 0x74, 0x5f, 0x70, 0x72
    .byte 0x69, 0x76, 0x20, 0x4e, 0x55, 0x4c, 0x4c, 0x0a, 0x00, 0x62, 0x61, 0x72, 0x5f, 0x63, 0x74, 0x72
    .byte 0x6c, 0x40, 0x25, 0x70, 0x20, 0x69, 0x62, 0x5f, 0x63, 0x70, 0x75, 0x3d, 0x25, 0x70, 0x61, 0x64
    .byte 0x20, 0x69, 0x62, 0x5f, 0x70, 0x63, 0x69, 0x3d, 0x25, 0x70, 0x61, 0x64, 0x20, 0x69, 0x62, 0x5f
    .byte 0x73, 0x69, 0x7a, 0x65, 0x3d, 0x30, 0x78, 0x25, 0x78, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b
    .byte 0x25, 0x64, 0x5d, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x69, 0x6e, 0x69, 0x74, 0x69
    .byte 0x61, 0x6c, 0x65, 0x64, 0x0a, 0x00, 0x4e, 0x6f, 0x64, 0x65, 0x20, 0x6f, 0x6e, 0x6c, 0x69, 0x6e
    .byte 0x65, 0x3a, 0x20, 0x25, 0x78, 0x00, 0x44, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x6f, 0x72
    .byte 0x5b, 0x25, 0x64, 0x5d, 0x20, 0x43, 0x50, 0x55, 0x20, 0x61, 0x64, 0x64, 0x72, 0x65, 0x73, 0x73
    .byte 0x3a, 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x00, 0x44, 0x65, 0x73, 0x63, 0x72, 0x69, 0x70, 0x74, 0x6f
    .byte 0x72, 0x5b, 0x25, 0x64, 0x5d, 0x20, 0x50, 0x43, 0x49, 0x20, 0x61, 0x64, 0x64, 0x72, 0x65, 0x73
    .byte 0x73, 0x3a, 0x20, 0x25, 0x6c, 0x6c, 0x78, 0x00, 0x6e, 0x6f, 0x64, 0x65, 0x5f, 0x69, 0x64, 0x5b
    .byte 0x25, 0x64, 0x5d, 0x20, 0x69, 0x73, 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x63, 0x6f, 0x6e, 0x73, 0x69
    .byte 0x73, 0x74, 0x65, 0x6e, 0x74, 0x20, 0x77, 0x69, 0x74, 0x68, 0x20, 0x70, 0x65, 0x65, 0x72, 0x5b
    .byte 0x25, 0x64, 0x5d, 0x0a, 0x00, 0x4e, 0x6f, 0x64, 0x65, 0x20, 0x6f, 0x66, 0x66, 0x6c, 0x69, 0x6e
    .byte 0x65, 0x3a, 0x20, 0x25, 0x78, 0x00, 0x77, 0x61, 0x6b, 0x65, 0x20, 0x74, 0x78, 0x20, 0x71, 0x75
    .byte 0x65, 0x75, 0x65, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x65, 0x6e
    .byte 0x74, 0x72, 0x79, 0x20, 0x6e, 0x6f, 0x64, 0x65, 0x5f, 0x69, 0x64, 0x20, 0x6d, 0x69, 0x73, 0x6d
    .byte 0x61, 0x74, 0x63, 0x68, 0x3a, 0x20, 0x70, 0x65, 0x3d, 0x25, 0x75, 0x20, 0x65, 0x78, 0x70, 0x65
    .byte 0x63, 0x74, 0x65, 0x64, 0x3d, 0x25, 0x75, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75
    .byte 0x5d, 0x20, 0x72, 0x78, 0x5f, 0x72, 0x65, 0x67, 0x69, 0x6f, 0x6e, 0x5b, 0x25, 0x75, 0x5d, 0x20
    .byte 0x68, 0x61, 0x73, 0x20, 0x6e, 0x6f, 0x20, 0x6c, 0x6f, 0x63, 0x61, 0x6c, 0x20, 0x56, 0x41, 0x0a
    .byte 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x52, 0x43, 0x20, 0x65, 0x6e, 0x74
    .byte 0x72, 0x79, 0x20, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6e, 0x67, 0x20, 0x72, 0x69, 0x6e, 0x67, 0x20
    .byte 0x64, 0x6d, 0x61, 0x3d, 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x62, 0x79, 0x74, 0x65, 0x73
    .byte 0x3d, 0x30, 0x78, 0x25, 0x78, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20
    .byte 0x6d, 0x61, 0x70, 0x5f, 0x70, 0x65, 0x65, 0x72, 0x5f, 0x62, 0x61, 0x72, 0x20, 0x66, 0x61, 0x69
    .byte 0x6c, 0x65, 0x64, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x70, 0x75
    .byte 0x62, 0x6c, 0x69, 0x73, 0x68, 0x65, 0x64, 0x20, 0x62, 0x6f, 0x67, 0x75, 0x73, 0x20, 0x72, 0x69
    .byte 0x6e, 0x67, 0x5f, 0x6f, 0x66, 0x66, 0x73, 0x65, 0x74, 0x20, 0x30, 0x78, 0x25, 0x78, 0x20, 0xe2
    .byte 0x80, 0x94, 0x20, 0x62, 0x61, 0x69, 0x6c, 0x0a, 0x00, 0x74, 0x78, 0x20, 0x73, 0x74, 0x61, 0x67
    .byte 0x69, 0x6e, 0x67, 0x3a, 0x20, 0x6d, 0x69, 0x73, 0x73, 0x69, 0x6e, 0x67, 0x20, 0x6d, 0x69, 0x6f
    .byte 0x70, 0x2c, 0x74, 0x78, 0x2d, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x2d, 0x72, 0x65, 0x67
    .byte 0x69, 0x6f, 0x6e, 0x0a, 0x00, 0x74, 0x78, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x3a
    .byte 0x20, 0x69, 0x6e, 0x76, 0x61, 0x6c, 0x69, 0x64, 0x20, 0x73, 0x6c, 0x6f, 0x74, 0x5f, 0x63, 0x6f
    .byte 0x75, 0x6e, 0x74, 0x3d, 0x25, 0x75, 0x0a, 0x00, 0x74, 0x78, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69
    .byte 0x6e, 0x67, 0x3a, 0x20, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x73, 0x6c, 0x69
    .byte 0x63, 0x65, 0x20, 0x6f, 0x75, 0x74, 0x73, 0x69, 0x64, 0x65, 0x20, 0x72, 0x65, 0x73, 0x65, 0x72
    .byte 0x76, 0x65, 0x64, 0x20, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x20, 0x6f, 0x66, 0x66, 0x73, 0x65
    .byte 0x74, 0x3d, 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x62, 0x79, 0x74, 0x65, 0x73, 0x3d, 0x30
    .byte 0x78, 0x25, 0x6c, 0x6c, 0x78, 0x20, 0x74, 0x6f, 0x74, 0x61, 0x6c, 0x3d, 0x30, 0x78, 0x25, 0x6c
    .byte 0x6c, 0x78, 0x0a, 0x00, 0x25, 0x73, 0x20, 0x25, 0x73, 0x3a, 0x20, 0x72, 0x65, 0x6a, 0x65, 0x63
    .byte 0x74, 0x69, 0x6e, 0x67, 0x20, 0x44, 0x4d, 0x41, 0x20, 0x6d, 0x61, 0x70, 0x20, 0x6f, 0x66, 0x20
    .byte 0x76, 0x6d, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x20, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x0a, 0x00
    .byte 0x74, 0x78, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x3a, 0x20, 0x70, 0x65, 0x65, 0x72
    .byte 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x64, 0x6d, 0x61, 0x5f, 0x6d, 0x61, 0x70, 0x5f, 0x73, 0x69, 0x6e
    .byte 0x67, 0x6c, 0x65, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20, 0x70, 0x68, 0x79, 0x73, 0x3d
    .byte 0x25, 0x70, 0x61, 0x20, 0x62, 0x79, 0x74, 0x65, 0x73, 0x3d, 0x30, 0x78, 0x25, 0x6c, 0x6c, 0x78
    .byte 0x0a, 0x00, 0x74, 0x78, 0x20, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x3a, 0x20, 0x70, 0x65
    .byte 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x72, 0x65, 0x73, 0x65, 0x72, 0x76, 0x65, 0x64, 0x20
    .byte 0x70, 0x68, 0x79, 0x73, 0x3d, 0x25, 0x70, 0x61, 0x20, 0x64, 0x6d, 0x61, 0x3d, 0x25, 0x70, 0x61
    .byte 0x64, 0x20, 0x63, 0x70, 0x75, 0x3d, 0x25, 0x70, 0x20, 0x62, 0x79, 0x74, 0x65, 0x73, 0x3d, 0x30
    .byte 0x78, 0x25, 0x78, 0x20, 0x73, 0x6c, 0x6f, 0x74, 0x73, 0x3d, 0x25, 0x75, 0x0a, 0x00, 0x70, 0x65
    .byte 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x6e, 0x65, 0x77, 0x2d, 0x61, 0x72, 0x63, 0x68, 0x20
    .byte 0x69, 0x6e, 0x69, 0x74, 0x3a, 0x20, 0x72, 0x78, 0x5f, 0x69, 0x64, 0x78, 0x3d, 0x25, 0x75, 0x20
    .byte 0x28, 0x73, 0x6c, 0x6f, 0x74, 0x73, 0x3d, 0x25, 0x75, 0x29, 0x20, 0x74, 0x78, 0x5f, 0x69, 0x64
    .byte 0x78, 0x3d, 0x25, 0x75, 0x20, 0x28, 0x73, 0x6c, 0x6f, 0x74, 0x73, 0x3d, 0x25, 0x75, 0x29, 0x20
    .byte 0x70, 0x65, 0x65, 0x72, 0x5f, 0x62, 0x61, 0x72, 0x5f, 0x76, 0x61, 0x3d, 0x25, 0x70, 0x20, 0x70
    .byte 0x65, 0x65, 0x72, 0x5f, 0x62, 0x61, 0x72, 0x5f, 0x64, 0x6d, 0x61, 0x3d, 0x25, 0x70, 0x61, 0x64
    .byte 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x6e, 0x65, 0x77, 0x2d, 0x61
    .byte 0x72, 0x63, 0x68, 0x20, 0x69, 0x6e, 0x69, 0x74, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x20
    .byte 0x28, 0x25, 0x64, 0x29, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72, 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x61
    .byte 0x6c, 0x6c, 0x6f, 0x63, 0x5f, 0x74, 0x78, 0x5f, 0x73, 0x74, 0x61, 0x67, 0x69, 0x6e, 0x67, 0x5f
    .byte 0x70, 0x6f, 0x6f, 0x6c, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a
    .byte 0x00, 0x6e, 0x65, 0x77, 0x2d, 0x74, 0x78, 0x5b, 0x25, 0x75, 0x5d, 0x3a, 0x20, 0x64, 0x6d, 0x61
    .byte 0x20, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73, 0x3d, 0x25, 0x64, 0x2c, 0x20, 0x72, 0x65, 0x70, 0x61
    .byte 0x69, 0x72, 0x65, 0x64, 0x20, 0x73, 0x6c, 0x6f, 0x74, 0x20, 0x25, 0x75, 0x20, 0x62, 0x79, 0x20
    .byte 0x43, 0x50, 0x55, 0x20, 0x63, 0x6f, 0x70, 0x79, 0x0a, 0x00, 0x6e, 0x65, 0x77, 0x2d, 0x74, 0x78
    .byte 0x5b, 0x25, 0x75, 0x5d, 0x3a, 0x20, 0x64, 0x6d, 0x61, 0x20, 0x73, 0x74, 0x61, 0x74, 0x75, 0x73
    .byte 0x3d, 0x25, 0x64, 0x2c, 0x20, 0x63, 0x61, 0x6e, 0x6e, 0x6f, 0x74, 0x20, 0x72, 0x65, 0x70, 0x61
    .byte 0x69, 0x72, 0x20, 0x73, 0x6c, 0x6f, 0x74, 0x20, 0x25, 0x75, 0x20, 0x6c, 0x65, 0x6e, 0x3d, 0x25
    .byte 0x75, 0x0a, 0x00, 0x61, 0x6c, 0x6c, 0x6f, 0x63, 0x5f, 0x65, 0x74, 0x68, 0x65, 0x72, 0x64, 0x65
    .byte 0x76, 0x5f, 0x6d, 0x71, 0x73, 0x28, 0x29, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x0a, 0x00
    .byte 0x26, 0x70, 0x72, 0x69, 0x76, 0x2d, 0x3e, 0x62, 0x65, 0x6e, 0x63, 0x68, 0x5f, 0x6c, 0x6f, 0x63
    .byte 0x6b, 0x00, 0x70, 0x63, 0x69, 0x25, 0x64, 0x00, 0x26, 0x6c, 0x69, 0x73, 0x74, 0x2d, 0x3e, 0x6c
    .byte 0x6f, 0x63, 0x6b, 0x00, 0x6e, 0x65, 0x74, 0x69, 0x66, 0x5f, 0x73, 0x65, 0x74, 0x5f, 0x72, 0x65
    .byte 0x61, 0x6c, 0x5f, 0x6e, 0x75, 0x6d, 0x5f, 0x74, 0x78, 0x5f, 0x71, 0x75, 0x65, 0x75, 0x65, 0x73
    .byte 0x28, 0x29, 0x20, 0x66, 0x61, 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6e
    .byte 0x65, 0x74, 0x69, 0x66, 0x5f, 0x73, 0x65, 0x74, 0x5f, 0x72, 0x65, 0x61, 0x6c, 0x5f, 0x6e, 0x75
    .byte 0x6d, 0x5f, 0x72, 0x78, 0x5f, 0x71, 0x75, 0x65, 0x75, 0x65, 0x73, 0x28, 0x29, 0x20, 0x66, 0x61
    .byte 0x69, 0x6c, 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x72, 0x65, 0x67, 0x69, 0x73, 0x74
    .byte 0x65, 0x72, 0x5f, 0x6e, 0x65, 0x74, 0x64, 0x65, 0x76, 0x28, 0x29, 0x20, 0x66, 0x61, 0x69, 0x6c
    .byte 0x65, 0x64, 0x3a, 0x20, 0x25, 0x64, 0x0a, 0x00, 0x6e, 0x6f, 0x20, 0x73, 0x75, 0x63, 0x68, 0x20
    .byte 0x70, 0x65, 0x65, 0x72, 0x20, 0x77, 0x69, 0x74, 0x68, 0x20, 0x6d, 0x61, 0x63, 0x68, 0x69, 0x6e
    .byte 0x65, 0x20, 0x69, 0x64, 0x3a, 0x20, 0x25, 0x30, 0x38, 0x78, 0x0a, 0x00, 0x70, 0x65, 0x65, 0x72
    .byte 0x5b, 0x25, 0x75, 0x5d, 0x20, 0x6e, 0x65, 0x77, 0x20, 0x70, 0x61, 0x74, 0x68, 0x20, 0x69, 0x73
    .byte 0x20, 0x6e, 0x6f, 0x74, 0x20, 0x72, 0x65, 0x61, 0x64, 0x79, 0x20, 0x66, 0x6f, 0x72, 0x20, 0x74
    .byte 0x78, 0x0a, 0x00, 0x73, 0x6b, 0x62, 0x5f, 0x63, 0x6c, 0x6f, 0x6e, 0x65, 0x28, 0x29, 0x20, 0x66
    .byte 0x61, 0x69, 0x6c, 0x65, 0x64, 0x2e, 0x00, 0x01, 0x36, 0x00, 0x6d, 0x69, 0x6f, 0x70, 0x5f, 0x65
    .byte 0x70, 0x5f, 0x6e, 0x65, 0x74, 0x00, 0x2f, 0x68, 0x6f, 0x6d, 0x65, 0x2f, 0x61, 0x64, 0x61, 0x6d
    .byte 0x2f, 0x77, 0x6f, 0x72, 0x6b, 0x2f, 0x6d, 0x69, 0x6f, 0x70, 0x2f, 0x6c, 0x69, 0x6e, 0x75, 0x78
    .byte 0x2d, 0x64, 0x72, 0x69, 0x76, 0x65, 0x72, 0x73, 0x2f, 0x6d, 0x69, 0x6f, 0x70, 0x2d, 0x65, 0x70
    .byte 0x2d, 0x6e, 0x65, 0x74, 0x2e, 0x63, 0x00

.section .rodata
.align 3
.global _rodata
_rodata:
    // Offset 0x0000: Magic/Versions
    .byte 0x10, 0x1b, 0xca, 0x0a, 0xa3, 0x19, 0x0d, 0x00
    
    // Offset 0x0008: Strings
    .asciz "miop_ep_poll_new"
    .asciz "miop_reap_tx_done_new"
    
    .align 3
    // Offset 0x0030 to 0x003F: Padding
    .space 16, 0

    // Offset 0x0040 to 0x0057: Core Network Pointers (struct net_device_ops)
    .quad miop_ndo_open
    .quad miop_ndo_stop
    .quad miop_ndo_start_xmit

    // Offset 0x0058 to 0x00B7: Padding
    .space 96, 0

    // Offset 0x00B8 to 0x00BF: Final Network Pointer
    .quad miop_ndo_change_mtu

    // Offset 0x00C0 to 0x02A7: Empty space
    .space 488, 0

    // Offset 0x02A8 to End: Trailing NAPI/Tx Strings
    .asciz "miop_ndo_start_xmit"
    .asciz "miop_on_tx_ready"

.section .rodata
.align 3
driver_name_str:
    .asciz "miop-ep-net"

.section .data
.align 3
.global _data
_data:
    // Raw network platform structure prefix
    .byte 0x40, 0x79, 0x63, 0xbe, 0x63, 0xcf, 0x7c, 0x2d, 0x44, 0x58, 0x9a, 0x25, 0xea, 0x49, 0x2d, 0x7f
    .byte 0x6d, 0xaf, 0x78, 0x83, 0x49, 0x4e, 0x59, 0x7e, 0xea, 0x6f, 0xcd, 0x7d, 0x7d, 0x7f, 0x72, 0xa4
    .byte 0x7e, 0x83, 0x77, 0x68, 0x64, 0x7f, 0xaf, 0x7c, 0xca, 0x7a, 0x68, 0x30, 0x7f, 0xb8, 0x63, 0xd5
    .byte 0x7c, 0x7f, 0x30, 0x7e, 0xb2, 0x63, 0xd7, 0x00, 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde
    .byte 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    .byte 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x5d, 0x72, 0xb2, 0x7e, 0xca, 0x75, 0x68, 0x30
    .byte 0x4f, 0x89, 0x5a, 0x8c, 0x50, 0x5d, 0x30, 0x74, 0xbc, 0x6f, 0xd1, 0x39, 0x5d, 0x53, 0x52, 0xaf
    .byte 0x2a, 0xc6, 0x77, 0x69, 0x60, 0x74, 0xa3, 0x64, 0xd7, 0x39, 0x63, 0x75, 0x6f, 0xae, 0x6f, 0xd5
    .byte 0x70, 0x6e, 0x75, 0x3b, 0xae, 0x78, 0xca, 0x6f, 0x68, 0x62, 0x3b, 0xa3, 0x64, 0xca, 0x6d, 0x64
    .byte 0x71, 0x77, 0xa3, 0x70, 0xca, 0x77, 0x6a, 0x00

    // Struct Pointers (Native GCC Symbols)
    .quad miop_ep_net_init
    .quad miop_ep_net_deinit
    .quad miop_on_peer_online
    .quad miop_on_peer_offline
    .quad miop_on_rx
    .quad miop_on_tx_ready
    .quad miop_on_rx_full

    // Raw network platform structure suffix
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde
    .byte 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    .byte 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde
    .byte 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    .byte 0xdc, 0x05, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

.section .bss
.align 3
.global _bss
_bss:

.section .data.once
.align 3
.global _data_once
_data_once:

.section .data.dyndbg
.align 3
.global __dyndbg
__dyndbg:
