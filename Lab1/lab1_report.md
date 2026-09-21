# Lab1 Report

## Objective 1

1. Finish `lab1/riscvstall/riscvstall-CoreCtrl.v` line 407 to 469 missing part.
2. Compile the test vhm file, edit `lab1/test/riscv/riscv.mk`, uncomment the ones you want to test.

Tips: uncomment all in `lab1/test/riscv/riscv.mk`, build all the test vhm files at once. Enable the tests you want in `lab1/build/Makefile` after modifying `lab1/riscvstall/riscvstall-CoreCtrl.v`

## Objective 2

Both `imuldiv-IntMulIterative.v` and `imuldiv-IntMulDivIterative.v` are implemented correctly, it always calculate 64bit multiply result. Focus on `muldiv_mux_sel_Xhl` signal in control, this signal control the output to be one of low or high 32bit of muldiv module output.

1. Uncomment `mulh` `mulhu` `mulhsu` related lines in `riscvstall-InstMsg.v`.
2. For `mulh`, only need to change the muldiv output mux to high 32bit. Edit `riscvstall-CoreCtrl.v` line 459, copy from `mul`, only change `mdm_l` to `mdm_u`, after that `mulh` should pass the test
3. Edit `riscvstall-CoreCtrl.v`, add `md_mulhu` and `md_mulhsu`, update `mulhu` `mulhsu` control signals
4. In `imuldiv-MulDivReqMsg.v`, add `mulhu` `mulhsu` definitions
5. In `imuldiv-IntMulDivIterative.v`, add a control line called `mul_mode`, and pass it into `imuldiv_IntMulIterative.v`, also update `mulreq_val` so that it also fires when executing `mulhu` and `mulhsu`
6. For `mulhu` and `mulhsu`, idea is that in `imuldiv-IntMulIterative.v`
    - add a input `mul_mode` for dpath, with `s` both signed, `u` both unsigned and `su` signed/unsigned, 0, 1, 2 respectively
    - after adding mode, `mul` and `mulh` should still work properly
    - update the initial input of a, b shift add mux, that select the signed/unsigned version of a, b
    - for the result sign mux:
        - `mulhu`: does not check both sign, so in last result_mux, mask out the select signal
        - `mulhsu`: result sign is decided on a's sign, modify result select signal based on a's sign
7. Update control signals in `riscvstall-CoreCtrl.v` for `mulhu` `mulhsu`
8. Write the test asm for `mulh` `mulhu` `mulhsu` and test them

## Objective 3

1. Enable `riscvbyp` in `lab1/build/Makefile`: uncomment `subpkgs += riscvbyp`, `sim_incs += -I $(topdir)/riscvbyp`, the `proc_template`/`asm_template`/`bmark_template` calls for `riscvbyp`, and point `check-asm`/`check-asm-rand` at `check-asm-riscvbyp`/`check-asm-rand-riscvbyp`.

2. Add a per-operand bypass mux in `riscvbyp-CoreDpath.v`:
    - New ctrl->dpath inputs `data0_byp_mux_sel_Dhl` / `data1_byp_mux_sel_Dhl` select among `BYP_NOBYP` (regfile read data), `BYP_FROM_X` (`byp_Xhl` = `execute_mux_out_Xhl`), `BYP_FROM_M` (`byp_Mhl` = `wb_mux_out_Mhl`), `BYP_FROM_W` (`byp_Whl` = `wb_mux_out_Whl`).
    - Route `op0_mux_out_Dhl`, `op1_mux_out_Dhl`, `wdata_Dhl` (store data), and `jumpreg_targ_Dhl` (JALR target) through `data0/1_byp_mux_out` instead of the raw regfile read data, so the ALU, branches, stores, and JALR all see forwarded values.
    - Export `inst_rd_Xhl` / `inst_rd_Mhl` / `inst_rd_Whl` (dpath->ctrl) so control can compare D-stage source registers against in-flight destination registers.
    - Gotcha: a Verilog `?:` chain needs a trailing default branch at every level (e.g. `: 32'bx;`) - leaving it off after the last `BYP_FROM_W` case compiles as garbage but iverilog rejects it as a "Syntax error in continuous assignment". (I am so stupid that I did't notice this.)

3. Compute the bypass select and rewrite the hazard stall in `riscvbyp-CoreCtrl.v`:
    - `data0/1_byp_mux_sel_Dhl` compares the D-stage source register (`inst_rs1_Dhl`/`inst_rs2_Dhl`, already decoded locally in ctrl - don't re-import them from dpath, that causes a duplicate-declaration error) against `inst_rd_Xhl/Mhl/Whl`, qualified by `inst_val_Xhl/Mhl/Whl`, `rf_wen_Xhl/Mhl/Whl`, and `rf_waddr_Xhl/Mhl/Whl != 0`, priority X > M > W (most recent producer wins, and a bubble or a non-writing/x0-targeting instruction must never trigger a false bypass).
    - Replace the old `stall_hazard_Dhl` (which stalls on *any* RAW hazard against X/M/W, same as `riscvstall`, defeating the point of bypassing) with a version scoped to the one hazard forwarding can't cover: a load still in X (its data isn't back from memory until it reaches M), and only when D's `rs1`/`rs2` actually reads that load's destination register.

4. Wire the new `data0/1_byp_mux_sel_Dhl` and `inst_rd_Xhl/Mhl/Whl` signals between `ctrl` and `dpath` in `riscvbyp-Core.v`.

After these changes `riscvbyp` passes the same asm/bmark tests as `riscvstall` with far fewer stall cycles from RAW hazards.

