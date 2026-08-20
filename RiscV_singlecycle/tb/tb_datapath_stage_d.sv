`include "../includes/riscv_defines.svh"

module tb_datapath_stage_d;

    logic        clk;
    logic [31:0] instruction;
    logic [31:0] pc_current;
    logic [31:0] pc_plus_4;

    logic [31:0] alu_result;
    logic        zero;
    logic [31:0] pc_next;

    int pass_count = 0;
    int fail_count = 0;

    datapath_stage_d dut (
        .clk         (clk),
        .instruction (instruction),
        .pc_current  (pc_current),
        .pc_plus_4   (pc_plus_4),
        .alu_result  (alu_result),
        .zero        (zero),
        .pc_next     (pc_next)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //B- type encoder

    function automatic logic [31:0] encode_btype (
        input logic signed [12:0] offset,
        input logic [4:0] rs2,
        input logic [4:0] rs1,
        input logic [2:0] funct3   
    );

    logic [12:0] imm;
    imm = offset;
    return {imm[12],imm[10:5],rs2,rs1,funct3,imm[4:1],imm[11],`OP_BRANCH};
    endfunction

    // J-type encoder: takes a signed offset (must be even), rd
    function automatic logic [31:0] encode_jtype(
        input logic signed [20:0] offset,   // 21-bit signed, bit0 always 0
        input logic [4:0] rd
    );
        logic [20:0] imm;
        imm = offset;
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, `OP_JAL};
    endfunction

    // I-type encoder for JALR
    function automatic logic [31:0] encode_jalr(
        input logic signed [11:0] offset,
        input logic [4:0] rs1,
        input logic [4:0] rd
    );
        logic [11:0] imm;
        imm = offset;
        return {imm, rs1, `FUNCT3_ADD, rd, `OP_JALR};  // JALR funct3 is always 000
    endfunction


    task automatic check_pc_next(input logic [31:0] exp_val, input string label);
        #1;
        if (pc_next === exp_val) begin
            pass_count++;
            $display("[PASS] %s: pc_next=%0h", label, pc_next);
        end else begin
            fail_count++;
            $display("[FAIL] %s: pc_next=%0h (exp %0h)", label, pc_next, exp_val);
        end
    endtask

    task automatic check_reg(input logic [4:0] reg_addr, input logic [31:0] exp_val, input string label);
        #1;
        if (dut.reg_file.registers[reg_addr] === exp_val) begin
            pass_count++;
            $display("[PASS] %s: x%0h=%0h", label, reg_addr, dut.reg_file.registers[reg_addr]);
        end else begin
            fail_count++;
            $display("[FAIL] %s: x%0h=%0h (exp %0h)", label, reg_addr, dut.reg_file.registers[reg_addr], exp_val);
        end
    endtask

    task force_reg(input int addr, input logic [31:0] val);
    case (addr)
        1: dut.reg_file.registers[1] = val;
        2: dut.reg_file.registers[2] = val;
        3: dut.reg_file.registers[3] = val;
    endcase
endtask

    initial begin
        pc_current  = 32'h1000;
        pc_plus_4   = 32'h1004;
        instruction = 32'd0;

        //---------------------------------------------
        // BEQ x1,x2, +8  -- taken (5 == 5)
        //---------------------------------------------
        force_reg(1, 32'd5);
        force_reg(2, 32'd5);
        @(negedge clk);
        instruction = encode_btype(13'sd8, 5'd2, 5'd1, `BR_BEQ);
        check_pc_next(32'h1008, "BEQ taken (5==5)");

        //---------------------------------------------
        // BEQ x1,x2, +8  -- not taken (5 != 8)
        //---------------------------------------------
        force_reg(1, 32'd5);
        force_reg(2, 32'd8);
        @(negedge clk);
        instruction = encode_btype(13'sd8, 5'd2, 5'd1, `BR_BEQ);
        check_pc_next(32'h1004, "BEQ not taken (5!=8)");

        //---------------------------------------------
        // BNE x1,x2, +8  -- taken (5 != 8)
        //---------------------------------------------
        force_reg(1, 32'd5);
        force_reg(2, 32'd8);
        @(negedge clk);
        instruction = encode_btype(13'sd8, 5'd2, 5'd1, `BR_BNE);
        check_pc_next(32'h1008, "BNE taken (5!=8)");

        //---------------------------------------------
        // BLT x1,x2, +12  -- signed, taken (-3 < 2)
        //---------------------------------------------
        force_reg(1, -32'sd3);
        force_reg(2, 32'd2);
        @(negedge clk);
        instruction = encode_btype(13'sd12, 5'd2, 5'd1, `BR_BLT);
        check_pc_next(32'h100C, "BLT taken (-3<2)");

        //---------------------------------------------
        // BGE x1,x2, +12  -- signed, taken (5 >= 2)
        //---------------------------------------------
        force_reg(1, 32'd5);
        force_reg(2, 32'd2);
        @(negedge clk);
        instruction = encode_btype(13'sd12, 5'd2, 5'd1, `BR_BGE);
        check_pc_next(32'h100C, "BGE taken (5>=2)");

        //---------------------------------------------
        // BGE x1,x2, +12  -- signed, not taken (-3 >= 2 is false)
        //---------------------------------------------
        force_reg(1, -32'sd3);
        force_reg(2, 32'd2);
        @(negedge clk);
        instruction = encode_btype(13'sd12, 5'd2, 5'd1, `BR_BGE);
        check_pc_next(32'h1004, "BGE not taken (-3>=2 false)");

        //---------------------------------------------
        // BLTU x1,x2, +16  -- unsigned, taken (5 < 8)
        //---------------------------------------------
        force_reg(1, 32'd5);
        force_reg(2, 32'd8);
        @(negedge clk);
        instruction = encode_btype(13'sd16, 5'd2, 5'd1, `BR_BLTU);
        check_pc_next(32'h1010, "BLTU taken (5<8 unsigned)");

        //---------------------------------------------
        // BLTU x1,x2, +16 -- unsigned, not taken (8 < 5 is false)
        //---------------------------------------------
        force_reg(1, 32'd8);
        force_reg(2, 32'd5);
        @(negedge clk);
        instruction = encode_btype(13'sd16, 5'd2, 5'd1, `BR_BLTU);
        check_pc_next(32'h1004, "BLTU not taken (8<5 false)");

        //---------------------------------------------
        // BGEU x1,x2, +16  -- unsigned, taken (8 >= 5)
        //---------------------------------------------
        force_reg(1, 32'd8);
        force_reg(2, 32'd5);
        @(negedge clk);
        instruction = encode_btype(13'sd16, 5'd2, 5'd1, `BR_BGEU);
        check_pc_next(32'h1010, "BGEU taken (8>=5)");

        //---------------------------------------------
        // JAL x5, +20
        //---------------------------------------------
        @(negedge clk);
        instruction = encode_jtype(21'sd20, 5'd5);
        check_pc_next(32'h1014, "JAL target");
        @(posedge clk);
        check_reg(5'd5, 32'h1004, "JAL writeback x5=pc+4");

        //---------------------------------------------
        // JALR x6, 4(x3)  -- x3 = 0x2000
        //---------------------------------------------
        force_reg(3, 32'h2000);
        @(negedge clk);
        instruction = encode_jalr(12'sd4, 5'd3, 5'd6);
        check_pc_next(32'h2004, "JALR target (base=rs1)");
        @(posedge clk);
        check_reg(5'd6, 32'h1004, "JALR writeback x6=pc+4");

        $display("---- %0d passed, %0d failed ----", pass_count, fail_count);
        $finish;
    end

endmodule
