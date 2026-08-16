`include "../includes/riscv_defines.svh"

module datapath_r_type (
    input  logic         clk,
    input  logic  [31:0] instruction,
    input  logic  [31:0] pc_current,

    output logic  [31:0] alu_result,
    output logic         zero
);

    logic [6:0] opcode;
    logic [4:0] rd;
    logic [2:0] funct3;
    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [6:0] funct7;

    logic [31:0] rs1_data, rs2_data;
    logic        reg_write_enable;

    logic        alu_src_b, alu_src_a;
    logic        mem_write_enable, mem_read_enable;
    logic [2:0]  alu_op;
    logic [1:0]  result_src;
    logic        branch, jump, base_select;

    logic [31:0] imm_ext;

    logic [3:0]  alu_control_signal;

    logic [31:0] mux_alu_a_out, mux_alu_b_out;

    instruction_decoder decoder (
        .instruction (instruction),
        .opcode      (opcode),
        .rd          (rd),
        .funct3      (funct3),
        .rs1         (rs1),
        .rs2         (rs2),
        .funct7      (funct7)
    );

    register_file reg_file (
        .clk          (clk),
        .write_enable (reg_write_enable),
        .read_addr1   (rs1),
        .read_addr2   (rs2),
        .write_addr   (rd),
        .write_data   (alu_result),
        .read_data1   (rs1_data),
        .read_data2   (rs2_data)
    );

    control_unit ctrl_unit (
        .opcode           (opcode),
        .reg_write_enable (reg_write_enable),
        .alu_src_a        (alu_src_a),
        .alu_src_b        (alu_src_b),
        .mem_write_enable (mem_write_enable),
        .mem_read_enable  (mem_read_enable),
        .alu_op           (alu_op),
        .result_src       (result_src),
        .branch           (branch),
        .jump             (jump),
        .base_select      (base_select)
    );

    immgen imm_gen (
        .instruction (instruction),
        .imm_ext     (imm_ext)
    );

    alu_control alu_ctrl (
        .alu_op             (alu_op),
        .funct3             (funct3),
        .funct7_5           (funct7[5]),
        .alu_control_signal (alu_control_signal)
    );

    mux_alu_src_a mux_a (
        .alu_src_sel_a (alu_src_a),
        .rs1_data      (rs1_data),
        .pc_current    (pc_current),
        .alu_in_a      (mux_alu_a_out)
    );

    mux_alu_src_b mux_b (
        .rs2_data      (rs2_data),
        .imm_data      (imm_ext),
        .alu_src_sel_b (alu_src_b),
        .alu_in_b      (mux_alu_b_out)
    );

    alu u_alu (
        .a        (mux_alu_a_out),
        .b        (mux_alu_b_out),
        .alu_op   (alu_control_signal),
        .result   (alu_result),
        .zero     (zero),
        .carry    (),
        .negative (),
        .overflow ()
    );

endmodule