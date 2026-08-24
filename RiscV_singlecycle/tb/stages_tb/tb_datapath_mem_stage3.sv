`include "../includes/riscv_defines.svh"

module tb_datapath_mem_stage3;

    logic        clk;
    logic [31:0] instruction;
    logic [31:0] pc_current;
    logic [31:0] pc_plus_4;

    logic [31:0] alu_result;
    logic        zero;

    int pass_count = 0;
    int fail_count = 0;

    datapath_mem_stage3 dut (
        .clk         (clk),
        .instruction (instruction),
        .pc_current  (pc_current),
        .pc_plus_4   (pc_plus_4),
        .alu_result  (alu_result),
        .zero        (zero)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //--------------------------------------------------
    // Instruction encoders
    //--------------------------------------------------
    function automatic logic [31:0] encode_rtype(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        return {funct7, rs2, rs1, funct3, rd, `OP_R_TYPE};
    endfunction

    // I-type (used here for LOAD): imm[11:0] rs1 funct3 rd opcode
    function automatic logic [31:0] encode_itype_load(
        input logic [11:0] imm,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3,
        input logic [4:0]  rd
    );
        return {imm, rs1, funct3, rd, `OP_LOAD};
    endfunction

    // S-type (STORE): imm[11:5] rs2 rs1 funct3 imm[4:0] opcode
    function automatic logic [31:0] encode_stype(
        input logic [11:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3
    );
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], `OP_STORE};
    endfunction

    //--------------------------------------------------
    // Check tasks
    //--------------------------------------------------
    task automatic check_result(input logic [31:0] exp_alu_result, input string label);
        #1;
        if (alu_result === exp_alu_result) begin
            pass_count++;
            $display("[PASS] %s: alu_result=%0d", label, alu_result);
        end else begin
            fail_count++;
            $display("[FAIL] %s: alu_result=%0d (exp %0d)", label, alu_result, exp_alu_result);
        end
    endtask

    task automatic check_reg(input logic [4:0] reg_addr, input logic [31:0] exp_val, input string label);
        #1;   // let NBA register write complete before sampling
        if (dut.reg_file.registers[reg_addr] === exp_val) begin
            pass_count++;
            $display("[PASS] %s: x%0d=%0d", label, reg_addr, dut.reg_file.registers[reg_addr]);
        end else begin
            fail_count++;
            $display("[FAIL] %s: x%0d=%0d (exp %0d)", label, reg_addr, dut.reg_file.registers[reg_addr], exp_val);
        end
    endtask

    // checks a stored 32-bit little-endian word directly in data_memory's byte array
    task automatic check_mem_word(input int addr, input logic [31:0] exp_val, input string label);
        logic [31:0] actual;
        #1;   // let NBA memory write complete before sampling
        actual = {dut.data_mem.memory[addr+3], dut.data_mem.memory[addr+2],
                  dut.data_mem.memory[addr+1], dut.data_mem.memory[addr]};
        if (actual === exp_val) begin
            pass_count++;
            $display("[PASS] %s: mem[%0d]=%0d", label, addr, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %s: mem[%0d]=%0d (exp %0d)", label, addr, actual, exp_val);
        end
    endtask

    // checks a stored 16-bit little-endian halfword directly in data_memory's byte array
    task automatic check_mem_half(input int addr, input logic [15:0] exp_val, input string label);
        logic [15:0] actual;
        #1;   // let NBA memory write complete before sampling
        actual = {dut.data_mem.memory[addr+1], dut.data_mem.memory[addr]};
        if (actual === exp_val) begin
            pass_count++;
            $display("[PASS] %s: mem16[%0d]=%0d", label, addr, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %s: mem16[%0d]=%0d (exp %0d)", label, addr, actual, exp_val);
        end
    endtask

    //--------------------------------------------------
    // Test sequence
    //--------------------------------------------------
    initial begin
        pc_current  = 32'd0;
        pc_plus_4   = 32'd4;
        instruction = 32'd0;

        // Preload x1 = 100 (base address), x2 = 99 (store value)
        force dut.reg_file.registers[1] = 32'd100;
        force dut.reg_file.registers[2] = 32'd99;
        #1;
        release dut.reg_file.registers[1];
        release dut.reg_file.registers[2];

        // SW x2, 0(x1)  -> mem[100] = 99
        @(negedge clk);
        instruction = encode_stype(12'd0, 5'd2, 5'd1, `FUNCT3_SW);
        check_result(32'd100, "SW addr calc (x1+0)");
        @(posedge clk);
        check_mem_word(100, 32'd99, "SW mem[100]=99");

        // LW x3, 0(x1) -> x3 = mem[100] = 99
        @(negedge clk);
        instruction = encode_itype_load(12'd0, 5'd1, `FUNCT3_LW, 5'd3);
        check_result(32'd100, "LW addr calc (x1+0)");
        @(posedge clk);
        check_reg(5'd3, 32'd99, "LW writeback x3");

        // Dependent chain:
        // ADD x4, x1, x2  -> 100 + 99 = 199
        @(negedge clk);
        instruction = encode_rtype(`FUNCT7_ADD, 5'd2, 5'd1, `FUNCT3_ADD, 5'd4);
        check_result(32'd199, "ADD x4,x1,x2");
        @(posedge clk);
        check_reg(5'd4, 32'd199, "writeback x4");

        // SW x4, 4(x1)  -> mem[104] = 199
        @(negedge clk);
        instruction = encode_stype(12'd4, 5'd4, 5'd1, `FUNCT3_SW);
        check_result(32'd104, "SW addr calc (x1+4)");
        @(posedge clk);
        check_mem_word(104, 32'd199, "SW mem[104]=199");

        // LW x5, 4(x1) -> x5 = mem[104] = 199
        @(negedge clk);
        instruction = encode_itype_load(12'd4, 5'd1, `FUNCT3_LW, 5'd5);
        check_result(32'd104, "LW addr calc (x1+4)");
        @(posedge clk);
        check_reg(5'd5, 32'd199, "LW writeback x5 (dependent)");

        // ---- funct3 routing sanity check: SH / LH ----
        // SH x2, 8(x1) -> mem16[108] = 99 (confirms funct3 reaches data_memory correctly)
        @(negedge clk);
        instruction = encode_stype(12'd8, 5'd2, 5'd1, `FUNCT3_SH);
        check_result(32'd108, "SH addr calc (x1+8)");
        @(posedge clk);
        check_mem_half(108, 16'd99, "SH mem16[108]=99");

        // LH x6, 8(x1) -> x6 = 99 (sign-extended, positive so no difference)
        @(negedge clk);
        instruction = encode_itype_load(12'd8, 5'd1, `FUNCT3_LH, 5'd6);
        check_result(32'd108, "LH addr calc (x1+8)");
        @(posedge clk);
        check_reg(5'd6, 32'd99, "LH writeback x6");

        $display("---- %0d passed, %0d failed ----", pass_count, fail_count);
        $finish;
    end

endmodule