`ifndef RISCVM_CACHE_ALL_V
`define RISCVM_CACHE_ALL_V

`include "riscvmc-CacheIcache.v"
`include "riscvmc-CacheDcache.v"

module riscv_Cache_MyCache (
    input                                  clk,
    input                                  reset,

    input                                  imemreq_val,
    output                                 imemreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq_msg,

    input                                  dmemreq_val,
    output                                 dmemreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] dmemreq_msg,

    output                                 imemresp_val,
    input                                  imemresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   imemresp_msg,

    output                                 dmemresp_val,
    input                                  dmemresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   dmemresp_msg,

    output                                 cache0req_val,
    input                                  cache0req_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cache0req_msg,

    input                                  cache0resp_val,
    output                                 cache0resp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cache0resp_msg,

    output                                 cache1req_val,
    input                                  cache1req_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cache1req_msg,

    input                                  cache1resp_val,
    output                                 cache1resp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cache1resp_msg
);

  // TODO: Instantiate and connect your instruction and data caches.

endmodule

`endif  /* RISCVM_CACHE_ALL_V */
