// Created by Samuel Prager.
// Copyright University of Southern California 2018
//
// Modifications based on work by:
//
// Copyright 2015 Ettus Research
// Copyright 2018 Ettus Research, a National Instruments Company
//
// SPDX-License-Identifier: LGPL-3.0-or-later

module axi_stream_buffer#(
  parameter FIFO_SIZE = 5,           // Size of FIFO in CHDR framer
  parameter WIDTH = 32
)(
  input clk, input reset, input clear,
  input [15:0] next_dst_sid,
  input [WIDTH-1:0] i_tdata, input i_tlast, input i_tvalid, output i_tready, input [127:0] i_tuser,
  output [WIDTH-1:0] o_tdata,output [127:0] o_tuser, output o_tlast, output o_tvalid, input o_tready
);
reg sof_in;
reg o_tlast_int;
wire [127:0] header_fifo_i_tdata = {i_tuser[127:96],i_tuser[79:64],next_dst_sid,i_tuser[63:0]};
wire         header_fifo_i_tvalid = sof_in & i_tvalid & i_tready;

// Only store header once per packet
always @(posedge clk)
 if(reset | clear)
   sof_in     <= 1'b1;
 else
   if(i_tvalid & i_tready)
     if(i_tlast)
       sof_in <= 1'b1;
     else
       sof_in <= 1'b0;

always @(posedge clk)
if(reset | clear)
  o_tlast_int     <= 1'b1;
else
  if(o_tvalid & o_tready)
    if(o_tlast)
      o_tlast_int <= 1'b1;
    else
      o_tlast_int <= 1'b0;

axi_fifo #(.WIDTH(128), .SIZE(5)) header_fifo
(.clk(clk), .reset(reset), .clear(0),
.i_tdata(header_fifo_i_tdata),
.i_tvalid(header_fifo_i_tvalid), .i_tready(),
.o_tdata(o_tuser), .o_tvalid(), .o_tready(o_tlast_int & o_tvalid & o_tready),
.occupied(), .space());


axi_fifo #(
  .WIDTH(WIDTH+1), .SIZE(FIFO_SIZE))
inst_axi_fifo (
  .clk(clk), .reset(reset), .clear(1'b0),
  .i_tdata({i_tlast,i_tdata}), .i_tvalid(i_tvalid), .i_tready(i_tready),
  .o_tdata({o_tlast,o_tdata}), .o_tvalid(o_tvalid), .o_tready(o_tready),
  .space(), .occupied());

endmodule