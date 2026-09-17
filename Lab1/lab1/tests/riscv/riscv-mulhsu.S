//========================================================================
// riscv-mulhsu.S
//========================================================================
// mulhsu treats src0 (rs1) as SIGNED and src1 (rs2) as UNSIGNED, and
// returns the upper 32 bits of the full 64-bit product.

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // Arithmetic tests
        //--------------------------------------------------------------------

        // Zero and one operands

        TEST_RR_OP( mulhsu,  0,  0, 0 )
        TEST_RR_OP( mulhsu,  0,  1, 0 )
        TEST_RR_OP( mulhsu,  1,  0, 0 )
        TEST_RR_OP( mulhsu,  1,  1, 0 )
        TEST_RR_OP( mulhsu,  0, -1, 0 )
        TEST_RR_OP( mulhsu, -1,  0, 0 )
        TEST_RR_OP( mulhsu, -1, -1, -1 )

        // Positive operands

        TEST_RR_OP( mulhsu,    42,   13, 0 )
        TEST_RR_OP( mulhsu,   716,   89, 0 )
        TEST_RR_OP( mulhsu, 20154, 8330, 0 )

        // Negative src0, positive (unsigned) src1

        TEST_RR_OP( mulhsu,    -42,   13, -1 )
        TEST_RR_OP( mulhsu,   -716,   89, -1 )
        TEST_RR_OP( mulhsu, -20154, 8330, -1 )

        // Mixed and overflow tests (extracting upper 32 bits of the
        // signed(src0) x unsigned(src1) result)

        TEST_RR_OP( mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_OP( mulhsu, 0xdeadbeef, 0x10000000, 0xfdeadbee )
        TEST_RR_OP( mulhsu, 0x7fffffff, 0x7fffffff, 0x3fffffff )
        TEST_RR_OP( mulhsu, 0x80000000, 0x7fffffff, 0xc0000000 )
        TEST_RR_OP( mulhsu, 0x80000000, 0x00000001, 0xffffffff )
        TEST_RR_OP( mulhsu, 0x80000000, 0xffffffff, 0x80000000 )

        //--------------------------------------------------------------------
        // Source/Destination tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC1_EQ_DEST( mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC0_EQ_SRC1( mulhsu, 0x7fffffff, 0x3fffffff )
        TEST_RR_SRCS_EQ_DEST( mulhsu, 0x7fffffff, 0x3fffffff )

        //--------------------------------------------------------------------
        // Bypassing tests
        //--------------------------------------------------------------------

        TEST_RR_DEST_BYP( 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 1, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 2, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 3, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 4, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 0, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 1, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 2, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 3, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 4, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 1, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 1, 1, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 2, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 0, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 1, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 2, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 3, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 4, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 1, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 1, 1, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 2, 0, mulhsu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RISCV_END