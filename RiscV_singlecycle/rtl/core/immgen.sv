`include "../includes/riscv_defines.svh"

module immgen (
    input logic [31:0] instruction,

    output logic [31:0] imm_ext
);

always_comb begin 

    case (instruction[6:0])
        `OP_I_TYPE, `OP_LOAD, `OP_JALR : begin
            imm_ext = {{20{instruction[31]}}, instruction[31:20]}; // Sign-extend I-type immediate
        end
        `OP_STORE : begin
            imm_ext = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}; // Sign-extend S-type immediate
        end
        `OP_BRANCH : begin
            imm_ext = {{20{instruction[31]}}, instruction [7], instruction[30:25], instruction[11:8], 1'b0}; // Sign-extend B-type immediate
            end
        `OP_LUI, `OP_AUIPC : begin
            imm_ext = {instruction[31:12], 12'b0}; // U-type immediate
        end
        `OP_JAL : begin
            imm_ext = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0}; // Sign-extend J-type immediate
        end
        default : begin
            imm_ext = 32'b0; // Default case
        end
    endcase
    
end
endmodule