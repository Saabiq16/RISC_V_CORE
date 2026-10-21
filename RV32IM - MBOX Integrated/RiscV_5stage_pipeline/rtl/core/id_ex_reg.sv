`include "../includes/riscv_defines.svh"


module id_ex_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        flush,        // squash to bubble (load-use stall inserts this)

    // control signals from control_unit (decode stage)
    input  logic        reg_write_enable_d,
    input  logic        alu_src_a_d, alu_src_b_d,
    input  logic        mem_write_enable_d, mem_read_enable_d,
    input  logic [2:0]  alu_op_d,
    input  logic [1:0]  result_src_d,
    input  logic        branch_d, jump_d, base_select_d,
    input  logic        is_mul_d,     // RV32M multiply: handled by MBOX in EX

    // data operands
    input  logic [31:0] pc_current_d, pc_plus_4_d,
    input  logic [31:0] rs1_data_d, rs2_data_d,
    input  logic [31:0] imm_ext_d,
    input  logic [4:0]  rs1_d, rs2_d, rd_d,
    input  logic [2:0]  funct3_d,
    input  logic        funct7_5_d,

    // ---- EX stage side ----
    output logic        reg_write_enable_e,
    output logic        alu_src_a_e, alu_src_b_e,
    output logic        mem_write_enable_e, mem_read_enable_e,
    output logic [2:0]  alu_op_e,
    output logic [1:0]  result_src_e,
    output logic        branch_e, jump_e, base_select_e,
    output logic        is_mul_e,

    output logic [31:0] pc_current_e, pc_plus_4_e,
    output logic [31:0] rs1_data_e, rs2_data_e,
    output logic [31:0] imm_ext_e,
    output logic [4:0]  rs1_e, rs2_e, rd_e,
    output logic [2:0]  funct3_e,
    output logic        funct7_5_e
);

    // ------------------------------------------------------------
    // Control signals: async reset, synchronous flush.
    // Zeroing these forces a bubble (no reg write, no mem write,
    // no branch/jump) regardless of what sits in the data fields.
    // rd_e is zeroed too, for the forwarding logic later.
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            reg_write_enable_e <= 1'b0;
            mem_write_enable_e <= 1'b0;
            mem_read_enable_e  <= 1'b0;
            branch_e           <= 1'b0;
            jump_e             <= 1'b0;
            alu_op_e           <= 3'b0;
            result_src_e       <= 2'b0;
            alu_src_a_e        <= 1'b0;
            alu_src_b_e        <= 1'b0;
            base_select_e      <= 1'b0;
            is_mul_e           <= 1'b0;
            rd_e               <= 5'b0;
        end else if (flush) begin
            reg_write_enable_e <= 1'b0;
            mem_write_enable_e <= 1'b0;
            mem_read_enable_e  <= 1'b0;
            branch_e           <= 1'b0;
            jump_e             <= 1'b0;
            alu_op_e           <= 3'b0;
            result_src_e       <= 2'b0;
            alu_src_a_e        <= 1'b0;
            alu_src_b_e        <= 1'b0;
            base_select_e      <= 1'b0;
            is_mul_e           <= 1'b0;
            rd_e               <= 5'b0;
        end else begin
            reg_write_enable_e <= reg_write_enable_d;
            alu_src_a_e        <= alu_src_a_d;
            alu_src_b_e        <= alu_src_b_d;
            mem_write_enable_e <= mem_write_enable_d;
            mem_read_enable_e  <= mem_read_enable_d;
            alu_op_e           <= alu_op_d;
            result_src_e       <= result_src_d;
            branch_e           <= branch_d;
            jump_e             <= jump_d;
            base_select_e      <= base_select_d;
            is_mul_e           <= is_mul_d;
            rd_e               <= rd_d;
        end
    end

    // ------------------------------------------------------------
    // Data fields: no reset, no flush, always pass through.
    // Garbage data with reg_write_enable = 0 and mem_write_enable = 0
    // never touches architectural state.
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        pc_current_e <= pc_current_d;
        pc_plus_4_e  <= pc_plus_4_d;
        rs1_data_e   <= rs1_data_d;
        rs2_data_e   <= rs2_data_d;
        imm_ext_e    <= imm_ext_d;
        rs1_e        <= rs1_d;
        rs2_e        <= rs2_d;
        funct3_e     <= funct3_d;
        funct7_5_e   <= funct7_5_d;
    end

endmodule