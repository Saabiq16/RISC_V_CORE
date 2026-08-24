`include "../includes/riscv_defines.svh"

module mux_alu_src_a (
    input  logic        alu_src_sel_a,      // 0 = rs1_data, 1 = pc_current
    input  logic [31:0] rs1_data,
    input  logic [31:0] pc_current,

    output logic [31:0] mux_alu_a_out
);

always_comb begin
    unique case (alu_src_sel_a)
        1'b0: mux_alu_a_out= rs1_data;
        1'b1: mux_alu_a_out = pc_current;
    endcase
end

endmodule