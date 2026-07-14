.section .text
.global _text
_text:

.global miop_register_pcie_ep_drv
.type miop_register_pcie_ep_drv, @function
miop_register_pcie_ep_drv:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    adrp     x20, _data
    add      x20, x20, :lo12:_data
    mov      x19, x0
    mov      x0, x20
    bl       mutex_lock
    adrp     x0, _bss
    cbz      x19, .Lmiop_register_pcie_ep_drv_54
    str      x19, [x0, :lo12:_bss]
.Lmiop_register_pcie_ep_drv_38:
    mov      x0, x20
    bl       mutex_unlock
    mov      x0, x19
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_register_pcie_ep_drv_54:
    ldr      x19, [x0, :lo12:_bss]
    b        .Lmiop_register_pcie_ep_drv_38

.global miop_register_ep_net_drv
.type miop_register_ep_net_drv, @function
miop_register_ep_net_drv:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    adrp     x20, _data
    add      x20, x20, :lo12:_data
    mov      x19, x0
    mov      x0, x20
    bl       mutex_lock
    adrp     x0, _bss
    add      x0, x0, :lo12:_bss
    cbz      x19, .Lmiop_register_ep_net_drv_b4
    str      x19, [x0, #8]
.Lmiop_register_ep_net_drv_98:
    mov      x0, x20
    bl       mutex_unlock
    mov      x0, x19
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_register_ep_net_drv_b4:
    ldr      x19, [x0, #8]
    b        .Lmiop_register_ep_net_drv_98

.global miop_register_is_ready
.type miop_register_is_ready, @function
miop_register_is_ready:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-32]!
    mov      x29, sp
    stp      x19, x20, [sp, #16]
    adrp     x19, _data
    add      x19, x19, :lo12:_data
    mov      x0, x19
    bl       mutex_lock
    adrp     x0, _bss
    add      x1, x0, :lo12:_bss
    ldr      x0, [x0, :lo12:_bss]
    cbz      x0, .Lmiop_register_is_ready_11c
    ldr      x0, [x1, #8]
    cmp      x0, #0x0
    cset     w20, ne
.Lmiop_register_is_ready_100:
    mov      x0, x19
    bl       mutex_unlock
    mov      w0, w20
    ldp      x19, x20, [sp, #16]
    ldp      x29, x30, [sp], #32
    autiasp  
    ret      
.Lmiop_register_is_ready_11c:
    mov      w20, #0x0
    b        .Lmiop_register_is_ready_100

.global miop_free_dma_skb_head
.type miop_free_dma_skb_head, @function
miop_free_dma_skb_head:
    nop      
    nop      
    mov      x4, x1
    paciasp  
    stp      x29, x30, [sp, #-16]!
    mov      x1, x2
    mov      x5, #0xfffffc0000000000
    mov      x29, sp
    ldr      x2, [x4, #200]
    mov      x4, #0x1000000000000
    add      x2, x2, x4
    mov      w4, #0x2
    lsr      x2, x2, #12
    add      x2, x5, x2, lsl #6
    bl       dma_free_pages
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global init_module
.type init_module, @function
init_module:
    nop      
    nop      
    paciasp  
    stp      x29, x30, [sp, #-16]!
    adrp     x0, _rodata_str1_1
    mov      x29, sp
    add      x0, x0, :lo12:_rodata_str1_1
    bl       _printk
    mov      w0, #0x0
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      

.global cleanup_module
.type cleanup_module, @function
cleanup_module:
    paciasp  
    stp      x29, x30, [sp, #-16]!
    adrp     x0, _rodata_str1_1+0x33
    mov      x29, sp
    add      x0, x0, :lo12:_rodata_str1_1+0x33
    bl       _printk
    ldp      x29, x30, [sp], #16
    autiasp  
    ret      
.section .rodata.str1.1
.global _rodata_str1_1
_rodata_str1_1:
    .byte 0x01, 0x36, 0x4d, 0x69, 0x78, 0x74, 0x69, 0x6c, 0x65, 0x20, 0x54, 0x43, 0x50, 0x2f, 0x49, 0x50
    .byte 0x20, 0x6f, 0x76, 0x65, 0x72, 0x20, 0x50, 0x43, 0x49, 0x65, 0x20, 0x64, 0x65, 0x76, 0x69, 0x63
    .byte 0x65, 0x20, 0x64, 0x72, 0x69, 0x76, 0x65, 0x72, 0x20, 0x72, 0x65, 0x67, 0x69, 0x73, 0x74, 0x72
    .byte 0x79, 0x0a, 0x00, 0x01, 0x36, 0x4d, 0x69, 0x78, 0x74, 0x69, 0x6c, 0x65, 0x20, 0x54, 0x43, 0x50
    .byte 0x2f, 0x49, 0x50, 0x20, 0x6f, 0x76, 0x65, 0x72, 0x20, 0x50, 0x43, 0x49, 0x65, 0x20, 0x64, 0x65
    .byte 0x76, 0x69, 0x63, 0x65, 0x20, 0x64, 0x72, 0x69, 0x76, 0x65, 0x72, 0x20, 0x72, 0x65, 0x67, 0x69
    .byte 0x73, 0x74, 0x72, 0x79, 0x20, 0x65, 0x78, 0x69, 0x74, 0x0a, 0x00

.section .rodata
.align 3
driver_name_str:
    .asciz "miop-reg"

.section .data
.align 3
.global _data
_data:
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    .byte 0x00, 0x00, 0x00, 0x00, 0xad, 0x4e, 0xad, 0xde
    .byte 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00
    .byte 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff
    .byte 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

    .quad _data + 0x28
    .quad _data + 0x28

.section .bss
.align 3
.global _bss
_bss:
    .space 16, 0
