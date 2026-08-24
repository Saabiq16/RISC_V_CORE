`timescale 1ns/1ps

module tb_mux_base_select_pc_branch;

    logic [31:0] pc_current;
    logic [31:0] rs1;
    logic        base_sel;
    logic [31:0] base_out;

    int pass_count = 0;
    int fail_count = 0;

    mux_base_select_pc_branch dut (
        .pc_current(pc_current),
        .rs1(rs1),
        .base_sel(base_sel),
        .base_out(base_out)
    );

    task automatic check(
        input [31:0] pc_in,
        input [31:0] rs1_in,
        input        sel_in,
        input [31:0] exp_out,
        input string test_name
    );
        pc_current = pc_in;
        rs1        = rs1_in;
        base_sel   = sel_in;
        #1;
        if (base_out === exp_out) begin
            pass_count++;
            $display("PASS: %s (pc=0x%08h, rs1=0x%08h, sel=%b, out=0x%08h)", test_name, pc_in, rs1_in, sel_in, base_out);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=0x%08h got=0x%08h", test_name, exp_out, base_out);
        end
    endtask

    initial begin

        // Test 1: base_sel=0 -> select pc_current
        check(32'h00000010, 32'h00000020, 1'b0, 32'h00000010, "sel=0 -> pc_current selected");

        // Test 2: base_sel=1 -> select rs1
        check(32'h00000010, 32'h00000020, 1'b1, 32'h00000020, "sel=1 -> rs1 selected");

        // Test 3: different values, base_sel=0
        check(32'h1000, 32'hABCD, 1'b0, 32'h1000, "sel=0 -> pc_current selected (diff values)");

        // Test 4: different values, base_sel=1
        check(32'h1000, 32'hABCD, 1'b1, 32'hABCD, "sel=1 -> rs1 selected (diff values)");

        // Test 5: edge case, both inputs zero
        check(32'h0, 32'h0, 1'b0, 32'h0, "sel=0 -> both zero, output zero");

        // Test 6: edge case, both inputs max value
        check(32'hFFFFFFFF, 32'hFFFFFFFF, 1'b1, 32'hFFFFFFFF, "sel=1 -> both max, output max");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule