`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test1;

    logic clk;
    logic rst;

    int pass_count = 0;
    int fail_count = 0;

    // Instantiate your top-level single-cycle core.
    // Adjust port names if your actual top module differs.
    riscv_single_cycle dut (
        .clk (clk),
        .reset (rst)
    );

    // Free-running clock: 10ns period (100 MHz), toggling every 5ns.
    initial clk = 0;
    always #5 clk = ~clk;

    // NOTE: instruction_memory.sv already loads instructions.hex itself
    // via its own $readmemh at elaboration time, so no separate load
    // step is needed here -- just make sure the hex file at that
    // hardcoded path is the one you want tested before each run.

    // Reusable register-check task, following your established
    // check()-task / pass_count / fail_count convention.
    task automatic check_reg(
        input int          reg_num,
        input logic [31:0] exp_val,
        input string        test_name
    );
        // Adjust hierarchical path if your reg_file instance name differs.
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
        // Hold reset for two clock cycles to guarantee a clean,
        // fully-settled reset state before releasing.
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

        // Single-cycle core retires exactly 1 instruction per clock edge,
        // so 6 real instructions need a minimum of 6 posedges to complete.
        // We wait for 10 as margin -- safe because the program then loops
        // forever on "done: j done", so extra cycles don't change state.
        repeat (10) @(negedge clk);
        #1; // settle delay before sampling, per your TB convention

        // Expected values, hand-computed from test1.s:
        //   x1 = 5
        //   x2 = 10
        //   x3 = x1 + x2       = 15
        //   x4 = x2 - x1       = 5
        //   x5 = x1 & x2       = 0000_0101 & 0000_1010 = 0
        //   x6 = x1 | x2       = 0000_0101 | 0000_1010 = 15
        check_reg(1, 32'd5,  "x1 = 5 (addi)");
        check_reg(2, 32'd10, "x2 = 10 (addi)");
        check_reg(3, 32'd15, "x3 = x1+x2 (add)");
        check_reg(4, 32'd5,  "x4 = x2-x1 (sub)");
        check_reg(5, 32'd0,  "x5 = x1&x2 (and)");
        check_reg(6, 32'd15, "x6 = x1|x2 (or)");

        $display("\n--- ISA-Level Test1 Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule