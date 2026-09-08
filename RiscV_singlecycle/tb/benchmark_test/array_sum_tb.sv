`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module array_sum_tb;
    logic clk;
    logic rst;

    localparam logic [31:0] DONE_PC = 32'h00000048;

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
    // array_sum benchmark build output before running this.

    initial begin
        rst = 1;
        cycle_count  = 0;
        instr_count  = 0;
        done_reached = 0;

        @(negedge clk);
        @(negedge clk);
        rst = 0;

        while (!done_reached) begin
            @(negedge clk);
            #1;

            if (dut.pc_current == DONE_PC) begin
                done_reached = 1;
            end
            else begin
                cycle_count = cycle_count + 1;
                instr_count = instr_count + 1;
            end
        end

        $display("\n--- Array Sum Benchmark: Single-Cycle Performance ---");
        $display("Dynamic Instructions : %0d", instr_count);
        $display("Total Cycles         : %0d", cycle_count);
        $display("CPI                  : %0.3f", real'(cycle_count) / real'(instr_count));

        $display("\n--- Functional Check ---");
        $display("x6 (sum) = %0d (expected 150)", dut.reg_file.registers[6]);

        $finish;
    end
endmodule