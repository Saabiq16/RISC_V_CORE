`timescale 1ns/1ps

module tb_pc_branch_adder;

    logic [31:0] base;
    logic [31:0] immediate;
    logic [31:0] branch_target;

    int pass_count = 0;
    int fail_count = 0;

    pc_branch_adder dut (
        .base(base),
        .immediate(immediate),
        .branch_target(branch_target)
    );

    task automatic check(
        input [31:0] base_in,
        input [31:0] imm_in,
        input [31:0] exp_target,
        input string test_name
    );
        base      = base_in;
        immediate = imm_in;
        #1;
        if (branch_target === exp_target) begin
            pass_count++;
            $display("PASS: %s (base=0x%08h, imm=0x%08h, target=0x%08h)", test_name, base_in, imm_in, branch_target);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=0x%08h got=0x%08h", test_name, exp_target, branch_target);
        end
    endtask

    initial begin

        // Test 1: basic addition
        check(32'd100, 32'd8, 32'd108, "Basic: 100 + 8 = 108");

        // Test 2: branch-like case, PC + small positive offset
        check(32'h00000010, 32'h00000008, 32'h00000018, "Branch-like: PC=0x10 + imm=0x8 -> 0x18");

        // Test 3: negative immediate (backward branch), PC=0x20 + (-8)
        // -8 in 32-bit two's complement = 0xFFFFFFF8
        check(32'h00000020, 32'hFFFFFFF8, 32'h00000018, "Backward branch: PC=0x20 + (-8) -> 0x18");

        // Test 4: JALR-like case, rs1 base + immediate
        check(32'h00002000, 32'h00000004, 32'h00002004, "JALR-like: rs1=0x2000 + imm=4 -> 0x2004");

        // Test 5: zero immediate, target equals base unchanged
        check(32'h00001234, 32'h00000000, 32'h00001234, "Zero immediate: target = base");

        // Test 6: overflow/wraparound
        check(32'hFFFFFFFF, 32'd1, 32'h00000000, "Overflow: 0xFFFFFFFF + 1 wraps to 0");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule