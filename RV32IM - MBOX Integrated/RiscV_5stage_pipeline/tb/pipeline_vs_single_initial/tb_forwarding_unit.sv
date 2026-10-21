`timescale 1ns/1ps

module tb_forwarding_unit;

    logic [4:0] rs1_e, rs2_e, rd_m, rd_w;
    logic       reg_write_m, reg_write_w;
    logic [1:0] forward_a_e, forward_b_e;

    int pass_count = 0;
    int fail_count = 0;

    // helper bits for coverage (updated in drive)
    bit a_hit_m, a_hit_w, b_hit_m, b_hit_w, a_x0, b_x0;

    forwarding_unit dut (.*);

    // COVERAGE_BEGIN
    covergroup cg_fwd;
        cp_wm   : coverpoint reg_write_m;
        cp_ww   : coverpoint reg_write_w;
        cp_fa   : coverpoint forward_a_e {
                      bins none = {2'b00};
                      bins wb   = {2'b01};
                      bins mem  = {2'b10};
                      illegal_bins bad = {2'b11}; }
        cp_fb   : coverpoint forward_b_e {
                      bins none = {2'b00};
                      bins wb   = {2'b01};
                      bins mem  = {2'b10};
                      illegal_bins bad = {2'b11}; }
        cp_a_m  : coverpoint a_hit_m;     // rs1_e == rd_m
        cp_a_w  : coverpoint a_hit_w;     // rs1_e == rd_w
        cp_b_m  : coverpoint b_hit_m;     // rs2_e == rd_m
        cp_b_w  : coverpoint b_hit_w;     // rs2_e == rd_w
        cp_a_x0 : coverpoint a_x0;        // rs1_e is x0
        cp_b_x0 : coverpoint b_x0;        // rs2_e is x0

        // MEM vs WB priority and write-enable gating, for each operand
        x_a_cases : cross cp_a_m, cp_a_w, cp_wm, cp_ww;
        x_b_cases : cross cp_b_m, cp_b_w, cp_wm, cp_ww;
        // x0 with a matching rd_m and an enabled write must still give 00
        x_a_x0    : cross cp_a_x0, cp_a_m, cp_wm;
        x_b_x0    : cross cp_b_x0, cp_b_m, cp_wm;
        // every A/B output combination
        x_ab      : cross cp_fa, cp_fb;
    endgroup
    cg_fwd cg_inst = new();
    // COVERAGE_END

    // independent reference model, written differently from the RTL
    function automatic logic [1:0] ref_fwd(
        input logic [4:0] rs, input logic [4:0] rdm, input logic [4:0] rdw,
        input logic wm, input logic ww);
        logic hit_m, hit_w;
        hit_m = wm & (rdm == rs) & (rs != 5'd0);
        hit_w = ww & (rdw == rs) & (rs != 5'd0);
        if (hit_m)      return 2'b10;
        else if (hit_w) return 2'b01;
        else            return 2'b00;
    endfunction

    task automatic check(input string name, input logic [1:0] got_a, input logic [1:0] exp_a,
                         input logic [1:0] got_b, input logic [1:0] exp_b);
        if (got_a === exp_a && got_b === exp_b) pass_count++;
        else begin
            fail_count++;
            $display("[FAIL] %s  rs1=%0d rs2=%0d rd_m=%0d rd_w=%0d wm=%b ww=%b  A got %b exp %b  B got %b exp %b",
                     name, rs1_e, rs2_e, rd_m, rd_w, reg_write_m, reg_write_w,
                     got_a, exp_a, got_b, exp_b);
        end
    endtask

    task automatic drive(input logic [4:0] a, b, m, w, input logic wm, ww);
        rs1_e = a; rs2_e = b; rd_m = m; rd_w = w; reg_write_m = wm; reg_write_w = ww;
        #1;
        a_hit_m = (rs1_e == rd_m);  a_hit_w = (rs1_e == rd_w);
        b_hit_m = (rs2_e == rd_m);  b_hit_w = (rs2_e == rd_w);
        a_x0    = (rs1_e == 5'd0);  b_x0    = (rs2_e == 5'd0);
        cg_inst.sample();
    endtask

    initial begin
        // ---- directed cases with literal expected values ----
        // (the exhaustive loop pairs rs1/rs2 by a fixed formula, so the last two
        //  directed cases cover the A/B output combinations it never produces)
        drive(5'd5, 5'd9, 5'd5, 5'd0, 1, 0);  check("MEM hit on A",         forward_a_e, 2'b10, forward_b_e, 2'b00);
        drive(5'd5, 5'd9, 5'd0, 5'd9, 0, 1);  check("WB hit on B",          forward_a_e, 2'b00, forward_b_e, 2'b01);
        drive(5'd5, 5'd5, 5'd5, 5'd5, 1, 1);  check("MEM beats WB",         forward_a_e, 2'b10, forward_b_e, 2'b10);
        drive(5'd0, 5'd0, 5'd0, 5'd0, 1, 1);  check("x0 never forwards",    forward_a_e, 2'b00, forward_b_e, 2'b00);
        drive(5'd7, 5'd7, 5'd7, 5'd7, 0, 0);  check("no write, no fwd",     forward_a_e, 2'b00, forward_b_e, 2'b00);
        drive(5'd7, 5'd7, 5'd7, 5'd7, 0, 1);  check("MEM no write, WB hit", forward_a_e, 2'b01, forward_b_e, 2'b01);
        drive(5'd1, 5'd2, 5'd2, 5'd1, 1, 1);  check("A from WB, B from MEM", forward_a_e, 2'b01, forward_b_e, 2'b10);
        drive(5'd5, 5'd6, 5'd5, 5'd6, 1, 1);  check("A from MEM, B from WB", forward_a_e, 2'b10, forward_b_e, 2'b01);

        // ---- exhaustive: every rs, rd_m, rd_w, write-enable combination ----
        // run twice with rs1/rs2 roles swapped so a copy-paste bug in either
        // output cannot hide behind rs1 == rs2
        for (int swap = 0; swap < 2; swap++)
          for (int a = 0; a < 32; a++)
            for (int m = 0; m < 32; m++)
              for (int w = 0; w < 32; w++)
                for (int en = 0; en < 4; en++) begin
                    logic [4:0] other;
                    other = 5'((a * 7 + m * 3 + w + 11) % 32);
                    if (swap == 0) drive(5'(a), other, 5'(m), 5'(w), en[1], en[0]);
                    else           drive(other, 5'(a), 5'(m), 5'(w), en[1], en[0]);
                    check("exhaustive",
                          forward_a_e, ref_fwd(rs1_e, rd_m, rd_w, reg_write_m, reg_write_w),
                          forward_b_e, ref_fwd(rs2_e, rd_m, rd_w, reg_write_m, reg_write_w));
                end

        $display("\n--- forwarding_unit ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else                 $display("SOME TESTS FAILED");
        $display("Functional coverage: %0.2f%%", cg_inst.get_coverage());  // COVERAGE_LINE
        $finish;
    end

endmodule