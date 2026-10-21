`timescale 1ns/1ps

// Timing rule (same as the other testbenches):
//   change inputs at negedge, check outputs at posedge + 1 ns.

module tb_program_counter_en;

    logic        clk, reset, enable;
    logic [31:0] pc_next, pc_current;

    int pass_count = 0;
    int fail_count = 0;

    program_counter_en dut (.*);

    always #5 clk = ~clk;

    task automatic check(input string name, input logic [31:0] actual, input logic [31:0] expected);
        if (actual === expected) begin
            pass_count++;
        end else begin
            fail_count++;
            $display("[FAIL] %-28s expected=%h actual=%h (time %0t)", name, expected, actual, $time);
        end
    endtask

    task automatic step(input logic r, input logic en, input logic [31:0] nxt);
        @(negedge clk);
        reset = r; enable = en; pc_next = nxt;
        @(posedge clk); #1;
    endtask

    initial begin
        clk = 0; reset = 1; enable = 1; pc_next = 32'hDEADBEEF;

        // reset clears the PC
        step(1, 1, 32'hDEADBEEF);  check("reset clears PC",             pc_current, 32'h0);

        // enable = 1: PC takes pc_next
        step(0, 1, 32'h00000004);  check("enable=1 loads pc_next",      pc_current, 32'h00000004);
        step(0, 1, 32'h00000008);  check("enable=1 loads again",         pc_current, 32'h00000008);

        // enable = 0: PC holds, pc_next ignored
        step(0, 0, 32'h0000000C);  check("enable=0 holds (1)",           pc_current, 32'h00000008);
        step(0, 0, 32'h00000010);  check("enable=0 holds (2)",           pc_current, 32'h00000008);

        // release: PC moves again
        step(0, 1, 32'h0000000C);  check("enable back to 1 loads",       pc_current, 32'h0000000C);

        // reset beats enable = 0
        step(1, 0, 32'h00000020);  check("reset wins over enable=0",     pc_current, 32'h0);

        // reset beats enable = 1
        step(0, 1, 32'h00000040);  check("load after reset",             pc_current, 32'h00000040);
        step(1, 1, 32'h00000044);  check("reset wins over enable=1",     pc_current, 32'h0);

        // every bit can be loaded and held (catches a stuck or crossed bit)
        for (int i = 0; i < 32; i++) begin
            step(0, 1, 32'h1 << i);
            check($sformatf("walk load bit%0d", i), pc_current, 32'h1 << i);
            step(0, 0, ~(32'h1 << i));
            check($sformatf("walk hold bit%0d", i), pc_current, 32'h1 << i);
        end

        // reset is synchronous: no clock edge, no change
        step(0, 1, 32'h000000AA);
        @(negedge clk);
        reset = 1;
        #1;
        check("sync reset: no edge, no change", pc_current, 32'h000000AA);
        @(posedge clk); #1;
        check("sync reset: edge clears",        pc_current, 32'h0);

        $display("\n--- program_counter_en ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $finish;
    end

endmodule