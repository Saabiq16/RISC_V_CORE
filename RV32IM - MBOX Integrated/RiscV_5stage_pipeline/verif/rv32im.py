#!/usr/bin/env python3
"""Tiny RV32IM encoder + reference ISS + constrained-random program generator.
Golden model for the 5-stage + MBOX core (the single-cycle core has no M extension).
"""
import random, sys, os

M32 = 0xFFFFFFFF
def s32(x): x &= M32; return x - (1 << 32) if x & 0x80000000 else x

OP_R, OP_I, OP_LD, OP_ST, OP_BR, OP_JAL, OP_JALR, OP_LUI, OP_AUIPC = \
    0b0110011, 0b0010011, 0b0000011, 0b0100011, 0b1100011, 0b1101111, 0b1100111, 0b0110111, 0b0010111

def enc_r(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def enc_i(imm, rs1, f3, rd, op):     return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def enc_s(imm, rs2, rs1, f3, op):    return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def enc_b(imm, rs2, rs1, f3, op):
    return (((imm >> 12) & 1) << 31) | (((imm >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | \
           (((imm >> 1) & 0xF) << 8) | (((imm >> 11) & 1) << 7) | op
def enc_u(imm20, rd, op):            return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op
def enc_j(imm, rd, op):
    return (((imm >> 20) & 1) << 31) | (((imm >> 1) & 0x3FF) << 21) | (((imm >> 11) & 1) << 20) | \
           (((imm >> 12) & 0xFF) << 12) | (rd << 7) | op

R_OPS = {  # name: (funct7, funct3)
    'add': (0, 0), 'sub': (0x20, 0), 'sll': (0, 1), 'slt': (0, 2), 'sltu': (0, 3), 'xor': (0, 4),
    'srl': (0, 5), 'sra': (0x20, 5), 'or': (0, 6), 'and': (0, 7),
    'mul': (1, 0), 'mulh': (1, 1), 'mulhsu': (1, 2), 'mulhu': (1, 3)}
I_OPS = {'addi': 0, 'slti': 2, 'sltiu': 3, 'xori': 4, 'ori': 6, 'andi': 7}
SH_OPS = {'slli': (0, 1), 'srli': (0, 5), 'srai': (0x20, 5)}
LD_OPS = {'lb': 0, 'lh': 1, 'lw': 2, 'lbu': 4, 'lhu': 5}
ST_OPS = {'sb': 0, 'sh': 1, 'sw': 2}
BR_OPS = {'beq': 0, 'bne': 1, 'blt': 4, 'bge': 5, 'bltu': 6, 'bgeu': 7}

def R(op, rd, rs1, rs2): f7, f3 = R_OPS[op]; return enc_r(f7, rs2, rs1, f3, rd, OP_R)
def I(op, rd, rs1, imm): return enc_i(imm, rs1, I_OPS[op], rd, OP_I)
def SH(op, rd, rs1, sh): f7, f3 = SH_OPS[op]; return enc_i((f7 << 5) | sh, rs1, f3, rd, OP_I)
def LD(op, rd, rs1, imm): return enc_i(imm, rs1, LD_OPS[op], rd, OP_LD)
def ST(op, rs2, rs1, imm): return enc_s(imm, rs2, rs1, ST_OPS[op], OP_ST)
def BR(op, rs1, rs2, off): return enc_b(off, rs2, rs1, BR_OPS[op], OP_BR)
def JAL(rd, off): return enc_j(off, rd, OP_JAL)
def JALR(rd, rs1, imm): return enc_i(imm, rs1, 0, rd, OP_JALR)
def LUI(rd, imm20): return enc_u(imm20, rd, OP_LUI)
def AUIPC(rd, imm20): return enc_u(imm20, rd, OP_AUIPC)
NOP = I('addi', 0, 0, 0)

# ------------------------------------------------------------------ ISS
def mulop(f3, a, b):
    sa, sb = s32(a), s32(b)
    if f3 == 0: return (sa * sb) & M32
    if f3 == 1: return ((sa * sb) >> 32) & M32
    if f3 == 2: return ((sa * (b & M32)) >> 32) & M32
    return (((a & M32) * (b & M32)) >> 32) & M32

def run_iss(words, max_steps=200000):
    mem_i = {4 * i: w for i, w in enumerate(words)}
    regs = [0] * 32
    dmem = {}
    def rb(a): return dmem.get(a & M32, 0)
    def wb(a, v): dmem[a & M32] = v & 0xFF
    pc = 0
    for _ in range(max_steps):
        ins = mem_i[pc]
        op = ins & 0x7F; rd = (ins >> 7) & 31; f3 = (ins >> 12) & 7
        rs1 = (ins >> 15) & 31; rs2 = (ins >> 20) & 31; f7 = (ins >> 25) & 0x7F
        a, b = regs[rs1], regs[rs2]
        nxt = pc + 4; res = None
        immI = s32(ins) >> 20
        if op == OP_R:
            if f7 == 1: res = mulop(f3, a, b)
            else:
                if f3 == 0: res = (a - b) & M32 if f7 == 0x20 else (a + b) & M32
                elif f3 == 1: res = (a << (b & 31)) & M32
                elif f3 == 2: res = int(s32(a) < s32(b))
                elif f3 == 3: res = int(a < b)
                elif f3 == 4: res = a ^ b
                elif f3 == 5: res = (s32(a) >> (b & 31)) & M32 if f7 == 0x20 else a >> (b & 31)
                elif f3 == 6: res = a | b
                else: res = a & b
        elif op == OP_I:
            im = immI & M32
            if f3 == 0: res = (a + im) & M32
            elif f3 == 2: res = int(s32(a) < immI)
            elif f3 == 3: res = int(a < im)
            elif f3 == 4: res = a ^ im
            elif f3 == 6: res = a | im
            elif f3 == 7: res = a & im
            elif f3 == 1: res = (a << (immI & 31)) & M32
            else: res = (s32(a) >> (immI & 31)) & M32 if (ins >> 30) & 1 else a >> (immI & 31)
        elif op == OP_LD:
            ad = (a + immI) & M32
            if f3 == 0: v = rb(ad); res = (v - 256 if v & 0x80 else v) & M32
            elif f3 == 1: v = rb(ad) | rb(ad + 1) << 8; res = (v - 65536 if v & 0x8000 else v) & M32
            elif f3 == 2: res = rb(ad) | rb(ad + 1) << 8 | rb(ad + 2) << 16 | rb(ad + 3) << 24
            elif f3 == 4: res = rb(ad)
            else: res = rb(ad) | rb(ad + 1) << 8
        elif op == OP_ST:
            imm = ((ins >> 25) << 5 | ((ins >> 7) & 31)); imm = imm - 4096 if imm & 0x800 else imm
            ad = (a + imm) & M32
            wb(ad, b)
            if f3 >= 1: wb(ad + 1, b >> 8)
            if f3 == 2: wb(ad + 2, b >> 16); wb(ad + 3, b >> 24)
        elif op == OP_BR:
            imm = (((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) | (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1)
            imm = imm - 8192 if imm & 0x1000 else imm
            t = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b), 6: a < b, 7: a >= b}[f3]
            if t: nxt = (pc + imm) & M32
        elif op == OP_JAL:
            imm = (((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12) | (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1)
            imm = imm - (1 << 21) if imm & (1 << 20) else imm
            res = pc + 4; nxt = (pc + imm) & M32
            if imm == 0 and rd == 0:
                regs[0] = 0
                return regs, dmem, pc
        elif op == OP_JALR:
            res = pc + 4; nxt = (a + immI) & M32 & ~1
        elif op == OP_LUI: res = ins & 0xFFFFF000
        elif op == OP_AUIPC: res = (pc + (ins & 0xFFFFF000)) & M32
        else: raise RuntimeError("bad op %x at %x" % (ins, pc))
        if res is not None and rd != 0: regs[rd] = res & M32
        pc = nxt
    raise RuntimeError("ISS did not terminate")

# ------------------------------------------------------------------ generator
SPECIAL = [0, 1, M32, 0x80000000, 0x7FFFFFFF, 2, 0xFFFF, 0x10000, 0x80000001, 0xDEADBEEF, 3, M32 - 1]
BASE = 0x400   # data region base, held in x31 (never a destination)

def li(rd, v):
    v &= M32
    hi = ((v + 0x800) >> 12) & 0xFFFFF
    lo = v & 0xFFF
    lo = lo - 4096 if lo & 0x800 else lo
    return [LUI(rd, hi), I('addi', rd, rd, lo)]

def gen_program(seed, n_items=60, pool_n=6, w_mul=25, directed=None):
    rnd = random.Random(seed)
    pool = rnd.sample(range(1, 31), pool_n)
    allregs = list(range(1, 31))
    words = []
    for r in allregs:
        v = rnd.choice(SPECIAL) if rnd.random() < 0.5 else rnd.getrandbits(32)
        words += li(r, v)
    words.append(I('addi', 31, 0, BASE))

    def src(): return 0 if rnd.random() < 0.06 else rnd.choice(pool)
    def dst(): return 0 if rnd.random() < 0.04 else rnd.choice(pool)

    # item = (kind, args). Layout first, encode second (branch targets need addresses).
    kinds = (['mul'] * w_mul + ['alu_r'] * 18 + ['alu_i'] * 12 + ['shift'] * 4 + ['load'] * 8 + ['store'] * 8 +
             ['branch'] * 8 + ['jal'] * 3 + ['jalr'] * 3 + ['upper'] * 4 + ['nop'] * 2)
    items = []
    for _ in range(n_items):
        k = rnd.choice(kinds)
        if k == 'mul':   items.append((k, (rnd.choice(['mul', 'mulh', 'mulhsu', 'mulhu']), dst(), src(), src())))
        elif k == 'alu_r': items.append((k, (rnd.choice(['add', 'sub', 'sll', 'slt', 'sltu', 'xor', 'srl', 'sra', 'or', 'and']), dst(), src(), src())))
        elif k == 'alu_i': items.append((k, (rnd.choice(list(I_OPS)), dst(), src(), rnd.randint(-2048, 2047))))
        elif k == 'shift': items.append((k, (rnd.choice(list(SH_OPS)), dst(), src(), rnd.randint(0, 31))))
        elif k == 'load':
            op = rnd.choice(list(LD_OPS)); al = {'lb': 1, 'lbu': 1, 'lh': 2, 'lhu': 2, 'lw': 4}[op]
            items.append((k, (op, dst(), rnd.randrange(0, 128, al))))
        elif k == 'store':
            op = rnd.choice(list(ST_OPS)); al = {'sb': 1, 'sh': 2, 'sw': 4}[op]
            items.append((k, (op, src(), rnd.randrange(0, 128, al))))
        elif k == 'branch': items.append((k, (rnd.choice(list(BR_OPS)), src(), src(), rnd.randint(1, 4))))
        elif k == 'jal':    items.append((k, (dst(), rnd.randint(1, 4))))
        elif k == 'jalr':   items.append((k, (dst(), rnd.choice(pool), rnd.randint(1, 4))))
        elif k == 'upper':  items.append((k, (rnd.choice(['lui', 'auipc']), dst(), rnd.getrandbits(20))))
        else: items.append((k, ()))
    sizes = [2 if it[0] == 'jalr' else 1 for it in items]
    base_addr = 4 * len(words)
    addr = []
    a = base_addr
    for s in sizes: addr.append(a); a += 4 * s
    sentinel_addr = a
    addr.append(sentinel_addr)               # target index n_items = sentinel
    for i, (k, ar) in enumerate(items):
        if k == 'mul' or k == 'alu_r': words.append(R(*ar))
        elif k == 'alu_i': words.append(I(*ar))
        elif k == 'shift': words.append(SH(*ar))
        elif k == 'load':  words.append(LD(ar[0], ar[1], 31, ar[2]))
        elif k == 'store': words.append(ST(ar[0], ar[1], 31, ar[2]))
        elif k == 'branch':
            t = min(i + ar[3], len(items)); words.append(BR(ar[0], ar[1], ar[2], addr[t] - addr[i]))
        elif k == 'jal':
            t = min(i + ar[1], len(items)); words.append(JAL(ar[0], addr[t] - addr[i]))
        elif k == 'jalr':
            t = min(i + ar[2], len(items)); rd, rt = ar[0], ar[1]
            words.append(AUIPC(rt, 0)); words.append(JALR(rd, rt, addr[t] - addr[i]))
        elif k == 'upper': words.append(LUI(ar[1], ar[2]) if ar[0] == 'lui' else AUIPC(ar[1], ar[2] & 0x3FF))
        else: words.append(NOP)
    words.append(JAL(0, 0))                  # sentinel: jal x0, 0
    return words

def dump_expected(path, regs, dmem):
    with open(path, 'w') as f:
        for r in range(1, 32): f.write("R %02x %08x\n" % (r, regs[r]))
        for a in range(BASE, BASE + 256, 4):
            w = sum(dmem.get(a + i, 0) << (8 * i) for i in range(4))
            f.write("M %04x %08x\n" % (a, w))

if __name__ == '__main__':
    outdir, n, seed0 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
    os.makedirs(outdir, exist_ok=True)
    for i in range(n):
        seed = seed0 + i
        rnd = random.Random(seed * 7919)
        words = gen_program(seed, n_items=rnd.choice([30, 60, 90]), pool_n=rnd.choice([3, 4, 6, 8]), w_mul=rnd.choice([10, 25, 40]))
        regs, dmem, _ = run_iss(words)
        with open("%s/prog_%d.hex" % (outdir, i), 'w') as f:
            for w in words: f.write("%08x\n" % w)
        dump_expected("%s/exp_%d.txt" % (outdir, i), regs, dmem)
    print("generated", n, "programs in", outdir)
