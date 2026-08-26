.section .text
.globl _start

_start:
    # ================= BEQ =================
    addi x1, x0, 5
    addi x2, x0, 5
    beq  x1, x2, beq_taken        # 5 == 5 -> should branch
    addi x10, x0, 99              # should be SKIPPED if BEQ works
beq_taken:
    addi x10, x0, 1               # x10=1 confirms BEQ-taken path

    addi x3, x0, 5
    addi x4, x0, 6
    beq  x3, x4, beq_bad          # 5 == 6 -> should NOT branch
    addi x11, x0, 1               # x11=1 confirms BEQ-not-taken path (falls through here)
    jal  x0, beq_done
beq_bad:
    addi x11, x0, 99              # wrong-path marker if BEQ incorrectly taken
beq_done:

    # ================= BNE =================
    addi x1, x0, 5
    addi x2, x0, 6
    bne  x1, x2, bne_taken        # 5 != 6 -> should branch
    addi x12, x0, 99              # should be SKIPPED
bne_taken:
    addi x12, x0, 1               # x12=1 confirms BNE-taken path

    addi x3, x0, 5
    addi x4, x0, 5
    bne  x3, x4, bne_bad          # 5 != 5 false -> should NOT branch
    addi x13, x0, 1               # x13=1 confirms BNE-not-taken path
    jal  x0, bne_done
bne_bad:
    addi x13, x0, 99              # wrong-path marker
bne_done:

    # ================= BLT (signed) =================
    addi x1, x0, -5
    addi x2, x0, 3
    blt  x1, x2, blt_taken        # -5 < 3 -> should branch (ordinary case, no overflow)
    addi x14, x0, 99
blt_taken:
    addi x14, x0, 1               # x14=1 confirms BLT-taken path

    addi x3, x0, 5
    addi x4, x0, 3
    blt  x3, x4, blt_bad          # 5 < 3 false -> should NOT branch
    addi x15, x0, 1               # x15=1 confirms BLT-not-taken path
    jal  x0, blt_done
blt_bad:
    addi x15, x0, 99              # wrong-path marker
blt_done:

    # ---- BLT overflow-boundary canary #1: INT_MIN < 1 ----
    # x5 = INT_MIN. SUB computes x5 - x6 = 0x80000000 - 1 = 0x7FFFFFFF,
    # which LOOKS positive (negative flag = 0) even though the true
    # math result should be very negative -- this is signed subtract
    # overflow. Correct signed "<" must be (negative XOR overflow),
    # not just the raw negative flag, or this case fails silently.
    lui  x5, 0x80000              # x5 = 0x80000000 = INT_MIN
    addi x6, x0, 1
    blt  x5, x6, blt_ovf_taken    # INT_MIN < 1 is TRUE -> should branch
    addi x16, x0, 99
blt_ovf_taken:
    addi x16, x0, 1               # x16=1 confirms negative^overflow logic works (case 1)

    # ================= BGE (signed) =================
    addi x1, x0, 3
    addi x2, x0, -5
    bge  x1, x2, bge_taken        # 3 >= -5 -> should branch
    addi x17, x0, 99
bge_taken:
    addi x17, x0, 1               # x17=1 confirms BGE-taken path

    addi x3, x0, -5
    addi x4, x0, 3
    bge  x3, x4, bge_bad          # -5 >= 3 false -> should NOT branch
    addi x18, x0, 1               # x18=1 confirms BGE-not-taken path
    jal  x0, bge_done
bge_bad:
    addi x18, x0, 99              # wrong-path marker
bge_done:

    # ---- BGE overflow-boundary canary #2: 1 >= INT_MIN ----
    # Opposite direction from the BLT canary above. SUB computes
    # x7 - x8 = 1 - 0x80000000 = 0x80000001, which LOOKS negative
    # (negative flag = 1) even though the true math result (huge
    # positive) should clearly satisfy ">=". This is the other
    # overflow direction -- positive-result wraps to look negative.
    # A correct (negative XOR overflow) implementation handles BOTH
    # directions; a buggy one may only get one of the two right.
    addi x7, x0, 1
    lui  x8, 0x80000              # x8 = 0x80000000 = INT_MIN
    bge  x7, x8, bge_ovf_taken    # 1 >= INT_MIN is TRUE -> should branch
    addi x23, x0, 99
bge_ovf_taken:
    addi x23, x0, 1               # x23=1 confirms negative^overflow logic works (case 2)

    # ================= BLTU (unsigned) =================
    addi x1, x0, 1
    addi x2, x0, 2
    bltu x1, x2, bltu_taken       # 1 <u 2 -> should branch (ordinary case)
    addi x19, x0, 99
bltu_taken:
    addi x19, x0, 1               # x19=1 confirms BLTU-taken path

    # ---- BLTU boundary canary: unsigned-vs-signed trap ----
    # x3 = 0xFFFFFFFF (huge as unsigned, -1 as signed), x4 = 1.
    # Unsigned: huge <u 1 is FALSE -> should NOT branch.
    # If BLTU were accidentally wired to signed logic instead of the
    # carry flag, it would wrongly conclude -1 < 1 = TRUE and branch.
    # This proves the unsigned compare path is genuinely separate
    # from the signed (negative^overflow) path.
    addi x3, x0, -1
    addi x4, x0, 1
    bltu x3, x4, bltu_bad
    addi x20, x0, 1               # x20=1 confirms BLTU-not-taken / carry-path correctness
    jal  x0, bltu_done
bltu_bad:
    addi x20, x0, 99              # wrong-path marker (signed/unsigned mixup signature)
bltu_done:

    # ================= BGEU (unsigned) =================
    addi x1, x0, -1                # 0xFFFFFFFF, huge as unsigned
    addi x2, x0, 1
    bgeu x1, x2, bgeu_taken        # huge >=u 1 -> should branch
    addi x21, x0, 99
bgeu_taken:
    addi x21, x0, 1               # x21=1 confirms BGEU-taken path

    addi x3, x0, 1
    addi x4, x0, -1                # x4 = huge as unsigned
    bgeu x3, x4, bgeu_bad          # 1 >=u huge is FALSE -> should NOT branch
    addi x22, x0, 1               # x22=1 confirms BGEU-not-taken path
    jal  x0, bgeu_done
bgeu_bad:
    addi x22, x0, 99              # wrong-path marker
bgeu_done:

loop: jal x0, loop