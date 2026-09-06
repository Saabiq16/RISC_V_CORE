.section .text
.globl _start

_start:
addi x0, x0, 5           # attempt to corrupt x0 -- must have NO effect
add  x1, x0, x0             # x1 = 0+0 = 0, proves x0 reads as 0 even after write attempt
addi x2, x0, 1                # x2 = 1, nonzero baseline for comparison elsewhere

addi x3, x0, 0                  # x3 = 0x00000000
addi x4, x0, -1                   # x4 = 0xFFFFFFFF
lui  x5, 0x80000                    # x5 = 0x80000000 (INT_MIN)
lui  x6, 0x80000                      # x6 = 0x80000000
addi x6, x6, -1                        # x6 = 0x80000000 - 1 = 0x7FFFFFFF (INT_MAX)

add  x7, x5, x5              # INT_MIN + INT_MIN = 0x100000000 mod 2^32 = 0x00000000
add  x8, x6, x2                # INT_MAX + 1 = 0x80000000 (wraps to INT_MIN)

addi x9,  x0, 0             # base address 0 (lowest valid address)
addi x10, x0, 1000            # base address 1000 (near highest valid word address, <=1020)
sw   x4, 0(x9)                  # store 0xFFFFFFFF at address 0
sw   x5, 0(x10)                   # store 0x80000000 at address 1000
lw   x11, 0(x9)                     # reload from address 0
lw   x12, 0(x10)                      # reload from address 1000

blt  x5, x6, edge_blt_taken       # INT_MIN < INT_MAX -> should branch
addi x20, x0, 99
jal  x0, edge_blt_done
edge_blt_taken:
addi x20, x0, 1                    # x20=1 confirms signed compare correct at extremes
edge_blt_done:

beq  x0, x3, edge_beq_taken          # 0 == 0 (from two different sources) -> should branch
addi x21, x0, 99
jal  x0, edge_beq_done
edge_beq_taken:
addi x21, x0, 1                        # x21=1 confirms zero-equality across sources
edge_beq_done:

jal  x0, edge_jump_target
addi x22, x0, 99                # should be SKIPPED
edge_jump_target:
addi x22, x0, 1                   # x22=1 confirms unconditional jump landed correctly

addi x13, x0, 7            # x13 = 7
addi x14, x13, 1              # x14 = x13+1 = 8
add  x15, x14, x14              # x15 = x14+x14 = 16

loop: jal x0, loop
