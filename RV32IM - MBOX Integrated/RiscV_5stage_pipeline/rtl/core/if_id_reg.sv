`include "../includes/riscv_defines.svh"

module if_id_reg (

    input logic        clk,
    input logic        reset,
    input logic        stall,
    input logic        flush,
    input logic [31:0] pc_current_f,
    input logic [31:0] instruction_f,
    input logic [31:0] pc_plus_4_f,

    output logic [31:0] pc_current_d,
    output logic [31:0] instruction_d,
    output logic [31:0] pc_plus_4_d
);

always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        pc_current_d   <= 32'b0;
        instruction_d  <= 32'b0;
        pc_plus_4_d    <= 32'b0;
    end else if (flush) begin
        pc_current_d   <= 32'b0;
        instruction_d  <= 32'h00000013; 
        pc_plus_4_d    <= 32'b0;
    end else if (!stall) begin
        pc_current_d   <= pc_current_f;
        instruction_d  <= instruction_f;
        pc_plus_4_d    <= pc_plus_4_f;
    end
end
endmodule