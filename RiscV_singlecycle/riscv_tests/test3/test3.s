.section .text
.globl _start

_start:
    lui   x1, 0x12345      # x1 = 0x12345000
    auipc x2, 0x1            # x2 = pc(0x4) + 0x1000 = 0x00001004
    auipc x3, 0                # x3 = pc(0x8) + 0 = 0x00000008
    lui   x4, 0xFFFFF            # x4 = 0xFFFFF000 (top-bit pattern, no sign issues in LUI itself)

loop: jal x0, loop