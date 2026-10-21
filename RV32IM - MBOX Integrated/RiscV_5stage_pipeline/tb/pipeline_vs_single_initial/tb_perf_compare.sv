`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

// Cycle count and CPI: single-cycle core vs pipeline, same program.
//
// Both cores run the SAME instructions.hex at the same time. No DONE_PC is
// needed: every program ends in a self-loop (loop: jal x0, loop), so
//   - single-cycle is done when its PC stops changing. That PC is the
//     address of the final loop instruction (the "sentinel").
//   - pipeline is done when the sentinel reaches WB.
// Both counts include the first execution of the sentinel, so the two numbers
// cover exactly the same instructions.
//
//   single-cycle : cycles = instructions (CPI = 1.000 by construction)
//   pipeline     : cycles = instructions + 4 (fill) + load-use stalls
//                           + 2 per taken branch/jump (flush)
// The last line checks the pipeline count against that formula, so any
// unexpected bubble shows up as a mismatch.

module tb_perf_compare;

    // Clock periods for the execution-time line. Take them from your timing
    // reports (minimum period of each core after implementation). Leave at
    // 0.0 to skip the time comparison.
    localparam real T_SINGLE_NS = 0.0;
    localparam real T_PIPE_NS   = 0.0;

    localparam int WATCHDOG = 200000;   // cycles, stops a program that never reaches its loop

    logic clk;
    logic rst;

    riscv_single_cycle dut_sc (.clk(clk), .reset(rst));
    riscv_pipeline     dut_pl (.clk(clk), .reset(rst));

    initial clk = 0;
    always #5 clk = ~clk;

    int          cyc;            // cycle index, 0 = first clock after reset
    logic [31:0] pc_prev;
    bit          have_prev;
    bit          sc_done, pl_done;
    logic [31:0] sentinel_pc;
    int          sc_cycles, pl_cycles, n_instr;
    int          c_stall, c_flush;

    // Sampled at posedge clk, where every register still holds the value of
    // the cycle that just ended.
    always @(posedge clk) begin
        if (!rst && !(sc_done && pl_done)) begin

            // ---- single-cycle: done when the PC repeats (self-loop) ----
            if (!sc_done) begin
                if (have_prev && dut_sc.pc_current === pc_prev) begin
                    sc_done     = 1;
                    sentinel_pc = dut_sc.pc_current;
                    sc_cycles   = cyc;      // cycles 0..cyc-1 ran every real instr + sentinel once
                    n_instr     = cyc;
                end
                pc_prev   = dut_sc.pc_current;
                have_prev = 1;
            end

            // ---- pipeline hazard activity ----
            if (!pl_done) begin
                if (dut_pl.pc_stall)     c_stall++;
                if (dut_pl.if_id_flush)  c_flush++;
            end

            // ---- pipeline: done when the sentinel is in WB ----
            // (a bubble has reg_write_w = 0, so only the real jal matches)
            if (sc_done && !pl_done) begin
                if (dut_pl.reg_write_w && dut_pl.pc_plus_4_w === sentinel_pc + 32'd4) begin
                    pl_done   = 1;
                    pl_cycles = cyc + 1;    // it finishes at the end of this cycle
                end
            end

            cyc++;
            if (cyc > WATCHDOG) begin
                $display("[FAIL] watchdog: program did not reach its final loop in %0d cycles", WATCHDOG);
                $finish;
            end
        end
    end

    initial begin
        cyc = 0; have_prev = 0; sc_done = 0; pl_done = 0;
        c_stall = 0; c_flush = 0;
        sc_cycles = 0; pl_cycles = 0; n_instr = 0;
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

        wait (sc_done && pl_done);
        @(negedge clk);
        #1;

        begin
            real cpi_pl;
            int  flush_real, expected;
            int  reg_mismatch;

            cpi_pl     = real'(pl_cycles) / real'(n_instr);
            // the last flush belongs to the final "jal x0, loop" itself and
            // does not delay anything before it
            flush_real = (c_flush > 0) ? c_flush - 1 : 0;
            expected   = n_instr + 4 + c_stall + 2 * flush_real;

            reg_mismatch = 0;
            for (int r = 1; r < 32; r++)
                if (dut_pl.reg_file.registers[r] !== dut_sc.reg_file.registers[r]) reg_mismatch++;

            $display("\n--- Performance: single-cycle vs pipeline ---");
            $display("Final loop instruction at PC = 0x%08h", sentinel_pc);
            $display("Dynamic instructions (incl. the first execution of the final jal): %0d", n_instr);
            $display("");
            $display("Single-cycle : cycles = %0d   CPI = %0.3f", sc_cycles, real'(sc_cycles) / real'(n_instr));
            $display("Pipeline     : cycles = %0d   CPI = %0.3f", pl_cycles, cpi_pl);
            $display("  load-use stall cycles      = %0d", c_stall);
            $display("  taken branch/jump flushes  = %0d  (final loop jump not counted)", flush_real);
            $display("  pipeline fill              = 4");
            if (expected == pl_cycles)
                $display("  accounting: %0d + 4 + %0d + 2*%0d = %0d  -> matches the measured cycle count",
                         n_instr, c_stall, flush_real, expected);
            else
                $display("  accounting: %0d + 4 + %0d + 2*%0d = %0d  -> DOES NOT MATCH (unexpected bubbles)",
                         n_instr, c_stall, flush_real, expected);
            $display("");
            $display("Cycle ratio pipeline / single-cycle = %0.3f", real'(pl_cycles) / real'(sc_cycles));

            if (T_SINGLE_NS > 0.0 && T_PIPE_NS > 0.0) begin
                $display("");
                $display("Execution time  single-cycle = %0.1f ns  (T = %0.3f ns)", sc_cycles * T_SINGLE_NS, T_SINGLE_NS);
                $display("Execution time  pipeline     = %0.1f ns  (T = %0.3f ns)", pl_cycles * T_PIPE_NS,   T_PIPE_NS);
                $display("Speedup (single / pipeline)  = %0.2fx", (sc_cycles * T_SINGLE_NS) / (pl_cycles * T_PIPE_NS));
            end else begin
                $display("(set T_SINGLE_NS and T_PIPE_NS to compare execution time, not only cycles)");
            end

            $display("");
            if (reg_mismatch == 0)
                $display("Final registers x1..x31, single vs pipeline: MATCH");
            else
                $display("Final registers x1..x31, single vs pipeline: MISMATCH (%0d registers)", reg_mismatch);
        end

        $finish;
    end

endmodule