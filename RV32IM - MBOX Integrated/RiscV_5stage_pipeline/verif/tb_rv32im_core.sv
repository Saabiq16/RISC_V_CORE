`timescale 1ns/1ps
// Integrated 5-stage + MBOX core vs the Python RV32IM reference model.
// Per program: load hex, reset, run CYC cycles, compare x1..x31 and data memory.
// Per cycle checks:
//   L1  MBOX write lands exactly 4 cycles after the MUL was in EX
//   L2  pend_valid[S2] / [S3] are exactly 1 / 2 cycles after issue
//   C1  wb_arbiter conflict never fires
//   X1  no X on the control/hazard/write-port signals after reset
module tb_rv32im_core;
  logic clk = 0, rst = 1;
  riscv_pipeline dut(.clk(clk), .reset(rst));
  always #5 clk = ~clk;

  int nprog, cyc, p, i, fd, code, mism, bad_progs;
  string dir, tag;
  logic [31:0] a, b;
  logic [3:0] sr;                 // is_mul_e history: sr[k] = issue k+1 cycles ago
  int warm;
  int err_lat, err_conf, err_x, err_pend;
  int t_cycles, t_mul, t_stall_mb, t_stall_ld, t_raw, t_waw, t_struct, t_flush, t_mbwr;
  int tot_cycles, tot_mul, tot_mb, tot_ld, tot_raw, tot_waw, tot_struct, tot_flush, tot_mbwr;
  int tot_lat, tot_conf, tot_x, tot_pend;
  logic running;

  always @(posedge clk) begin
    if (rst || !running) begin
      sr <= 4'b0; warm <= 0;
    end else begin
      warm <= warm + 1;
      sr   <= {sr[2:0], dut.is_mul_e};
      if (warm >= 2) begin
        if (dut.mb_wb_valid !== sr[3]) err_lat++;
        if (dut.mb_s2_valid !== sr[0]) err_pend++;
        if (dut.mb_s3_valid !== sr[1]) err_pend++;
        if (dut.wb_conflict !== 1'b0)  err_conf++;
        if ((^{dut.reg_write_w, dut.rd_w, dut.pc_stall, dut.if_id_stall, dut.if_id_flush,
               dut.id_ex_flush, dut.mb_stall, dut.is_mul_e, dut.mb_wb_valid, dut.wb_conflict}) === 1'bx)
          begin
            err_x++;
            if (err_x == 1) $display("[X first @warm=%0d] reg_write_w=%b rd_w=%b pc_stall=%b if_id_stall=%b if_id_flush=%b id_ex_flush=%b mb_stall=%b is_mul_e=%b mb_wb_valid=%b wb_conflict=%b hz_stall_f=%b pc_src_sel_e=%b",
              warm, dut.reg_write_w, dut.rd_w, dut.pc_stall, dut.if_id_stall, dut.if_id_flush, dut.id_ex_flush, dut.mb_stall, dut.is_mul_e, dut.mb_wb_valid, dut.wb_conflict, dut.hz_stall_f, dut.pc_src_sel_e);
          end
        t_cycles++;
        if (dut.is_mul_e) t_mul++;
        if (dut.mb_stall) begin
          t_stall_mb++;
          if (dut.mb_hz_unit.raw)        t_raw++;
          if (dut.mb_hz_unit.waw)        t_waw++;
          if (dut.mb_hz_unit.structural) t_struct++;
        end
        if (dut.hz_stall_f)  t_stall_ld++;
        if (dut.if_id_flush) t_flush++;
        if (dut.mb_wb_valid && dut.mb_wb_rd != 0) t_mbwr++;
      end
    end
  end

  initial begin
    if (!$value$plusargs("N=%d", nprog))  nprog = 1;
    if (!$value$plusargs("DIR=%s", dir))  dir = ".";
    if (!$value$plusargs("CYC=%d", cyc))  cyc = 3000;
    bad_progs = 0; running = 0;
    tot_cycles=0; tot_mul=0; tot_mb=0; tot_ld=0; tot_raw=0; tot_waw=0; tot_struct=0; tot_flush=0; tot_mbwr=0;
    tot_lat=0; tot_conf=0; tot_x=0; tot_pend=0;
    for (p = 0; p < nprog; p++) begin
      for (i = 0; i < 1024; i++) dut.instruction_memory_inst.memory[i] = 32'h00000013;
      $readmemh($sformatf("%s/prog_%0d.hex", dir, p), dut.instruction_memory_inst.memory);
      running = 0; rst = 1; repeat (3) @(posedge clk); @(negedge clk);
      for (i = 1024; i < 1536; i++) dut.data_mem.memory[i] = 8'h00;
      err_lat=0; err_conf=0; err_x=0; err_pend=0;
      t_cycles=0; t_mul=0; t_stall_mb=0; t_stall_ld=0; t_raw=0; t_waw=0; t_struct=0; t_flush=0; t_mbwr=0;
      rst = 0; running = 1;
      repeat (cyc) @(negedge clk);
      running = 0;
      mism = 0;
      fd = $fopen($sformatf("%s/exp_%0d.txt", dir, p), "r");
      while (!$feof(fd)) begin
        code = $fscanf(fd, "%s %h %h\n", tag, a, b);
        if (code == 3) begin
          if (tag == "R") begin
            if (dut.reg_file.registers[a[4:0]] !== b) begin
              mism++; if (mism <= 3) $display("[P%0d] x%0d dut=%h exp=%h", p, a[4:0], dut.reg_file.registers[a[4:0]], b);
            end
          end else begin
            logic [31:0] w;
            w = {dut.data_mem.memory[a+3], dut.data_mem.memory[a+2], dut.data_mem.memory[a+1], dut.data_mem.memory[a]};
            if (w !== b) begin mism++; if (mism <= 3) $display("[P%0d] mem[%h] dut=%h exp=%h", p, a, w, b); end
          end
        end
      end
      $fclose(fd);
      if (mism || err_lat || err_conf || err_x || err_pend) begin
        bad_progs++;
        $display("[P%0d] FAIL mism=%0d lat=%0d conf=%0d x=%0d pend=%0d", p, mism, err_lat, err_conf, err_x, err_pend);
      end
      tot_cycles+=t_cycles; tot_mul+=t_mul; tot_mb+=t_stall_mb; tot_ld+=t_stall_ld;
      tot_raw+=t_raw; tot_waw+=t_waw; tot_struct+=t_struct; tot_flush+=t_flush; tot_mbwr+=t_mbwr;
      tot_lat+=err_lat; tot_conf+=err_conf; tot_x+=err_x; tot_pend+=err_pend;
    end
    $display("RESULT programs=%0d failing=%0d | MULs issued=%0d MBOX writes=%0d", nprog, bad_progs, tot_mul, tot_mbwr);
    $display("COVERAGE mbox-stall cycles=%0d (raw=%0d waw=%0d struct=%0d, overlapping) load-use stall cycles=%0d flushes=%0d",
             tot_mb, tot_raw, tot_waw, tot_struct, tot_ld, tot_flush);
    $display("CHECKS latency_err=%0d pend_err=%0d conflict=%0d x_err=%0d", tot_lat, tot_pend, tot_conf, tot_x);
    $finish;
  end
endmodule
