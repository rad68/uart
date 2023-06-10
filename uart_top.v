`timescale 1ns/1ps

/*
    Config:
    [0] PARITY: 0 - even, 1 - odd
    [1] STOP BIT: 0 - one stop-bit, 1 - 2 stop-bits
    [2] MSB: 0 - msb first, 1 - msb last (not supported)
    [3] Turn on/off
    [4] Reserved
    [7:5] BAUD: 0 - 1200, 1 - 2400, 2 - 4800, 3 - 9600, 4 - 19200, 5 - 38400, 6 - 57600, 7 - 115200

    Note:
    - Error passively transfered to the ASYNC side as a [8] bit in rx_d and 
    there handled for interrupts signaling.
    - Error bit is not stored and RX keeps receiving after rx_d communication
    is over
    - Unlike in SPI, on the config update is not legal and will break execution
*/

module uart_top #(
   parameter FREQ = 200_000_000
  ,parameter CONFIG_WIDTH = 8
  ,parameter UART_DATA_WIDTH = 8
  ,parameter SYNC_STAGE = 2
)(
  //offchip ports
   input                        clock
  ,input                        reset
  ,input                        rx
  ,output                       tx
  //RX
  ,input                        async_rx_d_ack
  ,output                       async_rx_d_req
  ,output [UART_DATA_WIDTH  :0] async_rx_d
  //TX
  ,input                        async_tx_d_req
  ,output                       async_tx_d_ack
  ,input  [UART_DATA_WIDTH-1:0] async_tx_d
  //CONFIG
  ,input                        async_conf_req
  ,output                       async_conf_ack
  ,input  [CONFIG_WIDTH   -1:0] async_conf
  
);

wire  [UART_DATA_WIDTH  -1:0] sync_tx_d;
wire  [UART_DATA_WIDTH    :0] sync_rx_d;

wire  sync_tx_d_valid, sync_tx_d_ready;
wire  sync_rx_d_valid, sync_rx_d_ready;

sync_to_async_ctrl #(
   .DATA_WIDTH  (UART_DATA_WIDTH + 1)
  ,.SYNC_STAGE  (SYNC_STAGE)
) sync_to_async_rx_d (
   .clock       (clock)
  ,.reset       (reset)
  ,.sync_valid  (sync_rx_d_valid)
  ,.sync_ready  (sync_rx_d_ready)
  ,.sync_d      (sync_rx_d)
  ,.async_req   (async_rx_d_req)
  ,.async_ack   (async_rx_d_ack)
  ,.async_d     (async_rx_d)
);

async_to_sync_ctrl #(
   .DATA_WIDTH  (UART_DATA_WIDTH)
  ,.SYNC_STAGE  (SYNC_STAGE)
) async_to_sync_tx_d (
   .clock       (clock)
  ,.reset       (reset)
  ,.async_req   (async_tx_d_req)
  ,.async_ack   (async_tx_d_ack)
  ,.async_d     (async_tx_d)
  ,.sync_valid  (sync_tx_d_valid)
  ,.sync_ready  (sync_tx_d_ready)
  ,.sync_d      (sync_tx_d)
);

wire    [CONFIG_WIDTH-1:0] sync_conf, conf;
wire    sync_conf_valid, sync_conf_ready;
async_to_sync_ctrl #(
   .DATA_WIDTH  (CONFIG_WIDTH)
  ,.SYNC_STAGE  (SYNC_STAGE)
) async_to_sync_conf (
   .clock       (clock)
  ,.reset       (reset)
  ,.async_req   (async_conf_req)
  ,.async_ack   (async_conf_ack)
  ,.async_d     (async_conf)
  ,.sync_valid  (sync_conf_valid)
  ,.sync_ready  (sync_conf_ready)
  ,.sync_d      (sync_conf)
);

uart_conf #(
   .CONFIG_WIDTH   (CONFIG_WIDTH)
) uart_conf (
  //system
   .clock     (clock)
  ,.reset     (reset)
  //uart config
  ,.conf_req  (sync_conf_valid)
  ,.conf_ack  (sync_conf_ready)
  ,.conf_in   (sync_conf)
  ,.conf_out  (conf)
);

uart_tx #(
   .FREQ            (FREQ)
  ,.CONFIG_WIDTH    (CONFIG_WIDTH)
  ,.UART_DATA_WIDTH (UART_DATA_WIDTH)
) tx_inst (
  //system
   .clock     (clock)
  ,.reset     (reset)
  ,.tx        (tx)
  ,.din_valid (sync_tx_d_valid)
  ,.din_ready (sync_tx_d_ready)
  ,.din       (sync_tx_d)
  //conf
  ,.conf      (conf)
);

uart_rx #(
   .FREQ            (FREQ)
  ,.CONFIG_WIDTH    (CONFIG_WIDTH)
  ,.UART_DATA_WIDTH (UART_DATA_WIDTH)
) rx_inst (
  //system
   .clock       (clock)
  ,.reset       (reset)
  ,.rx          (rx)
  ,.dout_valid  (sync_rx_d_valid)
  ,.dout_ready  (sync_rx_d_ready)
  ,.dout        (sync_rx_d)
  //conf
  ,.conf        (conf)
);


endmodule
