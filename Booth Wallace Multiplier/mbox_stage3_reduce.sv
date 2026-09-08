// mbox_stage3_reduce.sv
// Stage 3 combinational logic: remaining Wallace CSA levels.
// 6 -> 4 -> 3 -> 2 rows, producing the final sum/carry pair that
// Stage 4's CLA adder consumes.

module mbox_stage3_reduce #(
  parameter int WIDTH = 68
) (
  input  logic [6*WIDTH-1:0] rows_in_flat,   // 6 rows in
  output logic [WIDTH-1:0]   sum_row,
  output logic [WIDTH-1:0]   carry_row
);

  logic [4*WIDTH-1:0] level4_out; // 6 -> 4
  logic [3*WIDTH-1:0] level5_out; // 4 -> 3
  logic [2*WIDTH-1:0] level6_out; // 3 -> 2

  mbox_wallace_level #(.NIN(6), .WIDTH(WIDTH)) u_lvl4 (
    .rows_in_flat  (rows_in_flat),
    .rows_out_flat (level4_out)
  );

  mbox_wallace_level #(.NIN(4), .WIDTH(WIDTH)) u_lvl5 (
    .rows_in_flat  (level4_out),
    .rows_out_flat (level5_out)
  );

  mbox_wallace_level #(.NIN(3), .WIDTH(WIDTH)) u_lvl6 (
    .rows_in_flat  (level5_out),
    .rows_out_flat (level6_out)
  );

  // level6_out packs 2 final rows: [WIDTH-1:0]=row0 (sum), [2*WIDTH-1:WIDTH]=row1 (carry)
  assign sum_row   = level6_out[WIDTH-1:0];
  assign carry_row = level6_out[2*WIDTH-1:WIDTH];

endmodule
