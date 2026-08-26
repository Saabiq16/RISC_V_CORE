`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test5;
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
    // test5_branch build output before running this. If register
    // values look like a previous test's results, rebuild and rerun.

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

        // test5_branch.s has ~70+ real instructions before the loop
        // (6 branch types x taken/not-taken, plus 2 overflow canaries).
        // Generous margin since it loops forever afterward anyway.
        repeat (100) @(negedge clk);
        #1;

        // Expected values -- every register below should read exactly 1
        // if the corresponding branch behaved correctly. A value of 99
        // means that specific branch direction is broken.
        check_reg(10, 32'd1, "x10 = BEQ taken");
        check_reg(11, 32'd1, "x11 = BEQ not-taken");
        check_reg(12, 32'd1, "x12 = BNE taken");
        check_reg(13, 32'd1, "x13 = BNE not-taken");
        check_reg(14, 32'd1, "x14 = BLT taken (ordinary)");
        check_reg(15, 32'd1, "x15 = BLT not-taken (ordinary)");
        check_reg(16, 32'd1, "x16 = BLT overflow canary (INT_MIN < 1)");
        check_reg(17, 32'd1, "x17 = BGE taken (ordinary)");
        check_reg(18, 32'd1, "x18 = BGE not-taken (ordinary)");
        check_reg(23, 32'd1, "x23 = BGE overflow canary (1 >= INT_MIN)");
        check_reg(19, 32'd1, "x19 = BLTU taken (ordinary)");
        check_reg(20, 32'd1, "x20 = BLTU not-taken (signed/unsigned trap)");
        check_reg(21, 32'd1, "x21 = BGEU taken (ordinary)");
        check_reg(22, 32'd1, "x22 = BGEU not-taken (ordinary)");

        $display("\n--- ISA-Level Test5 (Branches) Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule