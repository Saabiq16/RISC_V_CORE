`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test4;
    logic clk;
    logic rst;
    int pass_count = 0;
    int fail_count = 0;

    riscv_single_cycle dut (
        .clk   (clk),
        .reset (rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // NOTE: instruction_memory.sv loads instructions.hex itself via
    // $readmemh at elaboration -- make sure it's pointing at the
    // test4_ls build output before running this. Rebuild + rerun if
    // register values look like a previous test's results.

    task automatic check_reg(
        input int           reg_num,
        input logic [31:0]  exp_val,
        input string        test_name
    );
        if (dut.reg_file.registers[reg_num] === exp_val) begin
            pass_count++;
            $display("[PASS] %s  x%0d = 0x%08h", test_name, reg_num, dut.reg_file.registers[reg_num]);
        end else begin
            fail_count++;
            $display("[FAIL] %s  x%0d  exp=0x%08h got=0x%08h",
                       test_name, reg_num, exp_val, dut.reg_file.registers[reg_num]);
        end
    endtask

    initial begin
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

        // test4_ls.s has ~22 real instructions before the loop.
        // Wait margin generous since it loops forever afterward anyway.
        repeat (30) @(negedge clk);
        #1;

        // Expected values, hand-computed from test4_ls.s:
        check_reg(3,  32'hFFFFFFFF, "x3  = lw  word readback");
        check_reg(4,  32'hFFFFFFFF, "x4  = lb  sign-extend of 0xFF (-1)");
        check_reg(5,  32'h000000FF, "x5  = lbu zero-extend of 0xFF (255)");
        check_reg(6,  32'hFFFFFFFF, "x6  = lh  sign-extend of 0xFFFF (-1)");
        check_reg(7,  32'h0000FFFF, "x7  = lhu zero-extend of 0xFFFF (65535)");
        check_reg(9,  32'h0000007F, "x9  = lb  positive byte (no sign-flip)");
        check_reg(10, 32'h0000007F, "x10 = lbu positive byte (matches x9)");
        check_reg(15, 32'h44332211, "x15 = lw  reassembled from 4 sb's (little-endian)");
        check_reg(18, 32'hFFFF0000, "x18 = lw  after sh (upper half preserved)");

        $display("\n--- ISA-Level Test4 Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule