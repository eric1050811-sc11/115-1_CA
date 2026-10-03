//=========================================================================
// riscv-test3.S
//
// A write-after-write (WAW) scenario that executes correctly on both
// the original and the final processor.
// (Hint: Consider the time elapsed between the two writes.)
//
// Original processor: I2O2 version with scoreboard and dummy ROB
// (write register in W).
//
// nops between mul and addi:
// 0 and 1 nop: failed on original one, 0: same as riscv-test1.S
// == 2 nops: mul and addi compete for the W port in the same cycle; 
//            mul wins the arbitration and the addi stalls one cycle in X,
//            so it still writes second, both passed
// >= 3 nops: mul finished before addi, both passed
//
// This test uses 4 nops between mul and addi, so mul always writes back
// first, therefore both processors execute correctly. And
// another 4 nops between addi and TEST_CHECK_EQ to ensure both mul and addi
// have written back to the register file.
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        li    x2, 6
        li    x3, 7
        mul   x4, x2, x3        // older, slow (MUL pipe):  x4 = 42
        nop
        nop
        nop
        nop
        addi  x4, x0, 1         // younger, fast (ALU pipe): x4 = 1
        nop
        nop
        nop
        nop
        TEST_CHECK_EQ( x4, 1 )

        TEST_RISCV_END
