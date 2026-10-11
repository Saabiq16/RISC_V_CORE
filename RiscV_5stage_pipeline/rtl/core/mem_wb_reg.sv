`include "../includes/riscv_defines.svh"


module mem_wb_reg #(
    parameter RESULT_SRC_W = 2
)(
    input  logic                    clk,
    input  logic                    reset,          // match the other pipeline registers

    input  logic                    reg_write_m,
    input  logic [RESULT_SRC_W-1:0] result_src_m,
    input  logic [31:0]             alu_result_m,
    input  logic [31:0]             read_data_m,
    input  logic [31:0]             pc_plus4_m,
    input  logic [4:0]              rd_m,

    output logic                    reg_write_w,
    output logic [RESULT_SRC_W-1:0] result_src_w,
    output logic [31:0]             alu_result_w,
    output logic [31:0]             read_data_w,
    output logic [31:0]             pc_plus4_w,
    output logic [4:0]              rd_w
);
    // control: cleared by reset
    always_ff @(posedge clk) begin
        if (reset) begin
            reg_write_w  <= 1'b0;
            result_src_w <= '0;
        end else begin
            reg_write_w  <= reg_write_m;
            result_src_w <= result_src_m;
        end
    end

    // data: no reset, don't care until reg_write_w says valid
    always_ff @(posedge clk) begin
        alu_result_w <= alu_result_m;
        read_data_w  <= read_data_m;
        pc_plus4_w   <= pc_plus4_m;
        rd_w         <= rd_m;
    end
endmodule