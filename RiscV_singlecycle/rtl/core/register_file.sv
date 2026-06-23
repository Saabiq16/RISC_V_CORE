module register_file (
    input logic clk,
    input logic write_enable,
    input logic [4:0] read_addr1,
    input logic [4:0] read_addr2,
    input logic [4:0] write_addr,
    input logic [31:0] write_data,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2
);
    logic [31:0] registers [31:0];

    // Read Logic

    always_comb begin
        if (read_addr1 == 5'd0) begin
            read_data1 = 32'b0; // Register x0 is always zero
        end
        else begin
            read_data1 = registers[read_addr1];
        end

        if (read_addr2 == 5'd0) begin
            read_data2 = 32'b0; // Register x0 is always zero
        end
        else begin
            read_data2 = registers[read_addr2];
        end
    end

    // Write Logic

    always_ff @(posedge clk) begin
        if (write_enable && write_addr != 5'd0) begin
            registers[write_addr] <= write_data; // Write
        end
    end
endmodule