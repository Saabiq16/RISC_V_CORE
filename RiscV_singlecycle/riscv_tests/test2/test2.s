.section .text
.globl _start

_start:


# --- ADDI ---


addi x1, x0, 15          # x1 = 15
addi x2, x0, -5           # x2 = -5 (sign-extended imm)
addi x3, x1, -20           # x3 = 15 + (-20) = -5

# --- SLTI (signed) ---
slti x4, x2, 0              # x4 = (-5 < 0) = 1
slti x5, x1, 0              # x5 = (15 < 0) = 0

# --- SLTIU (unsigned) ---
sltiu x6, x1, 20             # x6 = (15 <u 20) = 1
sltiu x7, x2, 1                # x2=-5 as unsigned is huge -> (huge <u 1) = 0

# --- XORI ---
xori x8, x1, -1                 # x8 = 15 ^ 0xFFFFFFFF = ~15 = 0xFFFFFFF0

# --- ORI ---
ori  x9, x1, 0x20                 # x9 = 15 | 32 = 47

# --- ANDI ---
andi x10, x1, 0x0F                 # x10 = 15 & 15 = 15

# --- SLLI ---
addi x11, x0, 1                     # x11 = 1
slli x12, x11, 4                     # x12 = 1 << 4 = 16

# --- SRLI (logical, zero-fill) ---
addi  x13, x0, -1                     # x13 = 0xFFFFFFFF
srli  x14, x13, 4                      # x14 = 0x0FFFFFFF (zero-filled)

# --- SRAI (arithmetic, sign-fill) ---
addi  x15, x0, -1                      # x15 = 0xFFFFFFFF
srai  x16, x15, 4                       # x16 = 0xFFFFFFFF (sign-filled, still -1)

# infinite loop
loop: jal x0, loop