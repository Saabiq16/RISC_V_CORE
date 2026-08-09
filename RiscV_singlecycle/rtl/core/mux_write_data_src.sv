module mux_write_data_src (
    input  logic [31:0] alu_result,
    input  logic [31:0] memory_read_data,
    input  logic [31:0] pc_plus_4,
    input  logic [1:0]  mem_to_reg,
    output logic [31:0] write_back_data
);

assign write_back_data =
       (mem_to_reg == 2'b00) ? alu_result :
       (mem_to_reg == 2'b01) ? memory_read_data :
       (mem_to_reg == 2'b10) ? pc_plus_4 :
                                32'b0;

endmodule