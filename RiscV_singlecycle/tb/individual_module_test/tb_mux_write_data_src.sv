`timescale 1ns/1ps

module tb_mux_write_data_src;

    logic [31:0] alu_result;
    logic [31:0] memory_read_data;
    logic [31:0] pc_plus_4;
    logic [1:0]  result_src;
    logic [31:0] write_back_data;

    int pass_count = 0;
    int fail_count = 0;

    mux_write_data_src uut (
        .alu_result       (alu_result),
        .memory_read_data (memory_read_data),
        .pc_plus_4        (pc_plus_4),
        .result_src       (result_src),
        .write_back_data  (write_back_data)
    );

    task automatic check(
        input logic [31:0] alu_result_in,
        input logic [31:0] memory_read_data_in,
        input logic [31:0] pc_plus_4_in,
        input logic [1:0]  result_src_in,
        input logic [31:0] exp_out,
        input string       test_name
    );
        alu_result       = alu_result_in;
        memory_read_data = memory_read_data_in;
        pc_plus_4        = pc_plus_4_in;
        result_src       = result_src_in;
        #1;

        if (write_back_data === exp_out) begin
            pass_count++;
            $display("PASS: %s", test_name);
        end else begin
            fail_count++;
            $display("FAIL: %s | exp=0x%08h got=0x%08h", test_name, exp_out, write_back_data);
        end
    endtask

    initial begin
        check(32'hDEADBEEF, 32'hCAFEBABE, 32'h00000024, 2'b00, 32'hDEADBEEF, "result_src=00, alu_result selected");
        check(32'hDEADBEEF, 32'hCAFEBABE, 32'h00000024, 2'b01, 32'hCAFEBABE, "result_src=01, memory_read_data selected");
        check(32'hDEADBEEF, 32'hCAFEBABE, 32'h00000024, 2'b10, 32'h00000024, "result_src=10, PC+4 selected");
        check(32'hDEADBEEF, 32'hCAFEBABE, 32'h00000024, 2'b11, 32'h00000000, "result_src=11, default (unused) case");
        check(32'h12345678, 32'h12345678, 32'h00000024, 2'b00, 32'h12345678, "Both alu/mem same, result_src=00");
        check(32'h12345678, 32'h12345678, 32'h00000024, 2'b01, 32'h12345678, "Both alu/mem same, result_src=01");
        check(32'h00000000, 32'h00000000, 32'h00000000, 2'b10, 32'h00000000, "All zeros, PC+4 selected");
        check(32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 2'b01, 32'hFFFFFFFF, "All ones, memory_read_data selected");
        check(32'h11111111, 32'h22222222, 32'h33333333, 2'b00, 32'h11111111, "Unique values, alu_result selected");
        check(32'h11111111, 32'h22222222, 32'h33333333, 2'b01, 32'h22222222, "Unique values, memory_read_data selected");
        check(32'h11111111, 32'h22222222, 32'h33333333, 2'b10, 32'h33333333, "Unique values, PC+4 selected");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d", pass_count);
        $display("FAIL: %0d", fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule