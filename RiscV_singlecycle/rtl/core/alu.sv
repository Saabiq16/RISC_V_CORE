`include "../includes/riscv_defines.svh"

module alu(
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [3:0] alu_op,

    output logic [31:0] result,
    output logic zero,
    output logic carry,
    output logic negative,
    output logic overflow
);

logic [32:0] sub_ext;
assign sub_ext = {1'b0, a} - {1'b0, b};

logic ov_add, ov_sub;
assign ov_add = (a[31] ^~ b[31]) & (a[31] ^ result[31]);
assign ov_sub = (a[31]  ^ b[31]) & (a[31] ^ result[31]);
//flags

assign zero     = (result == 32'b0);
assign carry    = ~sub_ext[32];
assign negative = result[31];
assign overflow = (alu_op == `ALU_SUB)?ov_sub : ov_add;

//ALU operations

always_comb begin
    case (alu_op)
        `ALU_ADD:  result = a + b;
        `ALU_SUB:  result = a - b;
        `ALU_SLL:  result = a << b[4:0];
        `ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
        `ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
        `ALU_XOR:  result = a ^ b;
        `ALU_SRL:  result = a >> b[4:0];
        `ALU_SRA:  result = $signed(a) >>> b[4:0];
        `ALU_OR:   result = a | b;
        `ALU_AND:  result = a & b;
        `ALU_LUI:  result = b;
        default:   result = 32'b0;
    endcase
end

endmodule