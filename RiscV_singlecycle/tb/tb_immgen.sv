`timescale 1ns/1ps
`include "riscv_defines.svh"

module tb_immgen;

logic [31:0] instruction;
logic [31:0] imm_ext;

// DUT instantiation
immgen uut (
    .instruction(instruction),
    .imm_ext(imm_ext)
);

int fail;

// -----------------------------------------------------------------
// Reusable check task: prints instruction, expected, got, and result
// -----------------------------------------------------------------
task automatic check_test(
    input int          test_num,
    input string        test_name,
    input logic [31:0]  instr,
    input logic [31:0]  expected,
    input logic [31:0]  got
);
    if (got === expected) begin
        $display("[TEST %0d] %-28s | instr=0x%08h | expected=0x%08h | got=0x%08h | PASS",
                   test_num, test_name, instr, expected, got);
    end else begin
        $display("[TEST %0d] %-28s | instr=0x%08h | expected=0x%08h | got=0x%08h | FAIL",
                   test_num, test_name, instr, expected, got);
        fail++;
    end
endtask

initial begin
    fail = 0;

    $display("=================================================================================");
    $display(" IMMGEN TESTBENCH RESULTS");
    $display("=================================================================================");

    //Test 1 : I-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_I_TYPE};
    #10;
    check_test(1, "I-type (positive)", instruction, 32'h00000005, imm_ext);

    //Test 2 : I-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_I_TYPE};
    #10;
    check_test(2, "I-type (negative)", instruction, 32'hFFFFFABC, imm_ext);

    //Test 3 : S-type instruction (positive)(imm = 0x005)
    instruction = {7'h0, 5'b0, 5'b0, 3'b0, 5'b101, `OP_STORE};
    #10;
    check_test(3, "S-type (positive)", instruction, 32'h00000005, imm_ext);

    //Test 4 : S-type instruction (negative)(imm = 0xABC)
    instruction = {7'b1010101, 5'b0, 5'b0, 3'b0, 5'b11100, `OP_STORE};
    #10;
    check_test(4, "S-type (negative)", instruction, 32'hFFFFFABC, imm_ext);

    //test 5 : B-type instruction (positive)(imm = 0x006)
    instruction = {1'b0, 6'b000000, 5'b0, 5'b0, 3'b0, 4'b0011, 1'b0, `OP_BRANCH};
    #10;
    check_test(5, "B-type (positive)", instruction, 32'h00000006, imm_ext);

    //test 6 : B-type instruction (negative)(imm = 0xABC)
    instruction = {1'b1, 6'b010101, 5'b0, 5'b0, 3'b0, 4'b1110, 1'b1, `OP_BRANCH};
    #10;
    check_test(6, "B-type (negative)", instruction, 32'hFFFFFABC, imm_ext);

    //test 7 : LUI instruction (imm = 0xABC)
    instruction = {20'hABC, 5'b0, `OP_LUI};
    #10;
    check_test(7, "LUI", instruction, 32'h00ABC000, imm_ext);

    //test 8 : JAL instruction (imm = 0xABC)
    instruction = {1'b0, 10'b010_1011_110, 1'b1, 8'b0, 5'b0, `OP_JAL};
    #10;
    check_test(8, "JAL", instruction, 32'h00000ABC, imm_ext);

    //Test 9 : L-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_LOAD};
    #10;
    check_test(9, "L-type (positive)", instruction, 32'h00000005, imm_ext);

    //Test 10 : L-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_LOAD};
    #10;
    check_test(10, "L-type (negative)", instruction, 32'hFFFFFABC, imm_ext);

    //Test 11 : JALR-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_JALR};
    #10;
    check_test(11, "JALR (positive)", instruction, 32'h00000005, imm_ext);

    //Test 12 : JALR-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_JALR};
    #10;
    check_test(12, "JALR (negative)", instruction, 32'hFFFFFABC, imm_ext);

    //test 13 : AUIPC instruction (imm = 0xABC)
    instruction = {20'hABC, 5'b0, `OP_AUIPC};
    #10;
    check_test(13, "AUIPC", instruction, 32'h00ABC000, imm_ext);

    // Test 14: Default case (invalid opcode)
    instruction = {25'b0, 7'b0001111};
    #10;
    check_test(14, "Invalid opcode (default)", instruction, 32'h00000000, imm_ext);

    $display("=================================================================================");
    if (fail == 0) begin
        $display(" RESULT: All 14 tests passed!");
    end
    else begin
        $display(" RESULT: %0d test(s) failed.", fail);
    end
    $display("=================================================================================");

    $finish;
end
endmodule