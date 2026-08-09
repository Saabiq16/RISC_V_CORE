`timescale 1ns /1ps
`include "../includes/riscv_defines.svh"

module tb_branch_control;

    logic [2:0] funct3;
    logic       zero;
    logic       carry;
    logic       negative;
    logic       overflow;

    logic       branch_taken;

    int pass_count = 0;
    int fail_count = 0;

    branch_control dut (
        .funct3       (funct3),
        .zero         (zero),
        .carry        (carry),
        .negative     (negative),
        .overflow     (overflow),
        .branch_taken (branch_taken)
    );

    task automatic check(
        input string test_name,
        input logic [2:0] t_funct3,
        input logic t_zero,
        input logic t_carry,
        input logic t_negative,
        input logic t_overflow,
        input logic exp_branch_taken
    );
        funct3   = t_funct3;
        zero     = t_zero;
        carry    = t_carry;
        negative = t_negative;
        overflow = t_overflow;
        #1;

        if (branch_taken === exp_branch_taken) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            fail_count++;
            $display("[FAIL] %s  funct3=%b z=%b c=%b n=%b o=%b  exp=%b got=%b",
                       test_name, t_funct3, t_zero, t_carry, t_negative, t_overflow,
                       exp_branch_taken, branch_taken);
        end
    endtask

    initial begin
        check("BEQ taken (equal)",     `BR_BEQ, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);
        check("BEQ not taken",         `BR_BEQ, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);

        check("BNE taken (not equal)", `BR_BNE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
        check("BNE not taken (equal)", `BR_BNE, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

        check("BLT taken (a<b, no ovf)",       `BR_BLT, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        check("BLT not taken (a>=b)",          `BR_BLT, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
        check("BLT overflow case (not taken)", `BR_BLT, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
        check("BLT overflow case (taken)",     `BR_BLT, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1);

        check("BGE taken (a>=b)",              `BR_BGE, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
        check("BGE not taken (a<b)",           `BR_BGE, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        check("BGE overflow case (taken)",     `BR_BGE, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1);
        check("BGE overflow case (not taken)", `BR_BGE, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0);
        check("BGE taken (a==b)",              `BR_BGE, 1'b1, 1'b0, 1'b0, 1'b0, 1'b1);

        check("BLTU taken (a<b unsigned)",     `BR_BLTU, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1);
        check("BLTU not taken (a>=b unsigned)",`BR_BLTU, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0);

        check("BGEU taken (a>=b unsigned)",    `BR_BGEU, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1);
        check("BGEU not taken (a<b unsigned)", `BR_BGEU, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0);
        check("BGEU taken (a==b unsigned)",    `BR_BGEU, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1);

        check("Invalid funct3 010", 3'b010, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0);
        check("Invalid funct3 011", 3'b011, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0);

        $display("\n--- Branch Control Testbench Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule