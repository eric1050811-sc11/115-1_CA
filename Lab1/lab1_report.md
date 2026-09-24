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

## Objective 4

`riscvbyp`'s muldiv unit is iterative and stalls the *whole* pipeline for the entire multiply/divide latency. This objective swaps it for the provided 4-stage *pipelined* unit (`riscvlong-CoreDpathPipeMulDiv.v`) and extends the pipeline by two stages (`X2`, `X3`, inserted between `M` and `W`) so that latency has somewhere to live: `F -> D -> X -> M -> X2 -> X3 -> W`.

1. Enable `riscvlong` in `lab1/build/Makefile` - same pattern as Objective 3: uncomment `subpkgs += riscvlong`, `sim_incs += -I $(topdir)/riscvlong`, and the `proc_template`/`asm_template`/`bmark_template` calls for `riscvlong`.

2. `riscvlong-CoreDpathPipeMulDiv.v` - finish the provided skeleton:
    - Add `MULHU`/`MULHSU` to the `result0` mux. `mulh` needs no new case - it reuses the plain `MUL` funct code, since it's the same 64-bit signed product as `mul`, just takes the upper half downstream via `mdm_u`. `mulhu` is genuinely unsigned: `a_reg * b_reg` directly, no sign correction at all. `mulhsu`'s `b` is unsigned and must stay raw. Use a dedicated `product_su_raw = a_unsign * b_reg`, sign-corrected using only `a_reg[31]` (the same single-operand-sign pattern the file already uses for `remainder`).
    - Split the one shared `stall` wire that gated both `result2_reg` and `result3_reg` into separate `stall_X2hl`/`stall_X3hl` gates, one per register, and added the missing `val3_next` wire following the same "invalid if my producer stage was stalled, else inherit its validity" pattern already used for `val1_next`/`val2_next`.
    - `muldivreq_rdy` needs to depend on all four stall stages (`stall_Xhl/Mhl/X2hl/X3hl`), not just the response side.

3. Feed the muldiv unit from D, not X: `muldivreq_msg_a/b`, `muldivreq_msg_fn`, and `muldivreq_val` all come from D-stage decode/bypass signals now, not X-stage latched copies. Reason is that the unit's own `a_reg`/`b_reg`/`fn_reg` *are* its D->X latch (loaded on `muldivreq_go`, at the D->X edge) - feeding it already-latched X-stage values would double-register the operand and shift its internal 4 stages one slot later than X/M/X2/X3, breaking the intended stage alignment (would need a 5th extra stage instead of 2).

4. `riscvlong-CoreDpath.v` - extend the pipeline:
    - Add real `X2`/`X3` stages threading `pc`, `inst_rd`, `muldiv_mux_sel` forward.
    - Resolve the writeback value in two steps: an early ALU-vs-mem resolution at `M` (kept as `tmp_wb_mux_out_*`, carried forward through X2/X3 for bypass purposes), and the final ALU/mem-vs-muldiv resolution at `X3` (gated by a new `wb_mux_sel_X3hl` input from ctrl).
    - Add `byp_X2hl`/`byp_X3hl` and new `BYP_FROM_X2`/`BYP_FROM_X3` encodings - needs widening `data0/1_byp_mux_sel_Dhl` from 2 bits to 3 bits everywhere (ctrl output, dpath input, `Core.v` wire) to fit 6 bypass sources instead of 4.
    - Export `inst_rd_X2hl`/`inst_rd_X3hl` as new dpath->ctrl ports (same `_ff` pattern as the existing `inst_rd_Xhl/Mhl/Whl`) so ctrl's bypass-select logic can reach them.
    - Gotchas along the way: a `wb_mux_out_Mhl`-style wire commented out but still referenced elsewhere (dangling reference -> implicit 1-bit wire -> silent truncation); the `W <- X3` register block still reading stale `M`-stage signals after the section header was renamed to `X3`; `byp_X2hl` driven by a bare `assign` with no prior `wire [31:0]` declaration (same implicit-1-bit-wire trap); a `muldiv_mux_sel_X2hl <= muldiv_mux_sel_Xhl` chain-skip that reached two stages back instead of one, tagging the wrong instruction's mul/div half-select.

5. `riscvlong-CoreCtrl.v` - the control side:
    - Add `X2`/`X3` shadow-pipeline registers (`bubble`, `rf_wen`, `rf_waddr`, `csr_wen/addr`, `inst_val`), mirroring the existing `M`/`W` pattern exactly.
    - `stall_X2hl`/`stall_X3hl` are both just `1'b0` - nothing downstream of X2/X3 ever refuses (`W` never stalls, and neither X2 nor X3 have a local reason to stall on their own), and `stall_Mhl` folds in `stall_X2hl` to keep the standard backpressure chain (`stall_Xhl <- stall_Mhl <- stall_X2hl <- stall_X3hl`) intact.
    - Extend `data0/1_byp_mux_sel_Dhl` with X2/X3 branches, same shape as the existing X/M/W ones.
    - Remove `stall_muldiv_Xhl` (`muldivreq_val_Xhl && inst_val_Xhl && !muldivresp_val`) entirely - leftover from the old iterative unit. With the pipelined unit, `muldivresp_val` only turns true 3 cycles after the request starts, but the muldiv unit's own `result1/2/3_reg` keep shifting forward every cycle regardless of `stall_Xhl`. Keeping this stall would freeze X's shadow-pipeline bookkeeping for 3 cycles while the *real* muldiv result silently races ahead to X3 - by the time the stall clears, ctrl's notion of "which instruction is at X3" is 3 stages stale.
    - Drive `wb_mux_sel_X3hl` by threading `wb_mux_sel`/`execute_mux_sel` forward through new `X2hl`/`X3hl` regs, then combining them: `wb_mux_sel_X2hl==wm_alu && execute_mux_sel_X2hl==em_md`. First attempt used `execute_mux_sel` alone - wrong, because it's don't-care (`em_x`) for any load/store, which never goes through the execute mux at all; `wb_mux_sel` is always concrete and masks that don't-care before it can matter.
    - Add `stall_muldiv_hazard_Dhl`: a load-use-style stall, but for a muldiv producer sitting anywhere in X/M/X2 (not ready until X3) that a dependent instruction in D needs right now.

6. The bug that only showed up on an actual simulation run: `stall_muldiv_hazard_Dhl` reused the same `wb_mux_sel==wm_alu && execute_mux_sel==em_md` condition from item 5, but **branches** have *both* `wb_mux_sel` and `execute_mux_sel` set to don't-care (`wm_x`/`em_x`) in the decode table, since they never write anything back. So whenever a branch sat in X/M/X2, the whole condition evaluated to `x`, propagated straight through `stall_muldiv_hazard_Dhl` into `stall_Dhl`, and corrupted `imemreq_val`/`imemresp_rdy` (both computed from `!stall_Dhl`) - the sim ran the full test to its 1,000,000-cycle timeout with continuous `x assertion failed` errors on `memreq0_val`/`memresp0_rdy`, since branches occur in essentially every test. Fix: add back the `rf_wen_Xhl/Mhl/X2hl` check that I'd earlier dismissed as "redundant" - it's the one signal that's reliably concrete (`0`) for branches, and masks the don't-care `wb_mux_sel`/`execute_mux_sel` before the `x` can propagate anywhere.

After all of this, `riscvlong` passes the full asm test suite. Extending the pipeline adds two stages of latency to every instruction, not just muldiv, as expected - but the processor no longer stalls for the full muldiv latency on unrelated instructions the way the iterative design did.

