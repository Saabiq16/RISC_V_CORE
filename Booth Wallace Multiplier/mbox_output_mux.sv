// mbox_output_mux.sv
// Stage 4 output select. Truncates the CLA's full-width sum down to the
// true 64-bit product (the upper guard bits are redundant sign-extension,
// never real magnitude -- see mbox_pp_gen), then picks the 32-bit slice
// per funct3: MUL takes the low half, all three MULH variants take the
// high half.

module mbox_output_mux (
  input  logic [63:0] product,
  input  logic [1:0]  funct3,   // 00=MUL, 01/10/11=MULH/MULHSU/MULHU
  output logic [31:0] result
);
  assign result = (funct3 == 2'b00) ? product[31:0] : product[63:32];
endmodule
