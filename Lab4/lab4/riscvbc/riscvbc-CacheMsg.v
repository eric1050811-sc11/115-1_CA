`ifndef RISCV_CACHE_MSG_V
`define RISCV_CACHE_MSG_V

//------------------------------------------------------------------------
// Read or Write
//------------------------------------------------------------------------
`define READ  1'b0
`define WRITE 1'b1

//------------------------------------------------------------------------
// Bit field definitions for cache addressing
//------------------------------------------------------------------------
`define OFF_BITS 6
`define IDX_BITS 5
`define TAG_BITS 21

//------------------------------------------------------------------------
// Cache parameter
//------------------------------------------------------------------------
`define BLK_SIZE   512
`define D_SET_SIZE 1024

// Backing-memory interface transfers one 128-bit (16-byte) beat at a time.
// A 64-byte cache block therefore needs four refill/write-back beats.
`define MEM_BEAT_BITS  128
`define MEM_BEAT_BYTES 16
`define BEATS_PER_BLK  (`BLK_SIZE/`MEM_BEAT_BITS)

`define WAY0 1'b0
`define WAY1 1'b1

`endif
