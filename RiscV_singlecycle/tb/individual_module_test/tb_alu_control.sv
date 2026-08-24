`timescale 1ns/1ps

`include "../includes/riscv_defines.svh"

module tb_alu_control;

    logic [2:0] funct3;
    logic       funct7_5;
    logic [2:0] alu_op;

    logic [3:0] alu_control_signal;

    int pass_count = 0;
    int fail_count = 0;

    alu_control dut (
        .funct3             (funct3),
        .funct7_5           (funct7_5),
        .alu_op             (alu_op),
        .alu_control_signal (alu_control_signal)
    );

    task automatic check(
        input string      test_name,
        input logic [2:0] t_alu_op,
        input logic [2:0] t_funct3,
        input logic       t_funct7_5,
        input logic [3:0] exp_alu_control
    );
        alu_op   = t_alu_op;
        funct3   = t_funct3;
        funct7_5 = t_funct7_5;
        #1;

        if (alu_control_signal === exp_alu_control) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            fail_count++;
            $display("[FAIL] %s  alu_op=%b funct3=%b funct7_5=%b  exp=%b got=%b",
                       test_name, t_alu_op, t_funct3, t_funct7_5,
                       exp_alu_control, alu_control_signal);
        end
    endtask

    initial begin
        check("ADD (LOAD/STORE/AUIPC), f3=x",   `ALUOP_ADD, 3'b000, 1'b0, `ALU_ADD);
        check("ADD forced, f3/f7 ignored",      `ALUOP_ADD, 3'b101, 1'b1, `ALU_ADD);
        check("SUB (BRANCH), f3=x",             `ALUOP_SUB, 3'b000, 1'b0, `ALU_SUB);
        check("SUB forced, f3/f7 ignored",      `ALUOP_SUB, 3'b110, 1'b1, `ALU_SUB);
        check("LUI, f3=x ignored",              `ALUOP_LUI, 3'b000, 1'b0, `ALU_LUI);
        check("LUI, f3/f7 ignored",             `ALUOP_LUI, 3'b111, 1'b1, `ALU_LUI);

        check("R-TYPE ADD",  `ALUOP_RTYPE, `FUNCT3_ADD,  1'b0, `ALU_ADD);
        check("R-TYPE SUB",  `ALUOP_RTYPE, `FUNCT3_ADD,  1'b1, `ALU_SUB);
        check("R-TYPE SLL",  `ALUOP_RTYPE, `FUNCT3_SLL,  1'b0, `ALU_SLL);
        check("R-TYPE SLT",  `ALUOP_RTYPE, `FUNCT3_SLT,  1'b0, `ALU_SLT);
        check("R-TYPE SLTU", `ALUOP_RTYPE, `FUNCT3_SLTU, 1'b0, `ALU_SLTU);
        check("R-TYPE XOR",  `ALUOP_RTYPE, `FUNCT3_XOR,  1'b0, `ALU_XOR);
        check("R-TYPE SRL",  `ALUOP_RTYPE, `FUNCT3_SR,   1'b0, `ALU_SRL);
        check("R-TYPE SRA",  `ALUOP_RTYPE, `FUNCT3_SR,   1'b1, `ALU_SRA);
        check("R-TYPE OR",   `ALUOP_RTYPE, `FUNCT3_OR,   1'b0, `ALU_OR);
        check("R-TYPE AND",  `ALUOP_RTYPE, `FUNCT3_AND,  1'b0, `ALU_AND);

        check("I-TYPE ADDI",  `ALUOP_ITYPE, `FUNCT3_ADD,  1'b0, `ALU_ADD);
        check("I-TYPE SLLI",  `ALUOP_ITYPE, `FUNCT3_SLL,  1'b0, `ALU_SLL);
        check("I-TYPE SLTI",  `ALUOP_ITYPE, `FUNCT3_SLT,  1'b0, `ALU_SLT);
        check("I-TYPE SLTIU", `ALUOP_ITYPE, `FUNCT3_SLTU, 1'b0, `ALU_SLTU);
        check("I-TYPE XORI",  `ALUOP_ITYPE, `FUNCT3_XOR,  1'b0, `ALU_XOR);
        check("I-TYPE SRLI",  `ALUOP_ITYPE, `FUNCT3_SR,   1'b0, `ALU_SRL);
        check("I-TYPE SRAI",  `ALUOP_ITYPE, `FUNCT3_SR,   1'b1, `ALU_SRA);
        check("I-TYPE ORI",   `ALUOP_ITYPE, `FUNCT3_OR,   1'b0, `ALU_OR);
        check("I-TYPE ANDI",  `ALUOP_ITYPE, `FUNCT3_AND,  1'b0, `ALU_AND);

        check("Invalid ALUOp", 3'b111, 3'b000, 1'b0, `ALU_ADD);

        $display("\n--- ALU Control Decoder Testbench Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");

        $finish;
    end

endmodule