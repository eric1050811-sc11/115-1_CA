//=========================================================================
// Processor Test Pattern
//=========================================================================

`ifndef RISCV_PATTERN_V
`define RISCV_PATTERN_V

`include "vc-MemReqMsg.v"
`include "vc-MemRespMsg.v"
`include "vc-TestDualPortRandDelayMem.v"

module Pattern
#(
  parameter p_max_delay          = 0,
  parameter p_reset_cycles       = 2,
  parameter p_default_max_cycles = 100000,
  parameter p_is_rand_delay      = 0
)(
  output reg                              clk,
  output reg                              reset_proc,
  output reg                              reset_mem,

  input      [31:0]                       status,
  input                                   retire_valid,

  input                                   memreq0_val,
  output                                  memreq0_rdy,
  input      [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq0_msg,

  output                                  memresp0_val,
  input                                   memresp0_rdy,
  output     [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp0_msg,

  input                                   memreq1_val,
  output                                  memreq1_rdy,
  input      [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq1_msg,

  output                                  memresp1_val,
  input                                   memresp1_rdy,
  output     [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp1_msg
);

  //--------------------------------------------------------------------
  // Clock and reset
  //--------------------------------------------------------------------

  initial begin
    clk = 1'b0;
  end

  always #5 clk = ~clk;

  initial begin
    reset_proc = 1'b1;
    reset_mem  = 1'b1;

    repeat ( p_reset_cycles ) @( negedge clk );

    reset_proc = 1'b0;
    reset_mem  = 1'b0;
  end

  //--------------------------------------------------------------------
  // Unified instruction/data test memory
  //--------------------------------------------------------------------

  localparam c_mem_sz        = (1 << 20);
  localparam c_mem_num_words = c_mem_sz / 4;

  vc_TestDualPortRandDelayMem
  #(
    .p_mem_sz    (c_mem_sz),
    .p_addr_sz   (32),
    .p_data_sz   (32),
    .p_max_delay (p_max_delay)
  )
  mem
  (
    .clk          (clk),
    .reset        (reset_mem),

    .memreq0_val  (memreq0_val),
    .memreq0_rdy  (memreq0_rdy),
    .memreq0_msg  (memreq0_msg),
    .memresp0_val (memresp0_val),
    .memresp0_rdy (memresp0_rdy),
    .memresp0_msg (memresp0_msg),

    .memreq1_val  (memreq1_val),
    .memreq1_rdy  (memreq1_rdy),
    .memreq1_msg  (memreq1_msg),
    .memresp1_val (memresp1_val),
    .memresp1_rdy (memresp1_rdy),
    .memresp1_msg (memresp1_msg)
  );

  //--------------------------------------------------------------------
  // Command-line configuration and program loading
  //--------------------------------------------------------------------

  integer      fh;
  reg [1023:0] exe_filename;
  reg [1023:0] vcd_filename;
  reg   [31:0] max_cycles;
  reg          verbose;
  reg          stats;
  reg          vcd;

  initial begin
    verbose = 1'b0;
    stats   = 1'b0;
    vcd     = 1'b0;

    if ( $value$plusargs( "exe=%s", exe_filename ) ) begin
      fh = $fopen( exe_filename, "r" );
      if ( !fh ) begin
        $display( "\n ERROR: Could not open vmh file (%s)! \n", exe_filename );
        $finish;
      end
      $fclose( fh );

      $readmemh( exe_filename, mem.mem.m, 0, c_mem_num_words-1 );
    end
    else begin
      $display( "\n ERROR: No executable specified! (use +exe=<filename>) \n" );
      $finish;
    end

    if ( !$value$plusargs( "max-cycles=%d", max_cycles ) ) begin
      max_cycles = p_default_max_cycles;
    end

    if ( $value$plusargs( "stats=%d", stats ) ) begin
      verbose = stats;
    end
    else if ( !$value$plusargs( "verbose=%d", verbose ) ) begin
      verbose = 1'b0;
    end

    if ( $value$plusargs( "vcd=%d", vcd ) && vcd ) begin
      if ( p_is_rand_delay ) begin
        vcd_filename = { exe_filename[1023:32], "-rand.vcd" };
      end
      else begin
        vcd_filename = { exe_filename[1023:32], ".vcd" };
      end

      $dumpfile( vcd_filename );
      $dumpvars( 0, Testbench );
    end
  end

  //--------------------------------------------------------------------
  // Performance counters
  //--------------------------------------------------------------------

  reg [31:0] num_cycles;
  reg [31:0] num_inst;

  always @( posedge clk ) begin
    if ( reset_proc ) begin
      num_cycles <= 32'b0;
      num_inst   <= 32'b0;
    end
    else begin
      num_cycles <= num_cycles + 1'b1;

      if ( retire_valid ) begin
        num_inst <= num_inst + 1'b1;
      end
    end
  end

  //--------------------------------------------------------------------
  // Completion and timeout handling
  //--------------------------------------------------------------------

  real ipc;

  // Sample on the falling edge so status and counters updated on the
  // preceding rising edge are stable before reporting results.

  always @( negedge clk ) begin
    if ( !reset_proc ) begin
      if ( status != 0 ) begin
        if ( status == 1 ) begin
          $display( "*** PASSED ***" );
        end
        else begin
          $display( "*** FAILED *** (status = %d)", status );
        end

        if ( verbose ) begin
          if ( num_cycles != 0 ) begin
            ipc = num_inst / $itor( num_cycles );
          end
          else begin
            ipc = 0.0;
          end

          $display( "--------------------------------------------" );
          $display( " STATS                                      " );
          $display( "--------------------------------------------" );
          $display( " status     = %d", status     );
          $display( " num_cycles = %d", num_cycles );
          $display( " num_inst   = %d", num_inst   );
          $display( " ipc        = %f", ipc        );
        end

        #20 $finish;
      end
      else if ( num_cycles > max_cycles ) begin
        $display( "*** FAILED *** (timeout)" );
        #20 $finish;
      end
    end
  end

endmodule

`endif
