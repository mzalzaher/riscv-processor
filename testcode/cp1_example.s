.section .text
.globl _start
_start:

    addi    x1, x0, 4
    addi    x1, x1, 4
    addi    x1, x2, 4
    addi    x1, x3, 4
    addi    x1, x4, 4
    addi    x1, x5, 4
    addi    x1, x6, 4
    addi    x1, x7, 4
    addi    x1, x8, 4
    addi    x1, x9, 4
    addi    x1, x10, 4
    addi    x1, x11, 4
    addi    x1, x12, 4
    addi    x1, x13, 4
    addi    x1, x14, 4
    addi    x1, x15, 4
    addi    x1, x16, 4
    addi    x1, x17, 4
    addi    x1, x18, 4
    addi    x1, x19, 4
    addi    x1, x20, 4
    addi    x1, x21, 4
    addi    x1, x22, 4
    addi    x1, x23, 4
    addi    x1, x24, 4
    addi    x1, x25, 4
    addi    x1, x26, 4
    addi    x1, x27, 4
    addi    x1, x28, 4
    addi    x1, x29, 4
    addi    x1, x30, 4
    addi    x1, x31, 4





    addi    x3, x0, 8
    ADDI      	x26, x31, -857
	ADDI      	x26, x22, -961
	OR        	x7, x3, x31
	SLTI      	x6, x15, -408
	AUIPC     	x22, 544440
	LUI       	x7, 554948
	SRLI      	x15, x16, 4
	OR        	x22, x31, x7
	SLTU      	x30, x23, x7
	LUI       	x5, 251789
	SRLI      	x15, x4, 30
	ANDI      	x7, x5, -228
	SRAI      	x17, x1, 28
	SLL       	x24, x5, x7
	XOR       	x12, x15, x17
	XORI      	x17, x31, 570
	ORI       	x21, x15, -1019
	ANDI      	x5, x13, 772
	SRA       	x22, x17, x4
	SRLI      	x1, x22, 0
	SRA       	x21, x17, x15
	SLTI      	x16, x6, 1892
	ORI       	x5, x15, 55
	ADDI      	x30, x3, -610
	SLL       	x31, x17, x7
	XOR       	x21, x13, x7
	AND       	x7, x7, x26
	SRLI      	x12, x5, 8
	SLTU      	x17, x24, x4
	ADDI      	x29, x7, -272
	OR        	x17, x26, x1
	SUB       	x21, x17, x23
	ANDI      	x12, x17, -808
	SLT       	x3, x3, x31
	SRA       	x4, x30, x26
	SLTI      	x23, x15, 262
	SRL       	x15, x29, x5
	SUB       	x30, x17, x13
	LUI       	x12, 200495
	XOR       	x15, x15, x31
	SRL       	x22, x15, x31
	SRLI      	x22, x29, 25
	AUIPC     	x23, 988555
	AUIPC     	x31, 552204
	XOR       	x5, x31, x18
	SRLI      	x5, x5, 4
	ORI       	x30, x3, -119
	ADD       	x4, x21, x5
	AUIPC     	x3, 863841
	ADD       	x6, x29, x7
	XOR       	x24, x23, x26
	ORI       	x5, x31, -521
	SRAI      	x17, x29, 5
	AND       	x15, x7, x30
	SLLI      	x12, x24, 8
	AUIPC     	x21, 795844
	ANDI      	x22, x4, -486
	LUI       	x24, 599704
	SRL       	x30, x5, x5
	ADD       	x24, x7, x12
	ANDI      	x17, x21, 481
	SRA       	x26, x4, x30
	AUIPC     	x24, 25915
	SRLI      	x26, x22, 6
	AND       	x15, x5, x7
	ADD       	x5, x4, x3
	SRLI      	x3, x26, 24
	ORI       	x6, x16, 1626
	SRAI      	x17, x3, 31
	SLL       	x7, x22, x13
	SLTU      	x22, x3, x15
	ADDI      	x5, x26, 115
	SRA       	x6, x3, x6
	SLL       	x7, x3, x15
	SLTI      	x16, x26, -262
	SRL       	x7, x7, x22
	SLL       	x15, x5, x31
	ADD       	x15, x21, x5
	LUI       	x26, 648842
	ANDI      	x22, x17, 123
	XOR       	x29, x23, x3
	SRAI      	x12, x7, 7
	XOR       	x6, x26, x22
	SLTIU     	x16, x26, -936
	ADD       	x31, x5, x22
	ADD       	x7, x4, x17
	SLL       	x5, x15, x30
	SRA       	x23, x6, x17
	ADDI      	x1, x12, 313
	SLLI      	x16, x15, 17

    slti    x0, x0, -256    # this is the magic instruction to end the simulation
                            # preventing fetching illegal instructions