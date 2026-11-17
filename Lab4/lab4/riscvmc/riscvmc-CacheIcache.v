`ifndef RISCVM_CACHE_ICACHE_V
`define RISCVM_CACHE_ICACHE_V

`include "riscvmc-CacheMsg.v"

module riscvmc_CacheIcache (
    input                                  clk,
    input                                  reset,

    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                                 memresp_val,
    input                                  memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cachereq_msg,

    input                                  cacheresp_val,
    output                                 cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cacheresp_msg
);

  // TODO: Implement your instruction cache.

endmodule

`endif  /* RISCVM_CACHE_ICACHE_V */
