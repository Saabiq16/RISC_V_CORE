`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_if_id_reg;

    logic        clk, reset, stall, flush;
    logic [31:0] pc_current_f, instruction_f, pc_plus_4_f;
    logic [31:0] pc_current_d, instruction_d, pc_plus_4_d;

    int pass_count = 0;
    int fail_count = 0;

    if_id_reg dut (
        .clk           (clk),
        .reset         (reset),
        .stall         (stall),
        .flush         (flush),
        .pc_current_f  (pc_current_f),
        .instruction_f (instruction_f),
        .pc_plus_4_f   (pc_plus_4_f),
        .pc_current_d  (pc_current_d),
        .instruction_d (instruction_d),
        .pc_plus_4_d   (pc_plus_4_d)
    );

    always #5 clk = ~clk;

    // functional coverage: which stall/flush combinations actually got
    // exercised, not just "did every line of RTL execute"
    covergroup cg_hazard @(posedge clk);
        cp_stall : coverpoint stall;
        cp_flush : coverpoint flush;
        cp_cross : cross cp_stall, cp_flush;
    endgroup
    cg_hazard cg_inst = new();

    task automatic check(string name, logic [31:0] actual, logic [31:0] expected);
        if (actual === expected) begin
            pass_count++;
            $display("[PASS] %-24s expected=%h actual=%h", name, expected, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %-24s expected=%h actual=%h", name, expected, actual);
        end
    endtask

    initial begin
        clk = 0; reset = 1; stall = 0; flush = 0;
        pc_current_f = 32'h0; instruction_f = 32'h0; pc_plus_4_f = 32'h0;

        // --- reset ---
        @(negedge clk);
        @(posedge clk); #1;
        check("reset:pc_current_d",  pc_current_d,  32'h0);
        check("reset:instruction_d", instruction_d, 32'h0);
        check("reset:pc_plus_4_d",   pc_plus_4_d,   32'h0);
        reset = 0;

        // --- normal pass-through ---
        @(negedge clk);
        pc_current_f  = 32'h1000;
        instruction_f = 32'h00A50533;  // arbitrary R-type
        pc_plus_4_f   = 32'h1004;
        stall = 0; flush = 0;
        @(posedge clk); #1;
        check("passthrough:pc",   pc_current_d,  32'h1000);
        check("passthrough:inst", instruction_d, 32'h00A50533);
        check("passthrough:pc4",  pc_plus_4_d,   32'h1004);

        // --- stall: hold previous values despite new fetch inputs ---
        @(negedge clk);
        pc_current_f  = 32'h2000;
        instruction_f = 32'hDEADBEEF;
        pc_plus_4_f   = 32'h2004;
        stall = 1; flush = 0;
        @(posedge clk); #1;
        check("stall:pc_held",   pc_current_d,  32'h1000);
        check("stall:inst_held", instruction_d, 32'h00A50533);
        check("stall:pc4_held",  pc_plus_4_d,   32'h1004);

        // --- flush: inject NOP regardless of fetch inputs ---
        @(negedge clk);
        stall = 0; flush = 1;
        @(posedge clk); #1;
        check("flush:pc",   pc_current_d,  32'h0);
        check("flush:inst", instruction_d, 32'h00000013);
        check("flush:pc4",  pc_plus_4_d,   32'h0);

        // --- flush must win when stall and flush are asserted together ---
        @(negedge clk);
        pc_current_f = 32'h3000; instruction_f = 32'hFFFFFFFF; pc_plus_4_f = 32'h3004;
        stall = 1; flush = 1;
        @(posedge clk); #1;
        check("flush_over_stall:inst", instruction_d, 32'h00000013);

        // hold stall low, flush low for one more cycle so the coverage
        // sampler catches the (stall=0, flush=0) bin explicitly
        @(negedge clk);
        stall = 0; flush = 0;
        @(posedge clk); #1;

        $display("\n=== tb_if_id_reg: %0d passed, %0d failed ===", pass_count, fail_count);
        $display("Functional coverage (stall x flush): %0.2f%%", cg_inst.get_coverage());
        $finish;
    end

endmodule