//=========================================================================
// riscv-test1.S
//
// Current dummy ROB does not guard the commit order,
// so in the following test, even though issue mul first,
// the mul result is written back later, causing the
// check to failed.
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 6
        li    x3, 7
        mul   x4, x2, x3        // older, slow (MUL pipe):  x4 = 42
        addi  x4, x0, 1         // younger, fast (ALU pipe): x4 = 1
        nop                     // prevent bne in TEST_CHECK_EQ reads addi x4
        nop                     // while mul x4 still in flight, which let
        nop                     // the test pass
        nop
        TEST_CHECK_EQ( x4, 1 )  // program order says the last write wins

        TEST_RISCV_END
