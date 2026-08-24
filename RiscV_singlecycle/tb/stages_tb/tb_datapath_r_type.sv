`include "../includes/riscv_defines.svh"

module tb_datapath_r_type;

    logic        clk;
    logic [31:0] instruction;
    logic [31:0] pc_current;

    logic [31:0] alu_result;
    logic        zero;

    int pass_count = 0;
    int fail_count = 0;

    datapath_r_type dut (
        .clk         (clk),
        .instruction (instruction),
        .pc_current  (pc_current),
        .alu_result  (alu_result),
        .zero        (zero)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    function automatic logic [31:0] encode_rtype(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        return {funct7, rs2, rs1, funct3, rd, `OP_R_TYPE};
    endfunction

    task automatic check_result(
        input logic [31:0] exp_alu_result,
        input string        label
    );
        #1;
        if (alu_result === exp_alu_result) begin
            pass_count++;
            $display("[PASS] %s: alu_result=%0d", label, alu_result);
        end else begin
            fail_count++;
            $display("[FAIL] %s: alu_result=%0d (exp %0d)", label, alu_result, exp_alu_result);
        end
    endtask

    task automatic check_reg(
        input logic [4:0]  reg_addr,
        input logic [31:0] exp_reg_value,
        input string        label
    );
        #1;
        if (dut.reg_file.registers[reg_addr] === exp_reg_value) begin
            pass_count++;
            $display("[PASS] %s: reg[%0d]=%0d", label, reg_addr, dut.reg_file.registers[reg_addr]);
        end else begin
            fail_count++;
            $display("[FAIL] %s: reg[%0d]=%0d (exp %0d)", label, reg_addr, dut.reg_file.registers[reg_addr], exp_reg_value);
        end
    endtask

    initial begin
        pc_current  = 32'd0;
        instruction = 32'd0;

        // Preload x1=10, x2=3 directly into the register file
        force dut.reg_file.registers[1] = 32'd10;
        force dut.reg_file.registers[2] = 32'd3;
        #1;
        release dut.reg_file.registers[1];
        release dut.reg_file.registers[2];

        // ADD x3, x1, x2  -> 10 + 3 = 13
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd2, 5'd1, `FUNCT3_ADD, 5'd3);
        check_result(32'd13, "ADD x3,x1,x2");
        @(posedge clk);
        check_reg(5'd3, 32'd13, "writeback x3");

        // SUB x4, x1, x2 -> 10 - 3 = 7
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_SUB, 5'd2, 5'd1, `FUNCT3_ADD, 5'd4);
        check_result(32'd7, "SUB x4,x1,x2");
        @(posedge clk);
        check_reg(5'd4, 32'd7, "writeback x4");

        // AND x5, x1, x2 -> 10 & 3 = 2
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd2, 5'd1, `FUNCT3_AND, 5'd5);
        check_result(32'd2, "AND x5,x1,x2");
        @(posedge clk);
        check_reg(5'd5, 32'd2, "writeback x5");

        // OR x6, x1, x2 -> 10 | 3 = 11
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd2, 5'd1, `FUNCT3_OR, 5'd6);
        check_result(32'd11, "OR x6,x1,x2");
        @(posedge clk);
        check_reg(5'd6, 32'd11, "writeback x6");

        // SLT x7, x2, x1 -> (3 < 10) = 1
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd1, 5'd2, `FUNCT3_SLT, 5'd7);
        check_result(32'd1, "SLT x7,x2,x1");
        @(posedge clk);
        check_reg(5'd7, 32'd1, "writeback x7");

        // Dependent chain: ADD x8, x3, x1 -> 13 + 10 = 23
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd1, 5'd3, `FUNCT3_ADD, 5'd8);
        check_result(32'd23, "ADD x8,x3,x1 (dependent)");
        @(posedge clk);
        check_reg(5'd8, 32'd23, "writeback x8 (dependent)");

        $display("---- %0d passed, %0d failed ----", pass_count, fail_count);
        $finish;
    end

endmodule