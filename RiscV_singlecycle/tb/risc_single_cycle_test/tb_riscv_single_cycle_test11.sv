
`timescale 1ns/1ps
`include "../includes/riscv_defines.svh"

module tb_riscv_single_cycle_test11;

    logic clk;
    logic rst;

    int pass_count = 0;
    int fail_count = 0;

    riscv_single_cycle_mem_timing dut (
        .clk   (clk),
        .reset (rst)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // instruction_memory.sv loads instructions.hex through $readmemh.
    // Ensure instructions.hex contains the assembled test11 program.

    task automatic check_reg(
        input int          reg_num,
        input logic [31:0] exp_val,
        input string       test_name
    );
        if (dut.reg_file.registers[reg_num] === exp_val) begin
            pass_count++;
            $display("[PASS] %s: x%0d = 0x%08h",
                     test_name, reg_num,
                     dut.reg_file.registers[reg_num]);
        end else begin
            fail_count++;
            $display("[FAIL] %s: x%0d exp=0x%08h got=0x%08h",
                     test_name, reg_num, exp_val,
                     dut.reg_file.registers[reg_num]);
        end
    endtask

    initial begin
        rst = 1'b1;

        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Test11 has a backward loop and then an infinite final loop.
        // Allow enough cycles for the program to finish its checks.
        repeat (150) @(negedge clk);
        #1;

        $display("\n--- TEST11: Branch / Jump Results ---");

        // A: Taken BEQ skips wrong-path register write
        check_reg(10, 32'd0,  "A: Wrong-path x10 unchanged");
        check_reg(11, 32'd0,  "A: Unfetched x11 unchanged");
        check_reg(12, 32'd1,  "A: Branch target executed");

        // B: Not-taken branch
        check_reg(13, 32'd5,  "B: Not-taken branch x13");
        check_reg(14, 32'd6,  "B: Sequential x14");
        check_reg(15, 32'd7,  "B: Branch continuation x15");

        // C: Backward loop
        check_reg(16, 32'd5,  "C: Loop counter x16");
        check_reg(18, 32'd9,  "C: Loop exit x18");

        // D: JAL
        check_reg(19, 32'h00000050, "D: JAL link address x19");
        check_reg(20, 32'd0,        "D: Wrong-path x20 unchanged");
        check_reg(21, 32'd0,        "D: Wrong-path x21 unchanged");
        check_reg(22, 32'd3,        "D: JAL target x22");

        // E: JALR (la expands to AUIPC + ADDI)
        check_reg(25, 32'd0, "E: Wrong-path x25 unchanged");
        check_reg(26, 32'd0, "E: Wrong-path x26 unchanged");
        check_reg(27, 32'd4, "E: JALR target x27");

        // F: Back-to-back taken branches
        check_reg(28, 32'd0, "F: Wrong-path x28 unchanged");
        check_reg(29, 32'd0, "F: Wrong-path x29 unchanged");
        check_reg(30, 32'd8, "F: Branch target x30");

        // G: Load followed by a branch
        check_reg(5,  32'd2,  "G: Loaded value x5");
        check_reg(6,  32'd0,  "G: Wrong-path x6 unchanged");
        check_reg(7,  32'd0,  "G: Wrong-path x7 unchanged");
        check_reg(8,  32'd10, "G: Branch target x8");

        // H: Branch over one instruction
        check_reg(9, 32'd12, "H: Target x9");

        // I: Wrong-path loads
        check_reg(31, 32'd0,  "I: Wrong-path loads leave x31 unchanged");
        check_reg(4,  32'd15, "I: Branch target x4");

        // J: Wrong-path JAL must not redirect execution
        check_reg(21, 32'd16, "J: Correct path x21");

        // Memory checks: use the actual data_memory hierarchy
        if (dut.data_mem.mem2[32'h80 >> 2] === 8'h00) begin
            pass_count++;
            $display("[PASS] A: mem[0x80] low byte remains zero");
        end else begin
            fail_count++;
            $display("[FAIL] A: mem[0x80] low byte changed");
        end

        if (dut.data_mem.mem0[32'h84 >> 2] === 8'h02) begin
            pass_count++;
            $display("[PASS] G: mem[0x84] low byte = 2");
        end else begin
            fail_count++;
            $display("[FAIL] G: mem[0x84] low byte incorrect");
        end

        $display("\n--- TEST11 Summary ---");
        $display("PASS: %0d | FAIL: %0d", pass_count, fail_count);

        if (fail_count == 0)
            $display("ALL CHECKS PASSED");
        else
            $display("SOME CHECKS FAILED");

        $finish;
    end

endmodule
