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




endmodule

`endif

