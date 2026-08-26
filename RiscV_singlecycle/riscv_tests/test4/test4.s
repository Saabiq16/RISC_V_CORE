.section .text
.globl _start

_start:
    addi x1, x0, 0x20        # x1 = base address 0x20

    # --- Store a full word with a negative byte pattern ---
    addi x2, x0, -1            # x2 = 0xFFFFFFFF
    sw   x2, 0(x1)               # mem[0x20..0x23] = FF FF FF FF (little-endian)

    lw   x3, 0(x1)                 # x3 = 0xFFFFFFFF          (word readback)
    lb   x4, 0(x1)                  # x4 = 0xFFFFFFFF          (sign-extended byte = -1)
    lbu  x5, 0(x1)                   # x5 = 0x000000FF          (zero-extended byte)
    lh   x6, 0(x1)                    # x6 = 0xFFFFFFFF          (sign-extended half = -1)
    lhu  x7, 0(x1)                     # x7 = 0x0000FFFF          (zero-extended half)

    # --- Store a positive byte pattern to check sign-extend does NOT trigger on positives ---
    addi x8, x0, 0x7F             # x8 = 0x7F (positive, MSB of byte = 0)
    sb   x8, 4(x1)                  # mem[0x24] = 0x7F, rest untouched (still whatever was there)
    lb   x9, 4(x1)                    # x9 = 0x0000007F (sign-extend of positive byte = itself)
    lbu  x10, 4(x1)                    # x10 = 0x0000007F (same, since MSB=0)

    # --- Byte-addressing / no-corruption check ---
    addi x11, x0, 0x11              # x11 = 0x11
    addi x12, x0, 0x22               # x12 = 0x22
    addi x13, x0, 0x33                # x13 = 0x33
    addi x14, x0, 0x44                 # x14 = 0x44
    sb   x11, 8(x1)                      # mem[0x28] = 0x11
    sb   x12, 9(x1)                       # mem[0x29] = 0x22
    sb   x13, 10(x1)                       # mem[0x2A] = 0x33
    sb   x14, 11(x1)                        # mem[0x2B] = 0x44
    lw   x15, 8(x1)                          # x15 = 0x44332211 (little-endian word reassembly)

    # --- Halfword store + adjacent-byte-preserved check ---
    addi x16, x0, -1                # x16 = 0xFFFFFFFF
    sw   x16, 12(x1)                  # mem[0x2C..0x2F] = FF FF FF FF
    addi x17, x0, 0x0000                # x17 = 0
    sh   x17, 12(x1)                     # overwrite only lower half -> mem[0x2C..0x2D]=00 00, [0x2E..0x2F] unchanged = FF FF
    lw   x18, 12(x1)                       # x18 = 0xFFFF0000 (upper half preserved, lower half zeroed)

loop: jal x0, loop