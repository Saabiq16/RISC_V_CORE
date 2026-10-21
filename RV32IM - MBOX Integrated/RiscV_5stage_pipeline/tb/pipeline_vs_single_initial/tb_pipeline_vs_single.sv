`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

// Differential test: the frozen single-cycle core is the golden model.
// Both cores run the SAME instructions.hex, then final x1..x31 and all of
// data memory are compared. No hand-computed expected values.
//
// Padded programs (pad_nops.py) while hazard handling is incomplete.
// Once forwarding / stall / flush all exist, run the UNPADDED program.

module tb_pipeline_vs_single;

    localparam int NUM_CYCLES  = 1000;   // programs end in a self-loop, extra cycles are harmless
    localparam bit VERBOSE_FWD = 1;      // 1 = print every forwarding event, 0 = counters only

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

    // ------------------------------------------------------------
    // Forwarding usage counters and debug monitor.
    // A pass only proves the answers were right. These show which
    // forwarding paths the program actually exercised. A count of 0 in
    // every program means that path is untested.
    // Sampled at posedge clk, where the pipeline registers still hold the
    // values of the cycle that just ended. EX_PC is the PC carried by
    // id_ex_reg (pc_current_e).
    // ------------------------------------------------------------
    int c_a_mem, c_a_wb, c_b_mem, c_b_wb;
    int c_link, c_store, c_jalr_base, c_branch_cmp;
    int c_stall, c_flush;       // load-use stalls and branch/jump flushes

    always @(posedge clk) begin
        if (!rst) begin

            // A: MEM -> EX
            if (dut_pl.forward_a_e == 2'b10) begin
                c_a_mem++;
                if (VERBOSE_FWD)
                    $display("[FWD A: MEM] time=%0t EX_PC=%08h rs1=x%0d rd_m=x%0d",
                             $time, dut_pl.pc_current_e, dut_pl.rs1_e, dut_pl.rd_m);
            end

            // A: WB -> EX
            if (dut_pl.forward_a_e == 2'b01) begin
                c_a_wb++;
                if (VERBOSE_FWD)
                    $display("[FWD A: WB ] time=%0t EX_PC=%08h rs1=x%0d rd_w=x%0d",
                             $time, dut_pl.pc_current_e, dut_pl.rs1_e, dut_pl.rd_w);
            end

            // B: MEM -> EX
            if (dut_pl.forward_b_e == 2'b10) begin
                c_b_mem++;
                if (VERBOSE_FWD)
                    $display("[FWD B: MEM] time=%0t EX_PC=%08h rs2=x%0d rd_m=x%0d",
                             $time, dut_pl.pc_current_e, dut_pl.rs2_e, dut_pl.rd_m);
            end

            // B: WB -> EX
            if (dut_pl.forward_b_e == 2'b01) begin
                c_b_wb++;
                if (VERBOSE_FWD)
                    $display("[FWD B: WB ] time=%0t EX_PC=%08h rs2=x%0d rd_w=x%0d",
                             $time, dut_pl.pc_current_e, dut_pl.rs2_e, dut_pl.rd_w);
            end

            // jal/jalr link value forwarded out of MEM
            if ((dut_pl.forward_a_e == 2'b10 || dut_pl.forward_b_e == 2'b10) &&
                dut_pl.result_src_m == dut_pl.RESULT_SRC_PC4 &&
                dut_pl.reg_write_m) begin
                c_link++;
                if (VERBOSE_FWD)
                    $display("[FWD LINK] time=%0t EX_PC=%08h MEM_rd=x%0d A_sel=%b B_sel=%b",
                             $time, dut_pl.pc_current_e, dut_pl.rd_m,
                             dut_pl.forward_a_e, dut_pl.forward_b_e);
            end

            // store data taken from a forwarded rs2
            if (dut_pl.mem_write_enable_e && dut_pl.forward_b_e != 2'b00) begin
                c_store++;
                if (VERBOSE_FWD)
                    $display("[FWD STORE DATA] time=%0t EX_PC=%08h rs2=x%0d rd_m=x%0d rd_w=x%0d B_sel=%b",
                             $time, dut_pl.pc_current_e, dut_pl.rs2_e,
                             dut_pl.rd_m, dut_pl.rd_w, dut_pl.forward_b_e);
            end

            // jalr target built from a forwarded rs1
            if (dut_pl.jump_e && dut_pl.base_select_e && dut_pl.forward_a_e != 2'b00) begin
                c_jalr_base++;
                if (VERBOSE_FWD)
                    $display("[FWD JALR BASE] time=%0t EX_PC=%08h rs1=x%0d rd_m=x%0d rd_w=x%0d A_sel=%b",
                             $time, dut_pl.pc_current_e, dut_pl.rs1_e,
                             dut_pl.rd_m, dut_pl.rd_w, dut_pl.forward_a_e);
            end

            // branch compare using at least one forwarded operand
            if (dut_pl.branch_e &&
                (dut_pl.forward_a_e != 2'b00 || dut_pl.forward_b_e != 2'b00)) begin
                c_branch_cmp++;
                if (VERBOSE_FWD)
                    $display("[FWD BRANCH CMP] time=%0t EX_PC=%08h rs1=x%0d rs2=x%0d rd_m=x%0d rd_w=x%0d A_sel=%b B_sel=%b",
                             $time, dut_pl.pc_current_e, dut_pl.rs1_e, dut_pl.rs2_e,
                             dut_pl.rd_m, dut_pl.rd_w, dut_pl.forward_a_e, dut_pl.forward_b_e);
            end


            // hazard unit activity
            if (dut_pl.pc_stall) begin
                c_stall++;
                if (VERBOSE_FWD)
                    $display("[STALL] time=%0t ID_PC=%08h load in EX rd=x%0d",
                             $time, dut_pl.pc_current_d, dut_pl.rd_e);
            end
            if (dut_pl.if_id_flush) begin
                c_flush++;
                if (VERBOSE_FWD)
                    $display("[FLUSH] time=%0t EX_PC=%08h redirect to %08h",
                             $time, dut_pl.pc_current_e, dut_pl.branch_target_e);
            end

        end
    end

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;

        c_a_mem      = 0;
        c_a_wb       = 0;
        c_b_mem      = 0;
        c_b_wb       = 0;
        c_link       = 0;
        c_store      = 0;
        c_jalr_base  = 0;
        c_branch_cmp = 0;
        c_stall      = 0;
        c_flush      = 0;

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

        // forwarding summary (add these over all programs; 0 in every run = untested path)
        $display("\n--- Forwarding summary (this run) ---");
        $display("A from MEM=%0d  A from WB=%0d  B from MEM=%0d  B from WB=%0d",
                 c_a_mem, c_a_wb, c_b_mem, c_b_wb);
        $display("Link=%0d  Store data=%0d  JALR base=%0d  Branch compare=%0d",
                 c_link, c_store, c_jalr_base, c_branch_cmp);
        $display("Load-use stalls=%0d  Branch/jump flushes=%0d", c_stall, c_flush);
        $display("(the four A/B counts can be slightly high: the unit also fires on rs1/rs2 fields that");
        $display(" an instruction does not use, e.g. immediate bits. Link/Store/JALR/Branch are exact.)");

        $display("\n--- Pipeline vs single-cycle ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL MATCH");
        else                 $display("MISMATCH");

        $finish;
    end

endmodule