`timescale 1ns/1ps

`include "../includes/riscv_defines.svh"

module tb_datapath_fetch;

    logic clk, reset;
    logic [31:0] pc_next;
    logic [31:0] instruction, pc, pc_plus_4;

    int pass_count = 0;
    int fail_count = 0;

    // Instantiate the fetch module
    fetch fetch_inst (
        .clk(clk),
        .reset(reset),
        .pc_next(pc_next),
        .instruction(instruction),
        .pc(pc),
        .pc_plus_4(pc_plus_4)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 time unit period
    end

    // Self-checking task
    task automatic check(
        input logic [31:0] exp_pc,
        input logic [31:0] exp_pc_plus4,
        input logic [31:0] exp_instr,
        input string        label
    );
        #1; // settle
        if (pc === exp_pc && pc_plus_4 === exp_pc_plus4 && instruction === exp_instr) begin
            pass_count++;
            $display("[PASS] %s: pc=%h pc+4=%h instr=%h", label, pc, pc_plus_4, instruction);
        end else begin
            fail_count++;
            $display("[FAIL] %s: pc=%h (exp %h) pc+4=%h (exp %h) instr=%h (exp %h)",
                       label, pc, exp_pc, pc_plus_4, exp_pc_plus4, instruction, exp_instr);
        end
    endtask

    // Test sequence
    initial begin
        // Apply reset
        reset = 1;
        pc_next = 32'd0;
        @(posedge clk);
        check(32'h0, 32'h4, 32'h11111111, "reset state");

        reset = 0;

        // Straight-line fetch: feed pc_next = pc_plus_4 each cycle
        @(negedge clk); pc_next = pc_plus_4;
        @(posedge clk); check(32'h4, 32'h8, 32'h22222222, "seq +4");

        @(negedge clk); pc_next = pc_plus_4;
        @(posedge clk); check(32'h8, 32'hC, 32'h33333333, "seq +8");

        @(negedge clk); pc_next = pc_plus_4;
        @(posedge clk); check(32'hC, 32'h10, 32'h44444444, "seq +C");

        // Forced non-sequential jump — hex file word index 0x3FF -> byte address 0xFFC
        @(negedge clk); pc_next = 32'hFFC;
        @(posedge clk); check(32'hFFC, 32'h1000, 32'hFFFFFFFF, "jump");

        $display("---- %0d passed, %0d failed ----", pass_count, fail_count);
        $finish;
    end

endmodule