//=========================================================================
// 32-bit processor memory port to 128-bit backing-memory port
//=========================================================================

`ifndef VC_MEM_WIDTH_ADAPTER_V
`define VC_MEM_WIDTH_ADAPTER_V

`include "vc-MemReqMsg.v"
`include "vc-MemRespMsg.v"

module vc_MemWidthAdapter_32to128
(
  input                                  in_req_val,
  output                                 in_req_rdy,
  input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] in_req_msg,

  output                                 in_resp_val,
  input                                  in_resp_rdy,
  output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   in_resp_msg,

  output                                   out_req_val,
  input                                    out_req_rdy,
  output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] out_req_msg,

  input                                    out_resp_val,
  output                                   out_resp_rdy,
  input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]   out_resp_msg
);

  wire        req_type = in_req_msg[66];
  wire [31:0] req_addr = in_req_msg[65:34];
  wire [1:0]  req_len  = in_req_msg[33:32];
  wire [31:0] req_data = in_req_msg[31:0];

  // len=0 means the full width of its own interface. Translate a full
  // 32-bit processor access to an explicit four-byte memory access.
  wire [3:0] out_req_len = (req_len == 0) ? 4'd4 : {2'b0, req_len};

  wire        resp_type = out_resp_msg[132];
  wire [3:0]  resp_len  = out_resp_msg[131:128];
  wire [127:0] resp_data = out_resp_msg[127:0];
  wire [1:0] in_resp_len = (resp_len == 4) ? 2'b00 : resp_len[1:0];

  assign out_req_val  = in_req_val;
  assign in_req_rdy   = out_req_rdy;
  assign out_req_msg  = {req_type, req_addr, out_req_len, 96'b0, req_data};

  assign in_resp_val  = out_resp_val;
  assign out_resp_rdy = in_resp_rdy;
  assign in_resp_msg  = {resp_type, in_resp_len, resp_data[31:0]};

endmodule

`endif
