`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module fibonacci_tb;
    logic clk;
    logic rst;

    localparam logic [31:0] DONE_PC = 32'h00000020;

    int cycle_count;
    int instr_count;
    logic done_reached;

    riscv_single_cycle dut (
        .clk   (clk),
        .reset (rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // NOTE: instruction_memory.sv loads instructions.hex itself via
    // $readmemh at elaboration -- make sure it's pointing at the
    // fibonacci benchmark build output before running this.

    initial begin
        rst = 1;
        cycle_count  = 0;
        instr_count  = 0;
        done_reached = 0;

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        // Counting window: starts the cycle AFTER reset is released,
        // stops the moment PC first equals DONE_PC (before executing
        // whatever sits at DONE_PC itself, so the self-loop at 0x20
        // is never counted as part of the benchmark).
        while (!done_reached) begin
            @(negedge clk);
            #1;

            if (dut.pc_current == DONE_PC) begin
                done_reached = 1;
            end
            else begin
                cycle_count = cycle_count + 1;
                instr_count = instr_count + 1; // single-cycle: 1 instr/cycle by construction
            end
        end

        $display("\n--- Fibonacci Benchmark: Single-Cycle Performance ---");
        $display("Dynamic Instructions : %0d", instr_count);
        $display("Total Cycles         : %0d", cycle_count);
        $display("CPI                  : %0.3f", real'(cycle_count) / real'(instr_count));

        // Functional correctness check alongside the perf numbers --
        // fib(10) with this program's exact iteration structure.
        // x1/x2 hold the last two computed Fibonacci values.
        $display("\n--- Functional Check ---");
        $display("x1 (final) = %0d", dut.reg_file.registers[1]);
        $display("x2 (final) = %0d", dut.reg_file.registers[2]);

        $finish;
    end
endmodule