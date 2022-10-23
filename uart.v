`timescale 1ns/1ps

/*
    Config:
    [31:16] BAUD: 0 - 1200, 1 - 2400, 2 - 4800, 3 - 9600, 4 - 19200, 5 - 38400, 6 - 57600, 7 - 115200
    [0] PARITY: 0 - even, 1 - odd
    
    Interrupt: TX - [15:0], RX - [31:16]
    [0] - tx done after 1 char sent 
    [1] - tx done after 2 char sent
    [2] - tx done after 4 char sent
    [3] - tx done after 8 char sent
    [4] - tx done after 16 char sent
    [5] - tx done after 32 char sent
    [6] - tx buffer full
    ...
    [16] - rx done after 1 char recv
    [17] - rx done after 2 char recv
    [18] - rx done after 4 char recv
    [19] - rx done after 8 char recv
    [20] - rx done after 16 char recv
    [21] - rx done after 32 char recv
    [22] - rx parity error
    [23] - rx buffer full
    
    If none of completion interrupts are set(done after...) then UART
    continiously runs in both directions.
*/

module uart #(
  parameter FREQ = 200_000_000,
  parameter BUF_DEPTH = 32,
  parameter CONFIG_WIDTH = 32,
  parameter UART_DATA_WIDTH = 8
)(
  //offchip ports
   input    clock
  ,input    reset
  ,input    rx
  ,output   tx
  //asynchronous interface
  //RX
  ,input                            rx_pulse
  ,input                            rx_rd
  ,output                           rx_empty
  ,output   [UART_DATA_WIDTH-1:0]   rx_d_out
  //TX
  ,input                            tx_pulse
  ,input                            tx_wr
  ,output                           tx_full
  ,input    [UART_DATA_WIDTH-1:0]   tx_d_in
  //PLIC
  ,output                           plic_rx_req
  ,input                            plic_rx_ack
  ,output                           plic_tx_req
  ,input                            plic_tx_ack
  //uart csr
  ,input                        uart_ir_en_req
  ,output                       uart_ir_en_ack
  ,input    [CONFIG_WIDTH-1:0]  uart_ir_en      //interrupt enable config
  
  ,input                        uart_ir_clear_req
  ,output                       uart_ir_clear_ack
  ,input    [CONFIG_WIDTH-1:0]  uart_ir_clear   //writing to this reg clears uart_ir
  
  ,input                        uart_conf_req
  ,output                       uart_conf_ack
  ,input    [CONFIG_WIDTH-1:0]  uart_conf
);

wire [CONFIG_WIDTH-1:0] ir_en;
wire [CONFIG_WIDTH-1:0] ir_clear;
wire [CONFIG_WIDTH-1:0] conf;

csr_ctrl #(
    .CONFIG_WIDTH (CONFIG_WIDTH)
) csr_ctrl (
     .clock         (clock)
    ,.reset         (reset)
    ,.ir_clear_req  (uart_ir_clear_req)
    ,.ir_clear_ack  (uart_ir_clear_ack)
    ,.ir_clear_in   (uart_ir_clear)
    ,.ir_clear_out  (ir_clear)
    ,.ir_en_req     (uart_ir_en_req)
    ,.ir_en_ack     (uart_ir_en_ack)
    ,.ir_en_in      (uart_ir_en)
    ,.ir_en_out     (ir_en)
    ,.conf_req      (uart_conf_req)
    ,.conf_ack      (uart_conf_ack)
    ,.conf_in       (uart_conf)
    ,.conf_out      (conf)
);

wire    rx_full;
wire    rx_error_enable, rx_error, rx_error_clear, rx_done;
wire    tx_empty;
wire    tx_done_enable, tx_done, tx_done_clear;

wire [CONFIG_WIDTH/2-1:0] rx_src;
assign rx_src = {8'b0, rx_full, rx_error, rx_done, rx_done, rx_done, rx_done, rx_done, rx_done};

wire [CONFIG_WIDTH/2-1:0] tx_src;
assign tx_src = {9'b0, tx_full, tx_done, tx_done, tx_done, tx_done, tx_done, tx_done};

ir_ctrl #(
    .CONFIG_WIDTH (CONFIG_WIDTH)
) ir_ctrl (
     .clock     (clock)
    ,.reset     (reset)
    ,.ir_rx_req (plic_rx_req)
    ,.ir_rx_ack (plic_rx_ack)
    ,.ir_tx_req (plic_tx_req)
    ,.ir_tx_ack (plic_tx_ack)
    ,.ir_en     (ir_en)
    ,.ir_clear  (ir_clear)
    ,.src       ({rx_src, tx_src})
);

wire                         rx_d_valid;
wire [UART_DATA_WIDTH  -1:0] rx_d_in;

rx #(
     .FREQ   (FREQ)
    ,.CONFIG_WIDTH (CONFIG_WIDTH)
) rx_inst (
    //system
     .clock       (clock)
    ,.reset       (reset)
    ,.rx          (rx)
    ,.dout_valid  (rx_d_valid)
    ,.dout        (rx_d_in)
    //status
    ,.enable      (ir_en[CONFIG_WIDTH-1:CONFIG_WIDTH/2])
    ,.error       (rx_error)
    ,.clear       (ir_clear[CONFIG_WIDTH-1:CONFIG_WIDTH/2])
    ,.done        (rx_done)
    //csr
    ,.rx_conf     (conf)
);

dcfifo #(
    .DEPTH      (BUF_DEPTH),
    .DEPTH_l    ($clog2(BUF_DEPTH)),
    .WIDTH      (UART_DATA_WIDTH)
) rx_buf (
    //read clock
     .rclock    (rx_pulse)
    //write clock
    ,.wclock    (clock)
    //reset
    ,.reset     (reset)
    //write port
    ,.wr        (rx_d_valid)
    ,.din       (rx_d_in)
    //read port
    ,.rd        (rx_rd)
    ,.dout      (rx_d_out)
    //status
    ,.empty     (rx_empty)
    ,.full      (rx_full)
);

wire                            tx_rd;
wire                            tx_d_valid, tx_d_ready;
wire    [UART_DATA_WIDTH-1:0]   tx_d_out;

assign tx_d_valid = !tx_empty;
assign tx_rd = tx_d_ready;

tx #(
     .FREQ   (FREQ)
    ,.CONFIG_WIDTH (CONFIG_WIDTH)
) tx_inst (
    //system
     .clock         (clock)
    ,.reset         (reset)
    ,.tx            (tx)
    ,.din_valid     (tx_d_valid)
    ,.din_ready     (tx_d_ready)
    ,.din           (tx_d_out)
    //status
    ,.enable        (ir_en[CONFIG_WIDTH/2-1:0])
    ,.done          (tx_done)
    ,.clear         (ir_clear[CONFIG_WIDTH/2-1:0])
    //csr
    ,.tx_conf       (conf)
);

dcfifo #(
    .DEPTH      (BUF_DEPTH),
    .DEPTH_l    ($clog2(BUF_DEPTH)),
    .WIDTH      (UART_DATA_WIDTH)
) tx_buf (
    //read clock
     .rclock    (clock)
     //write clock
    ,.wclock    (tx_pulse)
    //reset
    ,.reset     (reset)
    //write port
    ,.wr        (tx_wr)
    ,.din       (tx_d_in)
    //read port
    ,.rd        (tx_rd)
    ,.dout      (tx_d_out)
    //status
    ,.empty     (tx_empty)
    ,.full      (tx_full)
);

endmodule
