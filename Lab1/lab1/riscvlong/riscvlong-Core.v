//=========================================================================
// 5-Stage RISCV Core
//=========================================================================

`ifndef RISCV_CORE_V
`define RISCV_CORE_V

`include "vc-MemReqMsg.v"
`include "vc-MemRespMsg.v"
`include "riscvlong-CoreCtrl.v"
`include "riscvlong-CoreDpath.v"
`include "riscvlong-CoreDpathPipeMulDiv.v"

module riscv_Core
(
  input         clk,
  input         reset,

  // Instruction Memory Request Port

  output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq_msg,
  output                                 imemreq_val,
  input                                  imemreq_rdy,

  // Instruction Memory Response Port

  input [`VC_MEM_RESP_MSG_SZ(32)-1:0] imemresp_msg,
  input                               imemresp_val,
  output                              imemresp_rdy,

  // Data Memory Request Port

  output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] dmemreq_msg,
  output                                 dmemreq_val,
  input                                  dmemreq_rdy,

  // Data Memory Response Port

  input [`VC_MEM_RESP_MSG_SZ(32)-1:0] dmemresp_msg,
  input                               dmemresp_val,
  output                              dmemresp_rdy,

  // CSR Status Register Output to Host

  output [31:0] csr_status,

  // Retire Interface

  output        retire_valid
);

  wire [31:0] imemreq_msg_addr;
  wire [31:0] imemreq_msg_addr_next;
  wire [31:0] imemresp_msg_data;

  wire        dmemreq_msg_rw;
  wire  [1:0] dmemreq_msg_len;
  wire [31:0] dmemreq_msg_addr;
  wire [31:0] dmemreq_msg_data;
  wire [31:0] dmemresp_msg_data;

  wire  [1:0] pc_mux_sel_Phl;
  wire  [2:0] data0_byp_mux_sel_Dhl;
  wire  [2:0] data1_byp_mux_sel_Dhl;
  wire  [1:0] op0_mux_sel_Dhl;
  wire  [2:0] op1_mux_sel_Dhl;
  wire [31:0] inst_Dhl;
  wire  [3:0] alu_fn_Xhl;
  wire  [2:0] muldivreq_msg_fn_Dhl;
  wire  [2:0] muldivreq_msg_fn_Xhl;
  wire        muldivreq_val_Dhl;
  wire        muldivreq_rdy_Dhl;
  wire        muldivreq_val;
  wire        muldivreq_rdy;
  wire        muldivresp_val;
  wire        muldivresp_rdy;
  wire        muldiv_mux_sel_Xhl;
  wire        execute_mux_sel_Xhl;
  wire  [2:0] dmemresp_mux_sel_Mhl;
  wire        wb_mux_sel_Mhl;
  wire        wb_mux_sel_X3hl;
  wire        rf_wen_Whl;
  wire  [4:0] rf_waddr_Whl;
  wire        stall_Fhl;
  wire        stall_Dhl;
  wire        stall_Xhl;
  wire        stall_Mhl;
  wire        stall_X2hl;
  wire        stall_X3hl;
  wire        stall_Whl;
  wire        squash_Fhl;
  wire        imem_initial_fetch_Fhl;
  wire        imemreq_pending_Fhl;

  wire  [4:0] inst_rd_Xhl;
  wire  [4:0] inst_rd_Mhl;
  wire  [4:0] inst_rd_X2hl;
  wire  [4:0] inst_rd_X3hl;
  wire  [4:0] inst_rd_Whl;

  wire        branch_cond_eq_Xhl;
  wire        branch_cond_ne_Xhl;
  wire        branch_cond_lt_Xhl;
  wire        branch_cond_ltu_Xhl;
  wire        branch_cond_ge_Xhl;
  wire        branch_cond_geu_Xhl;
  wire [31:0] proc2csr_data_Whl;

  //----------------------------------------------------------------------
  // Pack Memory Request Messages
  //----------------------------------------------------------------------
  // hold the addr until req handshake finishes (when req_val but !req_rdy)

  reg [31:0] imemreq_msg_addr_hold;

  always @ ( posedge clk ) begin
    if ( reset ) begin
      imemreq_msg_addr_hold <= 32'h00080000;
    end
    else if ( imemreq_val && !imemreq_pending_Fhl ) begin
      imemreq_msg_addr_hold <= imemreq_msg_addr_next;
    end
  end

  assign imemreq_msg_addr
    = imemreq_pending_Fhl ? imemreq_msg_addr_hold
    :                       imemreq_msg_addr_next;

  vc_MemReqMsgToBits#(32,32) imemreq_msg_to_bits
  (
    .type (`VC_MEM_REQ_MSG_TYPE_READ),
    .addr (imemreq_msg_addr),
    .len  (2'd0),
    .data (32'bx),
    .bits (imemreq_msg)
  );

  vc_MemReqMsgToBits#(32,32) dmemreq_msg_to_bits
  (
    .type (dmemreq_msg_rw),
    .addr (dmemreq_msg_addr),
    .len  (dmemreq_msg_len),
    .data (dmemreq_msg_data),
    .bits (dmemreq_msg)
  );

  //----------------------------------------------------------------------
  // Unpack Memory Response Messages
  //----------------------------------------------------------------------

  vc_MemRespMsgFromBits#(32) imemresp_msg_from_bits
  (
    .bits (imemresp_msg),
    .type (),
    .len  (),
    .data (imemresp_msg_data)
  );

  vc_MemRespMsgFromBits#(32) dmemresp_msg_from_bits
  (
    .bits (dmemresp_msg),
    .type (),
    .len  (),
    .data (dmemresp_msg_data)
  );

  //----------------------------------------------------------------------
  // Control Unit
  //----------------------------------------------------------------------

  riscv_CoreCtrl ctrl
  (
    .clk                    (clk),
    .reset                  (reset),

    // Instruction Memory Port

    .imemreq_val            (imemreq_val),
    .imemreq_rdy            (imemreq_rdy),
    .imemresp_msg_data      (imemresp_msg_data),
    .imemresp_val           (imemresp_val),
    .imemresp_rdy           (imemresp_rdy),
    .imem_initial_fetch_Fhl (imem_initial_fetch_Fhl),
    .imemreq_pending_Fhl    (imemreq_pending_Fhl),

    // Data Memory Port

    .dmemreq_msg_rw         (dmemreq_msg_rw),
    .dmemreq_msg_len        (dmemreq_msg_len),
    .dmemreq_val            (dmemreq_val),
    .dmemreq_rdy            (dmemreq_rdy),
    .dmemresp_val           (dmemresp_val),
    .dmemresp_rdy           (dmemresp_rdy),

    // Controls Signals (ctrl->dpath)

    .pc_mux_sel_Phl         (pc_mux_sel_Phl),
    .data0_byp_mux_sel_Dhl  (data0_byp_mux_sel_Dhl),
    .data1_byp_mux_sel_Dhl  (data1_byp_mux_sel_Dhl),
    .op0_mux_sel_Dhl        (op0_mux_sel_Dhl),
    .op1_mux_sel_Dhl        (op1_mux_sel_Dhl),
    .inst_Dhl               (inst_Dhl),
    .alu_fn_Xhl             (alu_fn_Xhl),
    .muldivreq_msg_fn_Dhl   (muldivreq_msg_fn_Dhl),
    .muldivreq_msg_fn_Xhl   (muldivreq_msg_fn_Xhl),
    .muldivreq_val_Dhl      (muldivreq_val_Dhl),
    .muldivreq_rdy_Dhl      (muldivreq_rdy_Dhl),
    .muldivreq_val          (muldivreq_val),
    .muldivreq_rdy          (muldivreq_rdy),
    .muldivresp_val         (muldivresp_val),
    .muldivresp_rdy         (muldivresp_rdy),
    .muldiv_mux_sel_Xhl     (muldiv_mux_sel_Xhl),
    .execute_mux_sel_Xhl    (execute_mux_sel_Xhl),
    .dmemresp_mux_sel_Mhl   (dmemresp_mux_sel_Mhl),
    .wb_mux_sel_Mhl         (wb_mux_sel_Mhl),
    .wb_mux_sel_X3hl        (wb_mux_sel_X3hl),
    .rf_wen_out_Whl         (rf_wen_Whl),
    .rf_waddr_Whl           (rf_waddr_Whl),
    .squash_Fhl             (squash_Fhl),
    .stall_Fhl              (stall_Fhl),
    .stall_Dhl              (stall_Dhl),
    .stall_Xhl              (stall_Xhl),
    .stall_Mhl              (stall_Mhl),
    .stall_X2hl             (stall_X2hl),
    .stall_X3hl             (stall_X3hl),
    .stall_Whl              (stall_Whl),

    // Control Signals (dpath->ctrl)

    .inst_rd_Xhl            (inst_rd_Xhl),
    .inst_rd_Mhl            (inst_rd_Mhl),
    .inst_rd_X2hl           (inst_rd_X2hl),
    .inst_rd_X3hl           (inst_rd_X3hl),
    .inst_rd_Whl            (inst_rd_Whl),

    .branch_cond_eq_Xhl	    (branch_cond_eq_Xhl),
    .branch_cond_ne_Xhl	    (branch_cond_ne_Xhl),
    .branch_cond_lt_Xhl	    (branch_cond_lt_Xhl),
    .branch_cond_ltu_Xhl	  (branch_cond_ltu_Xhl),
    .branch_cond_ge_Xhl	    (branch_cond_ge_Xhl),
    .branch_cond_geu_Xhl	  (branch_cond_geu_Xhl),
    .proc2csr_data_Whl      (proc2csr_data_Whl),

    // CSR Status

    .csr_status             (csr_status),

    // Retire Interface

    .retire_valid           (retire_valid)
  );

  //----------------------------------------------------------------------
  // Datapath
  //----------------------------------------------------------------------

  riscv_CoreDpath dpath
  (
    .clk                     (clk),
    .reset                   (reset),

    // Instruction Memory Port

    .imemreq_msg_addr        (imemreq_msg_addr_next),

    // Data Memory Port

    .dmemreq_msg_addr        (dmemreq_msg_addr),
    .dmemreq_msg_data        (dmemreq_msg_data),
    .dmemresp_msg_data       (dmemresp_msg_data),

    // Controls Signals (ctrl->dpath)
    .imem_initial_fetch_Fhl  (imem_initial_fetch_Fhl),
    .pc_mux_sel_Phl          (pc_mux_sel_Phl),
    .data0_byp_mux_sel_Dhl   (data0_byp_mux_sel_Dhl),
    .data1_byp_mux_sel_Dhl   (data1_byp_mux_sel_Dhl),
    .op0_mux_sel_Dhl         (op0_mux_sel_Dhl),
    .op1_mux_sel_Dhl         (op1_mux_sel_Dhl),
    .inst_Dhl                (inst_Dhl),
    .alu_fn_Xhl              (alu_fn_Xhl),
    .muldivreq_msg_fn_Dhl    (muldivreq_msg_fn_Dhl),
    .muldivreq_msg_fn_Xhl    (muldivreq_msg_fn_Xhl),
    .muldivreq_val_Dhl       (muldivreq_val_Dhl),
    .muldivreq_rdy_Dhl       (muldivreq_rdy_Dhl),
    .muldivreq_val           (muldivreq_val),
    .muldivreq_rdy           (muldivreq_rdy),
    .muldivresp_val          (muldivresp_val),
    .muldivresp_rdy          (muldivresp_rdy),
    .muldiv_mux_sel_Xhl      (muldiv_mux_sel_Xhl),
    .execute_mux_sel_Xhl     (execute_mux_sel_Xhl),
    .dmemresp_mux_sel_Mhl    (dmemresp_mux_sel_Mhl),
    .wb_mux_sel_Mhl          (wb_mux_sel_Mhl),
    .wb_mux_sel_X3hl         (wb_mux_sel_X3hl),
    .rf_wen_Whl              (rf_wen_Whl),
    .rf_waddr_Whl            (rf_waddr_Whl),
    .squash_Fhl              (squash_Fhl),
    .stall_Fhl               (stall_Fhl),
    .stall_Dhl               (stall_Dhl),
    .stall_Xhl               (stall_Xhl),
    .stall_Mhl               (stall_Mhl),
    .stall_X2hl              (stall_X2hl),
    .stall_X3hl              (stall_X3hl),
    .stall_Whl               (stall_Whl),

    // Control Signals (dpath->ctrl)

    .inst_rd_Xhl             (inst_rd_Xhl),
    .inst_rd_Mhl             (inst_rd_Mhl),
    .inst_rd_X2hl            (inst_rd_X2hl),
    .inst_rd_X3hl            (inst_rd_X3hl),
    .inst_rd_Whl             (inst_rd_Whl),

    .branch_cond_eq_Xhl      (branch_cond_eq_Xhl),
    .branch_cond_ne_Xhl      (branch_cond_ne_Xhl),
    .branch_cond_lt_Xhl      (branch_cond_lt_Xhl),
    .branch_cond_ltu_Xhl     (branch_cond_ltu_Xhl),
    .branch_cond_ge_Xhl      (branch_cond_ge_Xhl),
    .branch_cond_geu_Xhl     (branch_cond_geu_Xhl),
    .proc2csr_data_Whl       (proc2csr_data_Whl)
  );

endmodule

`endif

// vim: set textwidth=0 ts=2 sw=2 sts=2 :
