module mux_base_select_pc_branch (
    input logic [31:0] pc_current,
    input logic [31:0] rs1,
    input logic base_sel, // 0: pc_current, 1: rs1
    output logic [31:0] base_out
);

assign base_out = (base_sel) ? rs1 : pc_current;

endmodule