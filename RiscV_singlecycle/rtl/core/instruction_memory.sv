module instruction_memory(
    input logic [31:0] address,
    output logic [31:0] instruction
);

logic [31:0] memory [0:1023]; // 1K instructions


initial begin
    $readmemh("E:/project/RISC_V_CORE/RiscV_singlecycle/tb/instructions.hex", memory); // Load instructions from a hex file
end

assign instruction = memory[address[11:2]]; // Word-aligned access

endmodule