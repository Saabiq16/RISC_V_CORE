module mux_write_data_src (
    input  logic [31:0] alu_result,
    input  logic [31:0] memory_read_data,
    input  logic [31:0] pc_plus_4,
    input  logic [1:0]  result_src,
    output logic [31:0] write_back_data
);

assign write_back_data =
       (result_src == 2'b00) ? alu_result :
       (result_src == 2'b01) ? memory_read_data :
       (result_src == 2'b10) ? pc_plus_4 :
                                32'b0;

endmodule