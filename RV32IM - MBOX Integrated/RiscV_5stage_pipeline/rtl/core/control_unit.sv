`include "../includes/riscv_defines.svh"

module control_unit (
    input logic [6:0] opcode,
    input logic [2:0] funct3,      // needed only to recognise RV32M MUL-group (is_mul)
    input logic [6:0] funct7,      // needed only to recognise RV32M MUL-group (is_mul)

    output logic       reg_write_enable,
    output logic       alu_src_a,
    output logic       alu_src_b,
    output logic       mem_write_enable,
    output logic       mem_read_enable,
    output logic [2:0] alu_op,
    output logic [1:0] result_src,
    output logic       branch,
    output logic       jump,
    output logic       base_select,
    output logic       is_mul,      // MUL / MULH / MULHSU / MULHU  (routed to MBOX, not the ALU)
    output logic       uses_rs1,    // instruction really reads rs1 (not lui / auipc / jal)
    output logic       uses_rs2     // instruction really reads rs2 (R-type, store, branch)
);

// RV32M multiply group: opcode = OP (R-type), funct7 = 0000001, funct3[2] = 0.
// funct3[2] = 1 would be DIV/DIVU/REM/REMU, which MBOX does not implement; those
// are NOT flagged here and fall through the normal R-type path.
assign is_mul = (opcode == `OP_R_TYPE) && (funct7 == 7'b0000001) && (funct3[2] == 1'b0);

always_comb begin
    // Default values
    reg_write_enable = 1'b0;
    alu_src_a        = 1'b0;
    alu_src_b        = 1'b0;
    mem_write_enable = 1'b0;
    mem_read_enable  = 1'b0;
    alu_op           = `ALUOP_ADD; // Default to ADD
    result_src       = `RES_ALU;   // Default to ALU result
    branch           = 1'b0;
    jump             = 1'b0;
    base_select      = 1'b0;
    uses_rs1         = 1'b0;
    uses_rs2         = 1'b0;

    unique case (opcode)
        `OP_R_TYPE: begin
            uses_rs1         = 1'b1;
            uses_rs2         = 1'b1;
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b0; // Register
            alu_op           = `ALUOP_RTYPE;
            result_src       = `RES_ALU;
        end

        `OP_I_TYPE: begin
            uses_rs1         = 1'b1;
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_ITYPE;
            result_src       = `RES_ALU;
        end

        `OP_LOAD: begin
            uses_rs1         = 1'b1;
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_ADD; // Address calculation
            mem_read_enable  = 1'b1;
            result_src       = `RES_MEM;
        end

        `OP_STORE: begin
            uses_rs1         = 1'b1;
            uses_rs2         = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_ADD; // Address calculation
            mem_write_enable = 1'b1;
        end

        `OP_BRANCH: begin
            uses_rs1         = 1'b1;
            uses_rs2         = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b0; // Register
            alu_op           = `ALUOP_SUB; // For comparison
            branch           = 1'b1;
            base_select      = 1'b0; // Use PC for branch target
        end
        
        `OP_JAL: begin
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b0; // Register
            alu_op           = `ALUOP_ADD; // For PC + offset
            result_src       = `RES_PC_PLUS4;
            jump             = 1'b1;
            base_select      = 1'b0; // Use PC for jump target
        end

        `OP_JALR: begin
            uses_rs1         = 1'b1;
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_ADD; // For base + offset
            result_src       = `RES_PC_PLUS4;
            jump             = 1'b1;
            base_select      = 1'b1; // Use register for jump target
        end

        `OP_LUI: begin
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b0; // Register
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_LUI; // For LUI operation
            result_src       = `RES_ALU;
        end

        `OP_AUIPC: begin
            reg_write_enable = 1'b1;
            alu_src_a        = 1'b1; // PC
            alu_src_b        = 1'b1; // Immediate
            alu_op           = `ALUOP_ADD; // For PC + immediate
            result_src       = `RES_ALU;
        end

        default: begin
            // Unsupported opcode, keep defaults
        end
    endcase
end

endmodule
