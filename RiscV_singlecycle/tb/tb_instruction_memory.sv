module tb_instruction_memory ();

logic [31:0] instruction;
logic [31:0] address;

instruction_memory imem (
    .address(address),
    .instruction(instruction)
);

int pass_count = 0;
int fail_count = 0;

task automatic check(
    input logic [31:0] addr_in,
    input logic [31:0] expected_instruction,
    input string test_name
);

    address = addr_in;
    #1;

    if (instruction === expected_instruction)
    begin
        $display("PASS: %s - Address 0x%08h, Instruction 0x%08h", test_name, addr_in, instruction);
        pass_count++;
    end
    else
    begin
        $display("FAIL: %s - Address 0x%08h, Expected 0x%08h, Got 0x%08h", test_name, addr_in, expected_instruction, instruction);
        fail_count++;
    end
endtask

initial begin

    // Sequential address test
    //Test 1   address 0 -> mem[0]
    check(32'd0,32'h11111111, "Sequential Fetch : address 0 -> mem[0]");
    //Test 2   address 4 -> mem[1]
    check(32'd4,32'h22222222, "Sequential Fetch : address 4 -> mem[1]");
    //Test 3   address 8 -> mem[2]
    check(32'd8,32'h33333333, "Sequential Fetch : address 8 -> mem[2]");
    //Test 4   address 12 -> mem[3]
    check(32'd12,32'h44444444, "Sequential Fetch : address 12 -> mem[3]");


    //allignment chekck in between sequential address    
    //Test 5   address 1 -> mem[0]
    check(32'd1,32'h11111111, "Sequential Fetch : address 1 -> mem[0]");
    //Test 6   address 2 -> mem[0]
    check(32'd2,32'h11111111, "Sequential Fetch : address 2 -> mem[0]");
    //Test 7   address 3 -> mem[0]
    check(32'd3,32'h11111111, "Sequential Fetch : address 3 -> mem[0]");

    //Non-sequential address test
    //Test 8   address 4 -> mem[1]
    check(32'd4,32'h22222222, "Non-Sequential Fetch : address 4 -> mem[1]");
    //Test 9   address 12-> mem[3]
    check(32'd12,32'h44444444, "Non-Sequential Fetch : address 12 -> mem[3]");

    //Boundary address test
    //Test 10   address 0 -> mem[0]
    check(32'd0,32'h11111111, "Boundary Fetch : address 0 -> mem[0]");
    //Test 11   address 4092 -> mem[1023]    
    check(32'd4092,32'hFFFFFFFF, "Boundary Fetch : address 4092 -> mem[1023]");



     $display("\n===== TEST SUMMARY =====");
     $display("PASS: %0d, FAIL: %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
