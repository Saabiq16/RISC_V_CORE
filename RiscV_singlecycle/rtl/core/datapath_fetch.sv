module fetch (
    input logic clk,
    input logic [31:0] pc_next,
    input logic reset,

    output logic [31:0] instruction,
    output logic [31:0] pc,
    output logic [31:0] pc_plus_4
);

program_counter pc_inst (
    .clk(clk),
    .reset(reset),
    .pc_next(pc_next),
    .pc_out(pc)
);

pc_adder4 pc_adder_inst (
    .pc_current(pc),
    .pc_plus4(pc_plus_4)
);

instruction_memory instruction_memory_inst (
    .address(pc),
    .instruction(instruction)
);

endmodule