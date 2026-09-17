# Lab1 Report

## Objective 1

1. Finish `lab1/riscvstall/riscvstall-CoreCtrl.v` line 407 to 469 missing part.
2. Compile the test vhm file, edit `lab1/test/riscv/riscv.mk`, uncomment the ones you want to test.

Tips: uncomment all in `lab1/test/riscv/riscv.mk`, build all the test vhm files at once. Enable the tests you want in `lab1/build/Makefile` after modifying `lab1/riscvstall/riscvstall-CoreCtrl.v`

## Objective 2

I think both `imuldiv-IntMulIterative.v` and `imuldiv-IntMulDivIterative.v` are implemented correctly, it always calculate 64bit multiply result. Focus on `muldiv_mux_sel_Xhl` signal in control, this signal control the output to be one of low or high 32bit of muldiv module output.

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
