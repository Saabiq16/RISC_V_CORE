`include "../includes/riscv_defines.svh"

module branch_control (
    input  logic [2:0] funct3,
    input  logic       zero,
    input  logic       negative,
    input  logic       overflow,
    input  logic       carry,

    output logic       branch_taken
);

always_comb begin
    unique case (funct3)
        `BR_BEQ:  branch_taken = zero;                     // Branch if equal
        `BR_BNE:  branch_taken = ~zero;                    // Branch if not equal
        `BR_BLT:  branch_taken = negative ^ overflow;      // Branch if less than (signed)
        `BR_BGE:  branch_taken = ~(negative ^ overflow);   // Branch if greater than or equal (signed)
        `BR_BLTU: branch_taken = ~carry;                   // Branch if less than (unsigned)
        `BR_BGEU: branch_taken = carry;                    // Branch if greater than or equal (unsigned)

        default:  branch_taken = 1'b0;                     // Unsupported funct3

    endcase
end

endmodule