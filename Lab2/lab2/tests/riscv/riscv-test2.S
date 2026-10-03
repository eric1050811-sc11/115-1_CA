//=========================================================================
// riscv-test2.S
//
// A test case requiring a value to be bypassed from the ROB
// (i.e., bypassing a value that has been written back but not yet committed).
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 6
        li    x3, 7
        mul   x5, x2, x3   // slow, at ROB head
        addi  x6, x0, 1    // written back early, can't commit past the mul
        nop
        nop
        add  x7, x6, x6    // should be bypassed from ROB
        TEST_CHECK_EQ( x7, 2 )

        TEST_RISCV_END
