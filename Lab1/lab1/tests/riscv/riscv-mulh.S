//========================================================================
// riscv-mulh.S
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // Arithmetic tests
        //--------------------------------------------------------------------

        // Zero and one operands

        TEST_RR_OP( mulh,  0,  0, 0 )
        TEST_RR_OP( mulh,  0,  1, 0 )
        TEST_RR_OP( mulh,  1,  0, 0 )
        TEST_RR_OP( mulh,  1,  1, 0 )
        TEST_RR_OP( mulh,  0, -1, 0 )
        TEST_RR_OP( mulh, -1,  0, 0 )
        TEST_RR_OP( mulh, -1, -1, 0 )

        // Positive operands

        TEST_RR_OP( mulh,    42,   13, 0 )
        TEST_RR_OP( mulh,   716,   89, 0 )
        TEST_RR_OP( mulh, 20154, 8330, 0 )

        // Negative operands

        TEST_RR_OP( mulh,    42,    -13, -1 )
        TEST_RR_OP( mulh,  -716,     89, -1 )
        TEST_RR_OP( mulh, -20154, -8330,  0 )

        // Mixed and overflow tests (extracting upper 32 bits of signed result)

        TEST_RR_OP( mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_OP( mulh, 0xdeadbeef, 0x10000000, 0xfdeadbee )
        TEST_RR_OP( mulh, 0x7fffffff, 0x7fffffff, 0x3fffffff )
        TEST_RR_OP( mulh, 0x80000000, 0x80000000, 0x40000000 )
        TEST_RR_OP( mulh, 0x80000000, 0x00000001, 0xffffffff )

        //--------------------------------------------------------------------
        // Source/Destination tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC1_EQ_DEST( mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC0_EQ_SRC1( mulh, 0x7fffffff, 0x3fffffff )
        TEST_RR_SRCS_EQ_DEST( mulh, 0x7fffffff, 0x3fffffff )

        //--------------------------------------------------------------------
        // Bypassing tests
        //--------------------------------------------------------------------

        TEST_RR_DEST_BYP( 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 1, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 2, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 3, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 4, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 0, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 1, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 2, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 3, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 4, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 1, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 1, 1, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 2, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 0, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 1, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 2, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 3, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 4, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 1, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 1, 1, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 2, 0, mulh, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RISCV_END