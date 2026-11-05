//=========================================================================
// 7-Stage RISCV Scoreboard
//=========================================================================

`ifndef RISCV_CORE_SCOREBOARD_V
`define RISCV_CORE_SCOREBOARD_V

`define FUNC_UNIT_ALU 1 // FU A ALU
`define FUNC_UNIT_MEM 2 // FU A MEM
`define FUNC_UNIT_MUL 3 // FU A MUL
`define FUNC_UNIT_BLU 4 // FU B ALU

module riscv_CoreScoreboard
(
  input            clk              ,
  input            reset            ,

  input            inst_val_Dhl     ,

  input      [4:0] src00            ,
  input            src00_en         ,
  input      [4:0] src01            ,
  input            src01_en         ,
  input      [4:0] src10            ,
  input            src10_en         ,
  input      [4:0] src11            ,
  input            src11_en         ,

  output           stall_0_hazard   ,
  output           stall_1_hazard   ,

  output reg [3:0] src00_byp_mux_sel,
  output reg [3:0] src01_byp_mux_sel,
  output reg [3:0] src10_byp_mux_sel,
  output reg [3:0] src11_byp_mux_sel,

  input      [4:0] dstA             ,
  input            dstA_en          ,
  input            stall_A_Dhl      ,
  input            is_muldiv_A      ,
  input            is_load_A        ,

  input      [4:0] dstB             ,
  input            dstB_en          ,
  input            stall_B_Dhl      ,

  input            stall_X0hl       ,
  input            stall_X1hl
);

  localparam am_r0      = 4'd0; // Use rdata0
  localparam am_AX0_byp = 4'd1; // Bypass from X0
  localparam am_AX1_byp = 4'd2; // Bypass from X1
  localparam am_AX2_byp = 4'd3; // Bypass from X2
  localparam am_AX3_byp = 4'd4; // Bypass from X3
  localparam am_AW_byp  = 4'd5; // Bypass from W
  localparam am_BX0_byp = 4'd6; // Bypass from X0
  localparam am_BX1_byp = 4'd7; // Bypass from X1
  localparam am_BX2_byp = 4'd8; // Bypass from X2
  localparam am_BX3_byp = 4'd9; // Bypass from X3
  localparam am_BW_byp  = 4'd10; // Bypass from W

  // TODO: implement your scoreboard here!
  reg              pending         [31:0];
  reg [2:0]        functional_unit [31:0];
  reg [4:0]        reg_latency     [31:0];

  genvar r;
  generate
    for ( r = 0; r < 32; r = r + 1 ) begin: sc_row
      // TODO
      always @(posedge clk) begin
        if (reset) begin
          pending[r] <= 1'b0;
          functional_unit[r] <= 3'b0;
          reg_latency[r] <= 5'b0;
        end
        else if (dstA_en && r == dstA && dstA != 5'd0 && !stall_A_Dhl && inst_val_Dhl) begin
          pending[r] <= 1'b1;
          functional_unit[r] <= (is_muldiv_A) ? `FUNC_UNIT_MUL
                              : (is_load_A)   ? `FUNC_UNIT_MEM
                              :                 `FUNC_UNIT_ALU;
          reg_latency[r] <= 5'b10000;
        end
        else if (dstB_en && r == dstB && dstB != 5'd0 && !stall_B_Dhl && inst_val_Dhl) begin
          pending[r] <= 1'b1;
          functional_unit[r] <= `FUNC_UNIT_BLU;
          reg_latency[r] <= 5'b10000;
        end
        else begin
          pending[r] <= (reg_latency[r] == 5'b00001) ? 1'b0 : pending[r];
          reg_latency[r] <= ((reg_latency[r] == 5'b10000 && stall_X0hl) ||
                             (reg_latency[r] == 5'b01000 && stall_X1hl)) ? reg_latency[r] : (reg_latency[r] >> 1);
        end
      end
    end
  endgenerate

  // Outputs

  always @(*) begin
    src00_byp_mux_sel = 4'd0;
    if (src00_en && pending[src00]) begin
      case (functional_unit[src00])
        `FUNC_UNIT_ALU:
          case (reg_latency[src00])
            5'b10000: src00_byp_mux_sel = am_AX0_byp;
            5'b01000: src00_byp_mux_sel = am_AX1_byp;
            5'b00100: src00_byp_mux_sel = am_AX2_byp;
            5'b00010: src00_byp_mux_sel = am_AX3_byp;
            5'b00001: src00_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MEM:
          case (reg_latency[src00])
            5'b01000: src00_byp_mux_sel = am_AX1_byp;
            5'b00100: src00_byp_mux_sel = am_AX2_byp;
            5'b00010: src00_byp_mux_sel = am_AX3_byp;
            5'b00001: src00_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MUL:
          case (reg_latency[src00])
            5'b00010: src00_byp_mux_sel = am_AX3_byp;
            5'b00001: src00_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_BLU:
          case (reg_latency[src00])
            5'b10000: src00_byp_mux_sel = am_BX0_byp;
            5'b01000: src00_byp_mux_sel = am_BX1_byp;
            5'b00100: src00_byp_mux_sel = am_BX2_byp;
            5'b00010: src00_byp_mux_sel = am_BX3_byp;
            5'b00001: src00_byp_mux_sel = am_BW_byp;
          endcase
        default:;
      endcase
    end
  end

  always @(*) begin
    src01_byp_mux_sel = 4'd0;
    if (src01_en && pending[src01]) begin
      case (functional_unit[src01])
        `FUNC_UNIT_ALU:
          case (reg_latency[src01])
            5'b10000: src01_byp_mux_sel = am_AX0_byp;
            5'b01000: src01_byp_mux_sel = am_AX1_byp;
            5'b00100: src01_byp_mux_sel = am_AX2_byp;
            5'b00010: src01_byp_mux_sel = am_AX3_byp;
            5'b00001: src01_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MEM:
          case (reg_latency[src01])
            5'b01000: src01_byp_mux_sel = am_AX1_byp;
            5'b00100: src01_byp_mux_sel = am_AX2_byp;
            5'b00010: src01_byp_mux_sel = am_AX3_byp;
            5'b00001: src01_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MUL:
          case (reg_latency[src01])
            5'b00010: src01_byp_mux_sel = am_AX3_byp;
            5'b00001: src01_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_BLU:
          case (reg_latency[src01])
            5'b10000: src01_byp_mux_sel = am_BX0_byp;
            5'b01000: src01_byp_mux_sel = am_BX1_byp;
            5'b00100: src01_byp_mux_sel = am_BX2_byp;
            5'b00010: src01_byp_mux_sel = am_BX3_byp;
            5'b00001: src01_byp_mux_sel = am_BW_byp;
          endcase
        default:;
      endcase
    end
  end

  always @(*) begin
    src10_byp_mux_sel = 4'd0;
    if (src10_en && pending[src10]) begin
      case (functional_unit[src10])
        `FUNC_UNIT_ALU:
          case (reg_latency[src10])
            5'b10000: src10_byp_mux_sel = am_AX0_byp;
            5'b01000: src10_byp_mux_sel = am_AX1_byp;
            5'b00100: src10_byp_mux_sel = am_AX2_byp;
            5'b00010: src10_byp_mux_sel = am_AX3_byp;
            5'b00001: src10_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MEM:
          case (reg_latency[src10])
            5'b01000: src10_byp_mux_sel = am_AX1_byp;
            5'b00100: src10_byp_mux_sel = am_AX2_byp;
            5'b00010: src10_byp_mux_sel = am_AX3_byp;
            5'b00001: src10_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MUL:
          case (reg_latency[src10])
            5'b00010: src10_byp_mux_sel = am_AX3_byp;
            5'b00001: src10_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_BLU:
          case (reg_latency[src10])
            5'b10000: src10_byp_mux_sel = am_BX0_byp;
            5'b01000: src10_byp_mux_sel = am_BX1_byp;
            5'b00100: src10_byp_mux_sel = am_BX2_byp;
            5'b00010: src10_byp_mux_sel = am_BX3_byp;
            5'b00001: src10_byp_mux_sel = am_BW_byp;
          endcase
        default:;
      endcase
    end
  end

  always @(*) begin
    src11_byp_mux_sel = 4'd0;
    if (src11_en && pending[src11]) begin
      case (functional_unit[src11])
        `FUNC_UNIT_ALU:
          case (reg_latency[src11])
            5'b10000: src11_byp_mux_sel = am_AX0_byp;
            5'b01000: src11_byp_mux_sel = am_AX1_byp;
            5'b00100: src11_byp_mux_sel = am_AX2_byp;
            5'b00010: src11_byp_mux_sel = am_AX3_byp;
            5'b00001: src11_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MEM:
          case (reg_latency[src11])
            5'b01000: src11_byp_mux_sel = am_AX1_byp;
            5'b00100: src11_byp_mux_sel = am_AX2_byp;
            5'b00010: src11_byp_mux_sel = am_AX3_byp;
            5'b00001: src11_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_MUL:
          case (reg_latency[src11])
            5'b00010: src11_byp_mux_sel = am_AX3_byp;
            5'b00001: src11_byp_mux_sel = am_AW_byp;
          endcase
        `FUNC_UNIT_BLU:
          case (reg_latency[src11])
            5'b10000: src11_byp_mux_sel = am_BX0_byp;
            5'b01000: src11_byp_mux_sel = am_BX1_byp;
            5'b00100: src11_byp_mux_sel = am_BX2_byp;
            5'b00010: src11_byp_mux_sel = am_BX3_byp;
            5'b00001: src11_byp_mux_sel = am_BW_byp;
          endcase
        default:;
      endcase
    end
  end

  assign stall_0_hazard = (
    (src00_en && pending[src00]) && (
      (functional_unit[src00] == `FUNC_UNIT_MEM && reg_latency[src00] == 5'b10000) ||
      (functional_unit[src00] == `FUNC_UNIT_MUL && reg_latency[src00] >= 5'b00100)
    )
  ) || (
    (src01_en && pending[src01]) && (
      (functional_unit[src01] == `FUNC_UNIT_MEM && reg_latency[src01] == 5'b10000) ||
      (functional_unit[src01] == `FUNC_UNIT_MUL && reg_latency[src01] >= 5'b00100)
    )
  );

  assign stall_1_hazard = (
    (src10_en && pending[src10]) && (
      (functional_unit[src10] == `FUNC_UNIT_MEM && reg_latency[src10] == 5'b10000) ||
      (functional_unit[src10] == `FUNC_UNIT_MUL && reg_latency[src10] >= 5'b00100)
    )
  ) || (
    (src11_en && pending[src11]) && (
      (functional_unit[src11] == `FUNC_UNIT_MEM && reg_latency[src11] == 5'b10000) ||
      (functional_unit[src11] == `FUNC_UNIT_MUL && reg_latency[src11] >= 5'b00100)
    )
  );

endmodule

`endif
