`timescale 1ns/1ps

module tb_program_counter;

    logic        clk;
    logic        reset;
    logic [31:0] pc_next;
    logic [31:0] pc_out;

    int pass_count = 0;
    int fail_count = 0;

    program_counter dut (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .pc_out(pc_out)
    );

    // clock generation
    always #5 clk = ~clk;

    task automatic check(
        input [31:0] exp_pc_out,
        input string test_name
    );
        #1; // let non-blocking assignment settle after posedge
        if (pc_out === exp_pc_out) begin
            pass_count++;
            $display("PASS: %s (pc_out = %0h)", test_name, pc_out);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=%0h got=%0h", test_name, exp_pc_out, pc_out);
        end
    endtask

    initial begin
        clk     = 0;
        reset   = 1;
        pc_next = 32'hDEAD_BEEF; // garbage value, should be ignored during reset

        // Test 1: reset should force pc_out to 0 on posedge clk
        @(negedge clk); // let reset settle before clock edge
        @(posedge clk);
        check(32'h0000_0000, "Reset forces PC to 0");

        // Test 2: de-assert reset, load pc_next = 4 (simulating PC+4 first fetch)
        @(negedge clk);
        reset   = 0;
        pc_next = 32'h0000_0004;
        @(posedge clk);
        check(32'h0000_0004, "PC loads pc_next = 4 after reset de-asserted");

        // Test 3: normal sequential increment, pc_next = 8
        @(negedge clk);
        pc_next = 32'h0000_0008;
        @(posedge clk);
        check(32'h0000_0008, "PC loads pc_next = 8 (sequential fetch)");

        // Test 4: simulate a branch/jump target load, pc_next = some non-sequential address
        @(negedge clk);
        pc_next = 32'h0000_1000;
        @(posedge clk);
        check(32'h0000_1000, "PC loads branch/jump target 0x1000");

        // Test 5: re-assert reset mid-operation, should force back to 0 regardless of pc_next
        @(negedge clk);
        reset   = 1;
        pc_next = 32'hFFFF_FFFF; // garbage, should be ignored
        @(posedge clk);
        check(32'h0000_0000, "Mid-operation reset forces PC back to 0");

        // Test 6: de-assert reset again, confirm normal operation resumes
        @(negedge clk);
        reset   = 0;
        pc_next = 32'h0000_000C;
        @(posedge clk);
        check(32'h0000_000C, "PC resumes normal load after reset de-asserted again");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule