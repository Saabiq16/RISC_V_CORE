module pc_adder4 (
    input logic [31:0] pc_current,
    output logic [31:0] pc_plus4
);

    assign pc_plus4 = pc_current + 32'd4;
endmodule