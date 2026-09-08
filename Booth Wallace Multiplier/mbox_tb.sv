`timescale 1ns/1ps
module mbox_tb;
  localparam int TAGW = 5;

  logic              clk = 0;
  logic              rst_n;
  logic [31:0]       rs1, rs2;
  logic [1:0]        funct3;
  logic              valid_in;
  logic [TAGW-1:0]   rd_tag_in;
  logic [31:0]       result;
  logic              valid_out;
  logic [TAGW-1:0]   rd_tag_out;

  int pass_cnt = 0;
  int fail_cnt = 0;

  mbox_top #(.TAGW(TAGW)) dut (.*);

  always #5 clk = ~clk;

  task automatic check(input [31:0] a, input [31:0] b, input [1:0] f3,
                        input [31:0] expected, input string name);
    begin
      @(negedge clk);
      rs1 = a; rs2 = b; funct3 = f3; valid_in = 1'b1; rd_tag_in = 5'd1;
      @(negedge clk);
      valid_in = 1'b0;
      wait (valid_out === 1'b1);
      #1;  // let Stage 4's combinational CLA chain fully settle before sampling
      if (result === expected) begin
        pass_cnt = pass_cnt + 1;
        $display("PASS: %-18s got=%h exp=%h", name, result, expected);
      end else begin
        fail_cnt = fail_cnt + 1;
        $display("FAIL: %-18s got=%h exp=%h", name, result, expected);
      end
      @(negedge clk);
    end
  endtask

  initial begin
    rst_n = 0; valid_in = 0; rs1 = 0; rs2 = 0; funct3 = 0; rd_tag_in = 0;
    repeat (3) @(negedge clk);
    rst_n = 1;

    check(32'd6,          32'd7,          2'b00, 32'd42,       "MUL 6*7");
    check(32'hFFFFFFFD,   32'd5,          2'b00, 32'hFFFFFFF1, "MUL -3*5");
    check(32'hFFFFFFFF,   32'hFFFFFFFF,   2'b01, 32'h00000000, "MULH -1*-1 hi");
    check(32'hFFFFFFFF,   32'hFFFFFFFF,   2'b11, 32'hFFFFFFFE, "MULHU max*max hi");
    check(32'hFFFFFFFF,   32'hFFFFFFFF,   2'b10, 32'hFFFFFFFF, "MULHSU -1*umax hi");
    check(32'h00000000,   32'hFFFFFFFF,   2'b10, 32'h00000000, "MULHSU 0*umax hi");
    check(32'h7FFFFFFF,   32'h00000002,   2'b01, 32'h00000000, "MULH max*2 hi");

    $display("---- %0d passed, %0d failed ----", pass_cnt, fail_cnt);
    $finish;
  end
endmodule
