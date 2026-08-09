`timescale 1ns / 1ps
`include "../includes/riscv_defines.svh"

module tb_mux_alu_src_a;

    logic        alu_a_src;
    logic [31:0] rs1_data;
    logic [31:0] pc_current;

    logic [31:0] alu_src_sel_a;

    int pass_count = 0;
    int fail_count = 0;

    mux_alu_src_a dut (
        .alu_a_src     (alu_a_src),
        .rs1_data      (rs1_data),
        .pc_current    (pc_current),
        .alu_src_sel_a (alu_src_sel_a)
    );

    task automatic check(
        input string       test_name,
        input logic        t_alu_a_src,
        input logic [31:0] t_rs1_data,
        input logic [31:0] t_pc_current,
        input logic [31:0] exp_out
    );
        alu_a_src  = t_alu_a_src;
        rs1_data   = t_rs1_data;
        pc_current = t_pc_current;
        #1;

        if (alu_src_sel_a === exp_out) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            fail_count++;
            $display("[FAIL] %s  alu_a_src=%b rs1=%h pc=%h  exp=%h got=%h",
                       test_name, t_alu_a_src, t_rs1_data, t_pc_current,
                       exp_out, alu_src_sel_a);
        end
    endtask

    initial begin
        check("Select rs1_data, nonzero pc", 1'b0, 32'hDEAD_BEEF, 32'h0000_1000, 32'hDEAD_BEEF);
        check("Select rs1_data, pc=0",       1'b0, 32'h1234_5678, 32'h0000_0000, 32'h1234_5678);
        check("Select rs1_data, rs1=0",      1'b0, 32'h0000_0000, 32'hFFFF_FFFF, 32'h0000_0000);

        check("Select pc_current, nonzero rs1", 1'b1, 32'hDEAD_BEEF, 32'h0000_1000, 32'h0000_1000);
        check("Select pc_current, rs1=0",       1'b1, 32'h0000_0000, 32'h8000_0004, 32'h8000_0004);
        check("Select pc_current, pc=0",        1'b1, 32'hFFFF_FFFF, 32'h0000_0000, 32'h0000_0000);

        check("rs1 == pc, select rs1", 1'b0, 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA);
        check("rs1 == pc, select pc",  1'b1, 32'hAAAA_AAAA, 32'hAAAA_AAAA, 32'hAAAA_AAAA);

        $display("\n--- ALU Operand-A Mux Testbench Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule