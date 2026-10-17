module program_counter(
    input logic clk,
    input logic reset,
    input logic enable,
    input logic [31:0] pc_next,
    output logic [31:0] pc_current
);

    always_ff @(posedge clk) begin
        if (reset) begin
            pc_current <= 32'b0;
        end
        else if (enable) begin
            pc_current <= pc_next;
        end
    end
endmodule