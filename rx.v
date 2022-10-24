`timescale 1ns/1ps

module rx #(
    parameter FREQ = 50000000,
    parameter CONFIG_WIDTH = 32
)(
    //uart interface
     input              clock
    ,input              reset
    ,input              rx
    ,output reg         dout_valid
    ,output     [7:0]   dout
    //status
    ,input      [CONFIG_WIDTH/2-1:0]    enable
    ,output reg                         error
    ,input      [CONFIG_WIDTH/2-1:0]    clear
    ,output                             done
    //csr
    ,input      [CONFIG_WIDTH-1:0]  rx_conf 
);
            
reg [3:0]   bit_cnt;
reg [4:0]   byte_cnt; 

reg [31:0] baud_cnt;
wire [31:0] baud_cnt_limit;
reg [31:0] baud_cnt_limit_array[0:7];
always @ (posedge clock)
if (reset) begin
    baud_cnt_limit_array[0] <= FREQ/1200 -1;
    baud_cnt_limit_array[1] <= FREQ/2400 -1;
    baud_cnt_limit_array[2] <= FREQ/4800 -1;
    baud_cnt_limit_array[3] <= FREQ/9600 -1;
    baud_cnt_limit_array[4] <= FREQ/19200 -1;
    baud_cnt_limit_array[5] <= FREQ/38400 -1;
    baud_cnt_limit_array[6] <= FREQ/57600 -1;
    baud_cnt_limit_array[7] <= FREQ/115200 -1;
end

assign baud_cnt_limit = rx_conf[31:16] == 0 ? baud_cnt_limit_array[0] :
                        rx_conf[31:16] == 1 ? baud_cnt_limit_array[1] :
                        rx_conf[31:16] == 2 ? baud_cnt_limit_array[2] :
                        rx_conf[31:16] == 3 ? baud_cnt_limit_array[3] :
                        rx_conf[31:16] == 4 ? baud_cnt_limit_array[4] :
                        rx_conf[31:16] == 5 ? baud_cnt_limit_array[5] :
                        rx_conf[31:16] == 6 ? baud_cnt_limit_array[6] : baud_cnt_limit_array[7];

localparam  IDLE    = 1'b0,
            DATA    = 1'b1;

reg state;
wire next_state;

wire IDLE_state;
wire DATA_state;

assign IDLE_state   = !state;
assign DATA_state   =  state;

wire start_bit;
assign start_bit = bit_cnt == 0;

wire bit_flag;
assign bit_flag = baud_cnt == baud_cnt_limit;

wire bit_last;
assign bit_last = bit_flag & bit_cnt == 10;

wire bit_parity;
assign bit_parity = bit_cnt == 9;

assign next_state = IDLE_state & start_bit & !rx    ? DATA :
                    DATA_state & bit_last           ? IDLE  : state;

always @(posedge clock)
if (reset)  state <= IDLE;
else        state <= next_state;

reg [10:0] dout_buf;

wire even_parity;
assign even_parity = ((dout_buf[10] ^ dout_buf[9]) ^ (dout_buf[8] ^ dout_buf[7])) ^ ((dout_buf[6] ^ dout_buf[5]) ^ (dout_buf[4] ^ dout_buf[3]));
wire odd_parity;
assign odd_parity = ~(((dout_buf[10] ^ dout_buf[9]) ^ (dout_buf[8] ^ dout_buf[7])) ^ ((dout_buf[6] ^ dout_buf[5]) ^ (dout_buf[4] ^ dout_buf[3])));
wire parity;
assign parity = rx_conf[0] ? odd_parity : even_parity;

always @(posedge clock)
if (reset)                      dout_buf <= 0;
else if (IDLE_state)            dout_buf <= 0;
else if (DATA_state & bit_flag) dout_buf <= {rx, dout_buf[10:1]};
else                            dout_buf <= dout_buf;

assign dout = dout_buf[8:1];

always @(posedge clock)
if (reset)                                                  error <= 0;
else if (!enable[6] & IDLE_state)                           error <= 0;
else if (enable[6] & clear[6])                              error <= 0;
else if (enable[6] & bit_parity & (parity ^ rx) & bit_flag) error <= 1;
else                                                        error <= error;

always @(posedge clock)
if (reset) dout_valid <= 0;
else dout_valid <= bit_last & (!done);

always @(posedge clock)
if (reset)          bit_cnt <= 0;
else if (bit_last)  bit_cnt <= 0;
else if (bit_flag)  bit_cnt <= bit_cnt + 1;
else                bit_cnt <= bit_cnt;

always @(posedge clock)
if (reset)                  baud_cnt <= baud_cnt_limit >> 1;
else if (bit_flag)          baud_cnt <= 0;
else if (DATA_state | !rx)  baud_cnt <= baud_cnt + 1;
else                        baud_cnt <= baud_cnt_limit >> 1;

assign done =   (enable[0] == 1 & byte_cnt == 0) | 
                (enable[1] == 1 & byte_cnt == 1) |
                (enable[2] == 1 & byte_cnt == 3) | 
                (enable[3] == 1 & byte_cnt == 7) | 
                (enable[4] == 1 & byte_cnt == 15) | 
                (enable[5] == 1 & byte_cnt == 31);

wire enable_done;
assign enable_done = enable[0] | enable[1] | enable[2] | enable[3] | enable[4] | enable[5];
wire clear_done;
assign clear_done = clear[0] | clear[1] | clear[2] | clear[3] | clear[4] | clear[5];

always @(posedge clock)
if (reset)                                  byte_cnt <= 0;
else if (enable_done & clear_done)          byte_cnt <= 0;
else if (enable_done & bit_last & !done)    byte_cnt <= byte_cnt + 1;
else                                        byte_cnt <= byte_cnt;

endmodule
