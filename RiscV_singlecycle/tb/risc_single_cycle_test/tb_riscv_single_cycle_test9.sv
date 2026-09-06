`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test9;
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
    // test9_edgecases build output before running this. If register
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

        // test9_edgecases.s has ~28 real instructions before the loop.
        // Generous margin since it loops forever afterward anyway.
        repeat (40) @(negedge clk);
        #1;

        // ===== Phase A: x0 hardwired-zero =====
        // NOTE: x0 is intentionally NOT checked via direct raw-storage
        // access (dut.reg_file.registers[0]) here. This design's
        // register_file forces x0's value to 0 at the READ-PORT mux
        // (see register_file.sv), not by ensuring the underlying
        // storage cell itself holds 0 -- registers[0] is simply never
        // written and stays at its simulator-default (X) forever.
        // Every real instruction reads x0 through that same read-port
        // mux, so this is correct, intended behavior, not a bug.
        // x1 below proves x0 reads as zero through the ACTUAL read
        // path every instruction uses, which is the real requirement.
        check_reg(1, 32'h00000000, "x1  = 0+0, confirms x0 reads as zero");

        // ===== Phase B: boundary values =====
        check_reg(3, 32'h00000000, "x3  = 0x00000000 boundary");
        check_reg(4, 32'hFFFFFFFF, "x4  = 0xFFFFFFFF boundary");
        check_reg(5, 32'h80000000, "x5  = INT_MIN boundary");
        check_reg(6, 32'h7FFFFFFF, "x6  = INT_MAX boundary");

        // ===== Phase C: overflow arithmetic =====
        check_reg(7, 32'h00000000, "x7  = INT_MIN+INT_MIN overflow wraps to 0");
        check_reg(8, 32'h80000000, "x8  = INT_MAX+1 overflow wraps to INT_MIN");

        // ===== Phase D: memory boundary addresses =====
        check_reg(11, 32'hFFFFFFFF, "x11 = reload from address 0");
        check_reg(12, 32'h80000000, "x12 = reload from address 1000");

        // ===== Phase E: branch boundary conditions =====
        check_reg(20, 32'd1, "x20 = BLT correct at signed extremes (INT_MIN < INT_MAX)");
        check_reg(21, 32'd1, "x21 = BEQ correct comparing zero from two sources");

        // ===== Phase F: jump target =====
        check_reg(22, 32'd1, "x22 = unconditional JAL landed correctly");

        // ===== Phase G: back-to-back dependent instructions =====
        check_reg(13, 32'd7,  "x13 = dependency chain start");
        check_reg(14, 32'd8,  "x14 = depends immediately on x13");
        check_reg(15, 32'd16, "x15 = depends immediately on x14");

        $display("\n--- ISA-Level Test9 (Edge Cases) Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule