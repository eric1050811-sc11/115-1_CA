//========================================================================
// vc-TestRandDelay : Insert random delays
//========================================================================

`ifndef VC_TEST_RAND_DELAY_V
`define VC_TEST_RAND_DELAY_V

`include "vc-StateElements.v"

module vc_TestRandDelay
#(
  parameter p_msg_sz    = 1, // size of message in bits
  parameter p_max_delay = 0, // fixed delay, or random upper bound
  parameter p_is_random = 1  // 0: fixed p_max_delay, 1: random delay
)(
  input  clk,
  input  reset,

  // Input interface

  input                     in_val,
  output reg                in_rdy,
  input      [p_msg_sz-1:0] in_msg,

  // Output interface

  output reg                out_val,
  input                     out_rdy,
  output     [p_msg_sz-1:0] out_msg
);

  //----------------------------------------------------------------------
  // State
  //----------------------------------------------------------------------

  // Random number generator

  reg [31:0] rand_num;

  generate
  if ( p_max_delay == 0 )
    always @( posedge clk ) begin
      rand_num <= 0;
    end
  else if ( p_is_random )
    always @( posedge clk ) begin
      rand_num <= {$random} % p_max_delay;
    end
  else
    always @( posedge clk ) begin
      rand_num <= p_max_delay;
    end
  endgenerate

  // Random delay counter

  reg         rand_delay_en;
  reg  [31:0] rand_delay_next;
  wire [31:0] rand_delay;
  reg  [p_msg_sz-1:0] delayed_msg;

  vc_ERDFF_pf#(32,32'b0) rand_delay_pf
  (
    .clk     (clk),
    .reset_p (reset),
    .en_p    (rand_delay_en),
    .d_p     (rand_delay_next),
    .q_np    (rand_delay)
  );

  //----------------------------------------------------------------------
  // Helper combinational logic
  //----------------------------------------------------------------------

  // A zero delay can pass through directly. For a nonzero delay, consume
  // and buffer one response before starting the counter.

  wire zero_cycle_delay = (rand_num == 0);

  //----------------------------------------------------------------------
  // State register
  //----------------------------------------------------------------------

  localparam c_state_sz    = 1;
  localparam c_state_idle  = 1'b0;
  localparam c_state_delay = 1'b1;

  reg [c_state_sz-1:0] state_next;
  reg [c_state_sz-1:0] state;

  always @ ( posedge clk ) begin
    if ( reset ) begin
      state <= c_state_idle;
    end
    else begin
      state <= state_next;
    end
  end

  //----------------------------------------------------------------------
  // State transitions
  //----------------------------------------------------------------------

  always @(*) begin

    // Default is to stay in the same state

    state_next = state;

    case ( state )

      // Move into delay state if a message arrives on the input
      // interface, except in the case when there is a zero cycle delay
      // (see definition of zero_cycle_delay signal above).

      c_state_idle:
        if ( in_val && !zero_cycle_delay ) begin
          state_next = c_state_delay;
        end

      // Move back into idle state once we have waited the correct number
      // of cycles and the output interface is ready so that we can
      // actually transfer the message.

      c_state_delay:
        if ( out_rdy && (rand_delay == 0) ) begin
          state_next = c_state_idle;
        end

    endcase

  end

  //----------------------------------------------------------------------
  // State output
  //----------------------------------------------------------------------

  always @(*) begin

    case ( state )

      c_state_idle:
      begin
        rand_delay_en   = in_val && !zero_cycle_delay;
        rand_delay_next = rand_num;
        in_rdy          = zero_cycle_delay ? out_rdy : 1'b1;
        out_val         = in_val && zero_cycle_delay;
      end

      c_state_delay:
      begin
        rand_delay_en   = (rand_delay > 0);
        rand_delay_next = rand_delay - 1;
        in_rdy          = 1'b0;
        out_val         = (rand_delay == 0);
      end

      default:
      begin
        rand_delay_en   = 1'bx;
        rand_delay_next = 32'bx;
        in_rdy          = 1'bx;
        out_val         = 1'bx;
      end

    endcase

  end

  //----------------------------------------------------------------------
  // Other combinational logic
  //----------------------------------------------------------------------

  always @( posedge clk ) begin
    if ( reset ) begin
      delayed_msg <= {p_msg_sz{1'b0}};
    end
    else if ( state == c_state_idle && in_val && !zero_cycle_delay ) begin
      delayed_msg <= in_msg;
    end
  end

  assign out_msg = (state == c_state_idle) ? in_msg : delayed_msg;

endmodule

`endif
