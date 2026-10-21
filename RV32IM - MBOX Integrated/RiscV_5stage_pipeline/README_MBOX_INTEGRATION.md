# 5-stage RV32I pipeline + MBOX (RV32M multiply) — integration files

## 1. Where each file goes (repo: RiscV_5stage_pipeline/)

```
RiscV_5stage_pipeline/
├── rtl/
│   ├── includes/riscv_defines.svh          (unchanged)
│   ├── core/
│   │   ├── riscv_pipeline.sv               MODIFIED  top level
│   │   ├── control_unit.sv                 MODIFIED  + funct3/funct7 in; is_mul, uses_rs1, uses_rs2 out
│   │   ├── id_ex_reg.sv                    MODIFIED  carries is_mul
│   │   ├── mbox_hazard_unit.sv             NEW       RAW / WAW / write-port stall vs MUL in flight
│   │   ├── wb_arbiter.sv                   NEW       single regfile write port: MBOX has priority
│   │   ├── riscv_single_cycle.sv           MODIFIED  2 lines: connects funct3/funct7 to control_unit
│   │   │                                             (not used by the pipeline build)
│   │   └── (all other files unchanged: hazard_unit, forwarding_unit, if_id_reg, ex_mem_reg,
│   │        mem_wb_reg, program_counter_en, alu, alu_control, branch_control, immgen,
│   │        instruction_decoder, register_file, data_memory, instruction_memory, pc_adder4,
│   │        pc_branch_adder, mux_*.sv)
│   └── mbox/                               NEW FOLDER
│       ├── mbox_unit.sv                    NEW       wrapper: reset polarity + result register
│       ├── mbox_top.sv                     MODIFIED  + pend_valid / pend_rd_flat output ports
│       └── mbox_*.sv                       unchanged copies from branch MBOX
│           (sign_prep, booth_encoder, pp_gen, stage2_reduce, stage3_reduce,
│            wallace_level, fa_ha, cla_adder, output_mux)
├── tb/                                     existing testbenches (untouched)
└── verif/                                  NEW FOLDER
    ├── rv32im.py                           RV32IM encoder + reference model + random program generator
    ├── tb_rv32im_core.sv                   integrated core vs reference model + per-cycle checks
    └── tb_sc_ref.sv                        reference model vs original single-cycle core
```

## 2. Module hierarchy

```
riscv_pipeline
├─ IF   program_counter_en, mux_pc_src, pc_adder4, instruction_memory
│       if_id_reg
├─ ID   instruction_decoder, control_unit (is_mul, uses_rs1, uses_rs2), immgen, register_file
│       hazard_unit            load-use + redirect            (unchanged)
│       mbox_hazard_unit       MUL RAW / WAW / write-port     (new)
│       id_ex_reg
├─ EX   forwarding_unit, mux_alu_src_a, mux_alu_src_b, mux_base_select_pc_branch,
│       alu_control, alu, branch_control, pc_branch_adder
│       mbox_unit
│        └─ mbox_top
│            ├─ mbox_sign_prep
│            ├─ mbox_booth_encoder
│            ├─ mbox_pp_gen
│            ├─ mbox_stage2_reduce ── mbox_wallace_level ── mbox_fa / mbox_ha
│            ├─ mbox_stage3_reduce ── mbox_wallace_level ── mbox_fa / mbox_ha
│            ├─ mbox_cla_adder ── mbox_cla4
│            └─ mbox_output_mux
│       ex_mem_reg
├─ MEM  data_memory, mem_wb_reg
└─ WB   mux_write_data_src
        wb_arbiter           -> reg_write_w / rd_w / write_back_data_w
                                (regfile write port, WB->ID bypass, forwarding_unit, WB->EX forward)
```

## 3. Build and run (Icarus Verilog 12, tested)

Pipeline build: do NOT compile `riscv_single_cycle.sv` or `program_counter.sv` (the pipeline
uses `program_counter_en`; the old `program_counter` has an `enable` port that the single-cycle top
never connects).

```sh
cd RiscV_5stage_pipeline/rtl/core
CORE="$(ls *.sv | grep -v -e '^riscv_single_cycle.sv$' -e '^program_counter.sv$' | tr '\n' ' ')"
iverilog -g2012 -I. -o ../../../sim.vvp ../../../verif/tb_rv32im_core.sv $CORE ../mbox/*.sv   # ~100 s

cd ../../verif
python3 rv32im.py /tmp/rnd 40 1                      # 40 random programs + expected results
vvp ../sim.vvp +N=40 +DIR=/tmp/rnd +CYC=800          # ~1 min
```

Warnings that are expected: Icarus "constant selects in always_* processes" (cosmetic) and
`Constant bit select [-1]` in mbox_booth_encoder.sv (the i==0 ternary never uses it).

## 4. Verification status (what was actually run)

| Check | Result |
|---|---|
| Existing pipeline vs single-cycle differential test (RV32I) on the modified core | 16415 pass / 0 fail |
| Reference model vs original single-cycle core, 200 random RV32I programs | 200 / 200 match |
| Integrated core vs reference model, 40 random RV32IM programs (454 MULs, MUL-heavy, small register pools, forward branches/jal/jalr, loads/stores) | 40 / 40 pass, 0 mismatches |
| Per cycle: MUL result lands exactly 4 cycles after EX; pending-stage visibility; wb_arbiter conflict; X on control signals | 0 errors |
| Stall rules exercised in those runs | RAW 394, WAW 277, write-port 206 cycles (overlapping) |

NOT done: directed tests of exact bubble counts, a larger random campaign, STA / OpenLane,
single-cycle RV32IM (needs a combinational MBOX), DIV/REM (not in MBOX; funct3[2]=1 M-ops fall
through the normal R-type path and give a wrong result).

## 5. Repo issues noticed
* `instruction_memory.sv` reads `E:/project/...` in an `initial` block (fails on any other machine).
* Pipeline-folder `program_counter.sv` has `enable`, but `riscv_single_cycle.sv` leaves it unconnected.
