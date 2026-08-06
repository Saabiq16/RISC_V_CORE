`timescale 1ns/1ps

module tb_data_memory ();

logic clk;
logic [31:0] address;
logic [31:0] write_data;
logic dm_write_enable;
logic dm_read_enable;
logic [2:0] funct3;
logic [31:0] read_data;

int pass_count = 0;
int fail_count = 0;

data_memory dut (
    .clk(clk),
    .address(address),
    .write_data(write_data),
    .dm_write_enable(dm_write_enable),
    .dm_read_enable(dm_read_enable),
    .funct3(funct3),
    .read_data(read_data)
);

// Clock generation
always #5 clk = ~clk;

// TASK (write)
task automatic do_write (
    input logic [31:0] addr_in,
    input logic [31:0] data_in,
    input logic [2:0] funct3_in
);
    @(negedge clk);
      address = addr_in;
      write_data = data_in;
      funct3 = funct3_in;
      dm_write_enable = 1;
      dm_read_enable = 0;
    @(posedge clk);
      #1;
    @(negedge clk);
      dm_write_enable = 0;
endtask

// TASK (read and check)
task automatic do_read_check (
    input logic [31:0] addr_in,
    input logic [31:0] expected_data,
    input logic [2:0] funct3_in,
    input string test_name
);

    @(negedge clk);
      address = addr_in;
      funct3 = funct3_in;
      dm_write_enable = 0;
      dm_read_enable = 1;
    #1;

    if (read_data === expected_data) begin
        $display("PASS: %s (address : 0x%08h, funct3: 0x%03b, read : 0x%08h)", test_name, addr_in, funct3_in, read_data);
        pass_count++;
    end else begin
        $display("FAIL: %s (address : 0x%08h, funct3: 0x%03b, read : 0x%08h, expected : 0x%08h)", test_name, addr_in, funct3_in, read_data, expected_data);
        fail_count++;
    end
    dm_read_enable = 0;
endtask

initial begin

    clk = 0;
    dm_write_enable = 0;
    dm_read_enable = 0;
    address = 0;
    write_data = 0;
    funct3 = 0;

    //----TEST 1 : SW and LW ----
    do_write(32'd0, 32'h1609_2005, `FUNCT3_SW);
    do_read_check(32'd0, 32'h1609_2005, `FUNCT3_LW, "Test 1: SW and LW");

    //----TEST 2 : SB and LB (positive) ----
    do_write(32'd4, 32'h0000_0005, `FUNCT3_SB);
    do_read_check(32'd4, 32'h0000_0005, `FUNCT3_LB, "Test 2: SB and LB (positive)");

    //----TEST 3 : SB and LB (negative) ----
    do_write(32'd8, 32'h0000_00FF, `FUNCT3_SB);
    do_read_check(32'd8, 32'hFFFF_FFFF, `FUNCT3_LB, "Test 3: SB and LB (negative)");

    //----TEST 4 : SB and LBU (unsigned negative) ----
    do_read_check(32'd8, 32'h0000_00FF, `FUNCT3_LBU, "Test 4: SB and LBU (unsigned negative)");

    //----TEST 5 : SH and LH (positive) ----
    do_write(32'd12, 32'h0000_1234, `FUNCT3_SH);
    do_read_check(32'd12, 32'h0000_1234, `FUNCT3_LH, "Test 5: SH and LH (positive)");

    //----TEST 6 : SH and LH (negative) ----
    do_write(32'd16, 32'h0000_FFFF, `FUNCT3_SH);
    do_read_check(32'd16, 32'hFFFF_FFFF, `FUNCT3_LH, "Test 6: SH and LH (negative)");

    //----TEST 7 : SH and LHU (unsigned negative) ----
    do_read_check(32'd16, 32'h0000_FFFF, `FUNCT3_LHU, "Test 7: SH and LHU (unsigned negative)");

    //----TEST 8 : BYTE ordering / endianness ----
    do_write(32'd20, 32'h1234_5678, `FUNCT3_SW);
    do_read_check(32'd20, 32'h0000_0078, `FUNCT3_LBU, "Test 8a: BYTE ordering / endianness (LBU)");
    do_read_check(32'd21, 32'h0000_0056, `FUNCT3_LBU, "Test 8b: BYTE ordering / endianness (LBU)");
    do_read_check(32'd22, 32'h0000_0034, `FUNCT3_LBU, "Test 8c: BYTE ordering / endianness (LBU)");
    do_read_check(32'd23, 32'h0000_0012, `FUNCT3_LBU, "Test 8d: BYTE ordering / endianness (LBU)");

    // ---- Test 9: write enable gating - write should NOT happen when disabled ----
        do_write(32'd24, 32'hAAAAAAAA, `FUNCT3_SW); // legit write first
        @(negedge clk);
        address         = 32'd24;
        write_data      = 32'hDEADBEEF;
        funct3          = `FUNCT3_SW;
        dm_write_enable = 1'b0; // disabled - should NOT overwrite
        @(posedge clk);
        #1;
        do_read_check(32'd24, 32'hAAAAAAAA, `FUNCT3_LW, "Write gating: disabled write ignored");
     
// ---- Test 10: read enable gating - read_data should be 0 when disabled ----
        @(negedge clk);
        address        = 32'd0; // known non-zero location from Test 1
        dm_read_enable = 1'b0;
        #1;
        if (read_data === 32'b0) begin
            pass_count++;
            $display("PASS: Read gating: disabled read outputs 0");
        end else begin
            fail_count++;
            $display("FAIL: Read gating: expected 0, got 0x%08h", read_data);
        end

    
 // ---- Test 11: overwrite test - second write wins ----
        do_write(32'd28, 32'hAAAAAAAA, `FUNCT3_SW);
        do_write(32'd28, 32'h55555555, `FUNCT3_SW);
        do_read_check(32'd28, 32'h55555555, `FUNCT3_LW, "Overwrite: second write wins");

 // ---- Test 12: boundary - first address ----
        do_write(32'd0, 32'hCAFEBABE, `FUNCT3_SW);
        do_read_check(32'd0, 32'hCAFEBABE, `FUNCT3_LW, "Boundary: address 0");

        // ---- Test 13: boundary - last safe word-aligned address (1020) ----
        do_write(32'd1020, 32'hFEEDFACE, `FUNCT3_SW);
        do_read_check(32'd1020, 32'hFEEDFACE, `FUNCT3_LW, "Boundary: last word address 1020 (uses up to 1023)");

        $display("\n===== TEST SUMMARY =====");
        $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule