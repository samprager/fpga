`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 07/14/2016 04:32:51 PM
// Design Name:
// Module Name: chirp_sim_tb
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


module axi_bram_stream_tb;

localparam CLK_PERIOD          = 5000;         // 200 MHz
localparam RESET_PERIOD = 20000; //in pSec

reg reset_i;
reg clk_i;
reg clear_i = 0;

wire clk;
wire reset;
wire clear;

reg [31:0] i_tdata;
reg [127:0] i_tuser;
reg i_tvalid, i_tlast;
wire i_tready;
wire [31:0] o_tdata;
wire [127:0] o_tuser;
wire o_tvalid, o_tlast;
reg o_tready;

wire [31:0] out_size;
reg [31:0] in_size = 32'd10;
reg init_write;
wire write_ready, read_ready;

reg [31:0] wr_data;
reg [7:0] counter;
reg [7:0] dcounter;

initial
begin
      clk_i = 1'b0;
end

initial begin
  reset_i = 1'b1;
  #RESET_PERIOD
    reset_i = 1'b0;
 end

always
  begin
      clk_i = #(CLK_PERIOD/2.0) ~clk_i;
end

assign clk = clk_i;
assign reset = reset_i;
assign clear = clear_i;

initial begin
      repeat(4096)@(posedge clk); // wait for reset
      $finish;
end

always @(posedge clk) begin
    if (reset) begin
        init_write <= 0;
        i_tvalid <= 0;
        i_tlast <= 0;
        o_tready <= 0;
        counter <= 0;
        dcounter <= 0;
        i_tdata <= 0;
        i_tuser <= 0;
    end
    else begin
        counter <= counter + 1;
        o_tready <= 1;

        if (write_ready & counter == 0 )
            init_write <= 1;
        else if (write_ready)
            init_write <= 0;

        // if (counter < 8'hf)
        //     i_tvalid <= 1;
        // else
        //     i_tvalid <= 0;

        i_tvalid <= 1;

        if (i_tvalid & i_tready)
            i_tdata <= i_tdata +1;

        if (i_tvalid & i_tready & !i_tlast)
            dcounter <= dcounter+1;
        else if (i_tlast)
        	dcounter <= 0;

        if (dcounter == (in_size-8'd2) & i_tvalid & i_tready)
            i_tlast <= 1;
        else if (i_tready)
            i_tlast <= 0;
    end
end

axi_bram_stream axi_bram_stream_inst(
  .clk  (clk),
  .reset	(reset),
  .clear (clear),
  .in_size(in_size),
  .init_write(init_write),
  .write_ready(write_ready),
  .read_ready(read_ready),
  .out_size(out_size),
    // data to BRAM
  .in_axis_tdata(i_tdata),
  .in_axis_tvalid(i_tvalid),
  .in_axis_tlast(i_tlast),
  .in_axis_tkeep(4'hf),
  .in_axis_tready(i_tready),
  .out_axis_tdata(o_tdata),
  .out_axis_tvalid(o_tvalid),
  .out_axis_tlast(o_tlast),
  .out_axis_tkeep(),
  .out_axis_tready(o_tready)
);


endmodule
