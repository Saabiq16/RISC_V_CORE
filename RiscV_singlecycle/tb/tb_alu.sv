`timescale 1ns/1ps
`include "riscv_defines.svh"

module tb_alu;

    // Inputs
    logic [31:0] a;
    logic [31:0] b;
    logic [3:0]  alu_op;

    // Outputs
    logic [31:0] result;
    logic        zero, negative, carry, overflow;

    // DUT instantiation
    alu uut (
        .a        (a),
        .b        (b),
        .alu_op   (alu_op),
        .result   (result),
        .zero     (zero),
        .carry    (carry),
        .negative (negative),
        .overflow (overflow)
    );                         

    int fail;               

    // Task 
    task check;
        input [31:0] exp_result;
        input        exp_zero;
        input        exp_negative;
        input        exp_overflow;
        input        exp_carry;
        input int test_num;
        logic test_failed;        
        begin
            test_failed = 0;   

            if (result !== exp_result) begin
                $display("TEST %0d FAILED | RESULT   | a=%h b=%h op=%b | exp=%h got=%h",
                          test_num, a, b, alu_op, exp_result, result);
                test_failed = 1;
            end
            if (zero !== exp_zero) begin
                $display("TEST %0d FAILED | ZERO     | exp=%b got=%b",
                          test_num, exp_zero, zero);
                test_failed = 1;
            end
            if (negative !== exp_negative) begin
                $display("TEST %0d FAILED | NEGATIVE | exp=%b got=%b",
                          test_num, exp_negative, negative);
                test_failed = 1;
            end
            if (overflow !== exp_overflow) begin
                $display("TEST %0d FAILED | OVERFLOW | exp=%b got=%b",
                          test_num, exp_overflow, overflow);
                test_failed = 1;
            end
            if (carry !== exp_carry) begin
                $display("TEST %0d FAILED | CARRY    | exp=%b got=%b",
                          test_num, exp_carry, carry);
                test_failed = 1;
            end

            if (test_failed)
                fail = fail + 1;
            else
                $display("TEST %0d PASSED", test_num);
        end
    endtask

    initial begin
        fail = 0;               // ← initialize here

        // ADD
        a=32'd15;       b=32'd10;       alu_op=`ALU_ADD; #10; check(32'd25,         0,0,0,1, 1);
        a=32'd0;        b=32'd0;        alu_op=`ALU_ADD; #10; check(32'd0,          1,0,0,1, 2);
        a=32'hFFFFFFFF; b=32'd1;        alu_op=`ALU_ADD; #10; check(32'd0,          1,0,0,1, 3);

        // SUB
        a=32'd15;       b=32'd11;       alu_op=`ALU_SUB; #10; check(32'd4,          0,0,0,1, 4);
        a=32'd10;       b=32'd15;       alu_op=`ALU_SUB; #10; check(32'hFFFFFFFB,   0,1,0,0, 5);

        // AND / OR / XOR
        a=32'hF0F0F0F0; b=32'h0F0F0F0F; alu_op=`ALU_AND; #10; check(32'h00000000,  1,0,0,1, 6);
        a=32'hF0F0F0F0; b=32'h0F0F0F0F; alu_op=`ALU_OR;  #10; check(32'hFFFFFFFF,  0,1,0,1, 7);
        a=32'hF0F0F0F0; b=32'h0F0F0F0F; alu_op=`ALU_XOR; #10; check(32'hFFFFFFFF,  0,1,0,1, 8);

        // SHIFTS
        a=32'h00000001; b=32'd1;        alu_op=`ALU_SLL; #10; check(32'h00000002,   0,0,0,1, 9);
        a=32'h80000000; b=32'd1;        alu_op=`ALU_SRL; #10; check(32'h40000000,   0,0,0,1,10);
        a=32'h80000000; b=32'd1;        alu_op=`ALU_SRA; #10; check(32'hC0000000,   0,1,0,1,11);

        // SLT / SLTU
        a=32'hFFFFFFFF; b=32'h00000001; alu_op=`ALU_SLT;  #10; check(32'd1,         0,0,0,1,12);
        a=32'hFFFFFFFF; b=32'h00000001; alu_op=`ALU_SLTU; #10; check(32'd0,         1,0,0,1,13);

        // LUI
        a=32'h00000000; b=32'h12345678; alu_op=`ALU_LUI;  #10; check(32'h12345678,  0,0,0,0,14);

        // OVERFLOW
        a=32'h7FFFFFFF; b=32'h00000001; alu_op=`ALU_ADD;  #10; check(32'h80000000,  0,1,1,1,15);
        a=32'h80000000; b=32'h00000001; alu_op=`ALU_SUB;  #10; check(32'h7FFFFFFF,  0,0,1,1,16);

        if (fail == 0)
            $display("ALL 16 TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail);

        $finish;
    end

endmodule