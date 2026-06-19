`ifndef RISCV_DEFINES_SVH
`define RISCV_DEFINES_SVH

// ── Opcodes ──────────────────────────────────────────
`define OP_R_TYPE    7'b0110011
`define OP_I_TYPE    7'b0010011
`define OP_LOAD      7'b0000011
`define OP_STORE     7'b0100011
`define OP_BRANCH    7'b1100011
`define OP_JAL       7'b1101111
`define OP_JALR      7'b1100111
`define OP_LUI       7'b0110111
`define OP_AUIPC     7'b0010111

// ── ALU Operation Codes ──────────────────────────────
`define ALU_ADD      4'b0000
`define ALU_SUB      4'b0001
`define ALU_SLL      4'b0010
`define ALU_SLT      4'b0011
`define ALU_SLTU     4'b0100
`define ALU_XOR      4'b0101
`define ALU_SRL      4'b0110
`define ALU_SRA      4'b0111
`define ALU_OR       4'b1000
`define ALU_AND      4'b1001
`define ALU_LUI      4'b1010

// ── Immediate Type Encodings ─────────────────────────
`define IMM_I        3'b000    // I-type: ADDI, LW, JALR
`define IMM_S        3'b001    // S-type: SW
`define IMM_B        3'b010    // B-type: BEQ, BNE, BLT, BGE
`define IMM_U        3'b011    // U-type: LUI, AUIPC
`define IMM_J        3'b100    // J-type: JAL

// ── ResultSrc (Writeback Mux) ────────────────────────
`define RES_ALU      2'b00     // ALU result → rd
`define RES_MEM      2'b01     // Memory read → rd
`define RES_PC_PLUS4 2'b10     // PC+4 → rd (JAL, JALR)
`define RES_IMM      2'b11     // Reserved / Upper imm

// ── ALUOp (Control Unit → ALU Control) ──────────────
`define ALUOP_ADD    2'b00     // Force ADD (LW, SW)
`define ALUOP_SUB    2'b01     // Force SUB (Branch)
`define ALUOP_RTYPE  2'b10     // Use funct3/funct7 (R-type)
`define ALUOP_ITYPE  2'b11     // Use funct3 only (I-ALU)

// ── Branch Funct3 Codes ──────────────────────────────
`define BR_BEQ       3'b000
`define BR_BNE       3'b001
`define BR_BLT       3'b100
`define BR_BGE       3'b101
`define BR_BLTU      3'b110
`define BR_BGEU      3'b111

`endif // RISCV_DEFINES_SVH