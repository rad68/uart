`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/21/2022 04:52:39 PM
// Design Name: 
// Module Name: csr_ctrl
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


module uart_conf
#(
    parameter   CONFIG_WIDTH = 32
)(
     input                      clock
    ,input                      reset
    
    ,input                          conf_req
    ,output reg                     conf_ack
    ,input      [CONFIG_WIDTH-1:0]  conf_in
    ,output reg [CONFIG_WIDTH-1:0]  conf_out
);

always @(posedge clock)
if (reset)                      conf_ack <= 0;
else if (conf_req & conf_ack)   conf_ack <= 0;
else if (conf_req)              conf_ack <= 1;
else                            conf_ack <= conf_ack;

always @(posedge clock)
if (reset)                      conf_out <= 8'h62;
else if (conf_req & conf_ack)   conf_out <= conf_in;
else                            conf_out <= conf_out;

endmodule
