module instruction_memory(
    input logic [31:0] address,
    output logic [31:0] instruction
);

logic [31:0] memory [0:16383]; // 16kb


initial begin
    $readmemh(
        "/home/priyadharshan/Documents/RISC_V_tests/test_mbox_wb_words.hex",
        memory
    );
end

assign instruction = memory[address[15:2]]; // Word-aligned access

endmodule