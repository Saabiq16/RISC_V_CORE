`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test7;
    logic clk;
    logic rst;
    int pass_count = 0;
    int fail_count = 0;

    riscv_single_cycle dut (
        .clk   (clk),
        .reset (rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // NOTE: instruction_memory.sv loads instructions.hex itself via
    // $readmemh at elaboration -- make sure it's pointing at the
    // test7_jalr build output before running this. If register
    // values look like a previous test's results, rebuild and rerun.

    task automatic check_reg(
        input int           reg_num,
        input logic [31:0]  exp_val,
        input string        test_name
    );
        if (dut.reg_file.registers[reg_num] === exp_val) begin
            pass_count++;
            $display("[PASS] %s  x%0d = 0x%08h", test_name, reg_num, dut.reg_file.registers[reg_num]);
        end else begin
            fail_count++;
            $display("[FAIL] %s  x%0d  exp=0x%08h got=0x%08h",
                       test_name, reg_num, exp_val, dut.reg_file.registers[reg_num]);
        end
    endtask

    initial begin
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;

        // test7_jalr.s has ~26 real instructions before the loop
        // (each `la` expands to auipc+addi = 2 instructions).
        // Generous margin since it loops forever afterward anyway.
        repeat (40) @(negedge clk);
        #1;

        // Expected values -- addresses computed assuming `la` expands
        // to the standard auipc+addi pair (2 instructions, 8 bytes).
        // Instruction layout (each real instr = 4 bytes):
        //   0x00 auipc x1         \_ la x1, target1
        //   0x04 addi  x1,x1,..   /
        //   0x08 jalr  x2,x1,0        <-- Test1 JALR here
        //   0x0C addi  x10,x0,99
        //   0x10 jal   x0,skip1
        //   0x14 addi  x10,x0,1   <- target1
        //   0x18 auipc x3         \_ la x3, before_target2
        //   0x1C addi  x3,x3,..   /
        //   0x20 jalr  x4,x3,4        <-- Test2 JALR here
        //   0x24 addi  x11,x0,99
        //   0x28 jal   x0,skip2
        //   0x2C addi  x0,x0,0    <- before_target2
        //   0x30 addi  x11,x0,1   <- target2
        //   0x34 auipc x5         \_ la x5, target3
        //   0x38 addi  x5,x5,..   /
        //   0x3C jalr  x6,x5,1        <-- Test3 JALR here
        //   0x40 addi  x12,x0,99
        //   0x44 jal   x0,skip3
        //   0x48 addi  x12,x0,1   <- target3
        //   0x4C auipc x7         \_ la x7, target4   <- jalr4:
        //   0x50 addi  x7,x7,..   /
        //   0x54 jalr  x8,x7,0        <-- Test4 JALR here
        //   0x58 addi  x13,x0,99
        //   0x5C jal   x0,skip4
        //   0x60 addi  x13,x0,1   <- target4

        check_reg(2,  32'h0000000C, "x2  = link addr, Test1 JALR (pc=0x08)");
        check_reg(10, 32'd1,        "x10 = Test1 JALR used rs1, not pc");

        check_reg(4,  32'h00000024, "x4  = link addr, Test2 JALR (pc=0x20)");
        check_reg(11, 32'd1,        "x11 = Test2 JALR imm=4 correctly added");

        check_reg(6,  32'h00000040, "x6  = link addr, Test3 JALR (pc=0x3C)");
        check_reg(12, 32'd1,        "x12 = Test3 JALR LSB correctly cleared");

        check_reg(8,  32'h00000058, "x8  = link addr, Test4 JALR (pc=0x54)");
        check_reg(13, 32'd1,        "x13 = Test4 JALR jumped correctly");

        $display("\n--- ISA-Level Test7 (JALR) Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule