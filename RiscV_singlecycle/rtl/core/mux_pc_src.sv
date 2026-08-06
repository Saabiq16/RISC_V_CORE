module mux_pc_src (
    input logic [31:0] pc_plus_4,
    input logic [31:0] pc_branch,
    input logic       pc_src_sel,
    output logic [31:0] pc_next
);

assign pc_next = (pc_src_sel) ? pc_branch : pc_plus_4;

endmodule