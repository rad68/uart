`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/18/2022 01:32:48 PM
// Design Name: 
// Module Name: ir_ctrl
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ir_ctrl
#(
    parameter CONFIG_WIDTH = 32
)(
     input      clock
    ,input      reset
    //asynchronous PLIC interface
    ,output reg         ir_rx_req
    ,input              ir_rx_ack
    ,output reg         ir_tx_req
    ,input              ir_tx_ack
    //internal signals
    ,input      [CONFIG_WIDTH-1:0]  ir_en
    ,input      [CONFIG_WIDTH-1:0]  ir_clear
    ,input      [CONFIG_WIDTH-1:0]  src
);

localparam TX_DONE_1    =   0;
localparam TX_DONE_2    =   1;
localparam TX_DONE_4    =   2;
localparam TX_DONE_8    =   3;
localparam TX_DONE_16   =   4;
localparam TX_DONE_32   =   5;
localparam TX_FULL      =   6;

localparam RX_DONE_1    =   16;
localparam RX_DONE_2    =   17;
localparam RX_DONE_4    =   18;
localparam RX_DONE_8    =   19;
localparam RX_DONE_16   =   20;
localparam RX_DONE_32   =   21;
localparam RX_PAR       =   22;
localparam RX_FULL      =   23;

reg rx_done;
always @(posedge clock)
if (reset)                                          rx_done <= 0;
else if (ir_rx_ack & ir_rx_req)                     rx_done <= 1;
else if (|ir_clear[CONFIG_WIDTH-1:CONFIG_WIDTH/2])  rx_done <= 0;
else                                                rx_done <= rx_done;

always @(posedge clock)
if (reset)                                                                          ir_rx_req <= 0;
else if (ir_rx_ack & ir_rx_req)                                                     ir_rx_req <= 0;
else if (ir_en[CONFIG_WIDTH-1:CONFIG_WIDTH/2] & src[CONFIG_WIDTH-1:CONFIG_WIDTH/2]) ir_rx_req <= ~rx_done;
else                                                                                ir_rx_req <= ir_rx_req;

reg tx_done;
always @(posedge clock)
if (reset)                              tx_done <= 0;
else if (ir_tx_ack & ir_tx_req)         tx_done <= 1;
else if (|ir_clear[CONFIG_WIDTH/2-1:0]) tx_done <= 0;
else                                    tx_done <= tx_done;

always @(posedge clock)
if (reset)                                                      ir_tx_req <= 0;
else if (ir_tx_ack & ir_tx_req)                                 ir_tx_req <= 0;
else if (ir_en[CONFIG_WIDTH/2-1:0] & src[CONFIG_WIDTH/2-1:0])   ir_tx_req <= ~tx_done;
else                                                            ir_tx_req <= ir_tx_req;

endmodule
