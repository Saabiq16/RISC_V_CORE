`include "../includes/riscv_defines.svh"

module data_memory #(
    parameter int DEPTH_WORDS = 512          // 512 words = 2 KB
)(
    input  logic        clk,
    input  logic [31:0] address,
    input  logic [31:0] write_data,
    input  logic        dm_write_enable,
    input  logic        dm_read_enable,
    input  logic [2:0]  funct3,
    output logic [31:0] read_data
);

localparam int AW = $clog2(DEPTH_WORDS);

logic [AW-1:0] word_addr;
logic [1:0]    byte_off;
assign word_addr = address[AW+1:2];
assign byte_off  = address[1:0];

(* ram_style = "distributed" *) logic [7:0] mem0 [0:DEPTH_WORDS-1];
(* ram_style = "distributed" *) logic [7:0] mem1 [0:DEPTH_WORDS-1];
(* ram_style = "distributed" *) logic [7:0] mem2 [0:DEPTH_WORDS-1];
(* ram_style = "distributed" *) logic [7:0] mem3 [0:DEPTH_WORDS-1];

// ---------- store: byte enables and aligned data ----------
logic [3:0]  be;
logic [31:0] wdata_al;

always_comb begin
    be       = 4'b0000;
    wdata_al = write_data;
    if (dm_write_enable) begin
        case (funct3)
            `FUNCT3_SB: begin
                be       = 4'b0001 << byte_off;
                wdata_al = {4{write_data[7:0]}};
            end
            `FUNCT3_SH: begin
                be       = byte_off[1] ? 4'b1100 : 4'b0011;
                wdata_al = {2{write_data[15:0]}};
            end
            `FUNCT3_SW: be = 4'b1111;
            default:    be = 4'b0000;
        endcase
    end
end

always_ff @(posedge clk) begin
    if (be[0]) mem0[word_addr] <= wdata_al[7:0];
    if (be[1]) mem1[word_addr] <= wdata_al[15:8];
    if (be[2]) mem2[word_addr] <= wdata_al[23:16];
    if (be[3]) mem3[word_addr] <= wdata_al[31:24];
end

// ---------- load: async word read, then select and extend ----------
logic [31:0] word;
logic [7:0]  b;
logic [15:0] h;

assign word = {mem3[word_addr], mem2[word_addr], mem1[word_addr], mem0[word_addr]};
assign b    = word[8*byte_off +: 8];
assign h    = byte_off[1] ? word[31:16] : word[15:0];

always_comb begin
    read_data = 32'b0;
    if (dm_read_enable) begin
        case (funct3)
            `FUNCT3_LB:  read_data = {{24{b[7]}}, b};
            `FUNCT3_LH:  read_data = {{16{h[15]}}, h};
            `FUNCT3_LW:  read_data = word;
            `FUNCT3_LBU: read_data = {24'b0, b};
            `FUNCT3_LHU: read_data = {16'b0, h};
            default:     read_data = 32'b0;
        endcase
    end
end

endmodule