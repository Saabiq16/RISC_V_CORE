`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

// Full testbench for id_ex_reg.
//
// Rules of the DUT being tested:
//   1. reset (asynchronous) or flush (at a clock edge) clears every CONTROL
//      output and rd_e. This is the "bubble".
//   2. Otherwise every output is a copy of its input, one clock later.
//   3. DATA outputs (pc, rs1_data, rs2_data, imm, rs1, rs2, funct3, funct7_5)
//      are always copied, even during reset or flush. They are "don't care"
//      in a bubble, so this testbench does not check them on reset or flush.
//
// Timing rule used everywhere (same as your other testbenches):
//   change inputs at negedge, check outputs at posedge + 1 ns.

module tb_id_ex_reg_full;

    // ------------------------------------------------------------------
    // Signals
    // ------------------------------------------------------------------
    logic clk, reset, flush;

    // inputs from the decode side
    logic        reg_write_enable_d, alu_src_a_d, alu_src_b_d;
    logic        mem_write_enable_d, mem_read_enable_d;
    logic [2:0]  alu_op_d;
    logic [1:0]  result_src_d;
    logic        branch_d, jump_d, base_select_d;
    logic [31:0] pc_current_d, pc_plus_4_d, rs1_data_d, rs2_data_d, imm_ext_d;
    logic [4:0]  rs1_d, rs2_d, rd_d;
    logic [2:0]  funct3_d;
    logic        funct7_5_d;

    // outputs to the execute side
    logic        reg_write_enable_e, alu_src_a_e, alu_src_b_e;
    logic        mem_write_enable_e, mem_read_enable_e;
    logic [2:0]  alu_op_e;
    logic [1:0]  result_src_e;
    logic        branch_e, jump_e, base_select_e;
    logic [31:0] pc_current_e, pc_plus_4_e, rs1_data_e, rs2_data_e, imm_ext_e;
    logic [4:0]  rs1_e, rs2_e, rd_e;
    logic [2:0]  funct3_e;
    logic        funct7_5_e;

    int pass_count = 0;
    int fail_count = 0;
    bit verbose    = 1;     // 1 = print every PASS, 0 = print only FAIL

    id_ex_reg dut (
        .clk(clk), .reset(reset), .flush(flush),
        .reg_write_enable_d(reg_write_enable_d),
        .alu_src_a_d(alu_src_a_d), .alu_src_b_d(alu_src_b_d),
        .mem_write_enable_d(mem_write_enable_d), .mem_read_enable_d(mem_read_enable_d),
        .alu_op_d(alu_op_d), .result_src_d(result_src_d),
        .branch_d(branch_d), .jump_d(jump_d), .base_select_d(base_select_d),
        .pc_current_d(pc_current_d), .pc_plus_4_d(pc_plus_4_d),
        .rs1_data_d(rs1_data_d), .rs2_data_d(rs2_data_d), .imm_ext_d(imm_ext_d),
        .rs1_d(rs1_d), .rs2_d(rs2_d), .rd_d(rd_d),
        .funct3_d(funct3_d), .funct7_5_d(funct7_5_d),

        .reg_write_enable_e(reg_write_enable_e),
        .alu_src_a_e(alu_src_a_e), .alu_src_b_e(alu_src_b_e),
        .mem_write_enable_e(mem_write_enable_e), .mem_read_enable_e(mem_read_enable_e),
        .alu_op_e(alu_op_e), .result_src_e(result_src_e),
        .branch_e(branch_e), .jump_e(jump_e), .base_select_e(base_select_e),
        .pc_current_e(pc_current_e), .pc_plus_4_e(pc_plus_4_e),
        .rs1_data_e(rs1_data_e), .rs2_data_e(rs2_data_e), .imm_ext_e(imm_ext_e),
        .rs1_e(rs1_e), .rs2_e(rs2_e), .rd_e(rd_e),
        .funct3_e(funct3_e), .funct7_5_e(funct7_5_e)
    );

    always #5 clk = ~clk;

    // COVERAGE_BEGIN
    // Functional coverage: which situations did the test actually create?
    covergroup cg_id_ex @(posedge clk);
        cp_reset    : coverpoint reset;
        cp_flush    : coverpoint flush;
        cp_regwrite : coverpoint reg_write_enable_d;
        cp_memread  : coverpoint mem_read_enable_d;
        cp_memwrite : coverpoint mem_write_enable_d;
        cp_branch   : coverpoint branch_d;
        cp_jump     : coverpoint jump_d;
        cp_alu_op   : coverpoint alu_op_d;        // all 8 values
        cp_result   : coverpoint result_src_d;    // all 4 values
        // flush while each kind of instruction is in the register
        x_flush_regwrite : cross cp_flush, cp_regwrite;
        x_flush_memread  : cross cp_flush, cp_memread;   // load-use bubble
        x_flush_memwrite : cross cp_flush, cp_memwrite;  // store
        x_flush_branch   : cross cp_flush, cp_branch;    // branch
        x_flush_jump     : cross cp_flush, cp_jump;      // jump
    endgroup
    cg_id_ex cg_inst = new();
    // COVERAGE_END

    // ------------------------------------------------------------------
    // Check helpers
    // ------------------------------------------------------------------
    task automatic check(string name, logic [31:0] actual, logic [31:0] expected);
        if (actual === expected) begin
            pass_count++;
            if (verbose)
                $display("[PASS] %-34s expected=%h actual=%h", name, expected, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %-34s expected=%h actual=%h (time %0t)", name, expected, actual, $time);
        end
    endtask

    // After a flush or reset: every control output and rd_e must be 0.
    task automatic check_bubble(string tag);
        check($sformatf("%s:reg_write_enable_e", tag), reg_write_enable_e, 0);
        check($sformatf("%s:alu_src_a_e",        tag), alu_src_a_e,        0);
        check($sformatf("%s:alu_src_b_e",        tag), alu_src_b_e,        0);
        check($sformatf("%s:mem_write_enable_e", tag), mem_write_enable_e, 0);
        check($sformatf("%s:mem_read_enable_e",  tag), mem_read_enable_e,  0);
        check($sformatf("%s:alu_op_e",           tag), alu_op_e,           0);
        check($sformatf("%s:result_src_e",       tag), result_src_e,       0);
        check($sformatf("%s:branch_e",           tag), branch_e,           0);
        check($sformatf("%s:jump_e",             tag), jump_e,             0);
        check($sformatf("%s:base_select_e",      tag), base_select_e,      0);
        check($sformatf("%s:rd_e",               tag), rd_e,               0);
    endtask

    // Normal cycle: every output must equal its input.
    // The inputs have not changed since negedge, so they still hold the
    // values that were latched at the posedge.
    task automatic check_passthrough(string tag);
        check($sformatf("%s:reg_write_enable_e", tag), reg_write_enable_e, reg_write_enable_d);
        check($sformatf("%s:alu_src_a_e",        tag), alu_src_a_e,        alu_src_a_d);
        check($sformatf("%s:alu_src_b_e",        tag), alu_src_b_e,        alu_src_b_d);
        check($sformatf("%s:mem_write_enable_e", tag), mem_write_enable_e, mem_write_enable_d);
        check($sformatf("%s:mem_read_enable_e",  tag), mem_read_enable_e,  mem_read_enable_d);
        check($sformatf("%s:alu_op_e",           tag), alu_op_e,           alu_op_d);
        check($sformatf("%s:result_src_e",       tag), result_src_e,       result_src_d);
        check($sformatf("%s:branch_e",           tag), branch_e,           branch_d);
        check($sformatf("%s:jump_e",             tag), jump_e,             jump_d);
        check($sformatf("%s:base_select_e",      tag), base_select_e,      base_select_d);
        check($sformatf("%s:rd_e",               tag), rd_e,               rd_d);
        check($sformatf("%s:pc_current_e",       tag), pc_current_e,       pc_current_d);
        check($sformatf("%s:pc_plus_4_e",        tag), pc_plus_4_e,        pc_plus_4_d);
        check($sformatf("%s:rs1_data_e",         tag), rs1_data_e,         rs1_data_d);
        check($sformatf("%s:rs2_data_e",         tag), rs2_data_e,         rs2_data_d);
        check($sformatf("%s:imm_ext_e",          tag), imm_ext_e,          imm_ext_d);
        check($sformatf("%s:rs1_e",              tag), rs1_e,              rs1_d);
        check($sformatf("%s:rs2_e",              tag), rs2_e,              rs2_d);
        check($sformatf("%s:funct3_e",           tag), funct3_e,           funct3_d);
        check($sformatf("%s:funct7_5_e",         tag), funct7_5_e,         funct7_5_d);
    endtask

    // ------------------------------------------------------------------
    // Stimulus helpers (call these right after @(negedge clk))
    // ------------------------------------------------------------------
    task automatic set_inputs_zero();
        {reg_write_enable_d, alu_src_a_d, alu_src_b_d, mem_write_enable_d,
         mem_read_enable_d, branch_d, jump_d, base_select_d} = 8'h00;
        alu_op_d = 0;  result_src_d = 0;
        pc_current_d = 0; pc_plus_4_d = 0; rs1_data_d = 0; rs2_data_d = 0; imm_ext_d = 0;
        rs1_d = 0; rs2_d = 0; rd_d = 0; funct3_d = 0; funct7_5_d = 0;
    endtask

    task automatic set_inputs_ones();
        {reg_write_enable_d, alu_src_a_d, alu_src_b_d, mem_write_enable_d,
         mem_read_enable_d, branch_d, jump_d, base_select_d} = 8'hFF;
        alu_op_d = 3'b111;  result_src_d = 2'b11;
        pc_current_d = 32'hFFFFFFFF; pc_plus_4_d = 32'hFFFFFFFF;
        rs1_data_d = 32'hFFFFFFFF; rs2_data_d = 32'hFFFFFFFF; imm_ext_d = 32'hFFFFFFFF;
        rs1_d = 5'h1F; rs2_d = 5'h1F; rd_d = 5'h1F; funct3_d = 3'b111; funct7_5_d = 1;
    endtask

    task automatic set_inputs_random();
        reg_write_enable_d = $urandom;  alu_src_a_d = $urandom;  alu_src_b_d = $urandom;
        mem_write_enable_d = $urandom;  mem_read_enable_d = $urandom;
        branch_d = $urandom;  jump_d = $urandom;  base_select_d = $urandom;
        alu_op_d = $urandom;  result_src_d = $urandom;
        pc_current_d = $urandom;  pc_plus_4_d = $urandom;
        rs1_data_d = $urandom;  rs2_data_d = $urandom;  imm_ext_d = $urandom;
        rs1_d = $urandom;  rs2_d = $urandom;  rd_d = $urandom;
        funct3_d = $urandom;  funct7_5_d = $urandom;
    endtask

    // One clock cycle with flush = 1, then check the bubble.
    task automatic flush_cycle(string tag);
        @(negedge clk);
        flush = 1;
        @(posedge clk); #1;
        check_bubble(tag);
        @(negedge clk);
        flush = 0;
    endtask

    // ------------------------------------------------------------------
    // The test
    // ------------------------------------------------------------------
    logic [7:0] w;

    initial begin
        clk = 0; reset = 1; flush = 0;
        set_inputs_ones();          // non-zero inputs, so reset has something to clear

        // ---- TEST 1: reset clears all control outputs ----
        @(negedge clk);
        @(posedge clk); #1;
        check_bubble("T1_reset");
        reset = 0;

        // ---- TEST 2: pass-through, all inputs 1 ----
        @(negedge clk);
        set_inputs_ones();
        @(posedge clk); #1;
        check_passthrough("T2_all_ones");

        // ---- TEST 3: pass-through, all inputs 0 ----
        @(negedge clk);
        set_inputs_zero();
        @(posedge clk); #1;
        check_passthrough("T3_all_zero");

        // ---- TEST 4: one control bit at a time (catches crossed wires) ----
        for (int i = 0; i < 8; i++) begin
            @(negedge clk);
            set_inputs_zero();
            w = 8'b1 << i;
            {reg_write_enable_d, alu_src_a_d, alu_src_b_d, mem_write_enable_d,
             mem_read_enable_d, branch_d, jump_d, base_select_d} = w;
            @(posedge clk); #1;
            check_passthrough($sformatf("T4_ctrl_bit%0d", i));
        end

        // ---- TEST 5: every alu_op value, every result_src value ----
        for (int i = 0; i < 8; i++) begin
            @(negedge clk);
            set_inputs_zero();
            alu_op_d = i[2:0];
            @(posedge clk); #1;
            check_passthrough($sformatf("T5_alu_op_%0d", i));
        end
        for (int i = 0; i < 4; i++) begin
            @(negedge clk);
            set_inputs_zero();
            result_src_d = i[1:0];
            @(posedge clk); #1;
            check_passthrough($sformatf("T5_result_src_%0d", i));
        end

        // ---- TEST 6: data buses, one moving 1 on each, all different ----
        // Every bit of every data bus goes 0->1 and 1->0, and each bus
        // gets a different pattern so a crossed wire shows up as a mismatch.
        verbose = 0;                // 32 cycles x 20 checks, print only failures
        for (int i = 0; i < 32; i++) begin
            @(negedge clk);
            set_inputs_zero();
            pc_current_d = 32'h1 << i;
            pc_plus_4_d  = 32'h1 << ((i + 1) % 32);
            rs1_data_d   = 32'h1 << ((i + 2) % 32);
            rs2_data_d   = 32'h1 << ((i + 3) % 32);
            imm_ext_d    = 32'h1 << ((i + 4) % 32);
            rs1_d        = i[4:0];
            rs2_d        = (i + 11) % 32;
            rd_d         = (i + 21) % 32;
            funct3_d     = i % 8;
            funct7_5_d   = i % 2;
            @(posedge clk); #1;
            check_passthrough($sformatf("T6_data_walk%0d", i));
        end
        verbose = 1;
        $display("[INFO] T6 data walk finished (only failures are printed)");

        // ---- TEST 7: flush clears control, for each kind of instruction ----
        // load
        @(negedge clk);
        set_inputs_zero();
        mem_read_enable_d = 1; reg_write_enable_d = 1; result_src_d = 2'b01; rd_d = 5'd7;
        flush_cycle("T7_flush_load");
        // store
        @(negedge clk);
        set_inputs_zero();
        mem_write_enable_d = 1; alu_src_b_d = 1;
        flush_cycle("T7_flush_store");
        // branch
        @(negedge clk);
        set_inputs_zero();
        branch_d = 1; base_select_d = 0; alu_op_d = 3'b001;
        flush_cycle("T7_flush_branch");
        // jump (JALR style)
        @(negedge clk);
        set_inputs_zero();
        jump_d = 1; base_select_d = 1; reg_write_enable_d = 1; result_src_d = 2'b10;
        flush_cycle("T7_flush_jump");
        // everything set at once
        @(negedge clk);
        set_inputs_ones();
        flush_cycle("T7_flush_all_ones");

        // ---- TEST 8: after a flush, the next cycle is normal again ----
        @(negedge clk);
        set_inputs_ones();
        flush = 1;
        @(posedge clk); #1;
        check_bubble("T8_flushed");
        @(negedge clk);
        flush = 0;                  // same inputs, flush released
        @(posedge clk); #1;
        check_passthrough("T8_recovered");

        // ---- TEST 9: reset is asynchronous (acts without a clock edge) ----
        @(negedge clk);
        set_inputs_ones();
        @(posedge clk); #1;
        check_passthrough("T9_before_reset");
        @(negedge clk);
        reset = 1;                  // no clock edge for the next 5 ns
        #1;
        check_bubble("T9_async_reset");
        @(posedge clk); #1;
        check_bubble("T9_reset_held");
        @(negedge clk);
        reset = 0;
        @(posedge clk); #1;
        check_passthrough("T9_after_reset");

        // ---- TEST 10: random inputs, random flush, with a reference check ----
        verbose = 0;
        for (int n = 0; n < 300; n++) begin
            @(negedge clk);
            set_inputs_random();
            flush = ($urandom % 4 == 0);
            @(posedge clk); #1;
            if (flush) check_bubble($sformatf("T10_rand%0d_flush", n));
            else       check_passthrough($sformatf("T10_rand%0d", n));
        end
        verbose = 1;
        $display("[INFO] T10 random test finished (only failures are printed)");

        // ---- Summary ----
        $display("\n=== tb_id_ex_reg_full: %0d passed, %0d failed ===", pass_count, fail_count);
        if (fail_count == 0) $display("ALL CHECKS PASSED");
        else                 $display("SOME CHECKS FAILED");
        $display("Functional coverage: %0.2f%%", cg_inst.get_coverage());  // COVERAGE_LINE
        $finish;
    end

endmodule