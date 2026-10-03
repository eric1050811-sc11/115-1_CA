//=========================================================================
// 5-Stage RISCV Reorder Buffer
//=========================================================================

`ifndef RISCV_CORE_REORDERBUFFER_V
`define RISCV_CORE_REORDERBUFFER_V

`include "riscvooo-InstMsg.v"

module riscv_CoreReorderBuffer
(
  input               clk,
  input               reset,

  // From Decode
  input               rob_alloc_req_val,
  output              rob_alloc_req_rdy,
  input  [ 4:0]       rob_alloc_req_preg,
  output [`LOG_S-1:0] rob_alloc_resp_slot,

  // From Writeback
  input               rob_fill_val,
  input  [`LOG_S-1:0] rob_fill_slot,

  // To Commit
  output              rob_commit_wen,
  output [`LOG_S-1:0] rob_commit_slot,
  output [ 4:0]       rob_commit_rf_waddr
);

  // Original dummy ROB outputs
  // assign rob_alloc_req_rdy   = 1'b1;
  // assign rob_alloc_resp_slot = `LOG_S'b0;
  // assign rob_commit_wen      = 1'b0;
  // assign rob_commit_rf_waddr = 5'b0;
  // assign rob_commit_slot     = `LOG_S'b0;

  // ROB table
  reg              rob_valid   [`SLOTS-1:0];
  reg              rob_pending [`SLOTS-1:0];
  reg        [4:0] rob_phyreg  [`SLOTS-1:0];
  reg [`LOG_S-1:0] rob_headpt; // next entry to be commited
  reg [`LOG_S-1:0] rob_tailpt; // next available entry for allocation
  wire             rob_full = (rob_headpt == rob_tailpt && rob_valid[rob_headpt]);

  // ROB pointers
  always @(posedge clk) begin
    if (reset) begin
      rob_tailpt <= {`LOG_S{1'b0}};
    end
    else if (rob_alloc_req_val && !rob_full) begin
      rob_tailpt <= rob_tailpt + 1;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      rob_headpt <= {`LOG_S{1'b0}};
    end
    else if (rob_commit_wen) begin
      rob_headpt <= rob_headpt + 1;
    end
  end

  integer i;
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < `SLOTS; i++)
        rob_valid[i] <= 1'b0;
    end
    else begin
      for (i = 0; i < `SLOTS; i++)
        rob_valid[i] <= (rob_alloc_req_val && !rob_full && rob_tailpt == i) ? 1'b1
                      : (rob_commit_wen && rob_headpt == i) ? 1'b0
                      : rob_valid[i];
    end
  end

  integer j;
  always @(posedge clk) begin
    if (reset) begin
      for (j = 0; j < `SLOTS; j++)
        rob_pending[j] <= 1'b0;
    end
    else begin
      for (j = 0; j < `SLOTS; j++)
        rob_pending[j] <= (rob_alloc_req_val && !rob_full && rob_tailpt == j) ? 1'b1
                        : (rob_fill_val && rob_fill_slot == j) ? 1'b0
                        : rob_pending[j];
    end
  end

  integer k;
  always @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < `SLOTS; k++)
        rob_phyreg[k] <= 5'd0;
    end
    else if (rob_alloc_req_val && !rob_full) begin
      for (k = 0; k < `SLOTS; k++)
        rob_phyreg[k] <= (rob_tailpt == k) ? rob_alloc_req_preg : rob_phyreg[k];
    end
  end

  // Output
  assign rob_alloc_req_rdy   = !rob_full;
  assign rob_alloc_resp_slot = rob_tailpt;
  assign rob_commit_wen      = (rob_valid[rob_headpt] && !rob_pending[rob_headpt]);
  assign rob_commit_rf_waddr = rob_phyreg[rob_headpt];
  assign rob_commit_slot     = rob_headpt;

endmodule

`endif
