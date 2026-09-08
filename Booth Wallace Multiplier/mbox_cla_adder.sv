// mbox_cla_adder.sv
// Stage 4 final adder. Built from 4-bit carry-lookahead blocks
// (mbox_cla4) chained together -- each block computes its own carry-out
// via lookahead internally, with carry propagating block-to-block.
//
// NOTE: this is a block-level CLA, not a full two-level hierarchical
// lookahead (i.e. there's no lookahead *across* the 17 blocks needed for
// WIDTH=68, only within each 4-bit block). That's a reasonable
// first cut -- if STA shows the block-to-block carry chain is the
// bottleneck, the next step is adding a second lookahead level across
// groups of blocks (the standard 2-level CLA hierarchy), not switching
// families entirely.

module mbox_cla4 (
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       cin,
  output logic [3:0] sum,
  output logic       cout
);
  logic [3:0] p, g;
  logic [4:0] c;

  assign p = a ^ b;
  assign g = a & b;
  assign c[0] = cin;

  assign c[1] = g[0] | (p[0] & c[0]);
  assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
  assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & c[0]);
  assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1])
              | (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);

  assign sum  = p ^ c[3:0];
  assign cout = c[4];
endmodule

module mbox_cla_adder #(
  parameter int WIDTH = 68     // must be a multiple of 4
) (
  input  logic [WIDTH-1:0] a,
  input  logic [WIDTH-1:0] b,
  output logic [WIDTH-1:0] sum,
  output logic             cout
);
  localparam int NBLK = WIDTH / 4;

  logic [NBLK:0] carry;
  assign carry[0] = 1'b0;

  genvar k;
  generate
    for (k = 0; k < NBLK; k = k + 1) begin : blk
      mbox_cla4 u_cla4 (
        .a    (a[4*k +: 4]),
        .b    (b[4*k +: 4]),
        .cin  (carry[k]),
        .sum  (sum[4*k +: 4]),
        .cout (carry[k+1])
      );
    end
  endgenerate

  assign cout = carry[NBLK];
endmodule
