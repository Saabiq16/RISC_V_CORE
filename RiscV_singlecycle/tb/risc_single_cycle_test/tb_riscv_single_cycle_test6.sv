`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test6;
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
    // test6_jal build output before running this. If register values
    // look like a previous test's results, rebuild and rerun.

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

        // test6_jal.s has 10 real instructions before the loop.
        // Generous margin since it loops forever afterward anyway.
        repeat (20) @(negedge clk);
        #1;

        // Expected values, hand-computed from test6_jal.s:
        //   x1  = jal x1, jal_target @ pc=0x00  -> link = 0x00 + 4 = 0x04
        //   x10 = 1  (confirms first JAL actually jumped)
        //   x11 = 1  (confirms JAL with x0 as rd still jumped)
        //   x14 = 5  (canary: x13 + x0 -- proves x0 stayed hardwired to 0
        //             even though a prior JAL tried to write pc+4 into it)
        //   x15 = 1  (confirms second JAL actually jumped)
        //   x2  = jal x2, jal2_target @ pc=0x24  -> link = 0x24 + 4 = 0x28
        check_reg(1,  32'h00000004, "x1  = link addr of 1st JAL (pc=0x0)");
        check_reg(10, 32'd1,        "x10 = 1st JAL actually jumped");
        check_reg(11, 32'd1,        "x11 = JAL-with-x0 actually jumped");
        check_reg(14, 32'd5,        "x14 = x0 stayed hardwired-zero (canary)");
        check_reg(15, 32'd1,        "x15 = 2nd JAL actually jumped");
        check_reg(2,  32'h00000028, "x2  = link addr of 2nd JAL (pc=0x24)");

        $display("\n--- ISA-Level Test6 (JAL) Summary ---");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0) $display("ALL TESTS PASSED");
        else $display("SOME TESTS FAILED");
        $finish;
    end
endmodule