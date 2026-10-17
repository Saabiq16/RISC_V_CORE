module forwarding_unit (
    input  logic [4:0] rs1_e, rs2_e,
    input  logic [4:0] rd_m, rd_w,
    input  logic       reg_write_m, reg_write_w,
    output logic [1:0] forward_a_e,   // 00 regfile, 01 from WB, 10 from MEM
    output logic [1:0] forward_b_e
);
    always_comb begin
        if (reg_write_m && rd_m != 5'd0 && rd_m == rs1_e)
            forward_a_e = 2'b10;
        else if (reg_write_w && rd_w != 5'd0 && rd_w == rs1_e)
            forward_a_e = 2'b01;
        else
            forward_a_e = 2'b00;

        if (reg_write_m && rd_m != 5'd0 && rd_m == rs2_e)
            forward_b_e = 2'b10;
        else if (reg_write_w && rd_w != 5'd0 && rd_w == rs2_e)
            forward_b_e = 2'b01;
        else
            forward_b_e = 2'b00;
    end
endmodule