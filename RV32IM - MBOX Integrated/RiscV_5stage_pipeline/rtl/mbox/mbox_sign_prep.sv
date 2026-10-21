// mbox_sign_prep.sv
// Stage 1 front-end. Conditions rs1/rs2 signedness per funct3 and widens
// each operand by guard bit(s) so downstream Booth recoding never
// misreads an unsigned MSB as a sign bit.
//
// funct3 encoding used throughout MBOX (RV32M mul-group, bit 2 dropped
// since it is always 0 for this group):
//   00 = MUL      rs1 signed,   rs2 signed
//   01 = MULH     rs1 signed,   rs2 signed
//   10 = MULHSU   rs1 signed,   rs2 unsigned
//   11 = MULHU    rs1 unsigned, rs2 unsigned

module mbox_sign_prep #(
  parameter int TAGW = 5
) (
  input  logic [31:0]     rs1,
  input  logic [31:0]     rs2,
  input  logic [1:0]      funct3,
  input  logic            valid_in,
  input  logic [TAGW-1:0] rd_tag,

  output logic [32:0]     rs1_ext,   // multiplicand, 1 guard bit
  output logic [33:0]     rs2_ext,   // multiplier, 2 guard bits (even width for Booth windowing)
  output logic [1:0]      funct3_o,
  output logic            valid_o,
  output logic [TAGW-1:0] rd_tag_o
);

  logic rs1_signed, rs2_signed;

  assign rs1_signed = ~(funct3[1] & funct3[0]);  // unsigned only for MULHU
  assign rs2_signed = ~funct3[1];                // unsigned for MULHSU and MULHU

  assign rs1_ext = rs1_signed ? {rs1[31], rs1}        : {1'b0, rs1};
  assign rs2_ext = rs2_signed ? {{2{rs2[31]}}, rs2}   : {2'b00, rs2};

  assign funct3_o = funct3;
  assign valid_o  = valid_in;
  assign rd_tag_o = rd_tag;

endmodule
