`timescale 1ns/1ps

module tb_mux_pc_src;

    logic [31:0] pc_plus_4;
    logic [31:0] pc_branch;
    logic        pc_src_sel;
    logic [31:0] pc_next;

    int pass_count = 0;
    int fail_count = 0;

    mux_pc_src dut (
        .pc_plus_4(pc_plus_4),
        .pc_branch(pc_branch),
        .pc_src_sel(pc_src_sel),
        .pc_next(pc_next)
    );

    task automatic check(
        input [31:0] plus4_in,
        input [31:0] branch_in,
        input        sel_in,
        input [31:0] exp_out,
        input string test_name
    );
        pc_plus_4  = plus4_in;
        pc_branch  = branch_in;
        pc_src_sel = sel_in;
        #1;
        if (pc_next === exp_out) begin
            pass_count++;
            $display("PASS: %s (plus4=0x%08h, branch=0x%08h, sel=%b, out=0x%08h)", test_name, plus4_in, branch_in, sel_in, pc_next);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=0x%08h got=0x%08h", test_name, exp_out, pc_next);
        end
    endtask

    initial begin

        // Test 1: sel=0 -> select pc_plus_4 (normal sequential)
        check(32'h00000004, 32'h00001000, 1'b0, 32'h00000004, "sel=0 -> pc_plus_4 selected");

        // Test 2: sel=1 -> select pc_branch (branch/jump taken)
        check(32'h00000004, 32'h00001000, 1'b1, 32'h00001000, "sel=1 -> pc_branch selected");

        // Test 3: different values, sel=0
        check(32'h00000100, 32'h0000ABCD, 1'b0, 32'h00000100, "sel=0 -> pc_plus_4 selected (diff values)");

        // Test 4: different values, sel=1
        check(32'h00000100, 32'h0000ABCD, 1'b1, 32'h0000ABCD, "sel=1 -> pc_branch selected (diff values)");

        // Test 5: edge case, both zero
        check(32'h0, 32'h0, 1'b1, 32'h0, "sel=1 -> both zero, output zero");

        // Test 6: edge case, both max value
        check(32'hFFFFFFFF, 32'hFFFFFFFF, 1'b0, 32'hFFFFFFFF, "sel=0 -> both max, output max");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule