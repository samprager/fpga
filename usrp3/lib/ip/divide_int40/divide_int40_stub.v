// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.4.1 (lin64) Build 2117270 Tue Jan 30 15:31:13 MST 2018
// Date        : Fri Apr 19 18:16:54 2019
// Host        : MT-100036.jpl.nasa.gov running 64-bit CentOS Linux release 7.4.1708 (Core)
// Command     : write_verilog -force -mode synth_stub
//               /home/prager/Projects/ettus/fpga/usrp3/lib/ip/divide_int40/divide_int40_stub.v
// Design      : divide_int40
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z100ffg900-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "div_gen_v5_1_12,Vivado 2017.4.1" *)
module divide_int40(aclk, aresetn, s_axis_divisor_tvalid, 
  s_axis_divisor_tready, s_axis_divisor_tlast, s_axis_divisor_tdata, 
  s_axis_dividend_tvalid, s_axis_dividend_tready, s_axis_dividend_tlast, 
  s_axis_dividend_tdata, m_axis_dout_tvalid, m_axis_dout_tready, m_axis_dout_tuser, 
  m_axis_dout_tlast, m_axis_dout_tdata)
/* synthesis syn_black_box black_box_pad_pin="aclk,aresetn,s_axis_divisor_tvalid,s_axis_divisor_tready,s_axis_divisor_tlast,s_axis_divisor_tdata[39:0],s_axis_dividend_tvalid,s_axis_dividend_tready,s_axis_dividend_tlast,s_axis_dividend_tdata[39:0],m_axis_dout_tvalid,m_axis_dout_tready,m_axis_dout_tuser[0:0],m_axis_dout_tlast,m_axis_dout_tdata[47:0]" */;
  input aclk;
  input aresetn;
  input s_axis_divisor_tvalid;
  output s_axis_divisor_tready;
  input s_axis_divisor_tlast;
  input [39:0]s_axis_divisor_tdata;
  input s_axis_dividend_tvalid;
  output s_axis_dividend_tready;
  input s_axis_dividend_tlast;
  input [39:0]s_axis_dividend_tdata;
  output m_axis_dout_tvalid;
  input m_axis_dout_tready;
  output [0:0]m_axis_dout_tuser;
  output m_axis_dout_tlast;
  output [47:0]m_axis_dout_tdata;
endmodule
