`include "../includes/riscv_defines.svh"

module alu_control (
    input  logic [2:0] funct3,
    input  logic       funct7_5,
    input  logic [2:0] alu_op,

    output logic [3:0] alu_control_signal
);

always_comb begin
    unique case (alu_op)

        `ALUOP_ADD: alu_control_signal = `ALU_ADD; // Force ADD (LW, SW, AUIPC)
        `ALUOP_SUB: alu_control_signal = `ALU_SUB; // Force SUB (Branch)
        `ALUOP_LUI: alu_control_signal = `ALU_LUI; // Force LUI (LUI instruction)

        `ALUOP_RTYPE: begin
            unique case (funct3)
                `FUNCT3_ADD:     alu_control_signal = funct7_5 ? `ALU_SUB : `ALU_ADD;
                `FUNCT3_SLL:     alu_control_signal = `ALU_SLL;
                `FUNCT3_SLT:     alu_control_signal = `ALU_SLT;
                `FUNCT3_SLTU:    alu_control_signal = `ALU_SLTU;
                `FUNCT3_XOR:     alu_control_signal = `ALU_XOR;
                `FUNCT3_SR :     alu_control_signal = funct7_5 ? `ALU_SRA : `ALU_SRL;
                `FUNCT3_OR:      alu_control_signal = `ALU_OR;
                `FUNCT3_AND:     alu_control_signal = `ALU_AND;
                default:         alu_control_signal = `ALU_ADD; // Invalid funct3
            endcase
        end

        `ALUOP_ITYPE: begin
            unique case (funct3)
                `FUNCT3_ADD:     alu_control_signal = `ALU_ADD;
                `FUNCT3_SLL:     alu_control_signal = `ALU_SLL;
                `FUNCT3_SLT:     alu_control_signal = `ALU_SLT;
                `FUNCT3_SLTU:    alu_control_signal = `ALU_SLTU;
                `FUNCT3_XOR:     alu_control_signal = `ALU_XOR;
                `FUNCT3_SR :     alu_control_signal = funct7_5 ? `ALU_SRA : `ALU_SRL;
                `FUNCT3_OR:      alu_control_signal = `ALU_OR;
                `FUNCT3_AND:     alu_control_signal = `ALU_AND;
                default:         alu_control_signal = 4'bxxxx; // Invalid funct3
            endcase
        end

        default: alu_control_signal = `ALU_ADD; // Invalid ALUOp

    endcase
end

endmodule
