module mux_alu_src (
    input logic [31:0] rs2_data,
    input logic [31:0] imm_data,
    input logic       alu_src_sel,
    output logic [31:0] alu_in_b
);

assign alu_in_b = (alu_src_sel) ? imm_data : rs2_data;

endmodule