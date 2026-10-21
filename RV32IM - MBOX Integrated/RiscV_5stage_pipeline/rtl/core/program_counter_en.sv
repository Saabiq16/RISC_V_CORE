// PC with an enable, used by the pipeline only. The single-cycle core keeps
// the original program_counter (no enable), so Phase 1 stays untouched.
// enable = 0 holds the PC (load-use stall). Reset has priority over enable.
module program_counter_en (
    input  logic        clk,
    input  logic        reset,
    input  logic        enable,
    input  logic [31:0] pc_next,
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