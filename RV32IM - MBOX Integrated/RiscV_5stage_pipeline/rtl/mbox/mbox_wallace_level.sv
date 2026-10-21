// mbox_wallace_level.sv
// One greedy Wallace-tree CSA reduction level: takes NIN same-width rows
// (already bit-aligned -- shifts are baked in from pp_gen) and produces
// NOUT = (NIN/3)*2 + (NIN%3) rows. Full groups of 3 rows compress to a
// sum row + carry row via per-bit-column full adders; any 1-2 leftover
// rows pass through unchanged to the next level.
//
// This is the building block mbox_stage2_reduce / mbox_stage3_reduce
// chain to implement the full 17->12->8->6->4->3->2 reduction.

module mbox_wallace_level #(
  parameter int NIN   = 17,
  parameter int WIDTH = 68,
  parameter int FULL  = NIN / 3,
  parameter int REM   = NIN % 3,
  parameter int NOUT  = FULL*2 + REM
) (
  input  logic [NIN*WIDTH-1:0]  rows_in_flat,
  output logic [NOUT*WIDTH-1:0] rows_out_flat
);

  // Unpack at the boundary into local unpacked arrays -- generate-driven
  // continuous assigns work fine for internal (non-port) unpacked
  // arrays, it's only unpacked-array *ports* that Icarus mishandles.
  logic [WIDTH-1:0] rows_in [NIN-1:0];
  logic [WIDTH-1:0] rows_out [NOUT-1:0];

  genvar u;
  generate
    for (u = 0; u < NIN; u = u + 1) begin : unpack_in
      assign rows_in[u] = rows_in_flat[u*WIDTH +: WIDTH];
    end
  endgenerate

  genvar g, b;
  generate
    for (g = 0; g < FULL; g = g + 1) begin : grp
      logic [WIDTH-1:0] s;
      logic [WIDTH-1:0] c;

      assign c[0] = 1'b0;

      for (b = 0; b < WIDTH; b = b + 1) begin : col
        logic cb;

        mbox_fa u_fa (
          .a    (rows_in[3*g][b]),
          .b    (rows_in[3*g+1][b]),
          .cin  (rows_in[3*g+2][b]),
          .sum  (s[b]),
          .cout (cb)
        );

        if (b < WIDTH-1) begin : carry_wire
          assign c[b+1] = cb;
        end
      end

      assign rows_out[2*g]   = s;
      assign rows_out[2*g+1] = c;
    end

    for (g = 0; g < REM; g = g + 1) begin : pass
      assign rows_out[FULL*2 + g] = rows_in[FULL*3 + g];
    end
  endgenerate

  generate
    for (u = 0; u < NOUT; u = u + 1) begin : pack_out
      assign rows_out_flat[u*WIDTH +: WIDTH] = rows_out[u];
    end
  endgenerate

endmodule
