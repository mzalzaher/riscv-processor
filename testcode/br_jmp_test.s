.section .text
.globl _start
_start:

    auipc   x1, 0
    #nop
    #nop
    #lui     x2, 0xAA55A
    #addi    x1, x0, 0
    nop
    auipc   x25, 0
    addi    x23, x0, 0
    nop
    auipc   x2, 0x7     # 7117
    addi	x2,x2,-128  # f801 0113
    auipc   x7, 0x7     # 7397
    addi	x7,x7,1876  # 7543 ...
    beq	    x2,x7, end  # 2071 ...
    nop
    nop
    nop
    nop
    addi    x23, x0, 0
    jal     x25, loop
    #lw      x27, -4(x2)

    lw      x3, 0(x1)
    nop
    la      x4, mem_start
    la      x5, mem_end
    nop
    nop
    nop
    nop
    #addi    x23, x0, 0
    #jal     x25, loop_neg
    #add     x4, x3, 12
    nop
    nop
    nop
    nop
    nop
    lhu     x16, 6(x1)
    nop
    nop
    nop
    nop
    nop
    #sw      x16, 0(x1)
    nop
    nop
    nop
    nop
    nop
    add     x4, x3, 12
    lbu     x16, 8(x1)
    nop
    nop
    nop
    nop
    nop
    addi    x30, x1, 24
    nop
    nop
    nop
    nop
    nop
    lbu     x16, -8(x30)
    nop
    nop
    nop
    nop
    nop
    sw      x3, 0(x1)
    nop
    nop
    nop
    nop
    nop
    #add     x8, x1, x0
    sw      x16, 0(x1)
    nop
    nop
    nop
    nop
    nop
    nop
    #lw      x6, some_data_1
    nop
    nop
    la      x22, mem_end
    sw      x3, 0(x22)



    # li	x26,1
    # mv	x15,x8
    # j	aaaad4dc <core_bench_list+0x80>
    # lw	x15,0(x15)
    # beqz	x15,aaaad5d8 <core_bench_list+0x17c>
    # lw	x14,4(x15)
    # lh	x12,2(x14)
    # bne	x12,x26,aaaad4d4



    sh      x4, 0(x1)
    lw      x8, 0(x1)
    #addi    x8, x8, 3
    nop
    nop
    nop
    nop
    nop
    nop
    # la      x6, some_data_1
    lw      x6, 0(x1)
    #sw      x6, some_data_2, x7
    #bne     x1, x2, end
    nop
    nop
    nop
    nop
    nop
    addi x1, x0, 4
    nop             # nops in between to prevent hazard
    nop
    nop
    nop
    nop

    addi x1, x1, -16
    nop
    nop
    nop
    nop
    nop

    auipc x28, 0
    nop
    nop
    nop
    nop
    nop

    andi x3, x1, 8
    nop
    nop
    nop
    nop
    nop

    lui x3, 144
    nop
    nop
    nop
    nop
    nop

    add x6, x1, x3
    nop
    nop
    nop
    nop
    nop
    nop

    sw      x8, 0(x28)
    nop
    nop
    nop
    nop
    nop
    

    sh      x6, 0(x28)
    nop
    nop
    nop
    nop
    nop


end:

    slti x0, x0, -256

loop:
    lw      x3, 0(x1)

    #lh      x27, 0(x23)
    addi x24, x0, 6
    addi x23, x23, 1
    nop
    nop
    nop
    nop
    nop

    bltu x23, x24, loop
    nop
    nop
    nop
    nop
    nop
    jr x25


loop_neg:
    addi x24, x0, -32
    addi x23, x23, -1
    nop
    nop
    nop
    nop
    nop
    

    bgeu x23, x24, loop_neg
    nop
    nop
    nop
    nop
    nop
    ret

.section .data


mem_start:
    .word   0xAAAA9000
mem_end:
    .word   0xAAAAF000
some_data_1:
    .word   0xAAAAA000
some_data_2:
    .half   0x0000
    .byte   0x00
    .byte   0x00
