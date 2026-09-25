`include "../includes/riscv_defines.svh"

// Timing-only variant of riscv_single_cycle.
// Identical datapath to the verified functional core, except instruction
// and data memory are external port interfaces instead of instantiated
// behavioral arrays. This allows Vivado/Yosys to synthesize the CPU
// datapath alone, without attempting to infer BRAM/registers for the
// large asynchronous-read memory arrays used in functional simulation.
//
// riscv_single_cycle.sv, instruction_memory.sv, and data_memory.sv
// remain frozen and unmodified.

module riscv_single_cycle_timing (
    input  logic clk,
    input  logic reset,

    // Instruction memory interface (external)
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,

    // Data memory interface (external)
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic        dmem_write_enable,
    output logic        dmem_read_enable,
    output logic [2:0]  dmem_funct3,
    input  logic [31:0] dmem_rdata,

    // Synthesis/debug observability ports only
    output logic [31:0] debug_pc,
    output logic [31:0] debug_writeback_data
);

    logic [31:0] pc_current;
    logic [31:0] pc_next;
    logic [31:0] instruction;
    logic [31:0] pc_plus_4;

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
    logic        branch, jump, base_select, branch_taken;
    logic        carry, negative, overflow;

    logic [31:0] imm_ext;
    logic [3:0]  alu_control_signal;
    logic [31:0] mux_alu_a_out, mux_alu_b_out;
    logic [31:0] alu_result;
    logic        zero;
    logic [31:0] memory_read_data;
    logic [31:0] write_back_data;
    logic [31:0] base_out;
    logic [31:0] branch_target;
    logic        pc_src_sel;

    program_counter pc_inst (
        .clk        (clk),
        .reset      (reset),
        .pc_next    (pc_next),
        .pc_current (pc_current)
    );

    pc_adder4 pc_adder_inst (
        .pc_current (pc_current),
        .pc_plus_4  (pc_plus_4)
    );

    // Instruction memory replaced with external interface
    assign imem_addr   = pc_current;
    assign instruction = imem_rdata;

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
        .clk              (clk),
        .reg_write_enable (reg_write_enable),
        .read_addr1       (rs1),
        .read_addr2       (rs2),
        .write_addr       (rd),
        .write_data       (write_back_data),
        .read_data1       (rs1_data),
        .read_data2       (rs2_data)
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
        .mux_alu_a_out (mux_alu_a_out)
    );

    mux_alu_src_b mux_b (
        .rs2_data      (rs2_data),
        .imm_data      (imm_ext),
        .alu_src_sel_b (alu_src_b),
        .mux_alu_b_out (mux_alu_b_out)
    );

    alu u_alu (
        .a        (mux_alu_a_out),
        .b        (mux_alu_b_out),
        .alu_op   (alu_control_signal),
        .result   (alu_result),
        .zero     (zero),
        .carry    (carry),
        .negative (negative),
        .overflow (overflow)
    );

    // Data memory replaced with external interface
    assign dmem_addr         = alu_result;
    assign dmem_wdata        = rs2_data;
    assign dmem_write_enable = mem_write_enable;
    assign dmem_read_enable  = mem_read_enable;
    assign dmem_funct3       = funct3;
    assign memory_read_data  = dmem_rdata;

    mux_write_data_src write_back_mux (
        .alu_result       (alu_result),
        .memory_read_data (memory_read_data),
        .pc_plus_4        (pc_plus_4),
        .result_src       (result_src),
        .write_back_data  (write_back_data)
    );

    mux_base_select_pc_branch base_mux (
        .pc_current (pc_current),
        .rs1        (rs1_data),
        .base_sel   (base_select),
        .base_out   (base_out)
    );

    pc_branch_adder branch_adder (
        .base          (base_out),
        .immediate     (imm_ext),
        .branch_target (branch_target)
    );

    branch_control u_branch_control (
        .funct3       (funct3),
        .zero         (zero),
        .carry        (carry),
        .negative     (negative),
        .overflow     (overflow),
        .branch_taken (branch_taken)
    );

    assign pc_src_sel = jump | (branch & branch_taken);

    mux_pc_src u_pc_src_mux (
        .pc_plus_4  (pc_plus_4),
        .pc_branch  (branch_target),
        .pc_src_sel (pc_src_sel),
        .pc_next    (pc_next)
    );

    assign debug_pc             = pc_current;
    assign debug_writeback_data = write_back_data;

endmodule