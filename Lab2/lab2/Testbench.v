//=========================================================================
// Processor Testbench
//=========================================================================

`ifndef RISCV_TESTBENCH_V
`define RISCV_TESTBENCH_V

`include "riscvooo-Core.v"
`include "Pattern.v"


`ifndef PATTERN_MAX_DELAY
  `define PATTERN_MAX_DELAY 0
`endif

`ifndef PATTERN_RESET_CYCLES
  `define PATTERN_RESET_CYCLES 2
`endif

`ifndef PATTERN_DEFAULT_MAX_CYCLES
  `define PATTERN_DEFAULT_MAX_CYCLES 100000
`endif

`ifndef PATTERN_IS_RAND_DELAY
  `define PATTERN_IS_RAND_DELAY 0
`endif

module Testbench;

  wire clk;
  wire reset_proc;
  wire reset_mem;

  wire [31:0] status;
  wire        retire_valid;

  //--------------------------------------------------------------------
  // Core memory interface
  //--------------------------------------------------------------------

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq_msg;
  wire                                 imemreq_val;
  wire                                 imemreq_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   imemresp_msg;
  wire                                 imemresp_val;
  wire                                 imemresp_rdy;

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] dmemreq_msg;
  wire                                 dmemreq_val;
  wire                                 dmemreq_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   dmemresp_msg;
  wire                                 dmemresp_val;
  wire                                 dmemresp_rdy;

  riscv_Core proc
  (
    .clk           (clk),
    .reset         (reset_proc),

    .imemreq_msg   (imemreq_msg),
    .imemreq_val   (imemreq_val),
    .imemreq_rdy   (imemreq_rdy),
    .imemresp_msg  (imemresp_msg),
    .imemresp_val  (imemresp_val),
    .imemresp_rdy  (imemresp_rdy),

    .dmemreq_msg   (dmemreq_msg),
    .dmemreq_val   (dmemreq_val),
    .dmemreq_rdy   (dmemreq_rdy),
    .dmemresp_msg  (dmemresp_msg),
    .dmemresp_val  (dmemresp_val),
    .dmemresp_rdy  (dmemresp_rdy),

    .csr_status    (status),
    .retire_valid  (retire_valid)
  );

  //--------------------------------------------------------------------
  // Pattern-side memory interface
  //--------------------------------------------------------------------

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] pattern_memreq0_msg;
  wire                                 pattern_memreq0_val;
  wire                                 pattern_memreq0_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   pattern_memresp0_msg;
  wire                                 pattern_memresp0_val;
  wire                                 pattern_memresp0_rdy;

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] pattern_memreq1_msg;
  wire                                 pattern_memreq1_val;
  wire                                 pattern_memreq1_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   pattern_memresp1_msg;
  wire                                 pattern_memresp1_val;
  wire                                 pattern_memresp1_rdy;


  assign pattern_memreq0_msg  = imemreq_msg;
  assign pattern_memreq0_val  = imemreq_val;
  assign imemreq_rdy          = pattern_memreq0_rdy;
  assign imemresp_msg         = pattern_memresp0_msg;
  assign imemresp_val         = pattern_memresp0_val;
  assign pattern_memresp0_rdy = imemresp_rdy;

  assign pattern_memreq1_msg  = dmemreq_msg;
  assign pattern_memreq1_val  = dmemreq_val;
  assign dmemreq_rdy          = pattern_memreq1_rdy;
  assign dmemresp_msg         = pattern_memresp1_msg;
  assign dmemresp_val         = pattern_memresp1_val;
  assign pattern_memresp1_rdy = dmemresp_rdy;



  //--------------------------------------------------------------------
  // Pattern
  //--------------------------------------------------------------------

  Pattern
  #(
    .p_max_delay          (`PATTERN_MAX_DELAY),
    .p_reset_cycles       (`PATTERN_RESET_CYCLES),
    .p_default_max_cycles (`PATTERN_DEFAULT_MAX_CYCLES),
    .p_is_rand_delay      (`PATTERN_IS_RAND_DELAY)
  )
  pattern
  (
    .clk          (clk),
    .reset_proc   (reset_proc),
    .reset_mem    (reset_mem),
    .status       (status),
    .retire_valid (retire_valid),

    .memreq0_val  (pattern_memreq0_val),
    .memreq0_rdy  (pattern_memreq0_rdy),
    .memreq0_msg  (pattern_memreq0_msg),
    .memresp0_val (pattern_memresp0_val),
    .memresp0_rdy (pattern_memresp0_rdy),
    .memresp0_msg (pattern_memresp0_msg),

    .memreq1_val  (pattern_memreq1_val),
    .memreq1_rdy  (pattern_memreq1_rdy),
    .memreq1_msg  (pattern_memreq1_msg),
    .memresp1_val (pattern_memresp1_val),
    .memresp1_rdy (pattern_memresp1_rdy),
    .memresp1_msg (pattern_memresp1_msg)
  );

endmodule

`endif
