//=========================================================================
// riscv-test4.S
//
// A scenario in which the riscvlong processor achieves a higher IPC than
// the completed riscvooo processor.
// (Hint: What features are present in riscvooo but not in riscvlong?)
//
// With the 3 functional units in riscvooo, if any 2 of them arrive at W
// in the same cycle, one of them needs to stall. While for riscvlong,
// since all of them go through the same number of stages, no 2 instructions
// arrive at W in the same cycle. This is the case where riscvlong wins
// and has higher IPC.
//
// The following test let mul, lw and addi fight for W port in same cycle,
// mul has the highest priority to the port, lw and addi must stall. After
// mul finish, lw has the port and addi needs to stall. Each round causes
// riscvooo another 2 cycles. Repeat for 3 rounds, riscvooo has more total
// cycles than riscvlong.
//
// Result:
// - riscvlong: 31 cycles, ipc 0.774
// - riscvooo : 34 cycles, ipc 0.706
//=========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        la   x21, 0x1000
        li   x2, 6
        li   x3, 7
        mul  x4, x2, x3
        nop               // a nop do delay the following lw and addi
        lw   x5, 0(x21)   // so they arrive at W in the same cycle
        addi x6, x0, 1
        mul  x7, x2, x3
        nop
        lw   x8, 0(x21)
        addi x9, x0, 1
        mul  x10, x2, x3
        nop
        lw   x11, 0(x21)
        addi x12, x0, 1
        TEST_CHECK_EQ( x4, 42 )
        TEST_CHECK_EQ( x6, 1 )

        TEST_RISCV_END
