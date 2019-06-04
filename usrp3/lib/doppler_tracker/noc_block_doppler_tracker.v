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

module noc_block_doppler_tracker #(
  parameter NOC_ID = 64'hDFB0_0000_0000_0000,
  parameter STR_SINK_FIFOSIZE = 11)
(
  input bus_clk, input bus_rst,
  input ce_clk, input ce_rst,
  input [63:0] i_tdata, input i_tlast, input i_tvalid, output i_tready,
  output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
  output [63:0] debug, input pps
);

  //----------------------------------------------------------------------------
  // Constants
  //----------------------------------------------------------------------------

  // Settings registers addresses
  localparam SR_SUM_LEN    = 192;
  localparam SR_DIVISOR    = 193;
  localparam SR_THRESHOLD  = 194;
  localparam SR_OFFSET     = 195;
  localparam SR_CALIBRATE  = 196;
  localparam SR_ZC_SUM_LEN = 197;

  //----------------------------------------------------------------------------
  // Wires
  //----------------------------------------------------------------------------

  // Readback register address
  wire [7:0] rb_addr;

  // Number of samples to accumulate
  wire [7:0] sum_len;
  wire sum_len_changed;

  wire [7:0] zc_sum_len;
  wire zc_sum_len_changed;

  // Sum will be divided by this number
  wire [23:0] divisor;

  wire [31:0] threshold, offset;
  wire [15:0] threshold_i,threshold_q, offset_i,offset_q;
  wire [15:0] offset_auto_i,offset_auto_q;

  // RFNoC Shell
  wire [31:0] set_data;
  wire [7:0]  set_addr;
  wire        set_stb;

  wire clear_tx_seqnum;
  wire [15:0] next_dst_sid;

  wire [63:0] str_sink_tdata, str_src_tdata;
  wire str_sink_tlast, str_sink_tvalid, str_sink_tready;
  wire str_src_tlast, str_src_tvalid, str_src_tready;

  // AXI Wrapper
  wire [31:0]  m_axis_data_tdata, s_axis_data_tdata;
  wire [127:0] m_axis_data_tuser;
  wire m_axis_data_tlast, m_axis_data_tvalid, m_axis_data_tready;
  wire s_axis_data_tlast, s_axis_data_tvalid, s_axis_data_tready;

  // I part
  wire [15:0] ipart_tdata;
  wire ipart_tlast, ipart_tvalid, ipart_tready;

  // Q part
  wire [15:0] qpart_tdata;
  wire qpart_tlast, qpart_tvalid, qpart_tready;

  // I part
  wire [31:0] ipart_zc_tdata;
  wire ipart_zc_tlast, ipart_zc_tvalid, ipart_zc_tready;

  wire [31:0] ipart_zc_mavg_tdata;
  wire ipart_zc_mavg_tlast, ipart_zc_mavg_tvalid, ipart_zc_mavg_tready;

  // Q part
  wire [31:0] qpart_zc_tdata;
  wire qpart_zc_tlast, qpart_zc_tvalid, qpart_zc_tready;

  wire [31:0] qpart_zc_mavg_tdata;
  wire qpart_zc_mavg_tlast, qpart_zc_mavg_tvalid, qpart_zc_mavg_tready;

  wire [31:0] ipart_cycles_per_sec, qpart_cycles_per_sec;

  wire [31:0] log_cal_len;
  wire init_cal;

  // I part
   wire [31:0] o_mavg_tdata;
   wire o_mavg_tlast, o_mavg_tvalid, o_mavg_tready;

   // for bypassing moving average
   wire [31:0] o_mavg_use_tdata;
   wire o_mavg_use_tlast, o_mavg_use_tvalid, o_mavg_use_tready;
   wire m_axis_mavg_data_tready;

   reg [31:0] ipart_zc_mavg_tdata_r, qpart_zc_mavg_tdata_r;

  //----------------------------------------------------------------------------
  // Registers
  //----------------------------------------------------------------------------

  // Readback register data
  reg [63:0] rb_data;

  //----------------------------------------------------------------------------
  // Instantiations
  //----------------------------------------------------------------------------

  // Sum length
  setting_reg #(
    .my_addr(SR_SUM_LEN),
    .width(8),
    .at_reset(1))
  sr_sum_len (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(sum_len),
    .changed(sum_len_changed));

  // Divisor
  setting_reg #(
    .my_addr(SR_DIVISOR),
    .width(24),
    .at_reset(1))
  sr_divisor (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(divisor),
    .changed());

  // threshold for detection
  setting_reg #(
    .my_addr(SR_THRESHOLD),
    .width(32))
  sr_zc_threshold (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(threshold),
    .changed());

  // ZC offset bias from zero
  setting_reg #(
    .my_addr(SR_OFFSET),
    .width(32))
  sr_zc_offset (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(offset),
    .changed());

  // Initialize calibration routine to estimate threshold and bias
  setting_reg #(
    .my_addr(SR_CALIBRATE),
    .width(32))
  sr_zc_cal (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(log_cal_len),
    .changed(init_cal));

  // Sum length
  setting_reg #(
    .my_addr(SR_ZC_SUM_LEN),
    .width(8),
    .at_reset(1))
  sr_zc_sum_len (
    .clk(ce_clk),
    .rst(ce_rst),
    .strobe(set_stb),
    .addr(set_addr),
    .in(set_data),
    .out(zc_sum_len),
    .changed(zc_sum_len_changed));

  assign {threshold_i,threshold_q} = threshold;
  assign {offset_i,offset_q} = offset;

  // RFNoC Shell
  noc_shell #(
    .NOC_ID(NOC_ID),
    .STR_SINK_FIFOSIZE(STR_SINK_FIFOSIZE))
  noc_shell (
    .bus_clk(bus_clk),
    .bus_rst(bus_rst),
    .i_tdata(i_tdata),
    .i_tlast(i_tlast),
    .i_tvalid(i_tvalid),
    .i_tready(i_tready),
    .o_tdata(o_tdata),
    .o_tlast(o_tlast),
    .o_tvalid(o_tvalid),
    .o_tready(o_tready),
    // Computer Engine Clock Domain
    .clk(ce_clk),
    .reset(ce_rst),
    // Control Sink
    .set_data(set_data),
    .set_addr(set_addr),
    .set_stb(set_stb),
    .set_time(),
    .set_has_time(),
    .rb_stb(1'b1),
    .rb_data(rb_data),
    .rb_addr(rb_addr),
    // Control Source
    .cmdout_tdata(64'd0),
    .cmdout_tlast(1'b0),
    .cmdout_tvalid(1'b0),
    .cmdout_tready(),
    .ackin_tdata(),
    .ackin_tlast(),
    .ackin_tvalid(),
    .ackin_tready(1'b1),
    // Stream Sink
    .str_sink_tdata(str_sink_tdata),
    .str_sink_tlast(str_sink_tlast),
    .str_sink_tvalid(str_sink_tvalid),
    .str_sink_tready(str_sink_tready),
    // Stream Source
    .str_src_tdata(str_src_tdata),
    .str_src_tlast(str_src_tlast),
    .str_src_tvalid(str_src_tvalid),
    .str_src_tready(str_src_tready),
    .clear_tx_seqnum(clear_tx_seqnum),
    .vita_time(),
    .src_sid(),
    .next_dst_sid(next_dst_sid),
    .resp_in_dst_sid(),
    .resp_out_dst_sid(),
    .debug(debug));

  // AXI Wrapper - Convert RFNoC Shell interface into AXI stream interface
  axi_wrapper
  axi_wrapper_i (
    .bus_clk(bus_clk),
    .bus_rst(bus_rst),
    .clk(ce_clk),
    .reset(ce_rst),
    // RFNoC Shell
    .clear_tx_seqnum(clear_tx_seqnum),
    .next_dst(next_dst_sid),
    .set_stb(),
    .set_addr(),
    .set_data(),
    .i_tdata(str_sink_tdata),
    .i_tlast(str_sink_tlast),
    .i_tvalid(str_sink_tvalid),
    .i_tready(str_sink_tready),
    .o_tdata(str_src_tdata),
    .o_tlast(str_src_tlast),
    .o_tvalid(str_src_tvalid),
    .o_tready(str_src_tready),
    // Internal AXI streams
    .m_axis_data_tdata(m_axis_data_tdata),
    .m_axis_data_tlast(m_axis_data_tlast),
    .m_axis_data_tvalid(m_axis_data_tvalid),
    .m_axis_data_tready(m_axis_data_tready),
    .m_axis_data_tuser(m_axis_data_tuser),
    .s_axis_data_tdata(s_axis_data_tdata),
    .s_axis_data_tlast(s_axis_data_tlast),
    .s_axis_data_tvalid(s_axis_data_tvalid),
    .s_axis_data_tready(s_axis_data_tready),
    .s_axis_data_tuser(),
    .m_axis_config_tdata(),
    .m_axis_config_tlast(),
    .m_axis_config_tvalid(),
    .m_axis_config_tready(),
    .m_axis_pkt_len_tdata(),
    .m_axis_pkt_len_tvalid(),
    .m_axis_pkt_len_tready());



  wire [31:0] sum_len32 = {24'b0,sum_len};
  wire [31:0] divisor32 = {8'b0,divisor};

  wire [31:0] zc_divisor32 = {24'b0,zc_sum_len};

axi_moving_avg #(.MAX_LEN(255),.COMPLEX_IQ(1))
   axi_moving_avg_inst (
     .clk(ce_clk), .reset(ce_rst),
     .len(sum_len32),
     .divisor(divisor32),
     .clear(sum_len_changed),
     .i_tdata(m_axis_data_tdata),
     .i_tlast(m_axis_data_tlast),
     .i_tvalid(m_axis_data_tvalid),
     .i_tready(m_axis_mavg_data_tready),
     .o_tdata(o_mavg_tdata),
     .o_tlast(o_mavg_tlast),
     .o_tvalid(o_mavg_tvalid),
     .o_tready(o_mavg_tready));

  // Split incoming data into I and Q parts
  split_complex #(
    .WIDTH(16))
  split_complex_inst (
    .i_tdata(o_mavg_use_tdata),
    .i_tlast(o_mavg_use_tlast),
    .i_tvalid(o_mavg_use_tvalid),
    .i_tready(o_mavg_tready),
    .oi_tdata(ipart_tdata),
    .oi_tlast(ipart_tlast),
    .oi_tvalid(ipart_tvalid),
    .oi_tready(ipart_tready),
    .oq_tdata(qpart_tdata),
    .oq_tlast(qpart_tlast),
    .oq_tvalid(qpart_tvalid),
    .oq_tready(qpart_tready),
    .error());


assign o_mavg_use_tdata  = (sum_len32 == 32'b1) ? m_axis_data_tdata : o_mavg_tdata;
assign o_mavg_use_tlast  = (sum_len32 == 32'b1) ? m_axis_data_tlast : o_mavg_tlast;
assign o_mavg_use_tvalid  = (sum_len32 == 32'b1) ? m_axis_data_tvalid : o_mavg_tvalid;
assign m_axis_data_tready = (sum_len32 == 32'b1) ? o_mavg_tready : m_axis_mavg_data_tready;

    zero_crossing_detect #(.COUNTER_SIZE(32),.WIDTH(16),.IS_Q_PART(0))
    zc_detect_i(
        .clk(ce_clk),
        .reset(ce_rst),
        .clear(0),
        .threshold(threshold_i),
        .offset(offset_i),
        .offset_out(offset_auto_i),
        .init_cal(init_cal),
        .log_cal_len(log_cal_len),
        .i_tdata(ipart_tdata),
        .i_tlast(ipart_tlast),
        .i_tvalid(ipart_tvalid),
        .i_tready(ipart_tready),
        .o_tdata(ipart_zc_tdata),
        .o_tlast(ipart_zc_tlast),
        .o_tvalid(ipart_zc_tvalid),
        .o_tready(ipart_zc_tready),
        .cycles_per_sec(ipart_cycles_per_sec),
        .iq_sign(qpart_tdata[15]),
        .pps(pps)
    );

    zero_crossing_detect #(.COUNTER_SIZE(32),.WIDTH(16),.IS_Q_PART(1))
    zc_detect_q(
        .clk(ce_clk),
        .reset(ce_rst),
        .clear(0),
        .threshold(threshold_q),
        .offset(offset_q),
        .offset_out(offset_auto_q),
        .init_cal(init_cal),
        .log_cal_len(log_cal_len),
        .i_tdata(qpart_tdata),
        .i_tlast(qpart_tlast),
        .i_tvalid(qpart_tvalid),
        .i_tready(qpart_tready),
        .o_tdata(qpart_zc_tdata),
        .o_tlast(qpart_zc_tlast),
        .o_tvalid(qpart_zc_tvalid),
        .o_tready(qpart_zc_tready),
        .cycles_per_sec(qpart_cycles_per_sec),
        .iq_sign(ipart_tdata[15]),
        .pps(pps)
    );

  // // Concatenate I and Q part again
  // join_complex #(
  //   .WIDTH(32))
  // join_complex_inst (
  //   .ii_tdata(ipart_zc_tdata),
  //   .ii_tlast(ipart_zc_tlast),
  //   .ii_tvalid(ipart_zc_tvalid),
  //   .ii_tready(ipart_zc_tready),
  //   .iq_tdata(qpart_zc_tdata),
  //   .iq_tlast(qpart_zc_tlast),
  //   .iq_tvalid(qpart_zc_tvalid),
  //   .iq_tready(qpart_zc_tready),
  //   .o_tdata(s_axis_data_tdata),
  //   .o_tlast(s_axis_data_tlast),
  //   .o_tvalid(s_axis_data_tvalid),
  //   .o_tready(s_axis_data_tready),
  //   .error());


axi_moving_avg #(.MAX_LEN(255),.COMPLEX_IQ(0))
   i_zc_moving_avg_inst (
     .clk(ce_clk), .reset(ce_rst),
     .len(zc_sum_len),
     .divisor(zc_divisor32),
     .clear(zc_sum_len_changed),
     .i_tdata(ipart_zc_tdata),
     .i_tlast(ipart_zc_tlast),
     .i_tvalid(ipart_zc_tvalid),
     .i_tready(ipart_zc_tready),
     .o_tdata(ipart_zc_mavg_tdata),
     .o_tlast(ipart_zc_mavg_tlast),
     .o_tvalid(ipart_zc_mavg_tvalid),
     .o_tready(ipart_zc_mavg_tready));

 axi_moving_avg #(.MAX_LEN(255),.COMPLEX_IQ(0))
    q_zc_moving_avg_inst (
      .clk(ce_clk), .reset(ce_rst),
      .len(zc_sum_len),
      .divisor(zc_divisor32),
      .clear(zc_sum_len_changed),
      .i_tdata(qpart_zc_tdata),
      .i_tlast(qpart_zc_tlast),
      .i_tvalid(qpart_zc_tvalid),
      .i_tready(qpart_zc_tready),
      .o_tdata(qpart_zc_mavg_tdata),
      .o_tlast(qpart_zc_mavg_tlast),
      .o_tvalid(qpart_zc_mavg_tvalid),
      .o_tready(qpart_zc_mavg_tready));


always @(posedge ce_clk) begin
  if (ce_rst) begin
    qpart_zc_mavg_tdata_r     <= 0;
    ipart_zc_mavg_tdata_r     <= 0;
  end else begin
    if (ipart_zc_mavg_tvalid && ipart_zc_mavg_tready)
        ipart_zc_mavg_tdata_r     <= ipart_zc_mavg_tdata;
    if (qpart_zc_mavg_tvalid && qpart_zc_mavg_tready)
        qpart_zc_mavg_tdata_r     <= qpart_zc_mavg_tdata;
  end
end

// don't care if we drop samples
wire [32:0] iq_zc_sum = (qpart_zc_mavg_tdata_r + ipart_zc_mavg_tdata_r);
assign s_axis_data_tdata = iq_zc_sum[32:1];
assign s_axis_data_tvalid = qpart_zc_mavg_tvalid | ipart_zc_mavg_tvalid;
assign s_axis_data_tlast =  ipart_zc_mavg_tlast | qpart_zc_mavg_tlast;

assign qpart_zc_mavg_tready = 1'b1;
assign ipart_zc_mavg_tready = 1'b1;

  // Readback register values
  always @*
    case(rb_addr)
      8'd0    : rb_data <= sum_len;
      8'd1    : rb_data <= divisor;
      8'd2    : rb_data <= {ipart_cycles_per_sec,qpart_cycles_per_sec};
      8'd3    : rb_data <= {ipart_zc_mavg_tdata_r,qpart_zc_mavg_tdata_r};
      8'd4    : rb_data <= {threshold_i,threshold_q,offset_auto_i,offset_auto_q};
      default : rb_data <= 64'h0BADC0DE0BADC0DE;
    endcase

endmodule
