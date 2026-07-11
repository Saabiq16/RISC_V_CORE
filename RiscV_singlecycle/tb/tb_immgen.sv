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

initial begin
    fail = 0;

    //Test 1 : I-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_I_TYPE}; 
    #10;
    if (imm_ext === 32'h00000005) begin
        $display("Test 1 Passed") ;
    end
    else begin
        $display("Test 1 Failed: Expected 0x00000005, got %h",imm_ext);
        fail++;
    end

    //Test 2 : I-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_I_TYPE};
    #10;
    if (imm_ext === 32'hFFFFFABC) begin
        $display("Test 2 Passed") ;
    end
    else begin
        $display("Test 2 Failed: Expected 0xFFFFFABC, got %h",imm_ext);
        fail++;
    end

    //Test 3 : S-type instruction (positive)(imm = 0x005)
    instruction = {7'h0, 5'b0, 5'b0, 3'b0, 5'b101, `OP_STORE};
    #10;
    if (imm_ext === 32'h00000005) begin
        $display("Test 3 Passed") ;
    end
    else begin
        $display("Test 3 Failed: Expected 0x00000005, got %h",imm_ext);
        fail++;
    end

    //Test 4 : S-type instruction (negative)(imm = 0xABC)
    instruction = {7'b1010101, 5'b0, 5'b0, 3'b0, 5'b11100, `OP_STORE};
    #10;
    if (imm_ext === 32'hFFFFFABC) begin
        $display("Test 4 Passed") ;
    end
    else begin
        $display("Test 4 Failed: Expected 0xFFFFFABC, got %h",imm_ext);
        fail++;
    end

    //test 5 : B-type instruction (positive)(imm = 0x006)
    instruction = {1'b0, 6'b000000, 5'b0, 5'b0, 3'b0, 4'b0011, 1'b0, `OP_BRANCH};
    #10;
    if (imm_ext === 32'h00000006) begin
        $display("Test 5 Passed") ;
    end
    else begin
        $display("Test 5 Failed: Expected 0x00000006, got %h",imm_ext);
        fail++;
    end

    //test 6 : B-type instruction (negative)(imm = 0xABC)
    instruction = {1'b1, 6'b010101, 5'b0, 5'b0, 3'b0, 4'b1110, 1'b1, `OP_BRANCH};
    #10;
    if (imm_ext === 32'hFFFFFABC) begin
        $display("Test 6 Passed") ;
    end
    else begin
        $display("Test 6 Failed: Expected 0xFFFFFABC, got %h",imm_ext);
        fail++;
    end

   

    //test 7 : LUI instruction (imm = 0xABC)
    instruction = {20'hABC, 5'b0, `OP_LUI};
    #10;
    if (imm_ext === 32'h00ABC000) begin
        $display("Test 7 Passed") ;
    end
    else begin
        $display("Test 7 Failed: Expected 0x00ABC000, got %h",imm_ext);
        fail++;
    end

    //test 8 : JAL instruction (imm = 0xABC)
    instruction = {1'b0, 10'b010_1011_110, 1'b1, 8'b0, 5'b0, `OP_JAL};
    #10;
    if (imm_ext === 32'h00000ABC) begin
        $display("Test 8 Passed") ;
    end
    else begin
        $display("Test 8 Failed: Expected 0x00000ABC, got %h",imm_ext);
        fail++;
    end

    
    //Test 9 : L-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_LOAD}; 
    #10;
    if (imm_ext === 32'h00000005) begin
        $display("Test 9 Passed") ;
    end
    else begin
        $display("Test 9 Failed: Expected 0x00000005, got %h",imm_ext);
        fail++;
    end

    //Test 10 : L-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_LOAD};
    #10;
    if (imm_ext === 32'hFFFFFABC) begin
        $display("Test 10 Passed") ;
    end
    else begin
        $display("Test 10 Failed: Expected 0xFFFFFABC, got %h",imm_ext);
        fail++;
    end

    
    //Test 11 : JALR-type instruction (positive)
    instruction = {12'h005, 5'b0, 3'b0, 5'b0, `OP_JALR}; 
    #10;
    if (imm_ext === 32'h00000005) begin
        $display("Test 11 Passed") ;
    end
    else begin
        $display("Test 11 Failed: Expected 0x00000005, got %h",imm_ext);
        fail++;
    end

    //Test 12 : JALR-type instruction (negative)
    instruction = {12'hABC, 5'b0, 3'b0, 5'b0, `OP_JALR};
    #10;
    if (imm_ext === 32'hFFFFFABC) begin
        $display("Test 12 Passed") ;
    end
    else begin
        $display("Test 12 Failed: Expected 0xFFFFFABC, got %h",imm_ext);
        fail++;
    end

     //test 13 : AUIPC instruction (imm = 0xABC)
    instruction = {20'hABC, 5'b0, `OP_AUIPC};
    #10;
    if (imm_ext === 32'h00ABC000) begin
        $display("Test 13 Passed") ;
    end
    else begin
        $display("Test 13 Failed: Expected 0x00ABC000, got %h",imm_ext);
        fail++;
    end

// Test 14: Default case (invalid opcode)
instruction = {25'b0, 7'b0001111};
#10;
if (imm_ext === 32'h00000000) begin
    $display("Test 14 Passed");
end
else begin
    $display("Test 14 Failed: Expected 0x00000000, got %h", imm_ext);
    fail++;
end


    if (fail == 0) begin
        $display("All tests passed!");
    end
    else begin
        $display("%0d tests failed.", fail);
    end


    $finish;
end
endmodule