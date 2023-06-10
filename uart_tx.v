`timescale 1ns/1ps

module uart_tx #(
   parameter FREQ = 50000000
  ,parameter CONFIG_WIDTH = 8
  ,parameter UART_DATA_WIDTH = 8
)(
  //system
   input                          clock
  ,input                          reset
  ,input      [7:0]               din
  ,input                          din_valid
  ,output reg                     din_ready
  ,output                         tx
  //config
  ,input      [CONFIG_WIDTH-1:0]  conf
);

reg [CONFIG_WIDTH -1:0] tx_conf;

reg [3:0] bit_cnt;

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

assign baud_cnt_limit = tx_conf[7:5] == 0 ? baud_cnt_limit_array[0] :
                        tx_conf[7:5] == 1 ? baud_cnt_limit_array[1] :
                        tx_conf[7:5] == 2 ? baud_cnt_limit_array[2] :
                        tx_conf[7:5] == 3 ? baud_cnt_limit_array[3] :
                        tx_conf[7:5] == 4 ? baud_cnt_limit_array[4] :
                        tx_conf[7:5] == 5 ? baud_cnt_limit_array[5] :
                        tx_conf[7:5] == 6 ? baud_cnt_limit_array[6] : baud_cnt_limit_array[7];

localparam  IDLE = 1'b0,
            DATA = 1'b1;

reg     state;
wire    next_state;

wire IDLE_state;
wire DATA_state;

assign IDLE_state   = !state;
assign DATA_state   = state;

wire bit_flag;
wire bit_last;

assign next_state = IDLE_state & din_valid  ? DATA  :
                    DATA_state & bit_last   ? IDLE : state;

always @(posedge clock)
if (reset)  state <= IDLE;
else        state <= next_state;

always @(posedge clock)
if (reset)              tx_conf <= 0;
else if (state == IDLE) tx_conf <= conf;
else                    tx_conf <= tx_conf;

always @(posedge clock)
if (reset)                      din_ready <= 1;
else if (din_ready & din_valid) din_ready <= 0;
else if (IDLE_state | bit_last) din_ready <= 1;
else                            din_ready <= din_ready;

reg [11:0] tx_buf;

wire even_parity;
assign even_parity = ((din[7] ^ din[6]) ^ (din[5] ^ din[4])) ^((din[3] ^ din[2]) ^ (din[1] ^ din[0]));
wire odd_parity;
assign odd_parity = ~((din[7] ^ din[6]) ^ (din[5] ^ din[4])) ^((din[3] ^ din[2]) ^ (din[1] ^ din[0]));
wire parity;
assign parity = tx_conf[0] ? odd_parity : even_parity;

always @(posedge clock)
if (reset)                                                                tx_buf <= 1;
else if ((IDLE_state & din_valid) | (bit_last & din_valid) & ~tx_conf[1]) tx_buf <= {2'b11, parity, din, 1'b0};
else if ((IDLE_state & din_valid) | (bit_last & din_valid) &  tx_conf[1]) tx_buf <= {2'b11, parity, din, 1'b0};
else if (DATA_state & bit_flag)                                           tx_buf <= {1'b1, tx_buf[11:1]};
else                                                                      tx_buf <= tx_buf;

assign tx = tx_buf[0];

assign bit_flag = baud_cnt == baud_cnt_limit;
assign bit_last = tx_conf[1] ? bit_flag & bit_cnt == 11 : bit_flag & bit_cnt == 10;

always @(posedge clock)
if (reset)          bit_cnt <= 0;
else if (bit_last)  bit_cnt <= 0;
else if (bit_flag)  bit_cnt <= bit_cnt + 1;
else                bit_cnt <= bit_cnt;

always @(posedge clock)
if (reset)              baud_cnt <= 0;
else if (bit_flag)      baud_cnt <= 0;
else if (!IDLE_state)   baud_cnt <= baud_cnt + 1;
else                    baud_cnt <= 0;

endmodule
