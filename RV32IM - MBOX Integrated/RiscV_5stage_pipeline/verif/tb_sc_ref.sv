`timescale 1ns/1ps
// Cross-check: random RV32I-only programs on the ORIGINAL single-cycle core vs the Python ISS.
module tb_sc_ref;
  logic clk = 0, rst = 1;
  riscv_single_cycle dut(.clk(clk), .reset(rst));
  always #5 clk = ~clk;
  int nprog, p, i, fd, code, bad, mism, total_bad;
  string dir, path, tag;
  logic [31:0] a, b;
  initial begin
    if (!$value$plusargs("N=%d", nprog)) nprog = 1;
    if (!$value$plusargs("DIR=%s", dir)) dir = ".";
    total_bad = 0;
    for (p = 0; p < nprog; p++) begin
      for (i = 0; i < 16384; i++) dut.instruction_memory_inst.memory[i] = 32'h13;
      $readmemh($sformatf("%s/prog_%0d.hex", dir, p), dut.instruction_memory_inst.memory);
      rst = 1; repeat (3) @(posedge clk); @(negedge clk);
      // zero data memory only AFTER the reset clocks: the core does not gate writes during
      // reset, so the instruction at the stale PC can store once on the first reset edge.
      for (i = 0; i < 16384; i++) dut.data_mem.memory[i] = 8'h00;
      rst = 0;
      repeat (1500) @(negedge clk);
      mism = 0;
      fd = $fopen($sformatf("%s/exp_%0d.txt", dir, p), "r");
      while (!$feof(fd)) begin
        code = $fscanf(fd, "%s %h %h\n", tag, a, b);
        if (code == 3) begin
          if (tag == "R") begin
            if (dut.reg_file.registers[a[4:0]] !== b) begin mism++; if (mism <= 3) $display("[P%0d] x%0d dut=%h exp=%h", p, a[4:0], dut.reg_file.registers[a[4:0]], b); end
          end else begin
            logic [31:0] w;
            w = {dut.data_mem.memory[a+3], dut.data_mem.memory[a+2], dut.data_mem.memory[a+1], dut.data_mem.memory[a]};
            if (w !== b) begin mism++; if (mism <= 3) $display("[P%0d] mem[%h] dut=%h exp=%h", p, a, w, b); end
          end
        end
      end
      $fclose(fd);
      if (mism) total_bad++;
    end
    $display("SC-vs-ISS: %0d programs, %0d mismatching", nprog, total_bad);
    $finish;
  end
endmodule
