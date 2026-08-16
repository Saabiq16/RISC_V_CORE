`include "../includes/riscv_defines.svh"

module mux_alu_src_a (
    input  logic        alu_src_sel_a,      // 0 = rs1_data, 1 = pc_current
    input  logic [31:0] rs1_data,
    input  logic [31:0] pc_current,

    output logic [31:0] alu_in_a
);

always_comb begin
    unique case (alu_src_sel_a)
        1'b0: alu_in_a = rs1_data;
        1'b1: alu_in_a = pc_current;
    endcase
end

endmodule