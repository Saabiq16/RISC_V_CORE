`timescale 1ns/1ps

module tb_mem_wb_reg_full;
    localparam RSW = 2;

    logic                clk = 0, reset;
    logic                reg_write_m;
    logic [RSW-1:0]      result_src_m;
    logic [31:0]         alu_result_m, read_data_m, pc_plus4_m;
    logic [4:0]          rd_m;

    logic                reg_write_w;
    logic [RSW-1:0]      result_src_w;
    logic [31:0]         alu_result_w, read_data_w, pc_plus4_w;
    logic [4:0]          rd_w;

    integer pass_count = 0, fail_count = 0;

    mem_wb_reg #(.RESULT_SRC_W(RSW)) dut (
        .clk(clk), .reset(reset),
        .reg_write_m(reg_write_m), .result_src_m(result_src_m),
        .alu_result_m(alu_result_m), .read_data_m(read_data_m),
        .pc_plus4_m(pc_plus4_m), .rd_m(rd_m),
        .reg_write_w(reg_write_w), .result_src_w(result_src_w),
        .alu_result_w(alu_result_w), .read_data_w(read_data_w),
        .pc_plus4_w(pc_plus4_w), .rd_w(rd_w)
    );

    always #5 clk = ~clk;

    // ---------------------------------------------------------------
    // Functional coverage, sampled on the M-stage inputs at posedge.
    // Reset cycles are excluded.
    // ---------------------------------------------------------------
    covergroup cg_mem_wb @(posedge clk iff !reset);
        cp_reg_write  : coverpoint reg_write_m;
        cp_result_src : coverpoint result_src_m;
        cp_rd         : coverpoint rd_m {
            bins zero = {0};
            bins mid  = {[1:30]};
            bins max  = {31};
        }
        cp_alu        : coverpoint alu_result_m {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        cp_rdata      : coverpoint read_data_m {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        cp_pc4        : coverpoint pc_plus4_m {
            bins zero  = {32'h0};
            bins ones  = {32'hFFFFFFFF};
            bins other = {[32'h1:32'hFFFFFFFE]};
        }
        // write-back enable against every result source
        x_wb_src      : cross cp_reg_write, cp_result_src;
    endgroup

    cg_mem_wb cg = new();

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
        input logic rw, input logic [RSW-1:0] rs,
        input logic [31:0] alu, input logic [31:0] rdata, input logic [31:0] p4,
        input logic [4:0] rd);
        @(negedge clk);
        reg_write_m  = rw;   result_src_m = rs;
        alu_result_m = alu;  read_data_m  = rdata;
        pc_plus4_m   = p4;   rd_m         = rd;
        @(posedge clk); #1;
        check("reg_write",  reg_write_w,  rw);
        check("result_src", result_src_w, rs);
        check("alu_result", alu_result_w, alu);
        check("read_data",  read_data_w,  rdata);
        check("pc_plus4",   pc_plus4_w,   p4);
        check("rd",         rd_w,         rd);
    endtask

    // reset clears control only, data is don't care
    task automatic do_reset;
        @(negedge clk); reset = 1;
        @(posedge clk); #1;
        check("reset reg_write",  reg_write_w,  0);
        check("reset result_src", result_src_w, 0);
        @(negedge clk); reset = 0;
    endtask

    // ---------------------------------------------------------------
    // Stimulus
    // ---------------------------------------------------------------
    integer i, a, b;

    initial begin
        reset = 1; reg_write_m = 0; result_src_m = 0;
        alu_result_m = 0; read_data_m = 0; pc_plus4_m = 0; rd_m = 0;
        do_reset();

        // all zeros, all ones, back to zeros
        apply_and_check(0, '0, 32'h0,        32'h0,        32'h0,        5'h0);
        apply_and_check(1, '1, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'h1F);
        apply_and_check(0, '0, 32'h0,        32'h0,        32'h0,        5'h0);

        // walking ones, then walking zeros: every bit goes 0->1 and 1->0
        for (i = 0; i < 32; i++)
            apply_and_check(i[0], i[RSW-1:0],
                            32'h1 << i, 32'h1 << ((i+7)%32), 32'h1 << ((i+13)%32), i[4:0]);
        for (i = 0; i < 32; i++)
            apply_and_check(~i[0], ~i[RSW-1:0],
                            ~(32'h1 << i), ~(32'h1 << ((i+7)%32)), ~(32'h1 << ((i+13)%32)), ~i[4:0]);

        // full control cross: reg_write x result_src, random data
        for (a = 0; a < 2; a++)
            for (b = 0; b < (1<<RSW); b++)
                apply_and_check(a[0], b[RSW-1:0],
                                $urandom, $urandom, $urandom, $urandom);

        // random
        for (i = 0; i < 500; i++)
            apply_and_check($urandom, $urandom, $urandom, $urandom, $urandom, $urandom);

        // reset mid-run while control is high, then resume
        apply_and_check(1, '1, 32'h11111111, 32'h22222222, 32'h33333333, 5'd3);
        do_reset();
        apply_and_check(1, 2'd1, 32'h44444444, 32'h55555555, 32'h66666666, 5'd4);

        $display("mem_wb_reg: %0d checks, %0d failed", pass_count + fail_count, fail_count);
        $display("mem_wb_reg: functional coverage %0.2f%%", cg.get_inst_coverage());
        $finish;
    end
endmodule