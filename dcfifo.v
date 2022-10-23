`timescale 1ns/1ps
/*
  Dual Clock
	Fall ahead fifo.
	Data shows at the output right after being written.
*/
module dcfifo #(
	parameter DEPTH = 16,
	parameter DEPTH_l = 4,
	parameter WIDTH = 8
)(
	input										wclock,
	input										rclock,
	input										reset,
	input										wr,
	input				[WIDTH-1:0]	din,
	input										rd,
	output			[WIDTH-1:0]	dout,
	output									full,
	output									empty
);

reg	[WIDTH-1:0] data [0:DEPTH-1];

reg [DEPTH_l:0] wr_pnt;
reg [DEPTH_l:0] rd_pnt;

integer i;

assign dout = !empty ? data[rd_pnt[DEPTH_l-1:0]] : 0;

assign empty = wr_pnt == rd_pnt;
assign full = (wr_pnt[DEPTH_l] != rd_pnt[DEPTH_l]) & (wr_pnt[DEPTH_l-1:0] == rd_pnt[DEPTH_l-1:0]);

always @(posedge rclock or posedge reset)
if (reset)
	rd_pnt <= 0;
else if (rd & !empty)
	rd_pnt <= rd_pnt + 1;
else
	rd_pnt <= rd_pnt;

always @(posedge wclock or posedge reset)
if (reset)
	wr_pnt <= 0;
else if (wr & !full)
	wr_pnt <= wr_pnt + 1;
else
	wr_pnt <= wr_pnt;

always @(posedge wclock or posedge reset)
if (reset)
	for (i=0; i < DEPTH; i = i+1) begin
		data[i] <= 0;
	end
else if (wr & !full)
	data[wr_pnt] <= din;
else
	for (i=0; i < DEPTH; i = i+1) begin
		data[i] <= data[i];
	end

endmodule
