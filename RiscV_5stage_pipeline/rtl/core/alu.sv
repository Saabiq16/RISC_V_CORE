`include "../includes/riscv_defines.svh"

module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_op,
    output logic [31:0] result,
    output logic        zero,
    output logic        carry,
    output logic        negative,
    output logic        overflow
);

    logic [32:0] ext_result;

    always_comb begin
        // Default outputs
        result     = 32'd0;
        zero       = 1'b0;
        carry      = 1'b0;
        negative   = 1'b0;
        overflow   = 1'b0;
        ext_result = 33'd0;

        unique case (alu_op)
            //==================================================
            // Arithmetic
            //==================================================
            `ALU_ADD: begin
                ext_result = {1'b0, a} + {1'b0, b};
                result     = ext_result[31:0];
                // No flags needed — RV32I never reads overflow/carry
                // off ADD; only SUB (via branches) consumes flags.
            end
            `ALU_SUB: begin
                  ext_result = {1'b0, a} - {1'b0, b};
                  result     = ext_result[31:0];
                  zero       = (ext_result[31:0] == 32'd0);
                  carry      = ~ext_result[32];
                  negative   = ext_result[31];
                  overflow   = (a[31] ^ b[31]) & (a[31] ^ ext_result[31]);
            end

            //==================================================
            // Shifts
            //==================================================
            `ALU_SLL:
                result = a << b[4:0];
            `ALU_SRL:
                result = a >> b[4:0];
            `ALU_SRA:
                result = $signed(a) >>> b[4:0];

            //==================================================
            // Logical
            //==================================================
            `ALU_AND:
                result = a & b;
            `ALU_OR:
                result = a | b;
            `ALU_XOR:
                result = a ^ b;

            //==================================================
            // Comparison
            //==================================================
            `ALU_SLT:
                result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU:
                result = (a < b) ? 32'd1 : 32'd0;

            //==================================================
            // LUI
            //==================================================
            `ALU_LUI:
                result = b;

            default:
                result = 32'd0;
        endcase
    end

endmodule