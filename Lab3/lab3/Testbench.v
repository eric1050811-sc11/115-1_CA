//=========================================================================
// Processor Testbench
//=========================================================================

`ifndef RISCV_TESTBENCH_V
`define RISCV_TESTBENCH_V

`ifdef RISCV_CORE_PART2
  `include "riscvssc_part2-Core.v"
`else
  `include "riscvssc_part1-Core.v"
`endif
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

  //--------------------------------------------------------------------
  // Core memory interface
  //--------------------------------------------------------------------

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq0_msg;
  wire                                 imemreq0_val;
  wire                                 imemreq0_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   imemresp0_msg;
  wire                                 imemresp0_val;
  wire                                 imemresp0_rdy;

  wire [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq1_msg;
  wire                                 imemreq1_val;
  wire                                 imemreq1_rdy;
  wire [`VC_MEM_RESP_MSG_SZ(32)-1:0]   imemresp1_msg;
  wire                                 imemresp1_val;
  wire                                 imemresp1_rdy;

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

    .imemreq0_msg  (imemreq0_msg),
    .imemreq0_val  (imemreq0_val),
    .imemreq0_rdy  (imemreq0_rdy),
    .imemreq1_msg  (imemreq1_msg),
    .imemreq1_val  (imemreq1_val),
    .imemreq1_rdy  (imemreq1_rdy),

    .imemresp0_msg (imemresp0_msg),
    .imemresp0_val (imemresp0_val),
    .imemresp0_rdy (imemresp0_rdy),
    .imemresp1_msg (imemresp1_msg),
    .imemresp1_val (imemresp1_val),
    .imemresp1_rdy (imemresp1_rdy),

    .dmemreq_msg   (dmemreq_msg),
    .dmemreq_val   (dmemreq_val),
    .dmemreq_rdy   (dmemreq_rdy),
    .dmemresp_msg  (dmemresp_msg),
    .dmemresp_val  (dmemresp_val),
    .dmemresp_rdy  (dmemresp_rdy),

    .csr_status    (status)
  );

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

    .memreq0_val  (imemreq0_val),
    .memreq0_rdy  (imemreq0_rdy),
    .memreq0_msg  (imemreq0_msg),
    .memresp0_val (imemresp0_val),
    .memresp0_rdy (imemresp0_rdy),
    .memresp0_msg (imemresp0_msg),

    .memreq1_val  (imemreq1_val),
    .memreq1_rdy  (imemreq1_rdy),
    .memreq1_msg  (imemreq1_msg),
    .memresp1_val (imemresp1_val),
    .memresp1_rdy (imemresp1_rdy),
    .memresp1_msg (imemresp1_msg),

    .memreq2_val  (dmemreq_val),
    .memreq2_rdy  (dmemreq_rdy),
    .memreq2_msg  (dmemreq_msg),
    .memresp2_val (dmemresp_val),
    .memresp2_rdy (dmemresp_rdy),
    .memresp2_msg (dmemresp_msg)
  );

endmodule

`endif
