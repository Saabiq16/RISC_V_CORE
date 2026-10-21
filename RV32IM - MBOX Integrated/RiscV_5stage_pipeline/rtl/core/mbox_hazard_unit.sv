// mbox_hazard_unit.sv
// Extra hazards that exist only because of MBOX. hazard_unit (load-use and
// redirect) is NOT modified; the top ORs this stall into its stall/bubble.
//
// MUL timeline (EX is cycle N, see mbox_unit):   N: EX   N+1: S2   N+2: S3
//   N+3: S4   N+4: result register / write-back
//
// A MUL is "pending" while it is in EX, S2 or S3 (the 3 cycles N, N+1, N+2).
// The instruction in ID is held (PC + IF/ID hold, bubble into ID/EX) when:
//
//  RAW    it reads a register that a pending MUL will write.
//         It may leave ID in the cycle the MUL is in S4: it is then in EX
//         exactly when the MUL is in the result register, and the normal WB->EX
//         forwarding path delivers the value. Nothing is forwarded out of MBOX.
//         Cost: 3 bubbles for a dependent instruction right behind the MUL.
//
//  WAW    its rd equals the rd of a pending MUL. Otherwise it would write
//         before the MUL (ALU result in 2 cycles) and the MUL would later
//         overwrite the newer value with the older one.
//
//  STRUCT the MUL is in S2 and the instruction in ID writes a register through
//         the normal path. It would be in EX when the MUL is in S3, so its WB
//         lands in the same cycle as the MUL's result (N+4) on the single
//         register-file write port. A MUL in ID is exempt (its normal-path
//         write is masked, it uses MBOX). Writes to x0 are exempt (the
//         register file ignores them, and the arbiter gives MBOX priority).
//
// x0 is never a hazard: a pending MUL with rd = x0 writes nothing.
// Same rule as hazard_unit: if a taken branch / jump is in EX the instruction in
// ID is on the wrong path and is flushed, so no stall is requested.
module mbox_hazard_unit (
    // instruction in ID
    input  logic [4:0] rs1_d, rs2_d, rd_d,
    input  logic       uses_rs1_d, uses_rs2_d,
    input  logic       reg_write_d,
    input  logic       is_mul_d,

    // redirect from EX
    input  logic       pc_src_sel_e,

    // pending MULs: EX, MBOX stage 2, MBOX stage 3
    input  logic       mul_e,
    input  logic [4:0] rd_e,
    input  logic       s2_valid,
    input  logic [4:0] s2_rd,
    input  logic       s3_valid,
    input  logic [4:0] s3_rd,

    output logic       stall          // hold PC + IF/ID, bubble ID/EX
);
    logic p0, p1, p2;                 // pending slot valid and rd != x0
    assign p0 = mul_e    && (rd_e  != 5'd0);
    assign p1 = s2_valid && (s2_rd != 5'd0);
    assign p2 = s3_valid && (s3_rd != 5'd0);

    logic raw, waw, structural;

    assign raw = (p0 && ((uses_rs1_d && rs1_d == rd_e ) || (uses_rs2_d && rs2_d == rd_e ))) ||
                 (p1 && ((uses_rs1_d && rs1_d == s2_rd) || (uses_rs2_d && rs2_d == s2_rd))) ||
                 (p2 && ((uses_rs1_d && rs1_d == s3_rd) || (uses_rs2_d && rs2_d == s3_rd)));

    assign waw = reg_write_d && (rd_d != 5'd0) &&
                 ((p0 && rd_d == rd_e) || (p1 && rd_d == s2_rd) || (p2 && rd_d == s3_rd));

    assign structural = s2_valid && reg_write_d && (rd_d != 5'd0) && !is_mul_d;

    assign stall = (raw || waw || structural) && !pc_src_sel_e;
endmodule
