`timescale 1ns/1ps

module tb();

localparam FREQ = 10_000_0;
localparam BAUD_RATE = 9600;
localparam BIT = FREQ/BAUD_RATE;

reg     rx;
wire    tx;
reg     async_rx_d_ack;
wire    async_rx_d_req;
wire    [8:0] async_rx_d;

reg     async_tx_d_req;
wire    async_tx_d_ack;
reg     [7:0] async_tx_d;

reg     async_conf_req;
wire    async_conf_ack;
reg     [31:0] async_conf;


reg clock;
initial clock = 0;
always clock = #1 ~clock;

task delay;
input [31:0] d;
begin
    repeat (d) @(posedge clock);
end
endtask

task unit_delay;
input [31:0] D;
begin
    #D;
end
endtask

reg reset;
task reset_task;
begin
    reset = 0;
    async_conf_req = 0;
    async_conf = 0;
    rx = 1;
    delay(10);
    reset = 1;
    delay(10);
    reset = 0;
end
endtask

integer i, k;
reg [7:0] word_buf;

reg bit_test = 0;   //shows when the next bit comes
task send_rx_char;
input [4:0] num;
input       e;
begin
    for (i = 0; i < num; i = i + 1) begin
        bit_test = ~bit_test;
        word_buf = $random;
        rx = 0;   //start bit
        delay(BIT);
        for (k = 0; k < 8; k = k + 1) begin
            bit_test = ~bit_test;
            rx = word_buf[k]; //data bits
            delay(BIT);
        end
        bit_test = ~bit_test;
        if (e & $random) begin
            rx = ^word_buf; //parity bit
            delay(BIT);
        end else begin
            rx = $random; //parity bit
            delay(BIT);
        end
        bit_test = ~bit_test;
        rx = 1; //end bit
        delay(BIT);
        if (async_conf[1]) begin
            rx = 1; //end bit
            delay(BIT);
        end
    end
end
endtask

task set_config;
input [7:0] conf;
begin
    async_conf_req = 1;
    async_conf = conf;
    while (!async_conf_ack) delay(1);
    async_conf_req = 0;
end
endtask

reg test_run_0, test_run_1;
initial begin
    test_run_0 = 0;
    test_run_1 = 0;
    reset_task;
    delay(10);
    set_config(8'h68);
    delay(10);
    test_run_1 = 1; delay(1); test_run_0 = 1;
    //send_rx_char(8,0);
    //delay(100);
    //send_rx_char(10,1);
    $finish;
end

reg reset_d;
always @(posedge clock)
    reset_d <= #2 reset;

wire reset_posedge;
assign reset_posedge = ~reset_d &  reset;
wire reset_negedge;
assign reset_negedge =  reset_d & ~reset;

reg async_tx_d_ack_d;
always @(posedge clock)
    async_tx_d_ack_d <= async_tx_d_ack;

wire async_tx_d_ack_posedge;
assign async_tx_d_ack_posedge = ~async_tx_d_ack_d &  async_tx_d_ack;

wire async_tx_d_ack_negedge;
assign async_tx_d_ack_negedge =  async_tx_d_ack_d & ~async_tx_d_ack;

always @(posedge clock)
if (reset) begin
    async_tx_d_req <= 0;
    async_tx_d <= 0;
end else if (~test_run_0 & test_run_1) begin
    async_tx_d_req <= 1;
    async_tx_d <= $random;
end else if (test_run_1 & async_tx_d_ack_posedge) begin
    async_tx_d_req <= 0;
    async_tx_d <= 0;
end else if (test_run_1 & async_tx_d_ack_negedge) begin
    async_tx_d_req <= 1;
    async_tx_d <= $random;
end else begin
    async_tx_d_req <= async_tx_d_req;
    async_tx_d <= async_tx_d;
end

reg async_rx_d_req_d;
always @(posedge clock)
    async_rx_d_req_d <= async_rx_d_req;

wire async_rx_d_req_posedge;
assign async_rx_d_req_posedge = ~async_rx_d_req_d &  async_rx_d_req;

wire async_rx_d_req_negedge;
assign async_rx_d_req_negedge =  async_rx_d_req_d & ~async_rx_d_req;

always @(posedge clock)
if (reset) begin
    async_rx_d_ack <= 0;
end else if (test_run_1 & async_rx_d_req_posedge) begin
    async_rx_d_ack <= 1;
end else if (test_run_1 & async_rx_d_req_negedge) begin
    async_rx_d_ack <= 0;
end else begin
    async_rx_d_ack <= async_rx_d_ack;
end

always #1 rx = tx;

uart_top #(
   .FREQ (FREQ)
  ,.CONFIG_WIDTH (8)
  ,.UART_DATA_WIDTH (8)
  ,.SYNC_STAGE(2)
) uart (
   .clock               (clock              )
  ,.reset               (reset              )
  ,.rx                  (rx                 )
  ,.tx                  (tx                 )
  ,.async_rx_d_ack      (async_rx_d_ack     )
  ,.async_rx_d_req      (async_rx_d_req     )
  ,.async_rx_d          (async_rx_d         )
  ,.async_tx_d_req      (async_tx_d_req     )
  ,.async_tx_d_ack      (async_tx_d_ack     )
  ,.async_tx_d          (async_tx_d         )
  ,.async_conf_req      (async_conf_req     )
  ,.async_conf_ack      (async_conf_ack     )
  ,.async_conf          (async_conf         )
);

endmodule
