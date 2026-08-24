`timescale 1ns/1ps

module tb_mux_alu_src_b;

    logic [31:0] rs2_data;
    logic [31:0] imm_data;
    logic        alu_src_sel_b;
    logic [31:0] mux_alu_b_out;

    int pass_count = 0;
    int fail_count = 0;

    mux_alu_src_b dut (
        .rs2_data      (rs2_data),
        .imm_data      (imm_data),
        .alu_src_sel_b (alu_src_sel_b),
        .mux_alu_b_out (mux_alu_b_out)
    );

    task automatic check(
        input [31:0] rs2_in,
        input [31:0] imm_in,
        input        sel_in,
        input [31:0] exp_out,
        input string test_name
    );
        rs2_data      = rs2_in;
        imm_data      = imm_in;
        alu_src_sel_b = sel_in;
        #1;
        if (mux_alu_b_out === exp_out) begin
            pass_count++;
            $display("PASS: %s (rs2=0x%08h, imm=0x%08h, sel=%b, out=0x%08h)", test_name, rs2_in, imm_in, alu_src_sel_b, mux_alu_b_out);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=0x%08h got=0x%08h", test_name, exp_out, mux_alu_b_out);
        end
    endtask

    initial begin

        // Test 1: sel=0 -> select rs2_data (R-type)
        check(32'h00000005, 32'h000000FF, 1'b0, 32'h00000005, "sel=0 -> rs2_data selected");

        // Test 2: sel=1 -> select imm_data (I-type/S-type)
        check(32'h00000005, 32'h000000FF, 1'b1, 32'h000000FF, "sel=1 -> imm_data selected");

        // Test 3: different values, sel=0
        check(32'h1000, 32'hABCD, 1'b0, 32'h1000, "sel=0 -> rs2_data selected (diff values)");

        // Test 4: different values, sel=1
        check(32'h1000, 32'hABCD, 1'b1, 32'hABCD, "sel=1 -> imm_data selected (diff values)");

        // Test 5: edge case, both zero
        check(32'h0, 32'h0, 1'b0, 32'h0, "sel=0 -> both zero, output zero");

        // Test 6: edge case, both max value
        check(32'hFFFFFFFF, 32'hFFFFFFFF, 1'b1, 32'hFFFFFFFF, "sel=1 -> both max, output max");

        // Test 7: negative immediate value (sign-extended, e.g. from ImmGen)
        check(32'h00000010, 32'hFFFFFFF8, 1'b1, 32'hFFFFFFF8, "sel=1 -> negative immediate selected correctly");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule