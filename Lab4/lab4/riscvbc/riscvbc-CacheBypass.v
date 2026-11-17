//=========================================================================
// Cache Bypass FL Module
//=========================================================================

`ifndef RISCV_CACHE_BYPASS_V
`define RISCV_CACHE_BYPASS_V

`include "vc-MemWidthAdapter.v"

module riscv_CacheBypass (
    input clk,
    input reset,


    // imem
    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                               memresp_val,
    input                                memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp_msg,

    //cache
    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cachereq_msg,

    input                                cacheresp_val,
    output                               cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0] cacheresp_msg
);

  vc_MemWidthAdapter_32to128 adapter
  (
    .in_req_val   (memreq_val),
    .in_req_rdy   (memreq_rdy),
    .in_req_msg   (memreq_msg),
    .in_resp_val  (memresp_val),
    .in_resp_rdy  (memresp_rdy),
    .in_resp_msg  (memresp_msg),
    .out_req_val  (cachereq_val),
    .out_req_rdy  (cachereq_rdy),
    .out_req_msg  (cachereq_msg),
    .out_resp_val (cacheresp_val),
    .out_resp_rdy (cacheresp_rdy),
    .out_resp_msg (cacheresp_msg)
  );

endmodule


`endif  /* RISCV_CACHE_BYPASS_V */
