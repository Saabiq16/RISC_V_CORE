`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test8;
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
    // test8_combined build output before running this. If register
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

        // test8_combined.s has ~35 real instructions before the loop,
        // PLUS the countdown loop itself runs 5 iterations x 3 instrs
        // = 15 extra cycles. Generous margin since it loops forever
        // at the end anyway.
        repeat (80) @(negedge clk);
        #1;

        // ===== Intermediate checks (helps localize a failure fast) =====
        check_reg(3,  32'd20, "x3  = 12+8 (phase1 add)");
        check_reg(4,  32'd4,  "x4  = 12-8 (phase1 sub)");
        check_reg(5,  32'd80, "x5  = 20<<2 (phase1 slli)");
        check_reg(6,  32'd80, "x6  = 80&0xFF (phase1 andi)");
        check_reg(7,  32'h00000040, "x7  = base address (within data_memory range)");

        check_reg(8,  32'd20, "x8  = lw reload of x3's stored value");
        check_reg(9,  32'd4,  "x9  = lw reload of x4's stored value");
        check_reg(10, 32'd80, "x10 = lw reload of x5's stored value");
        check_reg(11, 32'd80, "x11 = lbu reload of x6's stored value");

        check_reg(12, 32'd24, "x12 = x8+x9 (recompute on LOADED values)");
        check_reg(13, 32'd56, "x13 = x10-x12 (recompute on LOADED values)");

        // ===== Integration-level checks (the real point of Test8) =====
        check_reg(20, 32'd1, "x20 = full arith->store->load->recompute->branch chain correct");
        check_reg(21, 32'd5, "x21 = backward-branch loop executed exactly 5 times");
        check_reg(15, 32'd0, "x15 = loop counter reached exact termination");
        check_reg(22, 32'd1, "x22 = JAL landed in subroutine");
        check_reg(23, 32'd1, "x23 = JALR correctly returned control after subroutine");

        $display("\n--- ISA-Level Test8 (Combined Integration) Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule