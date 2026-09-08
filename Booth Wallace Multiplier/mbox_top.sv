// mbox_top.sv
// Top-level MBOX: 4 internally-pipelined stages, 3 pipeline register
// boundaries. funct3/valid/rd_tag ride every register alongside the
// data path so a MUL sitting anywhere inside MBOX can still be seen by
// an external hazard detection unit as a pending register write.
//
//   Stage 1 (comb): sign-prep -> booth encode -> pp gen
//   --- reg ---
//   Stage 2 (comb): Wallace reduction, level A (17->12->8->6)
//   --- reg ---
//   Stage 3 (comb): Wallace reduction, level B (6->4->3->2)
//   --- reg ---
//   Stage 4 (comb): CLA final add -> output select mux -> drives WB
//                    arbitration mux (external to MBOX, not registered
//                    here -- result/valid/rd_tag_out are combinational
//                    outputs of Stage 4)

module mbox_top #(
  parameter int NDIG = 17,
  parameter int PPW  = 68,
  parameter int TAGW = 5
) (
  input  logic              clk,
  input  logic              rst_n,

  // Stage 0 / EX-entry inputs
  input  logic [31:0]       rs1,
  input  logic [31:0]       rs2,
  input  logic [1:0]        funct3,
  input  logic              valid_in,
  input  logic [TAGW-1:0]   rd_tag_in,

  // Stage 4 outputs -> WB arbitration mux
  output logic [31:0]       result,
  output logic              valid_out,
  output logic [TAGW-1:0]   rd_tag_out
);

  // ---------------- Stage 1 (combinational) ----------------
  logic [32:0]      rs1_ext;
  logic [33:0]      rs2_ext;
  logic [1:0]        s1_funct3;
  logic               s1_valid;
  logic [TAGW-1:0]   s1_rd_tag;

  mbox_sign_prep #(.TAGW(TAGW)) u_signprep (
    .rs1      (rs1),
    .rs2      (rs2),
    .funct3   (funct3),
    .valid_in (valid_in),
    .rd_tag   (rd_tag_in),
    .rs1_ext  (rs1_ext),
    .rs2_ext  (rs2_ext),
    .funct3_o (s1_funct3),
    .valid_o  (s1_valid),
    .rd_tag_o (s1_rd_tag)
  );

  logic [NDIG-1:0] neg, sel_one, sel_two;
  mbox_booth_encoder #(.NDIG(NDIG)) u_booth (
    .rs2_ext (rs2_ext),
    .neg     (neg),
    .sel_one (sel_one),
    .sel_two (sel_two)
  );

  logic [NDIG*PPW-1:0] pp_flat;
  mbox_pp_gen #(.NDIG(NDIG), .PPWIDTH(PPW)) u_ppgen (
    .rs1_ext (rs1_ext),
    .neg     (neg),
    .sel_one (sel_one),
    .sel_two (sel_two),
    .pp_flat (pp_flat)
  );

  // ---------------- Pipe reg: Stage1 -> Stage2 ----------------
  logic [NDIG*PPW-1:0] r12_pp;
  logic [1:0]          r12_funct3;
  logic                r12_valid;
  logic [TAGW-1:0]     r12_rd_tag;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r12_valid <= 1'b0;
    end else begin
      r12_pp     <= pp_flat;
      r12_funct3 <= s1_funct3;
      r12_valid  <= s1_valid;
      r12_rd_tag <= s1_rd_tag;
    end
  end

  // ---------------- Stage 2 (combinational) ----------------
  logic [6*PPW-1:0] s2_rows_flat;
  mbox_stage2_reduce #(.NDIG(NDIG), .WIDTH(PPW)) u_stage2 (
    .pp_in_flat    (r12_pp),
    .rows_out_flat (s2_rows_flat)
  );

  // ---------------- Pipe reg: Stage2 -> Stage3 ----------------
  logic [6*PPW-1:0] r23_rows;
  logic [1:0]       r23_funct3;
  logic             r23_valid;
  logic [TAGW-1:0]  r23_rd_tag;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r23_valid <= 1'b0;
    end else begin
      r23_rows   <= s2_rows_flat;
      r23_funct3 <= r12_funct3;
      r23_valid  <= r12_valid;
      r23_rd_tag <= r12_rd_tag;
    end
  end

  // ---------------- Stage 3 (combinational) ----------------
  logic [PPW-1:0] s3_sum, s3_carry;
  mbox_stage3_reduce #(.WIDTH(PPW)) u_stage3 (
    .rows_in_flat (r23_rows),
    .sum_row      (s3_sum),
    .carry_row    (s3_carry)
  );

  // ---------------- Pipe reg: Stage3 -> Stage4 ----------------
  logic [PPW-1:0]  r34_sum, r34_carry;
  logic [1:0]      r34_funct3;
  logic            r34_valid;
  logic [TAGW-1:0] r34_rd_tag;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r34_valid <= 1'b0;
    end else begin
      r34_sum    <= s3_sum;
      r34_carry  <= s3_carry;
      r34_funct3 <= r23_funct3;
      r34_valid  <= r23_valid;
      r34_rd_tag <= r23_rd_tag;
    end
  end

  // ---------------- Stage 4 (combinational) ----------------
  logic [PPW-1:0] s4_sum_full;
  logic           s4_cout;
  mbox_cla_adder #(.WIDTH(PPW)) u_cla (
    .a    (r34_sum),
    .b    (r34_carry),
    .sum  (s4_sum_full),
    .cout (s4_cout)
  );

  logic [31:0] s4_result;
  mbox_output_mux u_outmux (
    .product (s4_sum_full[63:0]),
    .funct3  (r34_funct3),
    .result  (s4_result)
  );

  // Stage 4 drives the WB-facing outputs combinationally -- the WB
  // arbitration mux/register lives outside MBOX.
  assign result     = s4_result;
  assign valid_out   = r34_valid;
  assign rd_tag_out  = r34_rd_tag;

endmodule
