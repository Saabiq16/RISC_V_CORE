`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle;

    logic clk, reset;

    int pass_count = 0;
    int fail_count = 0;

    riscv_single_cycle dut (
        .clk   (clk),
        .reset (reset)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // generic I-type encoder (covers ADDI and LW)
    function automatic logic [31:0] encode_itype(
        input logic signed [11:0] imm,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd,
        input logic [6:0] opcode
    );
        logic [11:0] immb;
        immb = imm;
        return {immb, rs1, funct3, rd, opcode};
    endfunction

    function automatic logic [31:0] encode_rtype(
        input logic [6:0] funct7,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3,
        input logic [4:0] rd
    );
        return {funct7, rs2, rs1, funct3, rd, `OP_R_TYPE};
    endfunction

    function automatic logic [31:0] encode_stype(
        input logic [11:0] imm,
        input logic [4:0]  rs2,
        input logic [4:0]  rs1,
        input logic [2:0]  funct3
    );
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], `OP_STORE};
    endfunction

    function automatic logic [31:0] encode_btype(
        input logic signed [12:0] offset,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3
    );
        logic [12:0] imm;
        logic [31:0] instr;
        imm = offset;
        instr = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], `OP_BRANCH};
        return instr;
    endfunction

    // direct poke into instruction memory (word index, not byte address)
    task load_instr(input int idx, input logic [31:0] instr);
        dut.instruction_memory_inst.memory[idx] = instr;
    endtask

    task automatic check_reg(input logic [4:0] reg_addr, input logic [31:0] exp_val, input string label);
        if (dut.reg_file.registers[reg_addr] === exp_val) begin
            pass_count++;
            $display("[PASS] %s: x%0d=%0h", label, reg_addr, dut.reg_file.registers[reg_addr]);
        end else begin
            fail_count++;
            $display("[FAIL] %s: x%0d=%0h (exp %0h)", label, reg_addr, dut.reg_file.registers[reg_addr], exp_val);
        end
    endtask

    task automatic check_mem_word(input int addr, input logic [31:0] exp_val, input string label);
        logic [31:0] actual;
        actual = {dut.data_mem.memory[addr+3], dut.data_mem.memory[addr+2],
                  dut.data_mem.memory[addr+1], dut.data_mem.memory[addr]};
        if (actual === exp_val) begin
            pass_count++;
            $display("[PASS] %s: mem[%0d]=%0h", label, addr, actual);
        end else begin
            fail_count++;
            $display("[FAIL] %s: mem[%0d]=%0h (exp %0h)", label, addr, actual, exp_val);
        end
    endtask

    initial begin
        // Load program directly into instruction memory before reset releases
        load_instr(0, encode_itype(12'sd5,  5'd0, `FUNCT3_ADD, 5'd1, `OP_I_TYPE)); // addi x1,x0,5
        load_instr(1, encode_itype(12'sd3,  5'd0, `FUNCT3_ADD, 5'd2, `OP_I_TYPE)); // addi x2,x0,3
        load_instr(2, encode_rtype(`FUNCT7_ADD, 5'd2, 5'd1, `FUNCT3_ADD, 5'd3));    // add x3,x1,x2
        load_instr(3, encode_stype(12'd0, 5'd3, 5'd0, `FUNCT3_SW));                 // sw x3,0(x0)
        load_instr(4, encode_itype(12'sd0, 5'd0, `FUNCT3_LW, 5'd4, `OP_LOAD));      // lw x4,0(x0)
        load_instr(5, encode_btype(13'sd8, 5'd1, 5'd1, `BR_BEQ));                   // beq x1,x1,+8
        load_instr(6, encode_itype(12'sd99, 5'd0, `FUNCT3_ADD, 5'd5, `OP_I_TYPE));  // addi x5,x0,99 (must be skipped)
        load_instr(7, encode_itype(12'sd7,  5'd0, `FUNCT3_ADD, 5'd6, `OP_I_TYPE));  // addi x6,x0,7 (branch target)

        // Reset pulse
        reset = 1;
        @(posedge clk);
        @(posedge clk);
        reset = 0;

        // Let the closed loop (fetch -> execute -> pc_next -> fetch) run freely
        repeat (10) @(posedge clk);
        #1;

        // Checks
        check_reg(5'd1, 32'd5, "x1 = 5 (addi)");
        check_reg(5'd2, 32'd3, "x2 = 3 (addi)");
        check_reg(5'd3, 32'd8, "x3 = 8 (add)");
        check_mem_word(0, 32'd8, "mem[0] = 8 (sw)");
        check_reg(5'd4, 32'd8, "x4 = 8 (lw)");
        check_reg(5'd6, 32'd7, "x6 = 7 (branch target reached)");

        // The skip proof: x5 should NEVER have been written
        if (dut.reg_file.registers[5] === 32'd99) begin
            fail_count++;
            $display("[FAIL] x5 got written to 99 -- branch was NOT taken, fell through instead!");
        end else begin
            pass_count++;
            $display("[PASS] x5 untouched (%0h) -- branch correctly skipped addr6", dut.reg_file.registers[5]);
        end

        $display("---- %0d passed, %0d failed ----", pass_count, fail_count);
        $finish;
    end

endmodule