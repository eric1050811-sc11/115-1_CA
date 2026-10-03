//=========================================================================
// 5-Stage RISCV Scoreboard
//=========================================================================

`ifndef RISCV_CORE_SCOREBOARD_V
`define RISCV_CORE_SCOREBOARD_V

`define FUNC_UNIT_ALU 1
`define FUNC_UNIT_MEM 2
`define FUNC_UNIT_MUL 3

`include "riscvooo-InstMsg.v"


module riscv_CoreScoreboard
(
  input                   clk,
  input                   reset,
  input      [ 4:0]       src0,             // Source register 0
  input                   src0_en,          // Use source register 0
  input      [ 4:0]       src1,             // Source register 1
  input                   src1_en,          // Use source register 1
  input      [ 4:0]       dst,              // Destination register
  input                   dst_en,           // Write to destination register
  input      [ 2:0]       func_unit,        // Functional Unit
  input      [ 4:0]       latency,          // Instruction latency (one-hot)
  input                   inst_val_Dhl,     // Instruction valid
  input                   stall_Dhl,

  input      [`LOG_S-1:0] rob_alloc_slot,   // ROB slot allocated to dst reg
  input      [`LOG_S-1:0] rob_commit_slot,  // ROB slot emptied during commit
  input                   rob_commit_wen,   // ROB slot emptied during commit

  input      [ 4:0]       stalls,           // Input stall signals

  output reg [ 2:0]       src0_byp_mux_sel, // Source reg 0 byp mux
  output     [`LOG_S-1:0] src0_byp_rob_slot,// Source reg 0 ROB slot
  output reg [ 2:0]       src1_byp_mux_sel, // Source reg 1 byp mux
  output     [`LOG_S-1:0] src1_byp_rob_slot,// Source reg 1 ROB slot

  output                  stall_hazard,     // Destination register ready
  output     [ 1:0]       wb_mux_sel,       // Writeback mux sel out
  output                  stall_wb_hazard_M,
  output                  stall_wb_hazard_X
);

  reg              pending         [31:0];
  reg [2:0]        functional_unit [31:0];
  reg [4:0]        reg_latency     [31:0];
  reg [`LOG_S-1:0] reg_rob_slot    [31:0];

  reg [4:0]        wb_alu_latency;
  reg [4:0]        wb_mem_latency;
  reg [4:0]        wb_mul_latency;

  // Unpack the stall signal
  // wire [4:0] stalls_combined = {stall_Xhl, stall_Mhl, 1'b0, 1'b0, stall_Whl};
  wire stall_Xhl = stalls[4];
  wire stall_Mhl = stalls[3];
  wire stall_Whl = stalls[0];

  // Pending bit logic
  integer i;
  always @(posedge clk) begin
    if (reset) begin
      for (i = 0; i < 32; i++)
        pending[i] <= 1'b0;
    end
    else begin
      for (i = 0; i < 32; i++) begin
        if (!stall_Dhl && inst_val_Dhl && dst_en && dst == i && dst != 32'd0)
          pending[i] <= 1'b1;
        else if (rob_commit_wen && rob_commit_slot == reg_rob_slot[i])
          pending[i] <= 1'b0;
        else
          pending[i] <= pending[i];
      end
    end
  end

  // Latency logic
  //
  // ALU: X → W
  // MEM: X → M → W
  // MUL: X → M → X2 → X3 → W
  //
  // │ unit │ latency at issue │ bit 4 │ bit 3 │ bit 2 │ bit 1 │ bit 0 │
  // │ ALU  │ 00010            │ –     │ –     │ –     │ X     │ W     │
  // │ MEM  │ 00100            │ -     │ -     │ X     │ M     │ W     │
  // │ MUL  │ 10000            │ X     │ M     │ X2    │ X3    │ W     │
  //
  wire [4:0] ALU_stall_vec = {1'b0, 1'b0,      1'b0, stall_Xhl, stall_Whl};
  wire [4:0] MEM_stall_vec = {1'b0, 1'b0, stall_Xhl, stall_Mhl, stall_Whl};
  wire [4:0] MUL_stall_vec = stalls;

  integer j;
  always @(posedge clk) begin
    if (reset) begin
      for (j = 0; j < 32; j++)
        reg_latency[j] <= 5'd0;
    end
    else begin
      for (j = 0; j < 32; j++) begin
          reg_latency[j] <= (!stall_Dhl && inst_val_Dhl && dst_en && dst == j && dst != 32'd0) ? latency :
                            (
                              (functional_unit[j] == `FUNC_UNIT_ALU && |(reg_latency[j] & ALU_stall_vec)) ||
                              (functional_unit[j] == `FUNC_UNIT_MEM && |(reg_latency[j] & MEM_stall_vec)) ||
                              (functional_unit[j] == `FUNC_UNIT_MUL && |(reg_latency[j] & MUL_stall_vec))
                            )
                            ? reg_latency[j] : (reg_latency[j] >> 1);
      end
    end
  end

  // Functional unit logic
  integer k;
  always @(posedge clk) begin
    if (reset) begin
      for (k = 0; k < 32; k++)
        functional_unit[k] <= 3'd0;
    end
    else if (!stall_Dhl && inst_val_Dhl) begin
      for (k = 0; k < 32; k++)
        functional_unit[k] <= (dst_en && dst == k && dst != 32'd0) ? func_unit : functional_unit[k];
    end
  end

  // Re-order buffer logic
  integer l;
  always @(posedge clk) begin
    if (reset) begin
      for (l = 0; l < 32; l++)
        reg_rob_slot[l] <= {`LOG_S{1'd0}};
    end
    else if (!stall_Dhl && inst_val_Dhl) begin
      for (l = 0; l < 32; l++)
        reg_rob_slot[l] <= (dst_en && dst == l && dst != 32'd0) ? rob_alloc_slot : reg_rob_slot[l];
    end
  end

  // Bypass logic for src0
  // wire [31:0] op0_byp_mux_out_Dhl
  // = ( op0_byp_mux_sel_Dhl == 3'd0 ) ? rf_rdata0_Dhl
  // : ( op0_byp_mux_sel_Dhl == 3'd1 ) ? alu_out_Xhl
  // : ( op0_byp_mux_sel_Dhl == 3'd2 ) ? dmemresp_mux_out_Mhl
  // : ( op0_byp_mux_sel_Dhl == 3'd3 ) ? muldiv_mux_out_X3hl
  // : ( op0_byp_mux_sel_Dhl == 3'd4 ) ? wb_mux_out_Whl
  // : ( op0_byp_mux_sel_Dhl == 3'd5 ) ? rob_data[op0_byp_rob_slot_Dhl]
  // :                                   32'bx;
  reg stall0;
  always @(*) begin
    src0_byp_mux_sel = 3'd0;
    stall0 = 1'b0;
    if (src0_en && pending[src0]) begin
      if (reg_latency[src0] == 5'b00000) begin
        src0_byp_mux_sel = 3'd5; // bypass from ROB (already written to ROB, waiting for commit)
      end
      else begin
        case (functional_unit[src0])
          `FUNC_UNIT_ALU:
            if (reg_latency[src0] == 5'b00010) begin
              src0_byp_mux_sel = 3'd1; // bypass from X
            end
            else if (reg_latency[src0] == 5'b00001) begin
              src0_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall0 = 1'b1;
          `FUNC_UNIT_MEM:
            if (reg_latency[src0] == 5'b00010) begin
              src0_byp_mux_sel = 3'd2; // bypass from M
            end
            else if (reg_latency[src0] == 5'b00001) begin
              src0_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall0 = 1'b1;
          `FUNC_UNIT_MUL:
            if (reg_latency[src0] == 5'b00010) begin
              src0_byp_mux_sel = 3'd3; // bypass from X3
            end
            else if (reg_latency[src0] == 5'b00001)
            begin
              src0_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall0 = 1'b1;
        endcase
      end
    end
  end

  // Bypass logic for src1
  reg stall1;
  always @(*) begin
    src1_byp_mux_sel = 3'd0;
    stall1 = 1'b0;
    if (src1_en && pending[src1]) begin
      if (reg_latency[src1] == 5'b00000) begin
        src1_byp_mux_sel = 3'd5; // bypass from ROB (already written to ROB, waiting for commit)
      end
      else begin
        case (functional_unit[src1])
          `FUNC_UNIT_ALU:
            if (reg_latency[src1] == 5'b00010) begin
              src1_byp_mux_sel = 3'd1; // bypass from X
            end
            else if (reg_latency[src1] == 5'b00001) begin
              src1_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall1 = 1'b1;
          `FUNC_UNIT_MEM:
            if (reg_latency[src1] == 5'b00010) begin
              src1_byp_mux_sel = 3'd2; // bypass from M
            end
            else if (reg_latency[src1] == 5'b00001) begin
              src1_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall1 = 1'b1;
          `FUNC_UNIT_MUL:
            if (reg_latency[src1] == 5'b00010) begin
              src1_byp_mux_sel = 3'd3; // bypass from X3
            end
            else if (reg_latency[src1] == 5'b00001)
            begin
              src1_byp_mux_sel = 3'd4; // bypass from W
            end
            else
              stall1 = 1'b1;
        endcase
      end
    end
  end

  // Wb latency
  always @(posedge clk) begin
    if (reset) begin
      wb_alu_latency <= 5'd0;
      wb_mem_latency <= 5'd0;
      wb_mul_latency <= 5'd0;
    end
    else begin
      // Update on every instruction.
      // Stores, branches and csrw don't write a register, but they still have to reach W.
      wb_alu_latency <= (!stall_Dhl && inst_val_Dhl && func_unit == `FUNC_UNIT_ALU) ? ((wb_alu_latency >> 1) | latency) :
                        ((wb_alu_latency & ALU_stall_vec) | ((wb_alu_latency & ~ALU_stall_vec) >> 1));
      wb_mem_latency <= (!stall_Dhl && inst_val_Dhl && func_unit == `FUNC_UNIT_MEM) ? ((wb_mem_latency >> 1) | latency) :
                        ((wb_mem_latency & MEM_stall_vec) | ((wb_mem_latency & ~MEM_stall_vec) >> 1));
      wb_mul_latency <= (!stall_Dhl && inst_val_Dhl && func_unit == `FUNC_UNIT_MUL) ? ((wb_mul_latency >> 1) | latency) :
                        ((wb_mul_latency & MUL_stall_vec) | ((wb_mul_latency & ~MUL_stall_vec) >> 1));
    end
  end

  // Outputs
  assign stall_hazard = stall0 || stall1;
  assign src0_byp_rob_slot = reg_rob_slot[src0];
  assign src1_byp_rob_slot = reg_rob_slot[src1];

  assign wb_mux_sel = (wb_mul_latency[1]) ? `FUNC_UNIT_MUL :
                      (wb_mem_latency[1]) ? `FUNC_UNIT_MEM :
                      (wb_alu_latency[1]) ? `FUNC_UNIT_ALU :
                      2'd0;
  assign stall_wb_hazard_M = wb_mem_latency[1] && wb_mul_latency[1];
  assign stall_wb_hazard_X = wb_alu_latency[1] && (wb_mem_latency[1] || wb_mul_latency[1]);

endmodule

`endif

