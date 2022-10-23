`timescale 1ns/1ps

module tb();

localparam FREQ = 10_000_0;
localparam BAUD_RATE = 9600;
localparam BIT = FREQ/BAUD_RATE;

reg rx;
wire tx;
wire rx_empty;
wire [7:0] rx_d_out;

wire tx_pulse;
wire tx_wr;
wire tx_full;
reg [7:0] tx_d_in;

wire plic_rx_req;
reg plic_rx_ack;
wire plic_tx_req;
reg plic_tx_ack;

reg uart_ir_en_req;
wire uart_ir_en_ack;
reg [31:0] uart_ir_en;

reg uart_ir_clear_req;
wire uart_ir_clear_ack;
reg [31:0] uart_ir_clear;

reg uart_conf_req;
wire uart_conf_ack;
reg [31:0] uart_conf;

reg rx_ack;
reg rx_req;
reg tx_ack;
reg tx_req;

reg clock;
initial clock = 0;
always clock = #10 ~clock;

reg fast_clock;
initial fast_clock = 0;
always fast_clock = #1 ~fast_clock;

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
    rx = 1;
    uart_ir_en_req = 0;
    uart_ir_en = 0;
    uart_ir_clear_req = 0;
    uart_ir_clear = 0;
    uart_conf_req = 0;
    uart_conf = 0;
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
        rx = ^word_buf; //parity bit
        delay(BIT);
        bit_test = ~bit_test;
        rx = 1; //end bit
        delay(BIT);
    end
end
endtask

task set_config;
input [31:0] conf;
begin
    uart_conf_req = 1;
    uart_conf = conf;
    while (!uart_conf_req) delay(1);
    delay(2);
    uart_conf_req = 0;
    delay(1);
end
endtask

task set_ir;
input [31:0] conf;
begin
    uart_ir_en_req = 1;
    uart_ir_en = conf;
    while (!uart_ir_en_ack) delay(1);
    while (uart_ir_en_ack) delay(1);
    uart_ir_en_req = 0;
end
endtask

task clear_ir;
input [31:0] conf;
begin
    uart_ir_clear_req = 1;
    uart_ir_clear = conf;
    while (!uart_ir_clear_ack) delay(1);
    while (uart_ir_clear_ack) delay(1);
    uart_ir_clear_req = 0;
    delay(1);
end
endtask

reg test_run = 0;
initial begin
    reset_task;
    delay(10);
    set_config(32'h0003_0000);
    delay(10);
    set_ir(32'h00C8_0020);
    delay(10);
    test_run = 1;
    send_rx_char(8);
    delay(100);
    send_rx_char(10);
    $finish;
end

//Clear irterrupt bits
reg uart_ir_clear_ack_d;
always @(posedge fast_clock)
if (reset)  uart_ir_clear_ack_d <= 0;
else        uart_ir_clear_ack_d <= uart_ir_clear_ack;

always @(posedge fast_clock)
if (reset) begin 
    uart_ir_clear_req <= 0;
    uart_ir_clear <= 0;
end else if (uart_ir_clear_req & !uart_ir_clear_ack & uart_ir_clear_ack_d) begin
    uart_ir_clear_req <= 0;
    uart_ir_clear <= 0;
end else if (plic_rx_req) begin
    uart_ir_clear_req <= 1;
    uart_ir_clear <= {16'hFFFF,16'h0};
end else if (plic_tx_req) begin
    uart_ir_clear_req <= 1;
    uart_ir_clear <= {16'h0,16'hFFFF};
end

//Asynchronous Agent on RX line
always @(posedge fast_clock)
if (reset)          rx_ack <= 0;
else if (rx_req)    rx_ack <= #5 1;
else if (!rx_req)   rx_ack <= #5 0;
else                rx_ack <= rx_ack;

assign #6 rx_pulse = rx_ack;
assign #2  rx_rd = rx_req & rx_ack;
wire rx_tmp;
assign #2 rx_tmp = rx_empty | rx_pulse;

always @(posedge fast_clock)
if (reset)                      rx_req <= 0;
else if (rx_pulse & rx_tmp)     rx_req <= 0;
else if (!rx_pulse & !rx_tmp)   rx_req <= 1;
else                            rx_req <= rx_req;

//PLIC response
always @(posedge fast_clock)
if (reset)              plic_rx_ack <= 0;
else if (plic_rx_req)   plic_rx_ack <= 1;
else                    plic_rx_ack <= 0;

always @(posedge fast_clock)
if (reset)              plic_tx_ack <= 0;
else if (plic_tx_req)   plic_tx_ack <= 1;
else                    plic_tx_ack <= 0;

//Asynchronous Agent on TX line
always @(posedge fast_clock)
if (reset)          tx_req <= 0;
else if (!test_run) tx_req <= 0;
else if (tx_ack)    tx_req <= 0;
else if (!tx_ack)   tx_req <= #10 1;
else                tx_req <= tx_req;

assign #6 tx_pulse = tx_req;
assign tx_wr = tx_req;
wire tx_tmp;
assign #2 tx_tmp = tx_pulse & ~tx_full;

always @(posedge fast_clock)
if (reset)                      tx_ack <= 0;
else if (tx_pulse & tx_tmp)     tx_ack <= 1;
else if (!tx_pulse & !tx_tmp)   tx_ack <= 0;
else                            tx_ack <= tx_ack;

reg tx_req_d;
always @(posedge fast_clock)
if (reset) tx_req_d <= 0;
else tx_req_d <= tx_req;
 
always @(posedge fast_clock)
if (reset)                      tx_d_in <= 0;
else if (tx_req & !tx_req_d)    tx_d_in <= $random;
else                            tx_d_in <= tx_d_in;

uart #(
   .FREQ (FREQ)
  ,.BUF_DEPTH (8)
  ,.CONFIG_WIDTH (32)
  ,.UART_DATA_WIDTH (8)
) uart (
   .clock               (clock              )
  ,.reset               (reset              )
  ,.rx                  (rx                 )
  ,.tx                  (tx                 )
  
  ,.rx_pulse            (rx_pulse           )
  ,.rx_rd               (rx_rd              )
  ,.rx_empty            (rx_empty           )
  ,.rx_d_out            (rx_d_out           )
  
  ,.tx_pulse            (tx_pulse           )
  ,.tx_wr               (tx_wr              )
  ,.tx_full             (tx_full            )
  ,.tx_d_in             (tx_d_in            )
  
  ,.plic_rx_req         (plic_rx_req        )
  ,.plic_rx_ack         (plic_rx_ack        )
  ,.plic_tx_req         (plic_tx_req        )
  ,.plic_tx_ack         (plic_tx_ack        )
  
  ,.uart_ir_en_req      (uart_ir_en_req     )
  ,.uart_ir_en_ack      (uart_ir_en_ack     )
  ,.uart_ir_en          (uart_ir_en         )
  
  ,.uart_ir_clear_req   (uart_ir_clear_req  )
  ,.uart_ir_clear_ack   (uart_ir_clear_ack  )
  ,.uart_ir_clear       (uart_ir_clear      )
  
  ,.uart_conf_req       (uart_conf_req      )
  ,.uart_conf_ack       (uart_conf_ack      )
  ,.uart_conf           (uart_conf          )
);

endmodule
