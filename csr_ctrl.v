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


module csr_ctrl
#(
    parameter   CONFIG_WIDTH = 32
)(
     input                      clock
    ,input                      reset
    ,input                      ir_clear_req
    ,output reg                 ir_clear_ack
    ,input      [CONFIG_WIDTH-1:0]  ir_clear_in
    ,output reg [CONFIG_WIDTH-1:0]  ir_clear_out
    
    ,input                      ir_en_req
    ,output reg                 ir_en_ack
    ,input      [CONFIG_WIDTH-1:0]  ir_en_in
    ,output reg [CONFIG_WIDTH-1:0]  ir_en_out
    
    ,input                      conf_req
    ,output reg                 conf_ack
    ,input      [CONFIG_WIDTH-1:0]  conf_in
    ,output reg [CONFIG_WIDTH-1:0]  conf_out
);

always @(posedge clock)
if (reset)                              ir_clear_ack <= 0;
else if (ir_clear_req & ir_clear_ack)   ir_clear_ack <= 0;
else if (ir_clear_req)                  ir_clear_ack <= 1;
else                                    ir_clear_ack <= ir_clear_ack;

always @(posedge clock)
if (reset)                              ir_clear_out <= 0;
else if (ir_clear_req & ir_clear_ack)   ir_clear_out <= ir_clear_in;
else                                    ir_clear_out <= 0;

always @(posedge clock)
if (reset)                      ir_en_ack <= 0;
else if (ir_en_req & ir_en_ack) ir_en_ack <= 0;
else if (ir_en_req)             ir_en_ack <= 1;
else                            ir_en_ack <= ir_en_ack;

always @(posedge clock)
if (reset)                      ir_en_out <= 0;
else if (ir_en_req & ir_en_ack) ir_en_out <= ir_en_in;
else                            ir_en_out <= ir_en_out;

always @(posedge clock)
if (reset)                      conf_ack <= 0;
else if (conf_req & conf_ack)   conf_ack <= 0;
else if (conf_req)              conf_ack <= 1;
else                            conf_ack <= conf_ack;

always @(posedge clock)
if (reset)                      conf_out <= 0;
else if (conf_req & conf_ack)   conf_out <= conf_in;
else                            conf_out <= conf_out;

endmodule
