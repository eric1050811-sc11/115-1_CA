//=========================================================================
// riscv-muldiv-hazard.S
//
// The bug that only showed up on an actual simulation run:
// `stall_muldiv_hazard_Dhl` reused the same `wb_mux_sel==wm_alu && execute_mux_sel==em_md` condition
// from item 5, but **branches** have *both* `wb_mux_sel` and `execute_mux_sel` set to don't-care (`wm_x`/`em_x`)
// in the decode table, since they never write anything back. So whenever a branch sat in X/M/X2, the whole
// condition evaluated to `x`, propagated straight through `stall_muldiv_hazard_Dhl` into `stall_Dhl`, and
// corrupted `imemreq_val`/`imemresp_rdy` (both computed from `!stall_Dhl`) - the sim ran the full test to its
// 1,000,000-cycle timeout with continuous `x assertion failed` errors on `memreq0_val`/`memresp0_rdy`, since
// branches occur in essentially every test. Fix: add back the `rf_wen_Xhl/Mhl/X2hl` check that I'd earlier
// dismissed as "redundant" - it's the one signal that's reliably concrete (`0`) for branches, and masks the
// don't-care `wb_mux_sel`/`execute_mux_sel` before the `x` can propagate anywhere.
//
//=========================================================================

#include "riscv-macros.h"

#define TEST_RR_OP_N0( inst_, src0_, src1_, result_ )                   \
    li    x2, src0_;                                                    \
    li    x3, src1_;                                                    \
    inst_ x4, x2, x3;                                                   \
    TEST_INSERT_NOPS(0)                                                 \
    TEST_CHECK_EQ( x4, result_ );                                       \

#define TEST_RR_OP_N1( inst_, src0_, src1_, result_ )                   \
    li    x2, src0_;                                                    \
    li    x3, src1_;                                                    \
    inst_ x4, x2, x3;                                                   \
    TEST_INSERT_NOPS(1)                                                 \
    TEST_CHECK_EQ( x4, result_ );                                       \

#define TEST_RR_OP_N2( inst_, src0_, src1_, result_ )                   \
    li    x2, src0_;                                                    \
    li    x3, src1_;                                                    \
    inst_ x4, x2, x3;                                                   \
    TEST_INSERT_NOPS(2)                                                 \
    TEST_CHECK_EQ( x4, result_ );                                       \

#define TEST_RR_OP_N3( inst_, src0_, src1_, result_ )                   \
    li    x2, src0_;                                                    \
    li    x3, src1_;                                                    \
    inst_ x4, x2, x3;                                                   \
    TEST_INSERT_NOPS(3)                                                 \
    TEST_CHECK_EQ( x4, result_ );                                       \

        TEST_RISCV_BEGIN

        TEST_RR_OP_N0( mul,    42,   13,       546 )
        TEST_RR_OP_N1( mul,   716,   89,     63724 )
        TEST_RR_OP_N2( mul, 20154, 8330, 167882820 )
        TEST_RR_OP_N3( mul, 0xdeadbeef, 0x10000000, 0xf0000000 )

        TEST_RISCV_END