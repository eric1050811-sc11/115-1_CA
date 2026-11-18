//====================================================================================
// Cache Alt Design (Feel free to create your own design if you have a better one)
//====================================================================================

`ifndef RISCV_CACHE_ALT_V
`define RISCV_CACHE_ALT_V

`include "riscvbc-CacheMsg.v"
`include "vc-RAMs.v"

module riscv_CacheAlt (
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

/* Uncomment the following code when you start working on the D-cache */

wire       memreq_en;
wire       tag_wen;
wire       data_wen;
wire       write_data_mux_sel;
wire       miss;
wire       refill_cnt_en;
wire       refill_cnt_clr;
wire       wb_cnt_en;
wire       wb_cnt_clr;
wire       hit_way_mux_sel;

wire [2:0] state;
wire       type;
wire       tag0_match;
wire       tag1_match;
wire       valid0_bit;
wire       valid1_bit;
wire       dirty0_bit;
wire       dirty1_bit;
wire       victim_way;

wire [3:0] refill_counter;
wire [3:0] wb_counter;


riscv_CacheAltDpath dpath
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
    .wb_cnt_en             (wb_cnt_en),
    .wb_cnt_clr            (wb_cnt_clr),
    .hit_way_mux_sel       (hit_way_mux_sel),

    .type                  (type),
    .tag0_match            (tag0_match),
    .tag1_match            (tag1_match),
    .valid0_bit            (valid0_bit),
    .valid1_bit            (valid1_bit),
    .dirty0_bit            (dirty0_bit),
    .dirty1_bit            (dirty1_bit),
    .victim_way            (victim_way),
    .refill_counter        (refill_counter),
    .wb_counter            (wb_counter)
);

riscv_CacheAltCtrl ctrl
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
    .tag0_match            (tag0_match),
    .tag1_match            (tag1_match),
    .valid0_bit            (valid0_bit),
    .valid1_bit            (valid1_bit),
    .dirty0_bit            (dirty0_bit),
    .dirty1_bit            (dirty1_bit),
    .victim_way            (victim_way),
    .refill_counter        (refill_counter),
    .wb_counter            (wb_counter),

    .state                 (state),
    .memreq_en             (memreq_en),
    .tag_wen               (tag_wen),
    .data_wen              (data_wen),
    .write_data_mux_sel    (write_data_mux_sel),
    .miss                  (miss),
    .refill_cnt_en         (refill_cnt_en),
    .refill_cnt_clr        (refill_cnt_clr),
    .wb_cnt_en             (wb_cnt_en),
    .wb_cnt_clr            (wb_cnt_clr),
    .hit_way_mux_sel       (hit_way_mux_sel)
);

endmodule

//------------------------------------------------------------------------
// Datapath
//------------------------------------------------------------------------

module riscv_CacheAltDpath (
    input         clk,
    input         reset,

    // msg
    input  [`VC_MEM_REQ_MSG_SZ(32,32)-1:0] memreq_msg,
    input  [`VC_MEM_RESP_MSG_SZ(128)-1:0]  cacheresp_msg,
    output   [`VC_MEM_RESP_MSG_SZ(32)-1:0] memresp_msg,
    output [`VC_MEM_REQ_MSG_SZ(32,128)-1:0] cachereq_msg,

    // control singal
    input      [2:0]  state,               // FSM state
    input             memreq_en,           // memreq enable
    input             tag_wen,             // tag cache write enable
    input             data_wen,            // data cache write enable
    input             write_data_mux_sel,  // write data is hit data or miss data
    input             miss,                // cache miss
    input             refill_cnt_en,       // refill counter enable
    input             refill_cnt_clr,      // refill counter clear
    input             wb_cnt_en,           // write back counter enable
    input             wb_cnt_clr,          // write back counter clear
    input             hit_way_mux_sel,     // which way is hit

    output            type,                // read or write
    output            tag0_match,          // way0 tag is match
    output            tag1_match,          // way1 tag is match
    output            valid0_bit,          // way0 is valid
    output            valid1_bit,          // way1 is valid
    output            dirty0_bit,          // way0 is dirty
    output            dirty1_bit,          // way1 is dirty
    output            victim_way,          // which way is victim in main cache
    output reg [3:0]  refill_counter,      // 128-bit refill beat counter
    output reg [3:0]  wb_counter           // 128-bit write-back beat counter
);

//------------------------------------------------------------------------
// Combinational logic
//------------------------------------------------------------------------

// message
wire        memreq_type = memreq_msg[66];
wire [31:0] memreq_addr = memreq_msg[65:34];
wire [1:0]  memreq_len  = memreq_msg[33:32];
wire [31:0] memreq_data = memreq_msg[31: 0];

wire [127:0] cacheresp_data = cacheresp_msg[127:0];

// address
wire [`OFF_BITS-1:0] offset = memreq_addr_reg[ 5: 0];
wire [`IDX_BITS-1:0] index  = memreq_addr_reg[10: 6];
wire [`TAG_BITS-1:0] tag    = memreq_addr_reg[31:11];

// extract tag and status bits
wire [22:0] read_tagS0 = read_tagS[22: 0];
wire [22:0] read_tagS1 = read_tagS[45:23];

// read way0 {valid, dirty, tag}
wire [`TAG_BITS-1:0] read_tag0  = read_tagS0[`TAG_BITS-1:0];
assign               dirty0_bit = read_tagS0[`TAG_BITS];
assign               valid0_bit = read_tagS0[`TAG_BITS+1];

// read way1 {valid, dirty, tag}
wire [`TAG_BITS-1:0] read_tag1  = read_tagS1[`TAG_BITS-1:0];
assign               dirty1_bit = read_tagS1[`TAG_BITS];
assign               valid1_bit = read_tagS1[`TAG_BITS+1];

// use left most bit to indicate LRU way
assign victim_way = read_tagS[46];

// 2-way data
wire [`BLK_SIZE-1:0] read_data0 = read_data[511:0];
wire [`BLK_SIZE-1:0] read_data1 = read_data[1023:512];

// compare tag
assign tag0_match    = ( tag == read_tag0 );
assign tag1_match    = ( tag == read_tag1 );

// select victim block in main cache (data/tag)
wire [`BLK_SIZE-1:0] read_data_vc  = ( victim_way ) ? read_data1 : read_data0;
wire [22:0]          read_tagS_vc  = ( victim_way ) ? read_tagS1 : read_tagS0;

// select survivor block in main cache (data/tag)
wire [`BLK_SIZE-1:0] read_data_surv = ( victim_way ) ? read_data0 : read_data1;
wire [22:0]          read_tagS_surv = ( victim_way ) ? read_tagS0 : read_tagS1;

// output request type to control
assign type = memreq_type_reg;

// select hit block
wire [`BLK_SIZE-1:0] hit_block_data = ( hit_way_mux_sel ) ? read_data1 : read_data0;

// read hit
reg [31:0] read_data_hit;
always@ (*) begin
    case ( memreq_len_reg )
        2'b01: read_data_hit = hit_block_data[offset*8 +: 8];
        2'b10: read_data_hit = hit_block_data[offset*8 +: 16];
        2'b11: read_data_hit = hit_block_data[offset*8 +: 24];
        2'b00: read_data_hit = hit_block_data[offset*8 +: 32];
    endcase
end

// read miss
wire [`BLK_SIZE-1:0] read_data_mux_out = ( victim_way_reg ) ? read_data1 : read_data0;
reg  [31:0]          read_data_miss;
always@ (*) begin
    case ( memreq_len_reg )
        2'b01: read_data_miss = read_data_mux_out[offset*8 +: 8];
        2'b10: read_data_miss = read_data_mux_out[offset*8 +: 16];
        2'b11: read_data_miss = read_data_mux_out[offset*8 +: 24];
        2'b00: read_data_miss = read_data_mux_out[offset*8 +: 32];
    endcase
end

// write hit
reg [`BLK_SIZE-1:0] write_data_hit;
always@ (*) begin
    write_data_hit = hit_block_data;
    case ( memreq_len_reg )
        2'b01: write_data_hit[offset*8 +: 8] = memreq_data_reg[7:0];
        2'b10: write_data_hit[offset*8 +: 16] = memreq_data_reg[15:0];
        2'b11: write_data_hit[offset*8 +: 24] = memreq_data_reg[23:0];
        2'b00: write_data_hit[offset*8 +: 32] = memreq_data_reg[31:0];
    endcase
end
wire [`D_SET_SIZE-1:0] write_data_hit_o = ( hit_way_mux_sel )
                                        ? {write_data_hit, read_data0} : {read_data1, write_data_hit};

// write miss
reg [`BLK_SIZE-1:0] write_data_miss;
always@ (*) begin
    write_data_miss = refill_data;
    if ( memreq_type_reg == `WRITE ) begin
        case ( memreq_len_reg )
            2'b01: write_data_miss[offset*8 +: 8] = memreq_data_reg[7:0];
            2'b10: write_data_miss[offset*8 +: 16] = memreq_data_reg[15:0];
            2'b11: write_data_miss[offset*8 +: 24] = memreq_data_reg[23:0];
            2'b00: write_data_miss[offset*8 +: 32] = memreq_data_reg[31:0];
        endcase
    end
end
wire [`D_SET_SIZE-1:0] write_data_miss_o = ( victim_way_reg )
                                         ? {write_data_miss, read_data0} : {read_data1, write_data_miss};

// select write data: hit or miss
wire [`D_SET_SIZE-1:0] write_data_mux_out = ( write_data_mux_sel ) ? write_data_miss_o : write_data_hit_o;

wire [22:0] new_tag_entry = {1'b1, type, tag};
wire [46:0] write_tagS = (tag0_match && valid0_bit) ? {1'b1, valid1_bit, dirty1_bit, read_tag1, valid0_bit, {type | dirty0_bit}, read_tag0}
                       : (tag1_match && valid1_bit) ? {1'b0, valid1_bit, {type | dirty1_bit}, read_tag1, valid0_bit, dirty0_bit, read_tag0}
                       : (victim_way_reg)           ? {1'b0, new_tag_entry, valid0_bit, dirty0_bit, read_tag0}  // way 1 being replaced
                                                    : {1'b1, valid1_bit, dirty1_bit, read_tag1, new_tag_entry}; // way 0 being replaced

// refill address (advance by `MEM_BEAT_BYTES for each beat)
wire [31:0] refill_addr = {memreq_addr_reg[31:6], 6'd0} + refill_counter * `MEM_BEAT_BYTES;

// write back address and data, to memory
wire [ 31:0] wb_addr = {read_tagS_vc_reg[20:0], index, 6'd0} + wb_counter * `MEM_BEAT_BYTES;
wire [127:0] wb_data = read_data_vc_reg[wb_counter*`MEM_BEAT_BITS +: 128];

//------------------------------------------------------------------------
// Sequential logic
//------------------------------------------------------------------------

// store memreq massage
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

// store data if missing
reg [`BLK_SIZE-1:0] read_data_vc_reg;
reg [`BLK_SIZE-1:0] read_data_surv_reg;
reg                 victim_way_reg;
reg [22:0]          read_tagS_vc_reg;
reg [22:0]          read_tagS_surv_reg;
always@ ( posedge clk ) begin
    if ( miss ) begin
        read_data_vc_reg   <= read_data_vc;
        read_data_surv_reg <= read_data_surv;
        victim_way_reg     <= victim_way;
        read_tagS_vc_reg   <= read_tagS_vc;
        read_tagS_surv_reg <= read_tagS_surv;
    end
end

// refill counter
always@ ( posedge clk ) begin
    if ( refill_cnt_clr ) begin
        refill_counter <= 4'd0;
    end
    else if ( refill_cnt_en ) begin
        refill_counter <= refill_counter + 1 ;
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

// write back counter
always@ ( posedge clk ) begin
    if ( wb_cnt_clr ) begin
        wb_counter <= 4'd0;
    end
    else if ( wb_cnt_en ) begin
        wb_counter <= wb_counter + 1 ;
    end
end

//------------------------------------------------------------------------
// FSM output massage
//------------------------------------------------------------------------

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;
localparam WB_MEM_REQ     = 3'b110;
localparam WB_MEM_RESP    = 3'b111;

reg [34:0] memresp_msg_reg;
reg [164:0] cachereq_msg_reg;

always@ (*) begin

    memresp_msg_reg   = 35'b0;
    cachereq_msg_reg  = {1'b0, refill_addr, 4'd0, 128'd0};

    case ( state )
        READ_CACHE: begin
            memresp_msg_reg   = {memreq_type_reg, memreq_len_reg, read_data_hit};
        end
        DONE: begin
            memresp_msg_reg   = {memreq_type_reg, memreq_len_reg, read_data_hit};
        end
        WB_MEM_REQ: begin
            cachereq_msg_reg = {1'b1, wb_addr, 4'd0, wb_data};
        end
    endcase
end

assign memresp_msg   = memresp_msg_reg;
assign cachereq_msg  = cachereq_msg_reg;

//------------------------------------------------------------------------
// D-cache RAM module
// 4KiB, 2-way set associative, write-allocate with 64B blocks
// 32 entries, 2^5, [4:0]
//------------------------------------------------------------------------

wire [46:0]            read_tagS;
wire [`D_SET_SIZE-1:0] read_data;

// 2-way assocative
vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (1024), // 2 way, 64B, total of 1024b
    .ENTRIES     (32),
    .ADDR_SZ     (5),
    .RESET_VALUE (0)
) _data (
    .clk         (clk),
    .reset_p     (reset),
    .raddr       (index),
    .rdata       (read_data),
    .wen_p       (data_wen),
    .waddr_p     (index),
    .wdata_p     (write_data_mux_out)
);

vc_RAM_rst_1w1r_pf #(
    .DATA_SZ     (47),
    .ENTRIES     (32),
    .ADDR_SZ     (5),
    .RESET_VALUE (0)
) _tag (
    .clk         (clk),
    .reset_p     (reset),
    .raddr       (index),
    .rdata       (read_tagS),
    .wen_p       (tag_wen),
    .waddr_p     (index),
    .wdata_p     (write_tagS)
);


endmodule


module riscv_CacheAltCtrl (
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
    input          tag0_match,          // way0 tag is match
    input          tag1_match,          // way1 tag is match
    input          valid0_bit,          // way0 is valid
    input          valid1_bit,          // way1 is valid
    input          dirty0_bit,          // way0 is dirty
    input          dirty1_bit,          // way1 is dirty
    input          victim_way,          // which way is victim in main cache
    input  [3:0]   refill_counter,      // 128-bit refill beat counter
    input  [3:0]   wb_counter,          // 128-bit write-back beat counter


    output [2:0]   state,               // FSM state
    output         memreq_en,           // memreq enable
    output         tag_wen,             // tag cache write enable
    output         data_wen,            // data cache write enable
    output         write_data_mux_sel,  // write data is hit data or miss data
    output         miss,                // cache miss
    output         refill_cnt_en,       // refill counter enable
    output         refill_cnt_clr,      // refill counter clear
    output         wb_cnt_en,           // write back counter enable
    output         wb_cnt_clr,          // write back counter clear
    output         hit_way_mux_sel      // which way is hit
);

// val/rdy enable
assign memreq_en = memreq_val && memreq_rdy;

// TODO

//------------------------------------------------------------------------
// FSM
//------------------------------------------------------------------------

localparam IDLE           = 3'b000;
localparam READ_CACHE     = 3'b001;
localparam UPDATE_CACHE   = 3'b010;
localparam READ_MEM_REQ   = 3'b011;
localparam READ_MEM_RESP  = 3'b100;
localparam DONE           = 3'b101;
localparam WB_MEM_REQ     = 3'b110;
localparam WB_MEM_RESP    = 3'b111;

reg [2:0] curr_state, next_state;

always@ ( posedge clk ) begin
    if ( reset )
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

    // TODO

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
            memreq_rdy_reg    = 1'b1;
            memresp_val_reg   = 1'b0;
            cachereq_val_reg  = 1'b0;
            cacheresp_rdy_reg = 1'b0;
        end

    // TODO

    endcase
end

assign memreq_rdy    = memreq_rdy_reg;
assign memresp_val   = memresp_val_reg;
assign cachereq_val  = cachereq_val_reg;
assign cacheresp_rdy = cacheresp_rdy_reg;

endmodule

`endif  /* RISCV_CACHE_ALT_V */
