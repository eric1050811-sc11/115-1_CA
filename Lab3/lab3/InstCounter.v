//=========================================================================
// RV32IM Functional Simulator for Instruction Counting
//=========================================================================
// Loads the same .vmh program as the test memory, starts at the reset
// vector 0x00080000, and executes instructions architecturally (no
// timing) until the program writes a non-zero value to the status CSR
// (csrw 21). The resulting count includes that csrw.
//
// Usage (from Pattern):
//
//   InstCounter #( .p_mem_sz(...) ) inst_counter();
//   ...
//   inst_counter.run( exe_filename, max_inst );
//   // inst_counter.num_inst / num_inst_stats / status / error are valid
//

`ifndef RISCV_INST_COUNTER_V
`define RISCV_INST_COUNTER_V

module InstCounter
#(
  parameter p_mem_sz = 1 << 20  // size of memory in bytes
);

  localparam c_num_words = p_mem_sz / 4;
  localparam c_addr_sz   = $clog2(p_mem_sz);

  localparam c_reset_vector = 32'h00080000;
  localparam c_csr_stats    = 12'd10;
  localparam c_csr_status   = 12'd21;

  //--------------------------------------------------------------------
  // Architectural state
  //--------------------------------------------------------------------

  reg [31:0] m[0:c_num_words-1];
  reg [31:0] rf[31:0];
  reg [31:0] pc;

  // Results

  reg [31:0] num_inst;        // instructions executed until status != 0
  reg [31:0] num_inst_stats;  // instructions between the csrw that enables
                              // stats and the csrw that disables it
                              // (both csrw excluded)
  reg [31:0] status;
  reg        stats_en;
  reg        error;           // unsupported instruction or max_inst hit

  //--------------------------------------------------------------------
  // Memory helpers (byte granularity, little endian)
  //--------------------------------------------------------------------

  function [7:0] rd_byte;
    input [31:0] addr;
    reg   [c_addr_sz-1:0] a;
    begin
      a       = addr[c_addr_sz-1:0];
      rd_byte = m[a >> 2] >> ( 8 * a[1:0] );
    end
  endfunction

  task wr_byte;
    input [31:0] addr;
    input  [7:0] data;
    reg   [c_addr_sz-1:0] a;
    begin
      a = addr[c_addr_sz-1:0];
      case ( a[1:0] )
        2'd0 : m[a >> 2][ 7: 0] = data;
        2'd1 : m[a >> 2][15: 8] = data;
        2'd2 : m[a >> 2][23:16] = data;
        2'd3 : m[a >> 2][31:24] = data;
      endcase
    end
  endtask

  //--------------------------------------------------------------------
  // Execute one instruction
  //--------------------------------------------------------------------

  reg [31:0] inst;
  reg  [6:0] opcode;
  reg  [4:0] rd;
  reg  [2:0] funct3;
  reg  [4:0] rs1;
  reg  [4:0] rs2;
  reg  [6:0] funct7;
  reg [31:0] a;
  reg [31:0] b;
  reg [31:0] imm_i;
  reg [31:0] imm_s;
  reg [31:0] imm_b;
  reg [31:0] imm_u;
  reg [31:0] imm_j;
  reg [31:0] addr;
  reg  [7:0] ld0, ld1, ld2, ld3;
  reg [31:0] result;
  reg        wen;
  reg [31:0] next_pc;
  reg        stats_en_prev;

  task step;
    begin
      stats_en_prev = stats_en;

      inst = { rd_byte( pc + 3 ), rd_byte( pc + 2 ),
               rd_byte( pc + 1 ), rd_byte( pc     ) };

      opcode = inst[6:0];
      rd     = inst[11:7];
      funct3 = inst[14:12];
      rs1    = inst[19:15];
      rs2    = inst[24:20];
      funct7 = inst[31:25];

      a = rf[rs1];
      b = rf[rs2];

      imm_i = { {20{inst[31]}}, inst[31:20] };
      imm_s = { {20{inst[31]}}, inst[31:25], inst[11:7] };
      imm_b = { {19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0 };
      imm_u = { inst[31:12], 12'b0 };
      imm_j = { {11{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0 };

      next_pc = pc + 4;
      wen     = 1'b0;
      result  = 32'b0;

      case ( opcode )

        7'b0110111 : begin wen = 1'b1; result = imm_u;      end // LUI
        7'b0010111 : begin wen = 1'b1; result = pc + imm_u; end // AUIPC

        7'b1101111 : begin                                      // JAL
          wen     = 1'b1;
          result  = pc + 4;
          next_pc = pc + imm_j;
        end

        7'b1100111 : begin                                      // JALR
          if ( funct3 != 3'b000 ) error = 1'b1;
          wen     = 1'b1;
          result  = pc + 4;
          next_pc = ( a + imm_i ) & ~32'b1;
        end

        7'b1100011 : begin                                      // Branches
          case ( funct3 )
            3'b000 : if ( a == b )                     next_pc = pc + imm_b;
            3'b001 : if ( a != b )                     next_pc = pc + imm_b;
            3'b100 : if ( $signed(a) <  $signed(b) )   next_pc = pc + imm_b;
            3'b101 : if ( $signed(a) >= $signed(b) )   next_pc = pc + imm_b;
            3'b110 : if ( a <  b )                     next_pc = pc + imm_b;
            3'b111 : if ( a >= b )                     next_pc = pc + imm_b;
            default: error = 1'b1;
          endcase
        end

        7'b0000011 : begin                                      // Loads
          addr = a + imm_i;
          ld0  = rd_byte( addr     );
          ld1  = rd_byte( addr + 1 );
          ld2  = rd_byte( addr + 2 );
          ld3  = rd_byte( addr + 3 );
          wen  = 1'b1;
          case ( funct3 )
            3'b000 : result = { {24{ld0[7]}}, ld0 };            // LB
            3'b001 : result = { {16{ld1[7]}}, ld1, ld0 };       // LH
            3'b010 : result = { ld3, ld2, ld1, ld0 };           // LW
            3'b100 : result = { 24'b0, ld0 };                   // LBU
            3'b101 : result = { 16'b0, ld1, ld0 };              // LHU
            default: begin wen = 1'b0; error = 1'b1; end
          endcase
        end

        7'b0100011 : begin                                      // Stores
          addr = a + imm_s;
          case ( funct3 )
            3'b000 : wr_byte( addr, b[7:0] );
            3'b001 : begin
              wr_byte( addr,     b[ 7:0] );
              wr_byte( addr + 1, b[15:8] );
            end
            3'b010 : begin
              wr_byte( addr,     b[ 7: 0] );
              wr_byte( addr + 1, b[15: 8] );
              wr_byte( addr + 2, b[23:16] );
              wr_byte( addr + 3, b[31:24] );
            end
            default: error = 1'b1;
          endcase
        end

        7'b0010011 : begin                                      // Reg-imm ALU
          wen = 1'b1;
          case ( funct3 )
            3'b000 : result = a + imm_i;
            3'b010 : result = { 31'b0, $signed(a) < $signed(imm_i) };
            3'b011 : result = { 31'b0, a < imm_i };
            3'b100 : result = a ^ imm_i;
            3'b110 : result = a | imm_i;
            3'b111 : result = a & imm_i;
            3'b001 : if ( funct7 == 7'b0000000 ) result = a << rs2;
                     else begin wen = 1'b0; error = 1'b1; end
            3'b101 : if ( funct7 == 7'b0000000 ) result = a >> rs2;
                     else if ( funct7 == 7'b0100000 ) result = $signed(a) >>> rs2;
                     else begin wen = 1'b0; error = 1'b1; end
          endcase
        end

        7'b0110011 : begin                                      // Reg-reg ALU
          wen = 1'b1;
          case ( { funct7, funct3 } )
            { 7'b0000000, 3'b000 } : result = a + b;
            { 7'b0100000, 3'b000 } : result = a - b;
            { 7'b0000000, 3'b001 } : result = a << b[4:0];
            { 7'b0000000, 3'b010 } : result = { 31'b0, $signed(a) < $signed(b) };
            { 7'b0000000, 3'b011 } : result = { 31'b0, a < b };
            { 7'b0000000, 3'b100 } : result = a ^ b;
            { 7'b0000000, 3'b101 } : result = a >> b[4:0];
            { 7'b0100000, 3'b101 } : result = $signed(a) >>> b[4:0];
            { 7'b0000000, 3'b110 } : result = a | b;
            { 7'b0000000, 3'b111 } : result = a & b;

            { 7'b0000001, 3'b000 } : result = a * b;            // MUL
            { 7'b0000001, 3'b100 } :                            // DIV
              if ( b == 0 )                                   result = 32'hffffffff;
              else if ( a == 32'h80000000 && b == 32'hffffffff ) result = a;
              else                                            result = $signed(a) / $signed(b);
            { 7'b0000001, 3'b101 } :                            // DIVU
              result = ( b == 0 ) ? 32'hffffffff : a / b;
            { 7'b0000001, 3'b110 } :                            // REM
              if ( b == 0 )                                   result = a;
              else if ( a == 32'h80000000 && b == 32'hffffffff ) result = 32'b0;
              else                                            result = $signed(a) % $signed(b);
            { 7'b0000001, 3'b111 } :                            // REMU
              result = ( b == 0 ) ? a : a % b;

            default: begin wen = 1'b0; error = 1'b1; end
          endcase
        end

        7'b1110011 : begin                                      // CSRW
          if ( funct3 == 3'b001 ) begin
            case ( inst[31:20] )
              c_csr_stats  : stats_en = a[0];
              c_csr_status : status   = a;
              default      : ;
            endcase
          end
          else
            error = 1'b1;
        end

        default : error = 1'b1;

      endcase

      if ( error ) begin
        $display( " [InstCounter] ERROR: unsupported instruction 0x%h at pc 0x%h",
                  inst, pc );
      end
      else begin
        if ( wen && rd != 5'd0 )
          rf[rd] = result;

        num_inst = num_inst + 1;
        // Count only if stats was on both before and after this
        // instruction, so neither the enabling nor the disabling csrw
        // is counted.

        if ( stats_en_prev && stats_en )
          num_inst_stats = num_inst_stats + 1;

        pc = next_pc;
      end
    end
  endtask

  //--------------------------------------------------------------------
  // Load program and run to completion
  //--------------------------------------------------------------------

  integer i;

  task run;
    input [1023:0] filename;
    input   [31:0] max_inst;
    begin
      for ( i = 0; i < c_num_words; i = i + 1 )
        m[i] = 32'b0;
      for ( i = 0; i < 32; i = i + 1 )
        rf[i] = 32'b0;

      $readmemh( filename, m );

      pc             = c_reset_vector;
      num_inst       = 32'b0;
      num_inst_stats = 32'b0;
      status         = 32'b0;
      stats_en       = 1'b0;
      error          = 1'b0;

      while ( status == 0 && !error && num_inst < max_inst )
        step;

      if ( !error && status == 0 ) begin
        $display( " [InstCounter] ERROR: no status write within %0d instructions",
                  max_inst );
        error = 1'b1;
      end
    end
  endtask

endmodule

`endif
