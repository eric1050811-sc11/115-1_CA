//========================================================================
// riscv-mulhu.S
//========================================================================

#include "riscv-macros.h"

        TEST_RISCV_BEGIN

        //--------------------------------------------------------------------
        // Arithmetic tests
        //--------------------------------------------------------------------

        // Zero and one operands

        TEST_RR_OP( mulhu,  0,  0, 0 )
        TEST_RR_OP( mulhu,  0,  1, 0 )
        TEST_RR_OP( mulhu,  1,  0, 0 )
        TEST_RR_OP( mulhu,  1,  1, 0 )
        TEST_RR_OP( mulhu,  0, -1, 0 )
        TEST_RR_OP( mulhu, -1,  0, 0 )
        TEST_RR_OP( mulhu, -1, -1, 0xfffffffe )

        // Positive (small) operands -- treated as unsigned, same as mulh

        TEST_RR_OP( mulhu,    42,   13, 0 )
        TEST_RR_OP( mulhu,   716,   89, 0 )
        TEST_RR_OP( mulhu, 20154, 8330, 0 )

        // Large unsigned operands (would be "negative" if interpreted as
        // signed -- mulhu must treat them purely as unsigned magnitudes)

        TEST_RR_OP( mulhu, -1,          13, 0x0000000c )
        TEST_RR_OP( mulhu, 0xdeadbeef, -1,  0xdeadbeee )
        TEST_RR_OP( mulhu, -1, 0x80000000,  0x7fffffff )

        // Mixed and overflow tests (extracting upper 32 bits of unsigned result)

        TEST_RR_OP( mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_OP( mulhu, 0xdeadbeef, 0x10000000, 0x0deadbee )
        TEST_RR_OP( mulhu, 0x7fffffff, 0x7fffffff, 0x3fffffff )
        TEST_RR_OP( mulhu, 0x80000000, 0x80000000, 0x40000000 )
        TEST_RR_OP( mulhu, 0x80000000, 0x00000001, 0x00000000 )
        TEST_RR_OP( mulhu, 0xffffffff, 0xffffffff, 0xfffffffe )

        //--------------------------------------------------------------------
        // Source/Destination tests
        //--------------------------------------------------------------------

        TEST_RR_SRC0_EQ_DEST( mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC1_EQ_DEST( mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC0_EQ_SRC1( mulhu, 0x7fffffff, 0x3fffffff )
        TEST_RR_SRCS_EQ_DEST( mulhu, 0x7fffffff, 0x3fffffff )

        //--------------------------------------------------------------------
        // Bypassing tests
        //--------------------------------------------------------------------

        TEST_RR_DEST_BYP( 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 1, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 2, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 3, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_DEST_BYP( 4, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 0, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 1, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 2, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 3, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 0, 4, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC01_BYP( 1, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 1, 1, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC01_BYP( 2, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 0, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 1, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 2, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 3, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 0, 4, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RR_SRC10_BYP( 1, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 1, 1, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )
        TEST_RR_SRC10_BYP( 2, 0, mulhu, 0x0deadbee, 0x10000000, 0x00deadbe )

        TEST_RISCV_END