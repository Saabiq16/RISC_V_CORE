module instruction_memory(
    input logic [31:0] address,
    output logic [31:0] instruction
);

logic [31:0] memory [0:16383]; // 16kb


initial begin
    $readmemh("E:/project/RISC_V_CORE/RiscV_singlecycle/test_hex/instructions.hex", memory); // Load instructions from a hex file
end

assign instruction = memory[address[15:2]]; // Word-aligned access

endmodule