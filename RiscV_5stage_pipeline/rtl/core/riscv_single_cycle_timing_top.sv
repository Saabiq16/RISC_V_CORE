module riscv_single_cycle_timing_top (
    input  logic clk,
    input  logic reset,

    // External instruction memory data
    input  logic [31:0] imem_rdata,

    // External data memory read data
    input  logic [31:0] dmem_rdata,

    // Instruction memory address
    output logic [31:0] imem_addr,

    // Data memory interface
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_write_enable,
    output logic        dmem_read_enable,
    output logic [2:0]  dmem_funct3,

    // Debug outputs
    output logic [31:0] debug_pc,
    output logic [31:0] debug_writeback_data
);

    riscv_single_cycle_timing dut (
        .clk                  (clk),
        .reset                (reset),

        .imem_addr            (imem_addr),
        .imem_rdata           (imem_rdata),

        .dmem_addr            (dmem_addr),
        .dmem_wdata           (dmem_wdata),
        .dmem_write_enable    (dmem_write_enable),
        .dmem_read_enable     (dmem_read_enable),
        .dmem_funct3          (dmem_funct3),
        .dmem_rdata           (dmem_rdata),

        .debug_pc             (debug_pc),
        .debug_writeback_data (debug_writeback_data)
    );

endmodule