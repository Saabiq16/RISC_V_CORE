`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test2;
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
    // test2_imm_alu build output before running this.

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

        // test2_imm_alu.s has 16 real instructions before the loop.
        // Wait margin bumped up accordingly; loop at the end makes
        // extra cycles harmless.
        repeat (20) @(negedge clk);
        #1;

        // Expected values, hand-computed from test2_imm_alu.s:
        check_reg(1,  32'd15,        "x1 = 15 (addi)");
        check_reg(2,  -32'd5,        "x2 = -5 (addi, sign-ext)");
        check_reg(3,  -32'd5,        "x3 = x1 + (-20) (addi)");
        check_reg(4,  32'd1,         "x4 = (x2<0) (slti signed)");
        check_reg(5,  32'd0,         "x5 = (x1<0) (slti signed)");
        check_reg(6,  32'd1,         "x6 = (x1<u20) (sltiu)");
        check_reg(7,  32'd0,         "x7 = (x2<u1) (sltiu unsigned trap)");
        check_reg(8,  32'hFFFFFFF0,  "x8 = x1^-1 (xori / NOT)");
        check_reg(9,  32'd47,        "x9 = x1|0x20 (ori)");
        check_reg(10, 32'd15,        "x10 = x1&0x0F (andi)");
        check_reg(12, 32'd16,        "x12 = x11<<4 (slli)");
        check_reg(14, 32'h0FFFFFFF,  "x14 = x13>>4 logical (srli)");
        check_reg(16, 32'hFFFFFFFF,  "x16 = x15>>>4 arithmetic (srai)");

        $display("\n--- ISA-Level Test2 Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule