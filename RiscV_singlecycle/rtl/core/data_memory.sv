`include "../includes/riscv_defines.svh"

module data_memory (
    input logic clk,
    input logic [31:0] address,
    input logic [31:0] write_data,
    input logic dm_write_enable,
    input logic dm_read_enable,
    input logic [2:0] funct3,

    output logic [31:0] read_data
);

logic [7:0] memory [0:1023];

//--------------------------------------------------
// Synchronous Write Logic
//--------------------------------------------------
always_ff @(posedge clk) begin
    if (dm_write_enable) begin
        unique case (funct3)

            `FUNCT3_SB: begin
                if (address < 1024)
                    memory[address] <= write_data[7:0];
            end

            `FUNCT3_SH: begin
                if (address <= 1022) begin
                    memory[address]     <= write_data[7:0];
                    memory[address + 1] <= write_data[15:8];
                end
            end

            `FUNCT3_SW: begin
                if (address <= 1020) begin
                    memory[address]     <= write_data[7:0];
                    memory[address + 1] <= write_data[15:8];
                    memory[address + 2] <= write_data[23:16];
                    memory[address + 3] <= write_data[31:24];
                end
            end

            default: ; // Unsupported store
        endcase
    end
end

//--------------------------------------------------
// Asynchronous Read Logic
//--------------------------------------------------
always_comb begin
    read_data = 32'b0;

    if (dm_read_enable) begin
        unique case (funct3)

            `FUNCT3_LB: begin
                if (address < 1024)
                    read_data = {{24{memory[address][7]}}, memory[address]};
            end

            `FUNCT3_LH: begin
                if (address <= 1022)
                    read_data = {{16{memory[address + 1][7]}},
                                  memory[address + 1],
                                  memory[address]};
            end

            `FUNCT3_LW: begin
                if (address <= 1020)
                    read_data = {memory[address + 3],
                                 memory[address + 2],
                                 memory[address + 1],
                                 memory[address]};
            end

            `FUNCT3_LBU: begin
                if (address < 1024)
                    read_data = {24'b0, memory[address]};
            end

            `FUNCT3_LHU: begin
                if (address <= 1022)
                    read_data = {16'b0,
                                 memory[address + 1],
                                 memory[address]};
            end

            default: read_data = 32'b0;
        endcase
    end
end

endmodule