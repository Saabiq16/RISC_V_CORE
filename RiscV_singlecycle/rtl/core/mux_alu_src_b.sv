module mux_alu_src_b (
    input  logic [31:0] rs2_data,
    input  logic [31:0] imm_data,
    input  logic        alu_src_sel_b,
    output logic [31:0] mux_alu_b_out
);

assign mux_alu_b_out = (alu_src_sel_b) ? imm_data : rs2_data;

endmodule