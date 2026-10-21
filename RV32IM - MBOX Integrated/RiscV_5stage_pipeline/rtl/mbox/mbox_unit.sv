// mbox_unit.sv
// Pipeline-facing wrapper around mbox_top.
//
//   * converts the pipeline's active-high reset to MBOX's active-low rst_n
//   * adds ONE result register after Stage 4 (decision D1b), so the 68-bit CLA
//     path ends at a flop instead of running on into write-back arbitration,
//     forwarding and the ALU.
//
// Timing (cycle N = the cycle the MUL is in EX and valid_in = 1):
//   N   : EX, MBOX Stage 1 (combinational)           -> r12 loads at end of N
//   N+1 : MBOX Stage 2   (pend_valid[0] seen here)   -> r23
//   N+2 : MBOX Stage 3   (pend_valid[1] seen here)   -> r34
//   N+3 : MBOX Stage 4 (CLA + output mux)            -> result register
//   N+4 : wb_valid = 1, wb_rd / wb_result drive the write-back arbiter
//         (the register file is written at the end of N+4)
//
// MBOX has no stall input: once valid_in is 1 the MUL always reaches wb_valid
// exactly 4 cycles later. All conflicts are therefore avoided before issue.

module mbox_unit (
    input  logic        clk,
    input  logic        reset,        // active-high, same as the pipeline

    // issue (EX stage)
    input  logic [31:0] rs1,          // forwarded operands
    input  logic [31:0] rs2,
    input  logic [1:0]  funct3,       // instruction funct3[1:0]
    input  logic        valid_in,     // is_mul_e
    input  logic [4:0]  rd_in,        // rd_e

    // result (to write-back arbiter)
    output logic        wb_valid,
    output logic [4:0]  wb_rd,
    output logic [31:0] wb_result,

    // pending MULs seen by the hazard unit
    output logic        s2_valid,     // MUL currently in MBOX Stage 2
    output logic [4:0]  s2_rd,
    output logic        s3_valid,     // MUL currently in MBOX Stage 3
    output logic [4:0]  s3_rd
);

    logic        rst_n;
    assign rst_n = ~reset;

    logic [31:0] s4_result;
    logic        s4_valid;
    logic [4:0]  s4_rd;
    logic [2:0]  pend_valid;
    logic [14:0] pend_rd_flat;

    mbox_top #(.NDIG(17), .PPW(68), .TAGW(5)) u_mbox (
        .clk          (clk),
        .rst_n        (rst_n),
        .rs1          (rs1),
        .rs2          (rs2),
        .funct3       (funct3),
        .valid_in     (valid_in),
        .rd_tag_in    (rd_in),
        .result       (s4_result),
        .valid_out    (s4_valid),
        .rd_tag_out   (s4_rd),
        .pend_valid   (pend_valid),
        .pend_rd_flat (pend_rd_flat)
    );

    assign s2_valid = pend_valid[0];
    assign s2_rd    = pend_rd_flat[4:0];
    assign s3_valid = pend_valid[1];
    assign s3_rd    = pend_rd_flat[9:5];

    // D1b result register. Only the valid bit is reset; data is don't-care
    // until wb_valid = 1 (same convention as the pipeline's stage registers).
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wb_valid <= 1'b0;
        else        wb_valid <= s4_valid;
    end

    always_ff @(posedge clk) begin
        wb_rd     <= s4_rd;
        wb_result <= s4_result;
    end

endmodule
