// mbox_booth_encoder.sv
// Stage 1. Radix-4 Booth recoding of rs2_ext[33:0] into NDIG=17 digits.
// Digit i examines the 3-bit window (rs2_ext[2i+1], rs2_ext[2i], rs2_ext[2i-1]),
// with an implicit 0 below bit 0 for digit 0. Only rs2 (the multiplier) is
// recoded here -- rs1 (the multiplicand) never passes through this module.
//
// Standard radix-4 Booth table:
//   000, 111 -> 0
//   001, 010 -> +1
//   011      -> +2
//   100      -> -2
//   101, 110 -> -1

module mbox_booth_encoder #(
  parameter int NDIG = 17
) (
  input  logic [2*NDIG-1:0] rs2_ext,     // 34 bits for NDIG=17
  output logic [NDIG-1:0]   neg,
  output logic [NDIG-1:0]   sel_one,
  output logic [NDIG-1:0]   sel_two
);

  genvar i;
  generate
    for (i = 0; i < NDIG; i = i + 1) begin : gen_digit
      logic b_hi, b_mid, b_lo;

      assign b_hi  = rs2_ext[2*i+1];
      assign b_mid = rs2_ext[2*i];
      assign b_lo  = (i == 0) ? 1'b0 : rs2_ext[2*i-1];

      always_comb begin
        case ({b_hi, b_mid, b_lo})
          3'b000, 3'b111: begin neg[i] = 1'b0; sel_one[i] = 1'b0; sel_two[i] = 1'b0; end // 0
          3'b001, 3'b010: begin neg[i] = 1'b0; sel_one[i] = 1'b1; sel_two[i] = 1'b0; end // +1
          3'b011:         begin neg[i] = 1'b0; sel_one[i] = 1'b0; sel_two[i] = 1'b1; end // +2
          3'b100:         begin neg[i] = 1'b1; sel_one[i] = 1'b0; sel_two[i] = 1'b1; end // -2
          3'b101, 3'b110: begin neg[i] = 1'b1; sel_one[i] = 1'b1; sel_two[i] = 1'b0; end // -1
          default:        begin neg[i] = 1'b0; sel_one[i] = 1'b0; sel_two[i] = 1'b0; end
        endcase
      end
    end
  endgenerate

endmodule
