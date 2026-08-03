`timescale 1ns/1ps

module tb_pc_adder4;

    logic [31:0] pc_current;
    logic [31:0] pc_plus4;

    int pass_count = 0;
    int fail_count = 0;

    pc_adder4 dut (
        .pc_current(pc_current),
        .pc_plus4(pc_plus4)
    );

    task automatic check(
        input [31:0] pc_in,
        input [31:0] exp_pc_plus4,
        input string test_name
    );
        pc_current = pc_in;
        #1;
        if (pc_plus4 === exp_pc_plus4) begin
            pass_count++;
            $display("PASS: %s (pc_current=0x%08h, pc_plus4=0x%08h)", test_name, pc_in, pc_plus4);
        end else begin
            fail_count++;
            $display("FAIL: %s | pc_current=0x%08h exp=0x%08h got=0x%08h", test_name, pc_in, exp_pc_plus4, pc_plus4);
        end
    endtask

    initial begin

        // Test 1: basic case, pc_current = 0
        check(32'd0, 32'd4, "Basic: pc_current=0 -> pc_plus4=4");

        // Test 2: sequential increment, pc_current = 4
        check(32'd4, 32'd8, "Sequential: pc_current=4 -> pc_plus4=8");

        // Test 3: arbitrary value, pc_current = 100
        check(32'd100, 32'd104, "Arbitrary: pc_current=100 -> pc_plus4=104");

        // Test 4: overflow/wraparound, pc_current = max 32-bit value
        check(32'hFFFFFFFF, 32'h00000003, "Overflow: pc_current=0xFFFFFFFF -> wraps to 0x3");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule