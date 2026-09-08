// mbox_stage2_reduce.sv
// Stage 2 combinational logic: first block of Wallace CSA levels.
// 17 -> 12 -> 8 -> 6 rows. This 3-level split (vs. Stage 3's remaining
// 3 levels) is the placeholder even split -- confirm against real STA
// numbers once Stage 4's adder is synthesized; Stage 4 may end up the
// deeper stage regardless of how this split lands.

module mbox_stage2_reduce #(
  parameter int NDIG  = 17,
  parameter int WIDTH = 68
) (
  input  logic [NDIG*WIDTH-1:0] pp_in_flat,
  output logic [6*WIDTH-1:0]    rows_out_flat   // 6 rows after 3 levels
);

  // All-flat wiring between chained levels -- no unpack/pack needed here
  // since mbox_wallace_level's ports are themselves flat vectors.
  logic [12*WIDTH-1:0] level1_out; // 17 -> 12
  logic [8*WIDTH-1:0]  level2_out; // 12 -> 8

  mbox_wallace_level #(.NIN(17), .WIDTH(WIDTH)) u_lvl1 (
    .rows_in_flat  (pp_in_flat),
    .rows_out_flat (level1_out)
  );

  mbox_wallace_level #(.NIN(12), .WIDTH(WIDTH)) u_lvl2 (
    .rows_in_flat  (level1_out),
    .rows_out_flat (level2_out)
  );

  mbox_wallace_level #(.NIN(8), .WIDTH(WIDTH)) u_lvl3 (
    .rows_in_flat  (level2_out),
    .rows_out_flat (rows_out_flat)      // 8 -> 6
  );

endmodule
