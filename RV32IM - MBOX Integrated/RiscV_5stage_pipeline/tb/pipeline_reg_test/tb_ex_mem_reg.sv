`timescale 1ns/1ps

module tb_ex_mem_reg_full;
    localparam RSW = 2;

    logic                clk = 0, reset;
    logic                reg_write_e, mem_write_e, mem_read_e;
    logic [RSW-1:0]      result_src_e;
    logic [2:0]          funct3_e;
    logic [31:0]         alu_result_e, write_data_e, pc_plus4_e;
    logic [4:0]          rd_e;

    logic                reg_write_m, mem_write_m, mem_read_m;
    logic [RSW-1:0]      result_src_m;
    logic [2:0]          funct3_m;
    logic [31:0]         alu_result_m, write_data_m, pc_plus4_m;
    logic [4:0]          rd_m;

    integer pass_count = 0, fail_count = 0;

    ex_mem_reg #(.RESULT_SRC_W(RSW)) dut (
        .clk(clk), .reset(reset),
        .reg_write_e(reg_write_e), .result_src_e(result_src_e),
        .mem_write_e(mem_write_e), .mem_read_e(mem_read_e), .funct3_e(funct3_e),
        .alu_result_e(alu_result_e), .write_data_e(write_data_e),
        .pc_plus4_e(pc_plus4_e), .rd_e(rd_e),
        .reg_write_m(reg_write_m), .result_src_m(result_src_m),
        .mem_write_m(mem_write_m), .mem_read_m(mem_read_m), .funct3_m(funct3_m),
        .alu_result_m(alu_result_m), .write_data_m(write_data_m),
        .pc_plus4_m(pc_plus4_m), .rd_m(rd_m)
    );

    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Functional coverage, sampled on the E-stage inputs at posedge.
    // Reset cycles are excluded.
    // ---------------------------------------------------------------
    covergroup cg_ex_mem @(posedge clk iff !reset);
        cp_reg_write  : coverpoint reg_write_e;
        cp_mem_write  : coverpoint mem_write_e;
        cp_mem_read   : coverpoint mem_read_e;
        cp_result_src : coverpoint result_src_e;
        cp_funct3     : coverpoint funct3_e;
        cp_rd         : coverpoint rd_e {
            bins zero = {0};
            bins mid  = {[1:30]};
            bins max  = {31};
        }
        cp_alu        : coverpoint alu_result_e {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        cp_wdata      : coverpoint write_data_e {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        cp_pc4        : coverpoint pc_plus4_e {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        x_mem_funct3  : cross cp_mem_write, cp_funct3;
        x_mem_rw      : cross cp_mem_write, cp_mem_read;
        x_wb_src      : cross cp_reg_write, cp_result_src;
    endgroup

    cg_ex_mem cg = new();

    // ---------------------------------------------------------------
    // Checking
    // ---------------------------------------------------------------
    task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);
        if (got === exp) begin
            pass_count++;
        end else begin
            fail_count++;
            $display("[FAIL] %s: got %h exp %h @%0t", name, got, exp, $time);
        end
    endtask

    // drive at negedge, check after the next posedge + #1
    task automatic apply_and_check(
        input logic rw, input logic [RSW-1:0] rs, input logic mw, input logic mr,
        input logic [2:0] f3,
        input logic [31:0] alu, input logic [31:0] wd, input logic [31:0] p4,
        input logic [4:0] rd);
        @(negedge clk);
        reg_write_e  = rw;  result_src_e = rs;  mem_write_e = mw;  mem_read_e = mr;
        funct3_e     = f3;
        alu_result_e = alu; write_data_e = wd;  pc_plus4_e  = p4;  rd_e = rd;
        @(posedge clk); #1;
        check("reg_write",  reg_write_m,  rw);
        check("result_src", result_src_m, rs);
        check("mem_write",  mem_write_m,  mw);
        check("mem_read",   mem_read_m,   mr);
        check("funct3",     funct3_m,     f3);
        check("alu_result", alu_result_m, alu);
        check("write_data", write_data_m, wd);
        check("pc_plus4",   pc_plus4_m,   p4);
        check("rd",         rd_m,         rd);
    endtask

    // reset clears control only, data is don't care
    task automatic do_reset;
        @(negedge clk); reset = 1;
        @(posedge clk); #1;
        check("reset reg_write",  reg_write_m,  0);
        check("reset mem_write",  mem_write_m,  0);
        check("reset mem_read",   mem_read_m,   0);
        check("reset result_src", result_src_m, 0);
        @(negedge clk); reset = 0;
    endtask

    // ---------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------
    integer i, a, b, c, d, e;

    initial begin
        reset = 1; reg_write_e = 0; result_src_e = 0; mem_write_e = 0; mem_read_e = 0;
        funct3_e = 0; alu_result_e = 0; write_data_e = 0; pc_plus4_e = 0; rd_e = 0;
        do_reset();

        // all zeros, all ones, back to zeros
        apply_and_check(0, '0, 0, 0, 3'h0, 32'h0,        32'h0,        32'h0,        5'h0);
        apply_and_check(1, '1, 1, 1, 3'h7, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'h1F);
        apply_and_check(0, '0, 0, 0, 3'h0, 32'h0,        32'h0,        32'h0,        5'h0);

        // walking ones, then walking zeros: every bit goes 0->1 and 1->0
        for (i = 0; i < 32; i++)
            apply_and_check(i[0], i[RSW-1:0], i[1], i[3], i[2:0],
                            32'h1 << i, 32'h1 << ((i+7)%32), 32'h1 << ((i+13)%32), i[4:0]);
        for (i = 0; i < 32; i++)
            apply_and_check(~i[0], ~i[RSW-1:0], ~i[1], ~i[3], ~i[2:0],
                            ~(32'h1 << i), ~(32'h1 << ((i+7)%32)), ~(32'h1 << ((i+13)%32)), ~i[4:0]);

        // full control cross: reg_write x result_src x mem_write x mem_read x funct3
        for (a = 0; a < 2; a++)
            for (b = 0; b < (1<<RSW); b++)
                for (c = 0; c < 2; c++)
                    for (e = 0; e < 2; e++)
                        for (d = 0; d < 8; d++)
                            apply_and_check(a[0], b[RSW-1:0], c[0], e[0], d[2:0],
                                            $urandom, $urandom, $urandom, $urandom);

        // random
        for (i = 0; i < 500; i++)
            apply_and_check($urandom, $urandom, $urandom, $urandom, $urandom,
                            $urandom, $urandom, $urandom, $urandom);

        // reset mid-run while control is high, then resume
        apply_and_check(1, '1, 1, 1, 3'h3, 32'h11111111, 32'h22222222, 32'h33333333, 5'd3);
        do_reset();
        apply_and_check(1, 2'd1, 1, 1, 3'h1, 32'h44444444, 32'h55555555, 32'h66666666, 5'd4);

        $display("ex_mem_reg: %0d checks, %0d failed", pass_count + fail_count, fail_count);
        $display("ex_mem_reg: functional coverage %0.2f%%", cg.get_inst_coverage());
        $finish;
    end
endmodule