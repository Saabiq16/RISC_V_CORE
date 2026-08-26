.section .text
.globl _start

_start:
    # ===== Test 1: Basic JALR, rs1 far from pc_current, imm=0 =====
    la   x1, target1
    jalr x2, x1, 0                 # target = x1; link x2 = pc+4 of THIS instr
    addi x10, x0, 99                # should be SKIPPED
    jal  x0, skip1
target1:
    addi x10, x0, 1                 # x10=1 confirms JALR used rs1, not pc
skip1:

    # ===== Test 2: JALR with a real nonzero immediate =====
    # Use la to get NEAR target2, then approach it via a small,
    # independently-known immediate rather than guessing byte counts.
    # x3 points 4 bytes BEFORE target2 (one instruction earlier),
    # so imm=4 must be correctly added to land exactly on target2.
    la   x3, before_target2
    jalr x4, x3, 4                  # target = before_target2_addr + 4 = target2_addr
    addi x11, x0, 99                 # should be SKIPPED
    jal  x0, skip2
before_target2:
    addi x0, x0, 0                    # dummy instr, exactly 4 bytes before target2
target2:
    addi x11, x0, 1                    # x11=1 confirms imm=4 was correctly added
skip2:

    # ===== Test 3: LSB-clear check =====
    # rs1 + imm is deliberately ODD (imm=1 on a word-aligned address).
    # Per spec, JALR must clear bit 0 before using the result as PC.
    la   x5, target3
    jalr x6, x5, 1                   # target = (x5 + 1) & ~1 = x5 exactly
    addi x12, x0, 99                  # should be SKIPPED
    jal  x0, skip3
target3:
    addi x12, x0, 1                   # x12=1 confirms LSB was correctly cleared
skip3:

    # ===== Test 4: Link value correctness =====
jalr4:
    la   x7, target4
    jalr x8, x7, 0                   # x8 must equal address(this jalr instr) + 4
    addi x13, x0, 99
    jal  x0, skip4
target4:
    addi x13, x0, 1
skip4:

loop: jal x0, loop