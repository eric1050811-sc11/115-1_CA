//====================================================================================
// Cache Base Design (Feel free to create your own design if you have a better one)
//====================================================================================

`ifndef RISCV_CACHE_BASE_V
`define RISCV_CACHE_BASE_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_CacheBase (
    input clk,
    input reset,

    input                                  memreq_val,
    output                                 memreq_rdy,
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,

    output                                 memresp_val,
    input                                  memresp_rdy,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,

    output                                 cachereq_val,
    input                                  cachereq_rdy,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cachereq_msg,

    input                                  cacheresp_val,
    output                                 cacheresp_rdy,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cacheresp_msg
);

wire       memreq_en;
wire       tag_wen;
wire       data_wen;
wire       write_data_mux_sel;
wire       miss;
wire       refill_cnt_en;
wire       refill_cnt_clr;

wire [2:0] state;
wire       type;
wire       tag_match;
wire       valid_bit;
wire       dirty_bit;
wire [3:0] refill_counter;

riscv_CacheBaseDpath dpath
(
    .clk                   (clk),
    .reset                 (reset),

    .memreq_msg            (memreq_msg),
    .cacheresp_msg         (cacheresp_msg),
    .memresp_msg           (memresp_msg),
    .cachereq_msg          (cachereq_msg),

    .state                 (state),
    .memreq_en             (memreq_en),
    .tag_wen               (tag_wen),
    .data_wen              (data_wen),
    .write_data_mux_sel    (write_data_mux_sel),
    .miss                  (miss),
    .refill_cnt_en         (refill_cnt_en),
    .refill_cnt_clr        (refill_cnt_clr),

    .type                  (type),
    .tag_match             (tag_match),
    .valid_bit             (valid_bit),
    .dirty_bit             (dirty_bit),
    .refill_counter        (refill_counter)
);

riscv_CacheBaseCtrl ctrl
(
    .clk                   (clk),
    .reset                 (reset),

    .memreq_val            (memreq_val),
    .memreq_rdy            (memreq_rdy),
    .memresp_val           (memresp_val),
    .memresp_rdy           (memresp_rdy),
    .cachereq_val          (cachereq_val),
    .cachereq_rdy          (cachereq_rdy),
    .cacheresp_val         (cacheresp_val),
    .cacheresp_rdy         (cacheresp_rdy),

    .type                  (type),
    .tag_match             (tag_match),
    .valid_bit             (valid_bit),
    .dirty_bit             (dirty_bit),
    .refill_counter        (refill_counter),

    .state                 (state),
    .memreq_en             (memreq_en),
    .tag_wen               (tag_wen),
    .data_wen              (data_wen),
    .write_data_mux_sel    (write_data_mux_sel),
    .miss                  (miss),
    .refill_cnt_en         (refill_cnt_en),
    .refill_cnt_clr        (refill_cnt_clr)
);

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module riscv_CacheBaseDpath (
    input         clk,
    input         reset,

    // msg
    // from/to processor
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    output [`VC_MEM_RESP_MSG_SZ(32)-1:0]   memresp_msg,
    // from/to memory
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cacheresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cachereq_msg,

    // control signal
    input      [2:0]  state,               // FSM state
    input             memreq_en,           // memreq enable
    input             tag_wen,             // tag cache write enable
    input             data_wen,            // data cache write enable
    input             write_data_mux_sel,  // write data is hit data or miss data
    input             miss,                // cache miss
    input             refill_cnt_en,       // refill counter enable
    input             refill_cnt_clr,      // refill counter clear

    output            type,                // read or write
    output            tag_match,           // tag is match
    output            valid_bit,           // cache block is valid
    output            dirty_bit,           // cache block is dirty
    output reg [3:0]  refill_counter       // 128-bit refill beat counter
);

//------------------------------------------------------------------------
// Combinational logic
//------------------------------------------------------------------------

// message
wire        memreq_type = memreq_msg[66];
wire [31:0] memreq_addr = memreq_msg[65:34];
wire [1:0]  memreq_len  = memreq_msg[33:32];
wire [31:0] memreq_data = memreq_msg[31: 0];

// latched addresses
wire [31:0] memreq_addr_r = memreq_addr_reg;
wire [`OFF_BITS-1:0] offset_r = memreq_addr_r[ 5: 0]; // 6 bits
wire [`IDX_BITS-1:0] index_r  = memreq_addr_r[10: 6]; // 5 bits
wire [`TAG_BITS-1:0] tag_r    = memreq_addr_r[31:11]; // 21 bits

wire [127:0] cacheresp_data = cacheresp_msg[127:0];

// address
wire [`OFF_BITS-1:0] offset = memreq_addr[ 5: 0]; // 6 bits
wire [`IDX_BITS-1:0] index  = memreq_addr[10: 6]; // 5 bits
wire [`TAG_BITS-1:0] tag    = memreq_addr[31:11]; // 21 bits

// extract tag and status bits {valid, dirty, tag}
wire [`TAG_BITS-1:0] read_tag  = read_tagS[`TAG_BITS-1:0];
assign               dirty_bit = read_tagS[`TAG_BITS];
assign               valid_bit = read_tagS[`TAG_BITS+1];

// compare tag
assign tag_match = ( tag_r == read_tag );

// output request type to control
assign type = memreq_type_reg;

// read hit
reg [31:0] read_data_hit;
always@ ( * ) begin
    case ( memreq_len_reg )
        2'b01: read_data_hit = read_data[offset_r*8 +: 8];
        2'b10: read_data_hit = read_data[offset_r*8 +: 16];
        2'b11: read_data_hit = read_data[offset_r*8 +: 24];
        2'b00: read_data_hit = read_data[offset_r*8 +: 32];
    endcase
end

// read miss
// not used here
reg [31:0] read_data_miss;
always@ ( * ) begin
    case ( memreq_len_reg )
        2'b01: read_data_miss = read_data[offset_r*8 +: 8];
        2'b10: read_data_miss = read_data[offset_r*8 +: 16];
        2'b11: read_data_miss = read_data[offset_r*8 +: 24];
        2'b00: read_data_miss = read_data[offset_r*8 +: 32];
    endcase
end

// write hit
reg [`BLK_SIZE-1:0] write_data_hit;
always@ ( * ) begin
    write_data_hit = read_data;
    case ( memreq_len_reg )
        2'b01: write_data_hit = memreq_data_reg[7:0];
        2'b10: write_data_hit = memreq_data_reg[15:0];
        2'b11: write_data_hit = memreq_data_reg[23:0];
        2'b00: write_data_hit = memreq_data_reg[31:0];
    endcase
end

// write miss
reg [`BLK_SIZE-1:0] write_data_miss;
always@ ( * ) begin
    write_data_miss = refill_data;
    if ( memreq_type_reg == `WRITE ) begin
        case ( memreq_len_reg )
            2'b01: write_data_miss = memreq_data_reg[7:0];
            2'b10: write_data_miss = memreq_data_reg[15:0];
            2'b11: write_data_miss = memreq_data_reg[23:0];
            2'b00: write_data_miss = memreq_data_reg[31:0];
        endcase
    end
end

wire [`BLK_SIZE-1:0] write_data_mux_out = ( write_data_mux_sel ) ? write_data_miss : write_data_hit;

// set write tagS
wire [22:0] write_tagS = {2'b10, tag_r}; // valid and clean, just read from memory

// refill address (advance by `MEM_BEAT_BYTES for each beat)
wire [31:0] refill_addr = {memreq_addr_r[31:6], 6'd0} + refill_counter * `MEM_BEAT_BYTES;

//------------------------------------------------------------------------
// Sequential logic
//------------------------------------------------------------------------

// store data if missing
reg        memreq_type_reg;
reg [31:0] memreq_addr_reg;
reg [1:0]  memreq_len_reg;
reg [31:0] memreq_data_reg;
always@ ( posedge clk ) begin
    if ( memreq_en ) begin
        memreq_type_reg <= memreq_type;
        memreq_addr_reg <= memreq_addr;
        memreq_len_reg  <= memreq_len;
        memreq_data_reg <= memreq_data;
    end
end

// store data when missing
// not used here
reg [`BLK_SIZE-1:0] read_data_reg;
reg [22:0]          read_tagS_reg;
always@ ( posedge clk ) begin
    if ( miss ) begin
        read_data_reg <= read_data;
        read_tagS_reg <= read_tagS;
    end
end

// refill counter
always@ ( posedge clk ) begin
    if ( refill_cnt_clr ) begin
        refill_counter <= 4'd0;
    end
    else if ( refill_cnt_en ) begin
        refill_counter <= refill_counter + 1;
    end
end

// refill data (write cacheresp_data into a 128-bit block slice)
reg [`BLK_SIZE-1:0] refill_data;
always@ ( posedge clk ) begin
    if ( reset ) begin
        refill_data <= 512'b0;
    end
    else if ( refill_cnt_en ) begin
        refill_data <= {cacheresp_data, (refill_data[511:128])};
    end
end

//------------------------------------------------------------------------
// FSM output msg
//------------------------------------------------------------------------

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;

reg [34:0] memresp_msg_reg;
reg [164:0] cachereq_msg_reg;

always@ (*) begin

    memresp_msg_reg   = 35'b0;
    cachereq_msg_reg  = {1'b0, refill_addr, 4'd0, 128'b0}; // instruction cache read only, get full 16 bytes

    case ( state )
        READ_CACHE: begin
            memresp_msg_reg   = {1'b0, memreq_len_reg, read_data_hit};
        end
        DONE: begin
            memresp_msg_reg   = {1'b0, memreq_len_reg, read_data_hit};
        end
    endcase
end

assign memresp_msg   = memresp_msg_reg;
assign cachereq_msg  = cachereq_msg_reg;

//------------------------------------------------------------------------
// I-cache RAM module
// 2KiB, direct-mapped cache with 64B blocks
// 32 entries, 2^5, [4:0]
//------------------------------------------------------------------------

wire [22:0]          read_tagS;
wire [`BLK_SIZE-1:0] read_data;

// direct-mapped
vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (512), // 64B=512b per block
    .ENTRIES     (32),
    .ADDR_SZ     (5),
    .RESET_VALUE (0)
) _data (
    .clk         (clk),
    .reset_p     (reset),
    .raddr       (index_r),
    .rdata       (read_data),
    .wen_p       (data_wen),
    .waddr_p     (index_r),
    .wdata_p     (write_data_mux_out)
);

vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (23), // {valid, dirty, tag}
    .ENTRIES     (32),
    .ADDR_SZ     (5),
    .RESET_VALUE (0)
) _tag (
    .clk         (clk),
    .reset_p     (reset),
    .raddr       (index_r),
    .rdata       (read_tagS),
    .wen_p       (tag_wen),
    .waddr_p     (index_r),
    .wdata_p     (write_tagS)
);

endmodule

//------------------------------------------------------------------------
// Control Logic
//------------------------------------------------------------------------

module riscv_CacheBaseCtrl (
    input         clk,
    input         reset,

    // CPU and memory interface
    input          memreq_val,
    output         memreq_rdy,
    output         memresp_val,
    input          memresp_rdy,
    output         cachereq_val,
    input          cachereq_rdy,
    input          cacheresp_val,
    output         cacheresp_rdy,

    input          type,                // read or write
    input          tag_match,           // tag is match
    input          valid_bit,           // cache block is valid
    input          dirty_bit,           // cache block is dirty
    input   [3:0]  refill_counter,      // 128-bit refill beat counter

    output  [2:0]  state,               // FSM state
    output         memreq_en,           // memreq enable
    output         tag_wen,             // tag cache write enable
    output         data_wen,            // data cache write enable
    output         write_data_mux_sel,  // write data is hit data or miss data
    output         miss,                // cache miss
    output         refill_cnt_en,       // refill counter enable
    output         refill_cnt_clr       // refill counter clear
);

// outputs
assign memreq_en = ( memreq_val && memreq_rdy );
assign miss      = ( !valid_bit | !tag_match );
assign tag_wen   = ( curr_state == UPDATE_CACHE );
assign data_wen  = ( curr_state == UPDATE_CACHE );
assign write_data_mux_sel = miss; // tag RAM is not written until the end of UPDATE_CACHE, so miss still holds here

assign refill_cnt_en  = ( curr_state == READ_MEM_RESP && cacheresp_val ); // a refill beat arrived
assign refill_cnt_clr = ( reset || next_state == UPDATE_CACHE ); // also clear on reset

//------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;

reg [2:0] curr_state, next_state;

always @(posedge clk) begin
  if (reset)
    curr_state <= IDLE;
  else
    curr_state <= next_state;
end

assign state = curr_state;

// transition logic
always@ (*) begin
    case ( curr_state )
        IDLE: begin
            next_state = ( memreq_val ) ? READ_CACHE : IDLE;
        end
        READ_CACHE: begin
            next_state = ( miss ) ?         READ_MEM_REQ // miss, get data from memory
                       : ( type == 1'b1 ) ? UPDATE_CACHE // hit & write
                       : ( !memreq_rdy )  ? READ_CACHE   // hit & read, response blocked
                       : ( memreq_val )   ? READ_CACHE   // hit & read, another request in
                       :                    IDLE;        // response delivered, no new request
        end
        UPDATE_CACHE: begin
            next_state = DONE;
        end
        READ_MEM_REQ: begin
            next_state = ( cachereq_rdy ) ? READ_MEM_RESP : READ_MEM_REQ;
        end
        READ_MEM_RESP: begin
            next_state = ( !cacheresp_val )         ? READ_MEM_RESP // waiting for memory
                       : ( refill_counter == 4'd3 ) ? UPDATE_CACHE  // finish refill
                       :                              READ_MEM_REQ; // next beat
        end
        DONE: begin
            next_state = ( memresp_rdy ) ? IDLE : DONE;
        end
    endcase
end

reg memreq_rdy_reg;
reg memresp_val_reg;
reg cachereq_val_reg;
reg cacheresp_rdy_reg;

// val/rdy output
always@ (*) begin

    memreq_rdy_reg    = 1'b0;
    memresp_val_reg   = 1'b0;
    cachereq_val_reg  = 1'b0;
    cacheresp_rdy_reg = 1'b0;

    case ( curr_state )
        IDLE: begin
            memreq_rdy_reg    = 1'b1; // ready for request from CPU
            memresp_val_reg   = 1'b0;
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b0;
        end
        READ_CACHE: begin
            memreq_rdy_reg    = (miss) ? 1'b0 : (memresp_rdy) ? 1'b1 : 1'b0;
            memresp_val_reg   = (miss) ? 1'b0 : 1'b1;
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b0;
        end
        UPDATE_CACHE: begin
            memreq_rdy_reg    = 1'b0;
            memresp_val_reg   = 1'b0;
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b0;
        end
        READ_MEM_REQ: begin
            memreq_rdy_reg    = 1'b0;
            memresp_val_reg   = 1'b0;
            cachereq_val_reg  = 1'b1; // send request to memory
            cacheresp_rdy_reg = 1'b0;
        end
        READ_MEM_RESP: begin
            memreq_rdy_reg    = 1'b0;
            memresp_val_reg   = 1'b0;
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b1; // ready to receive response from memory
        end
        DONE: begin
            memreq_rdy_reg    = 1'b0;
            memresp_val_reg   = 1'b1; // response to CPU valid
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b0;
        end
    endcase
end

assign memreq_rdy    = memreq_rdy_reg;
assign memresp_val   = memresp_val_reg;
assign cachereq_val  = cachereq_val_reg;
assign cacheresp_rdy = cacheresp_rdy_reg;

endmodule

`endif  /* RISCV_CACHE_BASE_V */
