`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

// Differential test: the frozen single-cycle core is the golden model.
// Both cores run the SAME instructions.hex (each instruction_memory does its
// own $readmemh of the same file), then final x1..x31 and all of data memory
// are compared. No hand-computed expected values, so it works for every
// padded test, including ones whose link/auipc values moved with padding.
//
// Use a NOP-padded program (pad_nops.py) while the pipeline has no hazard
// handling. After forwarding / stall / flush exist, run the UNPADDED program
// through this same testbench.

module tb_pipeline_vs_single;

    localparam int NUM_CYCLES = 1000;   // programs end in a self-loop, extra cycles are harmless

    logic clk;
    logic rst;

    int pass_count = 0;
    int fail_count = 0;

    riscv_single_cycle dut_sc (
        .clk   (clk),
        .reset (rst)
    );

    riscv_pipeline dut_pl (
        .clk   (clk),
        .reset (rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

        repeat (NUM_CYCLES) @(negedge clk);
        #1;

        // guard: if the hex never loaded, both cores are all-X and === would
        // report a match. The golden core must have produced real values.
        begin
            int known;
            known = 0;
            for (int r = 1; r < 32; r++)
                if (!$isunknown(dut_sc.reg_file.registers[r])) known++;
            if (known == 0) begin
                fail_count++;
                $display("[FAIL] single-cycle core has no known register values (hex not loaded?)");
            end
        end

        // ---- registers (x0 skipped: its storage cell is never written) ----
        for (int r = 1; r < 32; r++) begin
            if (dut_pl.reg_file.registers[r] === dut_sc.reg_file.registers[r]) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("[FAIL] x%0d  single=0x%08h  pipeline=0x%08h",
                         r, dut_sc.reg_file.registers[r], dut_pl.reg_file.registers[r]);
            end
        end

        // ---- data memory (byte array, size taken from the design) ----
        for (int a = 0; a < $size(dut_sc.data_mem.memory); a++) begin
            if (dut_pl.data_mem.memory[a] === dut_sc.data_mem.memory[a]) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("[FAIL] mem[%0d]  single=0x%02h  pipeline=0x%02h",
                         a, dut_sc.data_mem.memory[a], dut_pl.data_mem.memory[a]);
            end
        end

        // quick look at the registers so a pass is not a blind pass
        $display("\nsingle   : x1=%08h x2=%08h x3=%08h x4=%08h x6=%08h x10=%08h x20=%08h",
                 dut_sc.reg_file.registers[1], dut_sc.reg_file.registers[2],
                 dut_sc.reg_file.registers[3], dut_sc.reg_file.registers[4],
                 dut_sc.reg_file.registers[6], dut_sc.reg_file.registers[10],
                 dut_sc.reg_file.registers[20]);
        $display("pipeline : x1=%08h x2=%08h x3=%08h x4=%08h x6=%08h x10=%08h x20=%08h",
                 dut_pl.reg_file.registers[1], dut_pl.reg_file.registers[2],
                 dut_pl.reg_file.registers[3], dut_pl.reg_file.registers[4],
                 dut_pl.reg_file.registers[6], dut_pl.reg_file.registers[10],
                 dut_pl.reg_file.registers[20]);

        $display("\n--- Pipeline vs single-cycle ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL MATCH");
        else                 $display("MISMATCH");

        $finish;
    end

endmodule
