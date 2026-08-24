`timescale 1ns / 1ps
`include "../includes/riscv_defines.svh"

module tb_control_unit;

    logic [6:0] opcode;

    logic       reg_write_enable;
    logic       alu_src_a;
    logic       alu_src_b;
    logic       mem_write_enable;
    logic       mem_read_enable;
    logic [2:0] alu_op;
    logic [1:0] result_src;
    logic       branch;
    logic       jump;
    logic       base_select;

    int pass_count = 0;
    int fail_count = 0;

    control_unit dut (
        .opcode           (opcode),
        .reg_write_enable (reg_write_enable),
        .alu_src_a        (alu_src_a),
        .alu_src_b        (alu_src_b),
        .mem_write_enable (mem_write_enable),
        .mem_read_enable  (mem_read_enable),
        .alu_op           (alu_op),
        .result_src       (result_src),
        .branch           (branch),
        .jump             (jump),
        .base_select      (base_select)
    );

    task automatic check(
        input string      test_name,
        input logic [6:0] op,
        input logic       exp_reg_write,
        input logic       exp_alu_src_a,
        input logic       exp_alu_src_b,
        input logic       exp_mem_write,
        input logic       exp_mem_read,
        input logic [2:0] exp_alu_op,
        input logic [1:0] exp_result_src,
        input logic       exp_branch,
        input logic       exp_jump,
        input logic       exp_base_select
    );
        opcode = op;
        #1; // settle delay for combinational logic

        if (reg_write_enable === exp_reg_write &&
            alu_src_a        === exp_alu_src_a &&
            alu_src_b        === exp_alu_src_b &&
            mem_write_enable === exp_mem_write &&
            mem_read_enable  === exp_mem_read  &&
            alu_op           === exp_alu_op    &&
            result_src       === exp_result_src&&
            branch           === exp_branch    &&
            jump             === exp_jump      &&
            base_select      === exp_base_select) begin
            pass_count++;
            $display("[PASS] %s", test_name);
        end else begin
            fail_count++;
            $display("[FAIL] %s", test_name);
            $display("   opcode=%b", op);
            $display("   reg_write : exp=%b got=%b", exp_reg_write, reg_write_enable);
            $display("   alu_src_a : exp=%b got=%b", exp_alu_src_a, alu_src_a);
            $display("   alu_src_b : exp=%b got=%b", exp_alu_src_b, alu_src_b);
            $display("   mem_write : exp=%b got=%b", exp_mem_write, mem_write_enable);
            $display("   mem_read  : exp=%b got=%b", exp_mem_read, mem_read_enable);
            $display("   alu_op    : exp=%b got=%b", exp_alu_op, alu_op);
            $display("   result_src: exp=%b got=%b", exp_result_src, result_src);
            $display("   branch    : exp=%b got=%b", exp_branch, branch);
            $display("   jump      : exp=%b got=%b", exp_jump, jump);
            $display("   base_sel  : exp=%b got=%b", exp_base_select, base_select);
        end
    endtask

    initial begin

        // test_name,        opcode,        reg_wr, a_src_a, a_src_b, mem_wr, mem_rd, alu_op,          result_src,     branch, jump, base_sel
        check("R-TYPE",       `OP_R_TYPE,    1'b1,   1'b0,    1'b0,    1'b0,   1'b0,   `ALUOP_RTYPE,    `RES_ALU,       1'b0,   1'b0, 1'b0);
        check("I-TYPE",       `OP_I_TYPE,    1'b1,   1'b0,    1'b1,    1'b0,   1'b0,   `ALUOP_ITYPE,    `RES_ALU,       1'b0,   1'b0, 1'b0);
        check("LOAD",         `OP_LOAD,      1'b1,   1'b0,    1'b1,    1'b0,   1'b1,   `ALUOP_ADD,      `RES_MEM,       1'b0,   1'b0, 1'b0);
        check("STORE",        `OP_STORE,     1'b0,   1'b0,    1'b1,    1'b1,   1'b0,   `ALUOP_ADD,      `RES_ALU,       1'b0,   1'b0, 1'b0);
        check("BRANCH",       `OP_BRANCH,    1'b0,   1'b0,    1'b0,    1'b0,   1'b0,   `ALUOP_SUB,      `RES_ALU,       1'b1,   1'b0, 1'b0);
        check("JAL",          `OP_JAL,       1'b1,   1'b0,    1'b0,    1'b0,   1'b0,   `ALUOP_ADD,      `RES_PC_PLUS4,  1'b0,   1'b1, 1'b0);
        check("JALR",         `OP_JALR,      1'b1,   1'b0,    1'b1,    1'b0,   1'b0,   `ALUOP_ADD,      `RES_PC_PLUS4,  1'b0,   1'b1, 1'b1);
        check("LUI",          `OP_LUI,       1'b1,   1'b0,    1'b1,    1'b0,   1'b0,   `ALUOP_LUI,      `RES_ALU,       1'b0,   1'b0, 1'b0);
        check("AUIPC",        `OP_AUIPC,     1'b1,   1'b1,    1'b1,    1'b0,   1'b0,   `ALUOP_ADD,      `RES_ALU,       1'b0,   1'b0, 1'b0);
        check("UNSUPPORTED",  7'b1111111,    1'b0,   1'b0,    1'b0,    1'b0,   1'b0,   `ALUOP_ADD,      `RES_ALU,       1'b0,   1'b0, 1'b0);

        $display("\n--- Control Unit Testbench Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule