module pc_branch_adder (
    input logic [31:0] base,
    input logic [31:0] immediate,
    output logic [31:0] branch_target
);

assign branch_target = base + immediate;

endmodule