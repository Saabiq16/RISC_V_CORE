// Hazard control: load-use stall and branch/jump flush.
//
// Load-use: a load in EX has its data only at the end of MEM, so an
// instruction in ID that needs it waits one cycle:
//   stall_f  : hold the PC
//   stall_d  : hold IF/ID (the dependent instruction stays in ID)
//   flush_e  : bubble into ID/EX (the load moves on, nothing enters EX)
// One cycle later the load is in WB and the WB forwarding path delivers it.
//
// Redirect (taken branch, jal, jalr) is known in EX. The two instructions
// behind it (one in ID, one in IF) are on the wrong path and are killed:
//   flush_d  : bubble into IF/ID (kills the instruction fetched in IF)
//   flush_e  : bubble into ID/EX (kills the instruction that was in ID)
// The PC already takes the target through pc_next, so it must not be held.
//
// A load and a redirecting instruction cannot both be in EX, so the two cases
// never happen together in the pipeline. If they ever did, the redirect wins:
// the stall is dropped so the PC can take the target.
//
// rs1_d / rs2_d are the raw instruction fields. For instructions that do not
// read a register (lui, auipc, jal) those bits are immediate bits and can
// cause a harmless extra stall.
module hazard_unit (
    input  logic [4:0] rs1_d, rs2_d,
    input  logic [4:0] rd_e,
    input  logic       mem_read_e,
    input  logic       pc_src_sel_e,   // taken branch or jump in EX
    output logic       stall_f,
    output logic       stall_d,
    output logic       flush_d,
    output logic       flush_e
);
    logic load_use;

    assign load_use = mem_read_e && (rd_e != 5'd0) &&
                      ((rd_e == rs1_d) || (rd_e == rs2_d));

    assign stall_f = load_use && !pc_src_sel_e;
    assign stall_d = load_use && !pc_src_sel_e;
    assign flush_d = pc_src_sel_e;
    assign flush_e = load_use || pc_src_sel_e;
endmodule