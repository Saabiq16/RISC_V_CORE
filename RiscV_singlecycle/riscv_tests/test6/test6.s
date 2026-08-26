.section .text
.globl _start

_start:
    # ===== Basic forward JAL =====
    # This JAL is at address 0x0. pc+4 = 0x4, so x1 should get 0x00000004.
    jal x1, jal_target            # x1 = link (pc+4), jump to jal_target
    addi x10, x0, 99              # should be SKIPPED
jal_target:
    addi x10, x0, 1               # x10=1 confirms JAL actually jumped

    # ===== JAL with x0 (unconditional jump, discard link) =====
    # x0 must stay 0 even though JAL tries to write pc+4 into it --
    # this checks your register file's hardwired-zero enforcement
    # interacting correctly with the JAL write-enable path.
    jal x0, jal_x0_target
    addi x11, x0, 99              # should be SKIPPED
jal_x0_target:
    addi x11, x0, 1               # x11=1 confirms jump-with-x0 worked
    addi x12, x0, 1               # sentinel: check x0 below via a compare, not directly

    # x0 sanity check: add x0 to something known and confirm it's still 0
    addi x13, x0, 5
    add  x14, x13, x0             # x14 = x13 + 0 = 5, only correct if x0 is truly 0

    # ===== Link-address arithmetic check =====
    # jal2 sits at a known offset; verify x2 == exact pc+4 of THIS jal,
    # not pc+4 of the jump target -- a common off-by-instruction bug.
jal2:
    jal x2, jal2_target           # link value must equal address(jal2)+4
    addi x15, x0, 99              # should be SKIPPED
jal2_target:
    addi x15, x0, 1               # x15=1 confirms jump happened

loop: jal x0, loop