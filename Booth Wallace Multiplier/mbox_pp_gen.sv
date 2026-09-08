// mbox_pp_gen.sv
// Stage 1. Builds NDIG=17 partial products from rs1_ext (multiplicand)
// and the Booth digit selects. rs1_ext never touches the Booth encoder --
// it is sign-extended once to full working width here and then scaled
// (0, x1, x2, negated) and shifted per digit.
//
// NOTE ON WIDTH STRATEGY: this implementation fully sign-extends every
// partial product to PPWIDTH bits rather than using the compact
// "single correction bit per row" trick. That trick is the area-optimal
// approach (and the one worth moving to once this is verified), but it
// is easy to get subtly wrong. Fully sign-extending every row is
// functionally correct and easy to reason about/debug against a
// reference model first -- treat this as the correctness-first version,
// not the final area-optimized one. PPWIDTH=68 gives enough margin that
// truncating the final adder's output to the true 64-bit product
// (mbox_output_mux) discards only redundant, consistent sign-extension
// bits -- never real magnitude, since a 32x32 product always fits in 64 bits.

module mbox_pp_gen #(
  parameter int NDIG    = 17,
  parameter int PPWIDTH = 68
) (
  input  logic [32:0]             rs1_ext,
  input  logic [NDIG-1:0]         neg,
  input  logic [NDIG-1:0]         sel_one,
  input  logic [NDIG-1:0]         sel_two,
  output logic [NDIG*PPWIDTH-1:0] pp_flat   // NDIG rows of PPWIDTH bits, packed
);

  logic [PPWIDTH-1:0] rs1_full;
  assign rs1_full = {{(PPWIDTH-33){rs1_ext[32]}}, rs1_ext};

  genvar i;
  generate
    for (i = 0; i < NDIG; i = i + 1) begin : gen_pp
      logic [PPWIDTH-1:0] mag, val, shifted;

      assign mag = sel_two[i] ? (rs1_full << 1) :
                   sel_one[i] ? rs1_full         :
                               {PPWIDTH{1'b0}};

      // two's complement negate, written explicitly rather than relying
      // on signed unary minus
      assign val = neg[i] ? (~mag + 1'b1) : mag;

      assign shifted = val << (2*i);

      // NOTE: pp is packed into pp_flat rather than left as an unpacked
      // array output port. Icarus Verilog (and some other tools) does
      // not correctly drive an unpacked-array *port* from inside a
      // generate loop -- it elaborates without error but silently
      // yields X. Packing into a flat vector at the port boundary
      // sidesteps that; unpack with pp_flat[i*PPWIDTH +: PPWIDTH] on
      // the receiving side.
      assign pp_flat[i*PPWIDTH +: PPWIDTH] = shifted;
    end
  endgenerate

endmodule
