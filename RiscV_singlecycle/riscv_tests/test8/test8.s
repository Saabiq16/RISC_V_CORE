.section .text
.globl _start

_start:
    # ===== Phase 1: Arithmetic (build real working values) =====
    addi x1, x0, 12
    addi x2, x0, 8
    add  x3, x1, x2               # x3 = 20
    sub  x4, x1, x2                 # x4 = 4
    slli x5, x3, 2                    # x5 = 80
    andi x6, x5, 0xFF                    # x6 = 80

    # ===== Phase 2: base address WITHIN data_memory's 1024-byte range =====
    addi x7, x0, 0x40             # x7 = 0x40  (well within 0-1023)

    # ===== Phase 3: Store computed values to memory =====
    sw   x3, 0(x7)
    sw   x4, 4(x7)
    sw   x5, 8(x7)
    sb   x6, 12(x7)

    # ===== Phase 4: Load back and recompute =====
    lw   x8,  0(x7)
    lw   x9,  4(x7)
    lw   x10, 8(x7)
    lbu  x11, 12(x7)

    add  x12, x8, x9                # x12 = 24
    sub  x13, x10, x12                # x13 = 56

    # ===== Phase 5: Comparison + branch on computed result =====
    addi x14, x0, 56
    beq  x13, x14, combined_match
    addi x20, x0, 99
    jal  x0, combined_after_branch
combined_match:
    addi x20, x0, 1
combined_after_branch:

    # ===== Phase 6: Loop construct (backward branch) =====
    addi x15, x0, 5
    addi x21, x0, 0
combined_loop:
    addi x21, x21, 1
    addi x15, x15, -1
    bne  x15, x0, combined_loop

    # ===== Phase 7/8: JAL into subroutine, JALR clean return =====
    jal  x16, combined_subroutine
combined_after_jal:
    addi x23, x0, 1
    jal  x0, combined_end
combined_subroutine:
    addi x22, x0, 1
    jalr x0, x16, 0                # returns cleanly to combined_after_jal (no marker in the way)

combined_end:

loop: jal x0, loop