// mbox_fa_ha.sv
// Bit-level full adder and half adder primitives used as the compressor
// cells inside mbox_wallace_level. Kept as standalone gate-level modules
// so they map cleanly to standard-cell FA/HA during synthesis.

module mbox_fa (
  input  logic a,
  input  logic b,
  input  logic cin,
  output logic sum,
  output logic cout
);
  assign sum  = a ^ b ^ cin;
  assign cout = (a & b) | (a & cin) | (b & cin);
endmodule

module mbox_ha (
  input  logic a,
  input  logic b,
  output logic sum,
  output logic cout
);
  assign sum  = a ^ b;
  assign cout = a & b;
endmodule
