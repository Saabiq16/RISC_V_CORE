`timescale 1ns/1ps

module tb_register_file;

    // Testbench signals
    logic clk;
    logic write_enable;
    logic [4:0] read_addr1;
    logic [4:0] read_addr2;
    logic [4:0] write_addr;
    logic [31:0] write_data;
    logic [31:0] read_data1;
    logic [31:0] read_data2;

    // instantiating the register file
    register_file uut (
        .clk(clk),
        .write_enable(write_enable),
        .read_addr1(read_addr1),
        .read_addr2(read_addr2),
        .write_addr(write_addr),
        .write_data(write_data),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    int fail;

    task check;
        input [31:0] exp_read_data1;
        input [31:0] exp_read_data2;
        input int test_num;
        logic test_failed;
        begin
            test_failed = 0;

            if (read_data1 !== exp_read_data1) begin
                $display("TEST %0d FAILED | READ_DATA1 | exp = %h got = %h", test_num, exp_read_data1, read_data1);
                test_failed = 1;
            end

            if (read_data2 !== exp_read_data2) begin
                $display("TEST %0d FAILED | READ_DATA2 | exp = %h got = %h", test_num, exp_read_data2, read_data2);
                test_failed = 1;
            end

            if (test_failed) begin
                fail++;
            end else begin
                $display("TEST %0d PASSED", test_num);
            end
        end
    endtask

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 20ns clock period
    end

    // Test Sequence
    initial begin
        // Initialize signals
        write_enable = 0;
        read_addr1 = 0;
        read_addr2 = 0;
        write_addr = 0;
        write_data = 0;

        // Test 1: Check that register x0 is always zero
        #20; 
        read_addr1 = 5'd0; // x0
        check(32'd0, 32'd0, 1); // Expect both read_data1 and read_data2 to be 0

        // Test 2: Write to X0 and check that it remains zero
        #20;
        write_enable = 1;
        write_addr = 5'd0; // x0
        write_data = 32'd1;
        @(posedge clk);
        #1;
        write_enable = 0; // Disable write
        check(32'd0, 32'd0, 2); // Expect both read_data1 and read_data2 to be 0

        // Test 3: Write to another register and read it back
        #20;
        write_enable = 1;
        write_addr = 5'd1; // x1
        write_data = 32'hDEADBEEF;
        @(posedge clk);
        #1;
        write_addr = 5'd31;
        write_data = 32'hCAFEBABE;
        @(posedge clk);
        #1;

        write_addr = 5'd15;
        write_data = 32'h12345678;
        @(posedge clk);
        #1;

        write_enable = 0; // Disable write
        read_addr1 = 5'd1; // x1
        read_addr2 = 5'd31; // x31
        #1;
        check (32'hDEADBEEF, 32'hCAFEBABE, 3); // Expect read_data1 = 0xDEADBEEF and read_data2 = 0xCAFEBABE
    
        read_addr1 = 5'd15; // x15
        #1;
        check (32'h12345678, 32'hCAFEBABE, 3); // Expect read_data1 = 0x12345678 and read_data2 = 0xCAFEBABE

        // Test 4 : write and read at same time to check whether read data is from previous value or new value
      @(negedge clk);
      $display("DEBUG negedge: time=%0t", $time);
      write_enable = 1;
      write_addr = 5'd1;
      write_data = 32'hAAAAAAAA;
      read_addr1 = 5'd1;
      #0;
      $display("DEBUG before check: time=%0t rd1=%h we=%0d wa=%0d", 
                 $time, read_data1, write_enable, write_addr);
      check(32'hDEADBEEF, 32'hCAFEBABE, 4);
      $display("DEBUG after check: time=%0t rd1=%h", $time, read_data1);
      @(posedge clk);
      #1;
      check(32'hAAAAAAAA, 32'hCAFEBABE, 4);
      
        //  Test 5 : read from two different registers at the same time

        read_addr1 = 5'd1; // x1
        read_addr2 = 5'd31; // x31
        check (32'hAAAAAAAA, 32'hCAFEBABE, 5); //expect read_data1 = 0xAAAAAAAA and read_data2 = 0xCAFEBABE
        #10;

        // Test 6 : write to reg with write enable low and check that value is not written
        write_enable = 0;
        write_addr = 5'd1; // x1
        write_data = 32'hFFFFFFFF;
        #20;
        read_addr1 = 5'd1; // x1
        check (32'hAAAAAAAA, 32'hCAFEBABE, 6); 
        #10;

        //test 7 : write to x2 doesnot affect x1 and x31
        write_enable = 1;
        write_addr = 5'd2; // x2
        write_data = 32'h11111111;
        #20;
        read_addr1 = 5'd1; // x1
        read_addr2 = 5'd31; // x31
        #1;
        check (32'hAAAAAAAA, 32'hCAFEBABE, 7); //expect read_data1 = 0xAAAAAAAA and read_data2 = 0xCAFEBABE

        #100;

         if (fail == 0)
            $display("ALL 7 TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", fail);

        $finish;
    end
    endmodule










    

    

