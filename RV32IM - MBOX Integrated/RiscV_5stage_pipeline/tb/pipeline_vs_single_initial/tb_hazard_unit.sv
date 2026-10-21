`timescale 1ns/1ps

module tb_hazard_unit;

    logic [4:0] rs1_d, rs2_d, rd_e;
    logic       mem_read_e, pc_src_sel_e;
    logic       stall_f, stall_d, flush_d, flush_e;

    int pass_count = 0;
    int fail_count = 0;

    // helper bits for coverage (updated in drive)
    bit hit1, hit2, rd_x0;

    hazard_unit dut (.*);

    // COVERAGE_BEGIN
    covergroup cg_hz;
        cp_mr    : coverpoint mem_read_e;
        cp_hit1  : coverpoint hit1;        // rd_e == rs1_d
        cp_hit2  : coverpoint hit2;        // rd_e == rs2_d
        cp_rdx0  : coverpoint rd_x0;       // rd_e is x0
        cp_stall : coverpoint stall_f;
        cp_pc_src : coverpoint pc_src_sel_e;
        // every combination of the four conditions that decide the stall
        x_cond   : cross cp_mr, cp_hit1, cp_hit2, cp_rdx0;
        // stall result against the conditions
        x_res    : cross cp_stall, cp_mr, cp_rdx0;
        x_redirect : cross cp_pc_src, cp_stall;
    endgroup
    cg_hz cg_inst = new();
    // COVERAGE_END

    // independent reference model, written differently from the RTL
    function automatic logic ref_load_use(
        input logic [4:0] a, b, d, input logic mr);
        logic uses_load;
        uses_load = (a == d) | (b == d);
        if (!mr)            return 1'b0;
        else if (d == 5'd0) return 1'b0;
        else                return uses_load;
    endfunction

    // expected stall (applies to stall_f and stall_d), flush_d, flush_e
    task automatic check(input string name, input logic lu, input logic pc);
        logic exp_stall, exp_fd, exp_fe;
        exp_stall = lu & ~pc;      // redirect wins over stall
        exp_fd    = pc;
        exp_fe    = lu | pc;
        if (stall_f === exp_stall && stall_d === exp_stall &&
            flush_d === exp_fd    && flush_e === exp_fe) pass_count++;
        else begin
            fail_count++;
            $display("[FAIL] %s  rs1=%0d rs2=%0d rd_e=%0d mem_read=%b pc_src=%b | stall_f=%b stall_d=%b flush_d=%b flush_e=%b | exp stall=%b flush_d=%b flush_e=%b",
                     name, rs1_d, rs2_d, rd_e, mem_read_e, pc_src_sel_e,
                     stall_f, stall_d, flush_d, flush_e, exp_stall, exp_fd, exp_fe);
        end
    endtask

    task automatic drive(input logic [4:0] a, b, d, input logic mr, input logic pc);
        rs1_d = a; rs2_d = b; rd_e = d; mem_read_e = mr; pc_src_sel_e = pc;
        #1;
        hit1  = (rs1_d == rd_e);
        hit2  = (rs2_d == rd_e);
        rd_x0 = (rd_e == 5'd0);
        cg_inst.sample();
    endtask

    initial begin
        // ---- directed cases with literal expected values ----
        // check(name, load_use_expected, redirect)
        drive(5'd5, 5'd9, 5'd5, 1, 0);  check("load feeds rs1",             1'b1, 1'b0);
        drive(5'd9, 5'd5, 5'd5, 1, 0);  check("load feeds rs2",             1'b1, 1'b0);
        drive(5'd5, 5'd5, 5'd5, 1, 0);  check("load feeds both",            1'b1, 1'b0);
        drive(5'd1, 5'd2, 5'd3, 1, 0);  check("load, no match",             1'b0, 1'b0);
        drive(5'd5, 5'd9, 5'd5, 0, 0);  check("match but not a load",       1'b0, 1'b0);
        drive(5'd0, 5'd0, 5'd0, 1, 0);  check("load into x0, reads x0",     1'b0, 1'b0);
        drive(5'd0, 5'd7, 5'd0, 1, 0);  check("load into x0, rs1 is x0",    1'b0, 1'b0);
        drive(5'd7, 5'd0, 5'd0, 1, 0);  check("load into x0, rs2 is x0",    1'b0, 1'b0);
        drive(5'd31, 5'd1, 5'd31, 1, 0); check("highest register",          1'b1, 1'b0);
        // redirect cases
        drive(5'd1, 5'd2, 5'd3, 0, 1);  check("redirect alone",             1'b0, 1'b1);
        drive(5'd5, 5'd9, 5'd5, 0, 1);  check("redirect, no load",          1'b0, 1'b1);
        drive(5'd5, 5'd9, 5'd5, 1, 1);  check("redirect beats stall",       1'b1, 1'b1);
        drive(5'd0, 5'd0, 5'd0, 1, 1);  check("redirect, load into x0",     1'b0, 1'b1);

        // ---- exhaustive: every rs1, rs2, rd_e, mem_read and redirect value ----
        for (int a = 0; a < 32; a++)
          for (int b = 0; b < 32; b++)
            for (int d = 0; d < 32; d++)
              for (int mr = 0; mr < 2; mr++)
                for (int pc = 0; pc < 2; pc++) begin
                    drive(5'(a), 5'(b), 5'(d), mr[0], pc[0]);
                    check("exhaustive", ref_load_use(rs1_d, rs2_d, rd_e, mem_read_e), pc_src_sel_e);
                end

        $display("\n--- hazard_unit ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $display("Functional coverage: %0.2f%%", cg_inst.get_coverage());  // COVERAGE_LINE
        $finish;
    end

endmodule