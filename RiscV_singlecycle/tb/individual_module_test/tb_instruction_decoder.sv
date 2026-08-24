`timescale 1ns/1ps

module tb_instruction_decoder;

    logic [31:0] instruction;
    logic [6:0]  opcode;
    logic [4:0]  rd;
    logic [2:0]  funct3;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [6:0]  funct7;

    int pass_count = 0;
    int fail_count = 0;

    instruction_decoder dut (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .funct7(funct7)
    );

    task automatic check(
        input [31:0] instr_in,
        input [6:0]  exp_opcode,
        input [4:0]  exp_rd,
        input [2:0]  exp_funct3,
        input [4:0]  exp_rs1,
        input [4:0]  exp_rs2,
        input [6:0]  exp_funct7,
        input string test_name
    );
        instruction = instr_in;
        #1; // let combinational logic settle

        if (opcode === exp_opcode && rd === exp_rd && funct3 === exp_funct3 &&
            rs1 === exp_rs1 && rs2 === exp_rs2 && funct7 === exp_funct7) begin
            pass_count++;
            $display("PASS: %s", test_name);
        end else begin
            fail_count++;
            $display("FAIL: %s", test_name);
            $display("  instr    = %032b", instr_in);
            $display("  opcode   exp=%b got=%b", exp_opcode, opcode);
            $display("  rd       exp=%b got=%b", exp_rd, rd);
            $display("  funct3   exp=%b got=%b", exp_funct3, funct3);
            $display("  rs1      exp=%b got=%b", exp_rs1, rs1);
            $display("  rs2      exp=%b got=%b", exp_rs2, rs2);
            $display("  funct7   exp=%b got=%b", exp_funct7, funct7);
        end
    endtask

    initial begin
        // Test 1: R-type — add x3, x1, x2
        // funct7=0000000 rs2=00010 rs1=00001 funct3=000 rd=00011 opcode=0110011
        check(32'b0000000_00010_00001_000_00011_0110011,
              7'b0110011, 5'd3, 3'b000, 5'd1, 5'd2, 7'b0000000,
              "R-type ADD");

        // Test 2: R-type — sub x5, x6, x7
        // funct7=0100000 rs2=00111 rs1=00110 funct3=000 rd=00101 opcode=0110011
        check(32'b0100000_00111_00110_000_00101_0110011,
              7'b0110011, 5'd5, 3'b000, 5'd6, 5'd7, 7'b0100000,
              "R-type SUB (funct7 bit30 check)");

        // Test 3: I-type — addi x5, x0, 9
        // imm[11:0]=000000001001 rs1=00000 funct3=000 rd=00101 opcode=0010011
        check(32'b000000001001_00000_000_00101_0010011,
              7'b0010011, 5'd5, 3'b000, 5'd0, 5'd9, 7'b0000000,
              "I-type ADDI (rs2/funct7 fields don't carry real meaning here, just checking positional slicing)");

        // Test 4: S-type — sw x2, 8(x1)
        // imm[11:5]=0000000 rs2=00010 rs1=00001 funct3=010 imm[4:0]=01000 opcode=0100011
        check(32'b0000000_00010_00001_010_01000_0100011,
              7'b0100011, 5'b01000, 3'b010, 5'd1, 5'd2, 7'b0000000,
              "S-type SW (rd field holds imm[4:0] positionally)");

        // Test 5: B-type — beq x1, x2, offset
        // imm[12,10:5]=0000000 rs2=00010 rs1=00001 funct3=000 imm[4:1,11]=00001 opcode=1100011
        check(32'b0000000_00010_00001_000_00001_1100011,
              7'b1100011, 5'b00001, 3'b000, 5'd1, 5'd2, 7'b0000000,
              "B-type BEQ (positional slicing, semantics handled by control unit)");

        // Test 6: all-zero instruction (edge case)
        check(32'b0, 7'b0, 5'b0, 3'b0, 5'b0, 5'b0, 7'b0,
              "All-zero instruction");

        // Test 7: all-ones instruction (edge case)
        check(32'hFFFFFFFF, 7'h7F, 5'h1F, 3'h7, 5'h1F, 5'h1F, 7'h7F,
              "All-ones instruction");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule