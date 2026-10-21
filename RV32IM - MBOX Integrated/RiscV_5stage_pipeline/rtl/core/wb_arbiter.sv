// wb_arbiter.sv
// The register file has ONE write port. This mux merges the normal write-back
// (mem_wb_reg -> mux_write_data_src) with the MBOX result register.
//
// MBOX has priority. The hazard logic (mbox_hazard_unit, structural rule) never
// lets a normal write that targets a real register reach WB in the same cycle
// as an MBOX write, so `conflict` must stay 0. It exists so a testbench or an
// assertion can prove that; it is not used by the datapath.
//
// Everything downstream of WB (register file write port, WB->ID bypass,
// forwarding_unit rd_w / reg_write_w, WB->EX forward data) must use the OUTPUTS
// of this module, not the raw mem_wb_reg values.
module wb_arbiter (
    // normal path (mem_wb_reg + mux_write_data_src)
    input  logic        reg_write_n,
    input  logic [4:0]  rd_n,
    input  logic [31:0] data_n,

    // MBOX result register
    input  logic        mb_valid,
    input  logic [4:0]  mb_rd,
    input  logic [31:0] mb_data,

    // merged write port
    output logic        reg_write,
    output logic [4:0]  rd,
    output logic [31:0] data,

    output logic        conflict
);
    assign reg_write = mb_valid | reg_write_n;
    assign rd        = mb_valid ? mb_rd   : rd_n;
    assign data      = mb_valid ? mb_data : data_n;

    assign conflict  = mb_valid & reg_write_n & (rd_n != 5'd0);
endmodule
