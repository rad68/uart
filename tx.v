`timescale 1ns/1ps

module tx #(
    parameter FREQ = 50000000,
    parameter CONFIG_WIDTH = 32
)(
    //system
     input              clock
    ,input              reset
    ,input      [7:0]   din
    ,input              din_valid
    ,output reg         din_ready
    ,output             tx
    //status
    ,input      [CONFIG_WIDTH/2-1:0]    enable
    ,output                             done
    ,input      [CONFIG_WIDTH/2-1:0]    clear
    //csr
    ,input      [CONFIG_WIDTH-1:0]  tx_conf //31:16 - baud rate; 0 - parity
);


reg [3:0] bit_cnt;
reg [4:0] byte_cnt;

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

assign baud_cnt_limit = tx_conf[31:16] == 0 ? baud_cnt_limit_array[0] :
                        tx_conf[31:16] == 1 ? baud_cnt_limit_array[1] :
                        tx_conf[31:16] == 2 ? baud_cnt_limit_array[2] :
                        tx_conf[31:16] == 3 ? baud_cnt_limit_array[3] :
                        tx_conf[31:16] == 4 ? baud_cnt_limit_array[4] :
                        tx_conf[31:16] == 5 ? baud_cnt_limit_array[5] :
                        tx_conf[31:16] == 6 ? baud_cnt_limit_array[6] : baud_cnt_limit_array[7];

localparam  IDLE = 1'b0,
            DATA = 1'b1;

reg     state;
wire    next_state;

wire IDLE_state;
wire DATA_state;

assign IDLE_state   = !state;
assign DATA_state   = state;

wire bit_flag;
assign bit_flag = baud_cnt == baud_cnt_limit;

wire bit_last;
assign bit_last = bit_flag & bit_cnt == 10;

assign next_state = IDLE_state & din_valid  ? DATA  :
                    DATA_state & bit_last   ? IDLE : state;

always @(posedge clock)
if (reset)  state <= IDLE;
else        state <= next_state;

always @(posedge clock)
if (reset)                      din_ready <= 1;
else if (bit_last & !done)      din_ready <= 1;
else if (din_ready & din_valid) din_ready <= 0;
else                            din_ready <= din_ready;

reg [10:0] tx_buf;

wire even_parity;
assign even_parity = ((din[7] ^ din[6]) ^ (din[5] ^ din[4])) ^((din[3] ^ din[2]) ^ (din[1] ^ din[0]));
wire odd_parity;
assign odd_parity = ~((din[7] ^ din[6]) ^ (din[5] ^ din[4])) ^((din[3] ^ din[2]) ^ (din[1] ^ din[0]));
wire parity;
assign parity = tx_conf[0] ? odd_parity : even_parity;

always @(posedge clock)
if (reset)                                                  tx_buf <= 1;
else if ((IDLE_state & din_valid) | (bit_last & din_valid)) tx_buf <= {1'b0, din, parity, 1'b1};
else if (DATA_state & bit_flag)                             tx_buf <= tx_buf >> 1;
else                                                        tx_buf <= tx_buf;

assign tx = tx_buf[0];

always @(posedge clock)
if (reset)          bit_cnt <= 0;
else if (bit_flag)  bit_cnt <= bit_cnt == 10 ? 0 : bit_cnt + 1;
else                bit_cnt <= bit_cnt;

always @(posedge clock)
if (reset)              baud_cnt <= 0;
else if (bit_flag)      baud_cnt <= 0;
else if (!IDLE_state)   baud_cnt <= baud_cnt + 1;
else                    baud_cnt <= 0;

assign done =   (enable[0] == 1 & byte_cnt == 0) | 
                (enable[1] == 1 & byte_cnt == 1) |
                (enable[2] == 1 & byte_cnt == 2) | 
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
