//////////////////////////////////////////////////////////////////////////////////
// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 03/14/2017 07:29:14 PM
// Design Name:
// Module Name: noc_block_wavegen
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

module noc_block_pulse_avg #(
  parameter NOC_ID = 64'hDFB0_0000_0000_0000,
  parameter STR_SINK_FIFOSIZE = 11)
(
  input bus_clk, input bus_rst,
  input ce_clk, input ce_rst,
  input  [63:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
  output [63:0] debug
);

wire [31:0] set_data;
wire [7:0]  set_addr;
wire        set_stb;
reg  [63:0] rb_data;
wire [7:0]  rb_addr;

wire [63:0] cmdout_tdata, ackin_tdata;
wire        cmdout_tlast, cmdout_tvalid, cmdout_tready, ackin_tlast, ackin_tvalid, ackin_tready;

wire [63:0] str_sink_tdata, str_src_tdata;
wire        str_sink_tlast, str_sink_tvalid, str_sink_tready, str_src_tlast, str_src_tvalid, str_src_tready;

wire        clear_tx_seqnum;
wire [15:0] next_dst_sid;

noc_shell #(
  .NOC_ID(NOC_ID),
  .STR_SINK_FIFOSIZE(STR_SINK_FIFOSIZE))
noc_shell (
  .bus_clk(bus_clk), .bus_rst(bus_rst),
  .i_tdata(i_tdata), .i_tlast(i_tlast), .i_tvalid(i_tvalid), .i_tready(i_tready),
  .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready),
  // Computer Engine Clock Domain
  .clk(ce_clk), .reset(ce_rst),
  // Control Sink
  .set_data(set_data), .set_addr(set_addr), .set_stb(set_stb),
  .rb_stb(1'b1), .rb_data(rb_data), .rb_addr(rb_addr),
  // Control Source
  .cmdout_tdata(cmdout_tdata), .cmdout_tlast(cmdout_tlast), .cmdout_tvalid(cmdout_tvalid), .cmdout_tready(cmdout_tready),
  .ackin_tdata(ackin_tdata), .ackin_tlast(ackin_tlast), .ackin_tvalid(ackin_tvalid), .ackin_tready(ackin_tready),
  // Stream Sink
  .str_sink_tdata(str_sink_tdata), .str_sink_tlast(str_sink_tlast), .str_sink_tvalid(str_sink_tvalid), .str_sink_tready(str_sink_tready),
  // Stream Source
  .str_src_tdata(str_src_tdata), .str_src_tlast(str_src_tlast), .str_src_tvalid(str_src_tvalid), .str_src_tready(str_src_tready),
  .clear_tx_seqnum(clear_tx_seqnum), .src_sid(), .next_dst_sid(next_dst_sid), .resp_in_dst_sid(), .resp_out_dst_sid(),
  .debug(debug));

  // Control Source Unused
  assign cmdout_tdata = 64'd0;
  assign cmdout_tlast = 1'b0;
  assign cmdout_tvalid = 1'b0;
  assign ackin_tready = 1'b1;

  ////////////////////////////////////////////////////////////
  //
  // AXI Wrapper
  // Convert RFNoC Shell interface into AXI stream interface
  //
  ////////////////////////////////////////////////////////////
  wire [31:0] m_axis_data_tdata;
  wire [127:0] m_axis_data_tuser;
  wire        m_axis_data_tlast;
  wire        m_axis_data_tvalid;
  wire        m_axis_data_tready;

  wire [31:0] s_axis_data_tdata;
  wire [127:0] s_axis_data_tuser;
  wire        s_axis_data_tlast;
  wire        s_axis_data_tvalid;
  wire        s_axis_data_tready;

  `include "pulse_avg_regs.vh"

  axi_wrapper #(
    .SIMPLE_MODE(0))
  inst_axi_wrapper (
    .bus_clk(bus_clk), .bus_rst(bus_rst), 
    .clk(ce_clk), .reset(ce_rst),
    .clear_tx_seqnum(clear_tx_seqnum),
    .next_dst(next_dst_sid),
    .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),
    .i_tdata(str_sink_tdata), .i_tlast(str_sink_tlast), .i_tvalid(str_sink_tvalid), .i_tready(str_sink_tready),
    .o_tdata(str_src_tdata), .o_tlast(str_src_tlast), .o_tvalid(str_src_tvalid), .o_tready(str_src_tready),
    .m_axis_data_tuser(m_axis_data_tuser),
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tlast(m_axis_data_tlast),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .s_axis_data_tuser(s_axis_data_tuser),
    .s_axis_data_tdata(s_axis_data_tdata),
    .s_axis_data_tlast(s_axis_data_tlast),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(s_axis_data_tready),
    .m_axis_pkt_len_tdata(),
    .m_axis_pkt_len_tvalid(),
    .m_axis_pkt_len_tready(),
    .m_axis_config_tdata(),
    .m_axis_config_tlast(),
    .m_axis_config_tvalid(),
    .m_axis_config_tready());


    // Control Source Unused

    localparam MAX_PULSE_SIZE = 8192;

    wire [31:0] pulse_size, num_avg, num_count;

    setting_reg #(.my_addr(SR_PULSE_LENGTH), .at_reset(MAX_PULSE_SIZE)) sr_pulse_len (
          .clk(ce_clk),.rst(ce_rst),.strobe(set_stb),.addr(set_addr),
          .in(set_data),.out(pulse_size),.changed());

    setting_reg #(.my_addr(SR_PULSE_NUM_AVG), .at_reset(1)) sr_avg_num (
        .clk(ce_clk),.rst(ce_rst),.strobe(set_stb),.addr(set_addr),
        .in(set_data),.out(num_avg),.changed());

    // Readback register for maximum window size
    always @(*) begin
      case(rb_addr)
        RB_PULSE_LENGTH    : rb_data <= {MAX_PULSE_SIZE};
        default : rb_data <= 64'h0BADC0DE0BADC0DE;
      endcase
    end

    pulse_avg_core #(
        .MAX_PULSE_SIZE(MAX_PULSE_SIZE)
    )
    pulse_avg_core_inst (
        .clk(ce_clk), .reset(ce_rst), .clear(clear_avg),
        .pulse_size(pulse_size), .num_avg(num_avg), .num_count(num_count),
        .i_tdata(sample_tdata),.i_tuser(sample_tuser), .i_tvalid(sample_tvalid), .i_tlast(sample_tlast), .i_tready(sample_tready),
        .o_tdata(avg_tdata), .o_tuser(avg_tuser), .o_tvalid(avg_tvalid), .o_tlast(avg_tlast), .o_tready(avg_tready));

endmodule
