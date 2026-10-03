//=========================================================================
// riscv-test5.S
//
// A test which will use as many ROB slots as your design can.
//
// Here the ROB has 16 slots.
// One allocation per cycle, so peak occupancy = cycles from a mul's allocation
// to its commit: X, M, X2, X3, W, then commit is 6. And the head can't be held
// longer while D keeps issuing, because every stall that could delay it
// (memory in M, losing the W port) also stalls D. So max 6 ROB slots in use.
// Back-to-back muls never compete for the W port; a mix of mul and ALU ops does,
// and only reaches 5 slots.
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 6
        li    x3, 7
        mul   x5, x2, x3
        mul   x6, x2, x3
        mul   x7, x2, x3
        mul   x8, x2, x3
        mul   x9, x2, x3
        mul   x10, x2, x3
        TEST_CHECK_EQ( x5, 42 )
        TEST_CHECK_EQ( x10, 42 )

        TEST_RISCV_END
