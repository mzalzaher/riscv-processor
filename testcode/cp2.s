.section .text
.globl _start
_start:
    lui x3, %hi(data_array)
    addi x3, x3, %lo(data_array)
    li x25, 20025
    sh x25, 4(x3)
    sll x19, x22, x12
    and x30, x25, x21
    auipc x27, 93108
    add x18, x22, x14
    slti x26, x2, -951
    lw x19, 4(x3)
    slti x0, x0, -256

.section .data
.align 2
data_array: .word 0xDEADBEEF, 0x12345678, 0xCAFEBABE, 0x0BADF00D