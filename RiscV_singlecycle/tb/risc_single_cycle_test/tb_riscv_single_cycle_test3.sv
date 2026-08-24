`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test3;
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
    // test3_lui_auipc build output before running this.

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

        // test3_lui_auipc.s has 4 real instructions before the loop.
        // Wait margin generous since it loops forever afterward anyway.
        repeat (10) @(negedge clk);
        #1;

        // Expected values, hand-computed from test3_lui_auipc.s:
        //   x1 = lui  x1, 0x12345         = 0x12345000
        //   x2 = auipc x2, 0x1  @ pc=0x4  = 0x4 + 0x1000      = 0x00001004
        //   x3 = auipc x3, 0    @ pc=0x8  = 0x8 + 0             = 0x00000008
        //   x4 = lui  x4, 0xFFFFF         = 0xFFFFF000
        check_reg(1, 32'h12345000, "x1 = lui 0x12345");
        check_reg(2, 32'h00001004, "x2 = auipc 0x1 @ pc=0x4");
        check_reg(3, 32'h00000008, "x3 = auipc 0 @ pc=0x8 (pc-passthrough canary)");
        check_reg(4, 32'hFFFFF000, "x4 = lui 0xFFFFF");

        $display("\n--- ISA-Level Test3 Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule