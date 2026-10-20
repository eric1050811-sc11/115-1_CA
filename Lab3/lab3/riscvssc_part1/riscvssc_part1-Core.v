//=========================================================================
// 7-Stage RISCV Core
//=========================================================================

`ifndef RISCV_CORE_V
`define RISCV_CORE_V

`include "vc-MemReqMsg.v"
`include "vc-MemRespMsg.v"
`include "riscvssc_part1-CoreCtrl.v"
`include "riscvssc_part1-CoreDpath.v"

module riscv_Core
(
  input         clk,
  input         reset,

  // Instruction Memory Request Port

  output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq0_msg,
  output                                 imemreq0_val,
  input                                  imemreq0_rdy,

  // Instruction Memory Response Port

  input [`VC_MEM_RESP_MSG_SZ(32)-1:0] imemresp0_msg,
  input                               imemresp0_val,
  output                              imemresp0_rdy,

  // Instruction Memory Request Port

  output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] imemreq1_msg,
  output                                 imemreq1_val,
  input                                  imemreq1_rdy,

  // Instruction Memory Response Port

  input [`VC_MEM_RESP_MSG_SZ(32)-1:0] imemresp1_msg,
  input                               imemresp1_val,
  output                              imemresp1_rdy,

  // Data Memory Request Port

  output [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] dmemreq_msg,
  output                                 dmemreq_val,
  input                                  dmemreq_rdy,

  // Data Memory Response Port

  input [`VC_MEM_RESP_MSG_SZ(32)-1:0] dmemresp_msg,
  input                               dmemresp_val,
  output                              dmemresp_rdy,

  // CSR Status Register Output to Host

  output [31:0] csr_status
);

  wire [31:0] imemreq_msg_addr_next;
  wire [31:0] imemreq0_msg_addr;
  wire [31:0] imemresp0_msg_data;

  wire [31:0] imemreq1_msg_addr;
  wire [31:0] imemresp1_msg_data;

  wire        imem_initial_fetch_Fhl;
  wire        imemreq_start_Fhl;
  wire  [1:0] imemreq_pending_Fhl;

  wire        dmemreq_msg_rw;
  wire  [1:0] dmemreq_msg_len;
  wire [31:0] dmemreq_msg_addr;
  wire [31:0] dmemreq_msg_data;
  wire [31:0] dmemresp_msg_data;

  wire  [1:0] pc_mux_sel_Phl;
  wire        steering_mux_sel_Dhl;
  wire  [3:0] opA0_byp_mux_sel_Dhl;
  wire  [1:0] opA0_mux_sel_Dhl;
  wire  [3:0] opA1_byp_mux_sel_Dhl;
  wire  [2:0] opA1_mux_sel_Dhl;
  wire  [3:0] opB0_byp_mux_sel_Dhl;
  wire  [1:0] opB0_mux_sel_Dhl;
  wire  [3:0] opB1_byp_mux_sel_Dhl;
  wire  [2:0] opB1_mux_sel_Dhl;
  wire [31:0] instA_Dhl;
  wire [31:0] instB_Dhl;
  wire  [3:0] aluA_fn_X0hl;
  wire  [3:0] aluB_fn_X0hl;
  wire  [2:0] muldivreq_msg_fn_Dhl;
  wire        muldivreq_val;
  wire        muldivreq_rdy;
  wire        muldivresp_val;
  wire        muldivresp_rdy;
  wire  [2:0] dmemresp_mux_sel_X1hl;
  wire        muldiv_mux_sel_X3hl;
  wire        execute_mux_sel_X3hl;
  wire        memex_mux_sel_X1hl;
  wire        rfA_wen_Whl;
  wire  [4:0] rfA_waddr_Whl;
  wire        rfB_wen_Whl;
  wire  [4:0] rfB_waddr_Whl;
  wire        squash_Fhl;
  wire        stall_Fhl;
  wire        stall_Dhl;
  wire        stall_X0hl;
  wire        stall_X1hl;
  wire        stall_X2hl;
  wire        stall_X3hl;
  wire        stall_Whl;

  wire        branch_cond_eq_X0hl;
  wire        branch_cond_ne_X0hl;
  wire        branch_cond_lt_X0hl;
  wire        branch_cond_ltu_X0hl;
  wire        branch_cond_ge_X0hl;
  wire        branch_cond_geu_X0hl;
  wire [31:0] proc2csr_data_Whl;

  //----------------------------------------------------------------------
  // Instruction Memory Request Address
  //----------------------------------------------------------------------

  reg [31:0] imemreq_msg_addr_hold;

  always @ ( posedge clk ) begin
    if ( reset ) begin
      imemreq_msg_addr_hold <= 32'h00080000;
    end
    else if ( imemreq_start_Fhl ) begin
      imemreq_msg_addr_hold <= imemreq_msg_addr_next;
    end
  end

  assign imemreq0_msg_addr
    = imemreq_pending_Fhl[0] ? imemreq_msg_addr_hold
    :                          imemreq_msg_addr_next;

  assign imemreq1_msg_addr
    = ( imemreq_pending_Fhl[1] ? imemreq_msg_addr_hold
      :                          imemreq_msg_addr_next ) + 32'd4;

  //----------------------------------------------------------------------
  // Pack Memory Request Messages
  //----------------------------------------------------------------------

  vc_MemReqMsgToBits#(32,32) imemreq0_msg_to_bits
  (
    .type (`VC_MEM_REQ_MSG_TYPE_READ),
    .addr (imemreq0_msg_addr),
    .len  (2'd0),
    .data (32'bx),
    .bits (imemreq0_msg)
  );

  vc_MemReqMsgToBits#(32,32) imemreq1_msg_to_bits
  (
    .type (`VC_MEM_REQ_MSG_TYPE_READ),
    .addr (imemreq1_msg_addr),
    .len  (2'd0),
    .data (32'bx),
    .bits (imemreq1_msg)
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

  vc_MemRespMsgFromBits#(32) imemresp0_msg_from_bits
  (
    .bits (imemresp0_msg),
    .type (),
    .len  (),
    .data (imemresp0_msg_data)
  );

  vc_MemRespMsgFromBits#(32) imemresp1_msg_from_bits
  (
    .bits (imemresp1_msg),
    .type (),
    .len  (),
    .data (imemresp1_msg_data)
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

    .imemreq0_val            (imemreq0_val),
    .imemreq0_rdy            (imemreq0_rdy),
    .imemresp0_msg_data      (imemresp0_msg_data),
    .imemresp0_val           (imemresp0_val),
    .imemresp0_rdy           (imemresp0_rdy),

    // Instruction Memory Port

    .imemreq1_val            (imemreq1_val),
    .imemreq1_rdy            (imemreq1_rdy),
    .imemresp1_msg_data      (imemresp1_msg_data),
    .imemresp1_val           (imemresp1_val),
    .imemresp1_rdy           (imemresp1_rdy),

    // Instruction Fetch Sequencing (ctrl->core)

    .imem_initial_fetch_Fhl  (imem_initial_fetch_Fhl),
    .imemreq_start_Fhl       (imemreq_start_Fhl),
    .imemreq_pending_Fhl     (imemreq_pending_Fhl),

    // Data Memory Port

    .dmemreq_msg_rw         (dmemreq_msg_rw),
    .dmemreq_msg_len        (dmemreq_msg_len),
    .dmemreq_val            (dmemreq_val),
    .dmemreq_rdy            (dmemreq_rdy),
    .dmemresp_val           (dmemresp_val),
    .dmemresp_rdy           (dmemresp_rdy),

    // Controls Signals (ctrl->dpath)

    .pc_mux_sel_Phl          (pc_mux_sel_Phl),
    .steering_mux_sel_Dhl    (steering_mux_sel_Dhl),
    .opA0_byp_mux_sel_Dhl    (opA0_byp_mux_sel_Dhl),
    .opA0_mux_sel_Dhl        (opA0_mux_sel_Dhl),
    .opA1_byp_mux_sel_Dhl    (opA1_byp_mux_sel_Dhl),
    .opA1_mux_sel_Dhl        (opA1_mux_sel_Dhl),
    .opB0_byp_mux_sel_Dhl    (opB0_byp_mux_sel_Dhl),
    .opB0_mux_sel_Dhl        (opB0_mux_sel_Dhl),
    .opB1_byp_mux_sel_Dhl    (opB1_byp_mux_sel_Dhl),
    .opB1_mux_sel_Dhl        (opB1_mux_sel_Dhl),
    .instA_Dhl               (instA_Dhl),
    .instB_Dhl               (instB_Dhl),
    .aluA_fn_X0hl            (aluA_fn_X0hl),
    .aluB_fn_X0hl            (aluB_fn_X0hl),
    .muldivreq_msg_fn_Dhl    (muldivreq_msg_fn_Dhl),
    .muldivreq_val           (muldivreq_val),
    .muldivresp_rdy          (muldivresp_rdy),
    .dmemresp_mux_sel_X1hl   (dmemresp_mux_sel_X1hl),
    .muldiv_mux_sel_X3hl     (muldiv_mux_sel_X3hl),
    .execute_mux_sel_X3hl    (execute_mux_sel_X3hl),
    .memex_mux_sel_X1hl      (memex_mux_sel_X1hl),
    .rfA_wen_out_Whl         (rfA_wen_Whl),
    .rfA_waddr_Whl           (rfA_waddr_Whl),
    .rfB_wen_out_Whl         (rfB_wen_Whl),
    .rfB_waddr_Whl           (rfB_waddr_Whl),
    .squash_Fhl              (squash_Fhl),
    .stall_Fhl               (stall_Fhl),
    .stall_Dhl               (stall_Dhl),
    .stall_X0hl              (stall_X0hl),
    .stall_X1hl              (stall_X1hl),
    .stall_X2hl              (stall_X2hl),
    .stall_X3hl              (stall_X3hl),
    .stall_Whl               (stall_Whl),

    // Control Signals (dpath->ctrl)

    .branch_cond_eq_X0hl	  (branch_cond_eq_X0hl),
    .branch_cond_ne_X0hl	  (branch_cond_ne_X0hl),
    .branch_cond_lt_X0hl	  (branch_cond_lt_X0hl),
    .branch_cond_ltu_X0hl	  (branch_cond_ltu_X0hl),
    .branch_cond_ge_X0hl	  (branch_cond_ge_X0hl),
    .branch_cond_geu_X0hl	  (branch_cond_geu_X0hl),
    .proc2csr_data_Whl      (proc2csr_data_Whl),

    // CSR Status

    .csr_status             (csr_status)
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

    .imem_initial_fetch_Fhl   (imem_initial_fetch_Fhl),
    .squash_Fhl               (squash_Fhl),
    .pc_mux_sel_Phl           (pc_mux_sel_Phl),
    .steering_mux_sel_Dhl     (steering_mux_sel_Dhl),
    .opA0_byp_mux_sel_Dhl     (opA0_byp_mux_sel_Dhl),
    .opA0_mux_sel_Dhl         (opA0_mux_sel_Dhl),
    .opA1_byp_mux_sel_Dhl     (opA1_byp_mux_sel_Dhl),
    .opA1_mux_sel_Dhl         (opA1_mux_sel_Dhl),
    .opB0_byp_mux_sel_Dhl     (opB0_byp_mux_sel_Dhl),
    .opB0_mux_sel_Dhl         (opB0_mux_sel_Dhl),
    .opB1_byp_mux_sel_Dhl     (opB1_byp_mux_sel_Dhl),
    .opB1_mux_sel_Dhl         (opB1_mux_sel_Dhl),
    .instA_Dhl                (instA_Dhl),
    .instB_Dhl                (instB_Dhl),
    .aluA_fn_X0hl             (aluA_fn_X0hl),
    .aluB_fn_X0hl             (aluB_fn_X0hl),
    .muldivreq_msg_fn_Dhl     (muldivreq_msg_fn_Dhl),
    .muldivreq_val            (muldivreq_val),
    .muldivreq_rdy            (muldivreq_rdy),
    .muldivresp_val           (muldivresp_val),
    .muldivresp_rdy           (muldivresp_rdy),
    .dmemresp_mux_sel_X1hl    (dmemresp_mux_sel_X1hl),
    .muldiv_mux_sel_X3hl      (muldiv_mux_sel_X3hl),
    .execute_mux_sel_X3hl     (execute_mux_sel_X3hl),
    .memex_mux_sel_X1hl       (memex_mux_sel_X1hl),
    .rfA_wen_Whl              (rfA_wen_Whl),
    .rfA_waddr_Whl            (rfA_waddr_Whl),
    .rfB_wen_Whl              (rfB_wen_Whl),
    .rfB_waddr_Whl            (rfB_waddr_Whl),
    .stall_Fhl                (stall_Fhl),
    .stall_Dhl                (stall_Dhl),
    .stall_X0hl               (stall_X0hl),
    .stall_X1hl               (stall_X1hl),
    .stall_X2hl               (stall_X2hl),
    .stall_X3hl               (stall_X3hl),
    .stall_Whl                (stall_Whl),

    // Control Signals (dpath->ctrl)

    .branch_cond_eq_X0hl	   (branch_cond_eq_X0hl),
    .branch_cond_ne_X0hl	   (branch_cond_ne_X0hl),
    .branch_cond_lt_X0hl	   (branch_cond_lt_X0hl),
    .branch_cond_ltu_X0hl	   (branch_cond_ltu_X0hl),
    .branch_cond_ge_X0hl	   (branch_cond_ge_X0hl),
    .branch_cond_geu_X0hl	   (branch_cond_geu_X0hl),
    .proc2csr_data_Whl       (proc2csr_data_Whl)
  );

endmodule

`endif

// vim: set textwidth=0 ts=2 sw=2 sts=2 :