`include "../includes/riscv_defines.svh"

// 5-stage RV32I pipeline.
// Forwarding, load-use stall and branch/jump flush are all in, so programs run
// without NOP padding.                                         // <<< CHANGED 1
// Suffixes: _f fetch, _d decode, _e execute, _m memory, _w write-back.
module riscv_pipeline (
    input logic clk,
    input logic reset
);

    // ------------------------------------------------------------
    // Hazard control, all four driven by hazard_unit.          // <<< CHANGED 2
    //   pc_stall, if_id_stall : load-use stall
    //   if_id_flush           : taken branch / jump in EX (kills the IF instruction)
    //   id_ex_flush           : load-use bubble or taken branch / jump (kills the ID instruction)
    // ------------------------------------------------------------
    logic pc_stall, if_id_stall, if_id_flush, id_ex_flush;

    // ------------------------------------------------------------
    // IF
    // ------------------------------------------------------------
    logic [31:0] pc_current_f, pc_next, pc_plus_4_f, instruction_f;

    // ------------------------------------------------------------
    // ID
    // ------------------------------------------------------------
    logic [31:0] pc_current_d, pc_plus_4_d, instruction_d;
    logic [6:0]  opcode_d, funct7_d;
    logic [4:0]  rd_d, rs1_d, rs2_d;
    logic [2:0]  funct3_d;
    logic [31:0] rf_rs1_data_d, rf_rs2_data_d;   // raw regfile outputs
    logic [31:0] rs1_data_d, rs2_data_d;         // after write-through bypass
    logic [31:0] imm_ext_d;
    logic        reg_write_enable_d, alu_src_a_d, alu_src_b_d;
    logic        mem_write_enable_d, mem_read_enable_d;
    logic        branch_d, jump_d, base_select_d;
    logic [2:0]  alu_op_d;
    logic [1:0]  result_src_d;

    // ------------------------------------------------------------
    // EX
    // ------------------------------------------------------------
    logic        reg_write_enable_e, alu_src_a_e, alu_src_b_e;
    logic        mem_write_enable_e, mem_read_enable_e;
    logic        branch_e, jump_e, base_select_e;
    logic [2:0]  alu_op_e, funct3_e;
    logic [1:0]  result_src_e;
    logic        funct7_5_e;
    logic [31:0] pc_current_e, pc_plus_4_e, rs1_data_e, rs2_data_e, imm_ext_e;
    logic [4:0]  rs1_e, rs2_e, rd_e;
    logic [3:0]  alu_control_signal_e;
    logic [31:0] alu_a_e, alu_b_e, alu_result_e;
    logic        zero_e, carry_e, negative_e, overflow_e;
    logic [31:0] base_out_e, branch_target_e;
    logic        branch_taken_e, pc_src_sel_e;

    // forwarding
    logic [1:0]  forward_a_e, forward_b_e;
    logic [31:0] rs1_fwd_e, rs2_fwd_e;
    logic [31:0] fwd_data_m;

    // ------------------------------------------------------------
    // MEM
    // ------------------------------------------------------------
    logic        reg_write_m, mem_write_m, mem_read_m;
    logic [1:0]  result_src_m;
    logic [2:0]  funct3_m;
    logic [31:0] alu_result_m, write_data_m, pc_plus_4_m, read_data_m;
    logic [4:0]  rd_m;

    // ------------------------------------------------------------
    // WB
    // ------------------------------------------------------------
    logic        reg_write_w;
    logic [1:0]  result_src_w;
    logic [31:0] alu_result_w, read_data_w, pc_plus_4_w, write_back_data_w;
    logic [4:0]  rd_w;

    // ============================================================
    // IF stage
    // pc_next comes from EX (branch/jump resolve there); the two wrong-path
    // instructions behind a taken branch are flushed by hazard_unit
    // ============================================================
    program_counter_en pc_inst (                                // <<< CHANGED 4 (unchanged since the stall step)
        .clk         (clk),
        .reset       (reset),
        .enable      (~pc_stall),
        .pc_next     (pc_next),
        .pc_current  (pc_current_f)
    );

    pc_adder4 pc_adder_inst (
        .pc_current (pc_current_f),
        .pc_plus_4  (pc_plus_4_f)
    );

    instruction_memory instruction_memory_inst (
        .address     (pc_current_f),
        .instruction (instruction_f)
    );

    if_id_reg u_if_id_reg (
        .clk           (clk),
        .reset         (reset),
        .stall         (if_id_stall),
        .flush         (if_id_flush),
        .pc_current_f  (pc_current_f),
        .instruction_f (instruction_f),
        .pc_plus_4_f   (pc_plus_4_f),
        .pc_current_d  (pc_current_d),
        .instruction_d (instruction_d),
        .pc_plus_4_d   (pc_plus_4_d)
    );

    // ============================================================
    // ID stage
    // ============================================================
    instruction_decoder decoder (
        .instruction (instruction_d),
        .opcode      (opcode_d),
        .rd          (rd_d),
        .funct3      (funct3_d),
        .rs1         (rs1_d),
        .rs2         (rs2_d),
        .funct7      (funct7_d)
    );

    control_unit ctrl_unit (
        .opcode           (opcode_d),
        .reg_write_enable (reg_write_enable_d),
        .alu_src_a        (alu_src_a_d),
        .alu_src_b        (alu_src_b_d),
        .mem_write_enable (mem_write_enable_d),
        .mem_read_enable  (mem_read_enable_d),
        .alu_op           (alu_op_d),
        .result_src       (result_src_d),
        .branch           (branch_d),
        .jump             (jump_d),
        .base_select      (base_select_d)
    );

    immgen imm_gen (
        .instruction (instruction_d),
        .imm_ext     (imm_ext_d)
    );

    // regfile: written from WB, read in ID
    register_file reg_file (
        .clk              (clk),
        .reg_write_enable (reg_write_w),
        .read_addr1       (rs1_d),
        .read_addr2       (rs2_d),
        .write_addr       (rd_w),
        .write_data       (write_back_data_w),
        .read_data1       (rf_rs1_data_d),
        .read_data2       (rf_rs2_data_d)
    );

    // write-through: an instruction in WB writing rd is visible to the
    // instruction reading it in ID in the same cycle. Never for x0.
    assign rs1_data_d = (reg_write_w & (rd_w != 5'd0) & (rd_w == rs1_d))
                        ? write_back_data_w : rf_rs1_data_d;
    assign rs2_data_d = (reg_write_w & (rd_w != 5'd0) & (rd_w == rs2_d))
                        ? write_back_data_w : rf_rs2_data_d;

    // ------------------------------------------------------------
    // Hazard unit.
    //   load-use: a load in EX whose rd is read by the instruction in ID.
    //             Hold PC and IF/ID one cycle, bubble ID/EX.
    //   redirect: taken branch or jump in EX (pc_src_sel_e). Bubble IF/ID and
    //             ID/EX, the PC already takes the target through pc_next.
    // ------------------------------------------------------------
    hazard_unit hz_unit (                                       // <<< CHANGED 3
        .rs1_d        (rs1_d),
        .rs2_d        (rs2_d),
        .rd_e         (rd_e),
        .mem_read_e   (mem_read_enable_e),
        .pc_src_sel_e (pc_src_sel_e),
        .stall_f      (pc_stall),
        .stall_d      (if_id_stall),
        .flush_d      (if_id_flush),
        .flush_e      (id_ex_flush)
    );

    id_ex_reg u_id_ex_reg (
        .clk                (clk),
        .reset              (reset),
        .flush              (id_ex_flush),

        .reg_write_enable_d (reg_write_enable_d),
        .alu_src_a_d        (alu_src_a_d),
        .alu_src_b_d        (alu_src_b_d),
        .mem_write_enable_d (mem_write_enable_d),
        .mem_read_enable_d  (mem_read_enable_d),
        .alu_op_d           (alu_op_d),
        .result_src_d       (result_src_d),
        .branch_d           (branch_d),
        .jump_d             (jump_d),
        .base_select_d      (base_select_d),

        .pc_current_d       (pc_current_d),
        .pc_plus_4_d        (pc_plus_4_d),
        .rs1_data_d         (rs1_data_d),
        .rs2_data_d         (rs2_data_d),
        .imm_ext_d          (imm_ext_d),
        .rs1_d              (rs1_d),
        .rs2_d              (rs2_d),
        .rd_d               (rd_d),
        .funct3_d           (funct3_d),
        .funct7_5_d         (funct7_d[5]),

        .reg_write_enable_e (reg_write_enable_e),
        .alu_src_a_e        (alu_src_a_e),
        .alu_src_b_e        (alu_src_b_e),
        .mem_write_enable_e (mem_write_enable_e),
        .mem_read_enable_e  (mem_read_enable_e),
        .alu_op_e           (alu_op_e),
        .result_src_e       (result_src_e),
        .branch_e           (branch_e),
        .jump_e             (jump_e),
        .base_select_e      (base_select_e),

        .pc_current_e       (pc_current_e),
        .pc_plus_4_e        (pc_plus_4_e),
        .rs1_data_e         (rs1_data_e),
        .rs2_data_e         (rs2_data_e),
        .imm_ext_e          (imm_ext_e),
        .rs1_e              (rs1_e),
        .rs2_e              (rs2_e),
        .rd_e               (rd_e),
        .funct3_e           (funct3_e),
        .funct7_5_e         (funct7_5_e)
    );

    // ============================================================
    // EX stage
    // ============================================================
    alu_control alu_ctrl (
        .alu_op             (alu_op_e),
        .funct3             (funct3_e),
        .funct7_5           (funct7_5_e),
        .alu_control_signal (alu_control_signal_e)
    );

    // ------------------------------------------------------------
    // Forwarding (EX stage)
    // ------------------------------------------------------------
    forwarding_unit fwd_unit (
        .rs1_e       (rs1_e),
        .rs2_e       (rs2_e),
        .rd_m        (rd_m),
        .rd_w        (rd_w),
        .reg_write_m (reg_write_m),
        .reg_write_w (reg_write_w),
        .forward_a_e (forward_a_e),
        .forward_b_e (forward_b_e)
    );

    // jal/jalr in MEM must forward the link value, not the ALU result.
    // A load in MEM is never forwarded from here: the load-use stall makes
    // the dependent instruction wait until the load is in WB.
    localparam logic [1:0] RESULT_SRC_PC4 = 2'b10;   // CHECK against mux_write_data_src
    assign fwd_data_m = (result_src_m == RESULT_SRC_PC4) ? pc_plus_4_m : alu_result_m;

    assign rs1_fwd_e = (forward_a_e == 2'b10) ? fwd_data_m :
                       (forward_a_e == 2'b01) ? write_back_data_w : rs1_data_e;
    assign rs2_fwd_e = (forward_b_e == 2'b10) ? fwd_data_m :
                       (forward_b_e == 2'b01) ? write_back_data_w : rs2_data_e;

    mux_alu_src_a mux_a (
        .alu_src_sel_a (alu_src_a_e),
        .rs1_data      (rs1_fwd_e),
        .pc_current    (pc_current_e),
        .mux_alu_a_out (alu_a_e)
    );

    mux_alu_src_b mux_b (
        .rs2_data      (rs2_fwd_e),
        .imm_data      (imm_ext_e),
        .alu_src_sel_b (alu_src_b_e),
        .mux_alu_b_out (alu_b_e)
    );

    alu u_alu (
        .a        (alu_a_e),
        .b        (alu_b_e),
        .alu_op   (alu_control_signal_e),
        .result   (alu_result_e),
        .zero     (zero_e),
        .carry    (carry_e),
        .negative (negative_e),
        .overflow (overflow_e)
    );

    mux_base_select_pc_branch base_mux (
        .pc_current (pc_current_e),
        .rs1        (rs1_fwd_e),
        .base_sel   (base_select_e),
        .base_out   (base_out_e)
    );

    pc_branch_adder branch_adder (
        .base          (base_out_e),
        .immediate     (imm_ext_e),
        .branch_target (branch_target_e)
    );

    branch_control u_branch_control (
        .funct3       (funct3_e),
        .zero         (zero_e),
        .carry        (carry_e),
        .negative     (negative_e),
        .overflow     (overflow_e),
        .branch_taken (branch_taken_e)
    );

    assign pc_src_sel_e = jump_e | (branch_e & branch_taken_e);

    mux_pc_src u_pc_src_mux (
        .pc_plus_4  (pc_plus_4_f),
        .pc_branch  (branch_target_e),
        .pc_src_sel (pc_src_sel_e),
        .pc_next    (pc_next)
    );

    ex_mem_reg u_ex_mem_reg (
        .clk          (clk),
        .reset        (reset),
        .reg_write_e  (reg_write_enable_e),
        .result_src_e (result_src_e),
        .mem_write_e  (mem_write_enable_e),
        .mem_read_e   (mem_read_enable_e),
        .funct3_e     (funct3_e),
        .alu_result_e (alu_result_e),
        .write_data_e (rs2_fwd_e),
        .pc_plus4_e   (pc_plus_4_e),
        .rd_e         (rd_e),
        .reg_write_m  (reg_write_m),
        .result_src_m (result_src_m),
        .mem_write_m  (mem_write_m),
        .mem_read_m   (mem_read_m),
        .funct3_m     (funct3_m),
        .alu_result_m (alu_result_m),
        .write_data_m (write_data_m),
        .pc_plus4_m   (pc_plus_4_m),
        .rd_m         (rd_m)
    );

    // ============================================================
    // MEM stage
    // ============================================================
    data_memory data_mem (
        .clk             (clk),
        .address         (alu_result_m),
        .write_data      (write_data_m),
        .dm_write_enable (mem_write_m),
        .dm_read_enable  (mem_read_m),
        .funct3          (funct3_m),
        .read_data       (read_data_m)
    );

    mem_wb_reg u_mem_wb_reg (
        .clk          (clk),
        .reset        (reset),
        .reg_write_m  (reg_write_m),
        .result_src_m (result_src_m),
        .alu_result_m (alu_result_m),
        .read_data_m  (read_data_m),
        .pc_plus4_m   (pc_plus_4_m),
        .rd_m         (rd_m),
        .reg_write_w  (reg_write_w),
        .result_src_w (result_src_w),
        .alu_result_w (alu_result_w),
        .read_data_w  (read_data_w),
        .pc_plus4_w   (pc_plus_4_w),
        .rd_w         (rd_w)
    );

    // ============================================================
    // WB stage
    // ============================================================
    mux_write_data_src write_back_mux (
        .alu_result       (alu_result_w),
        .memory_read_data (read_data_w),
        .pc_plus_4        (pc_plus_4_w),
        .result_src       (result_src_w),
        .write_back_data  (write_back_data_w)
    );

endmodule