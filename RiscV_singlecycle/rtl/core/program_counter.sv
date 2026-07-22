module program_counter(
    input logic clk,
    input logic reset,
    input logic [31:0] pc_next,
    output logic [31:0] pc_out
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_out <= 32'b0;
        end
        else begin
            pc_out <= pc_next;
        end
    end
endmodule