`include "../includes/riscv_defines.svh"

module ex_mem_reg #(
    parameter RESULT_SRC_W = 2
)(
    input  logic                    clk,
    input  logic                    reset,

    input  logic                    reg_write_e,
    input  logic [RESULT_SRC_W-1:0] result_src_e,
    input  logic                    mem_write_e,
    input  logic                    mem_read_e,
    input  logic [2:0]              funct3_e,
    input  logic [31:0]             alu_result_e,
    input  logic [31:0]             write_data_e,
    input  logic [31:0]             pc_plus4_e,
    input  logic [4:0]              rd_e,

    output logic                    reg_write_m,
    output logic [RESULT_SRC_W-1:0] result_src_m,
    output logic                    mem_write_m,
    output logic                    mem_read_m,
    output logic [2:0]              funct3_m,
    output logic [31:0]             alu_result_m,
    output logic [31:0]             write_data_m,
    output logic [31:0]             pc_plus4_m,
    output logic [4:0]              rd_m
);
    // control: cleared by reset
    always_ff @(posedge clk) begin
        if (reset) begin
            reg_write_m  <= 1'b0;
            mem_write_m  <= 1'b0;
            mem_read_m   <= 1'b0;
            result_src_m <= '0;
        end else begin
            reg_write_m  <= reg_write_e;
            mem_write_m  <= mem_write_e;
            mem_read_m   <= mem_read_e;
            result_src_m <= result_src_e;
        end
    end

    // data path: no reset, don't care until control says valid
    always_ff @(posedge clk) begin
        funct3_m     <= funct3_e;
        alu_result_m <= alu_result_e;
        write_data_m <= write_data_e;
        pc_plus4_m   <= pc_plus4_e;
        rd_m         <= rd_e;
    end
endmodule