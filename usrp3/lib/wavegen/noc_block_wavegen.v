//////////////////////////////////////////////////////////////////////////////////
// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 07/14/2016 07:29:14 PM
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

module noc_block_wavegen #(
  parameter NOC_ID = 64'hDFA0_0000_0000_0000,
  parameter STR_SINK_FIFOSIZE = 11)
(
  input bus_clk, input bus_rst,
  input ce_clk, input ce_rst,
  input  [63:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [63:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready,
  output [63:0] debug,
  input pps, input sync_in, output sync_out,
  input rx_stb
);

  ////////////////////////////////////////////////////////////
  //
  // RFNoC Shell
  //
  ////////////////////////////////////////////////////////////
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
  wire [15:0] src_sid;
  wire [15:0] resp_in_dst_sid, resp_out_dst_sid;
  wire [63:0]                     vita_time;
  wire [31:0]                     test_readback;

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
    .set_data(set_data), .set_addr(set_addr), .set_stb(set_stb), .set_time(),
    .rb_stb(1'b1), .rb_data(rb_data), .rb_addr(rb_addr),
    // Control Source
    .cmdout_tdata(cmdout_tdata), .cmdout_tlast(cmdout_tlast), .cmdout_tvalid(cmdout_tvalid), .cmdout_tready(cmdout_tready),
    .ackin_tdata(ackin_tdata), .ackin_tlast(ackin_tlast), .ackin_tvalid(ackin_tvalid), .ackin_tready(ackin_tready),
    // Stream Sink
    .str_sink_tdata(str_sink_tdata), .str_sink_tlast(str_sink_tlast), .str_sink_tvalid(str_sink_tvalid), .str_sink_tready(str_sink_tready),
    // Stream Source
    .str_src_tdata(str_src_tdata), .str_src_tlast(str_src_tlast), .str_src_tvalid(str_src_tvalid), .str_src_tready(str_src_tready),
    .clear_tx_seqnum(clear_tx_seqnum), .src_sid(src_sid), .next_dst_sid(next_dst_sid), .resp_in_dst_sid(resp_in_dst_sid), .resp_out_dst_sid(resp_out_dst_sid),
    .vita_time(vita_time), .debug(debug));

  // Control Source Unused
  // assign cmdout_tdata = 64'd0;
  // assign cmdout_tlast = 1'b0;
  // assign cmdout_tvalid = 1'b0;

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

  wire [31:0] buf_m_axis_data_tdata;
  wire [127:0] buf_m_axis_data_tuser;
  wire        buf_m_axis_data_tlast;
  wire        buf_m_axis_data_tvalid;
  wire        buf_m_axis_data_tready;


  wire [31:0] s_axis_data_tdata;
  wire [127:0] s_axis_data_tuser;
  wire        s_axis_data_tlast;
  wire        s_axis_data_tvalid;
  wire        s_axis_data_tready;

  wire [31:0] s_axis_awg_data_tdata;
  wire [127:0] s_axis_awg_data_tuser;
  wire        s_axis_awg_data_tlast;
  wire        s_axis_awg_data_tvalid;
  wire        s_axis_awg_data_tready;


  // VITA time is shared between radio cores
  `include "../../lib/radio/radio_core_regs.vh"
  `include "wavegen_regs.vh"
  wire [63:0] vita_time_lastpps;
  timekeeper #(
    .SR_TIME_HI(SR_TIME_HI),
    .SR_TIME_LO(SR_TIME_LO),
    .SR_TIME_CTRL(SR_TIME_CTRL))
  timekeeper (
    .clk(ce_clk), .reset(ce_rst), .pps(pps), .sync_in(sync_in), .strobe(rx_stb),
    .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),
    .vita_time(vita_time), .vita_time_lastpps(vita_time_lastpps),
    .sync_out(sync_out));

  axi_wrapper #(
    .SIMPLE_MODE(0), .RESIZE_OUTPUT_PACKET(0))
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

// assign m_axis_data_tready = 1'b1;


  ////////////////////////////////////////////////////////////
  //
  // Arbitrary Waveform Generator Implementation
  //
  ////////////////////////////////////////////////////////////

  localparam CHIRP_CLK_FREQ = 200000000;    // Hz
  localparam ADC_SAMPLE_COUNT_INIT = 32'h000001ff;
  localparam CHIRP_PRF_INT_COUNT_INIT = 32'h00000000;
  //localparam CHIRP_PRF_FRAC_COUNT_INIT = 32'h1d4c0000;
  localparam CHIRP_PRF_FRAC_COUNT_INIT = 32'h00000fff;

  localparam CHIRP_TUNING_COEF_INIT = 32'b1;
  localparam CHIRP_COUNT_MAX_INIT = 32'h00000dff; // 3584 samples
  localparam CHIRP_FREQ_OFFSET_INIT = 32'h0b00; // 2816 -> 10.56 MHz min freq
  localparam AWG_CTRL_WORD_INIT = 32'h10;
  localparam RADAR_POLICY_INIT = 32'd1;
  localparam MAX_SPP_INIT = 32'd64;
  // POLICY[0] : auto(0) or manual(1).
  // POLICY[1] : use cmd time(0) or forward cmd time(1)
  // POLICY[2] : do not send rx cmd (0) or send rx cmd1)

  wire awg_ready;
  wire awg_done;
  wire awg_active;
  wire awg_init;
  wire awg_enable;
  wire adc_enable;
  wire adc_run;
  wire adc_last;
  wire [31:0] awg_control_word;
  wire [31:0] num_adc_samples;
  wire [63:0] prf;
  wire [31:0] policy;
  wire [31:0] max_spp;
  wire [63:0] timestamp;
  wire has_time;

  wire [31:0] awg_data_tdata;
  wire [127:0] awg_data_tuser;
  wire        awg_data_tlast;
  wire        awg_data_tvalid;
  wire        awg_data_tready;

   wire [31:0] awg_data_len;         // payload len in samples

   wire [31:0] m_axis_awg_reload_tdata;
   wire        m_axis_awg_reload_tvalid, m_axis_awg_reload_tready, m_axis_awg_reload_tlast;

   wire [63:0] rx_cmdout_tdata, resp_tdata;
   wire        rx_cmdout_tlast, rx_cmdout_tvalid, rx_cmdout_tready, resp_tlast, resp_tvalid, resp_tready;

   reg in_sample_passthrough_r,in_sample_load_r;
   wire in_sample_passthrough,in_sample_load;

  // Readback registers

  always @(*) begin
    case (rb_addr)
      RB_VITA_TIME  : rb_data <= vita_time;
      RB_VITA_LASTPPS : rb_data <= vita_time_lastpps;
      RB_TEST         : rb_data <= {32'd0,test_readback};
      RB_AWG_LEN   : rb_data <= {32'd0, awg_data_len};
      RB_ADC_LEN   : rb_data <= {32'd0, num_adc_samples};
      // All others default to daughter board control readback data
      RB_AWG_CTRL    : rb_data <= {32'd0, awg_control_word};
      RB_AWG_PRF     : rb_data <= prf;
      RB_AWG_POLICY  : rb_data <= {32'd0, policy};
      RB_AWG_STATE  : rb_data <= {56'd0,1'd0, awg_ready,awg_active,awg_enable,2'd0,adc_enable,adc_run};
      default         : rb_data <= 64'h0BADC0DE0BADC0DE;
    endcase
  end

  // Switches to either pass incoming samples on m_axis_data_tready through to radio or load them into the awg (requires valid header pre-appended)



  always @(posedge ce_clk) begin
   if (ce_rst) begin
       in_sample_passthrough_r <= 1'b0;
       in_sample_load_r <= 1'b0;
   end else begin
       in_sample_passthrough_r <= awg_control_word[0];
       in_sample_load_r <= awg_control_word[1];
   end
  end

  assign sample_passthrough = sample_passthrough_r;
  assign in_sample_load = in_sample_load_r;

  axi_stream_buffer #(.FIFO_SIZE(64),.WIDTH(32))
  axi_stream_buffer_i (.clk(ce_clk), .reset(ce_rst), .clear(clear_tx_seqnum),
  .i_tdata(m_axis_data_tdata),.i_tuser(m_axis_data_tuser), .i_tlast(m_axis_data_tlast), .i_tvalid(m_axis_data_tvalid), .i_tready(m_axis_data_tready),
  .o_tdata(buf_m_axis_data_tdata), .o_tuser(buf_m_axis_data_tuser), .o_tlast(buf_m_axis_data_tlast), .o_tvalid(buf_m_axis_data_tvalid), .o_tready(buf_m_axis_data_tready));

  axi_pulse_mux #(.NUM_INPUTS(2),.MUX_PRE_FIFO_SIZE(0),.MUX_POST_FIFO_SIZE(0),.FIFO_SIZE(5),.WIDTH(32))
  axi_pulse_mux_i (.clk(ce_clk), .reset(ce_rst), .clear(1'b0),
  .i_tdata({buf_m_axis_data_tdata,s_axis_awg_data_tdata}),.i_tuser({buf_m_axis_data_tuser,s_axis_awg_data_tuser}), .i_tlast({buf_m_axis_data_tlast,s_axis_awg_data_tlast}), .i_tvalid({buf_m_axis_data_tvalid,s_axis_awg_data_tvalid}), .i_tready({buf_m_axis_data_tready,s_axis_awg_data_tready}),
  .o_tdata(s_axis_data_tdata), .o_tuser(s_axis_data_tuser), .o_tlast(s_axis_data_tlast), .o_tvalid(s_axis_data_tvalid), .o_tready(s_axis_data_tready));

  // pulse sample reload bus
  // (see Xilinx FIR Filter Compiler documentation)
  axi_setting_reg #(
    .ADDR(SR_AWG_RELOAD),
    .USE_ADDR_LAST(1),
    .ADDR_LAST(SR_AWG_RELOAD_LAST),
    .WIDTH(32),
    .USE_FIFO(1),
    .FIFO_SIZE(2))
  set_awg_samples (
    .clk(ce_clk),
    .reset(ce_rst),
    .set_stb(set_stb),
    .set_addr(set_addr),
    .set_data(set_data),
    .o_tdata(m_axis_awg_reload_tdata),
    .o_tlast(m_axis_awg_reload_tlast),
    .o_tvalid(m_axis_awg_reload_tvalid),
    .o_tready(m_axis_awg_reload_tready));


    setting_reg #(.my_addr(SR_AWG_CTRL_WORD_ADDR), .at_reset(AWG_CTRL_WORD_INIT)) sr_awg_ctrl_word (
      .clk(ce_clk),.rst(ce_rst),.strobe(set_stb),.addr(set_addr),
      .in(set_data),.out(awg_control_word),.changed());

  // Set this register to put a test value on the readback mux.
  setting_reg #(.my_addr(SR_TEST), .width(32)) sr_test (
    .clk(ce_clk), .rst(ce_rst), .strobe(set_stb), .addr(set_addr), .in(set_data),
    .out(test_readback), .changed());

 setting_reg #(.my_addr(SR_RADAR_CTRL_POLICY), .at_reset(RADAR_POLICY_INIT)) sr_policy (
       .clk(ce_clk),.rst(ce_rst),.strobe(set_stb),.addr(set_addr),
       .in(set_data),.out(policy),.changed());

   setting_reg #(.my_addr(SR_RADAR_CTRL_MAXLEN), .at_reset(MAX_SPP_INIT)) sr_max_spp (
         .clk(ce_clk),.rst(ce_rst),.strobe(set_stb),.addr(set_addr),
         .in(set_data),.out(max_spp),.changed());


    wavegen_block #(
        .CHIRP_TUNING_COEF_INIT(CHIRP_TUNING_COEF_INIT),
        .CHIRP_COUNT_MAX_INIT (CHIRP_COUNT_MAX_INIT),
        .CHIRP_FREQ_OFFSET_INIT (CHIRP_FREQ_OFFSET_INIT),


        .SR_CH_COUNTER_ADDR(SR_CH_COUNTER_ADDR),
        .SR_CH_TUNING_COEF_ADDR(SR_CH_TUNING_COEF_ADDR),
        .SR_CH_FREQ_OFFSET_ADDR(SR_CH_FREQ_OFFSET_ADDR)
    )
    wavegen_block_inst (
        .clk(ce_clk),
        .rst(ce_rst),

        .clear(1'b0),
        .vita_time(vita_time), .resp_sid({src_sid,resp_in_dst_sid}),

        .resp_tdata(resp_tdata), .resp_tlast(resp_tlast), .resp_tvalid(resp_tvalid), .resp_tready(resp_tready),

        .awg_out_iq(awg_data_tdata),
        .awg_data_valid(awg_data_tvalid),
        .awg_data_last(awg_data_tlast),
        .awg_data_ready(awg_data_tready),
        .awg_data_len(awg_data_len),

        .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),

        .wr_axis_tdata(m_axis_awg_reload_tdata),
        .wr_axis_tvalid(m_axis_awg_reload_tvalid),
        .wr_axis_tlast(m_axis_awg_reload_tlast),
        .wr_axis_tuser(),
        .wr_axis_tkeep(),
        .wr_axis_tdest(),
        .wr_axis_tid(),
        .wr_axis_tready(m_axis_awg_reload_tready),

        .awg_control_word(awg_control_word),


        .awg_ready (awg_ready),
        .awg_done (awg_done),
        .awg_active (awg_active),
        .awg_init  (awg_init),
        .awg_enable  (awg_enable),
        .adc_enable   (adc_enable)

    );

    radar_pulse_controller #(
        .CLK_FREQ (CHIRP_CLK_FREQ),
        .ADC_SAMPLE_COUNT_INIT(ADC_SAMPLE_COUNT_INIT),
        .CHIRP_PRF_INT_COUNT_INIT(CHIRP_PRF_INT_COUNT_INIT),
        .CHIRP_PRF_FRAC_COUNT_INIT(CHIRP_PRF_FRAC_COUNT_INIT),

        .SR_PRF_INT_ADDR(SR_PRF_INT_ADDR),
        .SR_PRF_FRAC_ADDR(SR_PRF_FRAC_ADDR),
        .SR_ADC_SAMPLE_ADDR(SR_ADC_SAMPLE_ADDR),
        .SR_RADAR_CTRL_COMMAND(SR_RADAR_CTRL_COMMAND),
        .SR_RADAR_CTRL_TIME_HI(SR_RADAR_CTRL_TIME_HI),
        .SR_RADAR_CTRL_TIME_LO(SR_RADAR_CTRL_TIME_LO),
        .SR_RADAR_CTRL_CLEAR_CMDS(SR_RADAR_CTRL_CLEAR_CMDS)
    )
    radar_pulse_controller_inst (
      //.aclk(sysclk_bufg),
      //.aresetn(sysclk_resetn),
      .clk(ce_clk),
      .reset(ce_rst),
      .vita_time(vita_time),
      .set_stb(set_stb), .set_addr(set_addr), .set_data(set_data),

      .num_adc_samples (num_adc_samples),
      .awg_data_valid(awg_data_tvalid),
      .prf_out(prf),
      .policy(policy),

      .timestamp(timestamp),
      .has_time(has_time),

      .awg_ready (awg_ready),
      .awg_done (awg_done),
      .awg_active (awg_active),
      .awg_init  (awg_init),
      .awg_enable  (awg_enable),
      .adc_enable   (adc_enable),
      .adc_run (adc_run),
      .adc_last (adc_last)
    );

    rx_command_gen #(
        .FIFO_SIZE(5),
        .SR_RX_CTRL_COMMAND(SR_RX_CTRL_COMMAND),
        .SR_RX_CTRL_TIME_HI(SR_RX_CTRL_TIME_HI),
        .SR_RX_CTRL_TIME_LO(SR_RX_CTRL_TIME_LO)
    ) rx_command_gen(
          .clk(ce_clk), .reset(ce_rst), .clear(1'b0),
          .cmdout_tdata(rx_cmdout_tdata), .cmdout_tlast(rx_cmdout_tlast), .cmdout_tvalid(rx_cmdout_tvalid),.cmdout_tready(rx_cmdout_tready),
          .awg_data_len(awg_data_len),
          .num_adc_samples (num_adc_samples),
          .src_sid(src_sid), .dst_sid(next_dst_sid),
          .vita_time(timestamp),
          .has_time(has_time),
          .send_cmds(policy[2]),
          .awg_init (awg_init),
          .adc_run (adc_run),
          .adc_enable (adc_enable));


  axi_burst_packetizer axi_burst_packetizer
     (.clk(ce_clk), .reset(ce_rst),
      .max_spp(max_spp),
      .i_tdata(awg_data_tdata), .i_tuser(awg_data_tuser), .i_tlast(awg_data_tlast), .i_tvalid(awg_data_tvalid), .i_tready(awg_data_tready),
      // .o_tdata(s_axis_data_tdata), .o_tuser(s_axis_data_tuser), .o_tlast(s_axis_data_tlast), .o_tvalid(s_axis_data_tvalid), .o_tready(s_axis_data_tready));
      .o_tdata(s_axis_awg_data_tdata), .o_tuser(s_axis_awg_data_tuser), .o_tlast(s_axis_awg_data_tlast), .o_tvalid(s_axis_awg_data_tvalid), .o_tready(s_axis_awg_data_tready));

    cvita_hdr_encoder cvita_hdr_encoder (
      .pkt_type(2'd0), .eob(1'b1), .has_time(has_time),
      .seqnum(12'd0), .payload_length({awg_data_len[13:0],2'b00}), .dst_sid(next_dst_sid), .src_sid(src_sid),
      .vita_time(timestamp),
      .header(awg_data_tuser));


  // assign payload_length = (max_spp == 0) ? {awg_data_len[13:0],2'b00} : (awg_data_len >= (samp_count + max_spp)) ? {max_spp[13:0],2'b00} : {last_pkt_len[13:0],2'b00} ;
  // assign eob = ((max_spp == 0) | (awg_data_len < (samp_count + max_spp))) ? 1'b1 : 1'b0;


  // Command and response packet mux
  // axi_mux  #(.WIDTH(64), .PRE_FIFO_SIZE(0), .POST_FIFO_SIZE(1), .SIZE(2))
  // axi_mux_cmd (
  //   .clk(ce_clk), .reset(ce_rst), .clear(1'b0),
  //   .i_tdata({rx_cmdout_tdata,resp_tdata}), .i_tlast({rx_cmdout_tlast,resp_tlast}), .i_tvalid({rx_cmdout_tvalid,resp_tvalid}), .i_tready({rx_cmdout_tready,resp_tready}),
  //   .o_tdata(cmdout_tdata), .o_tlast(cmdout_tlast), .o_tvalid(cmdout_tvalid), .o_tready(cmdout_tready));
  assign cmdout_tdata = rx_cmdout_tdata;
  assign cmdout_tlast = rx_cmdout_tlast;
  assign cmdout_tvalid = rx_cmdout_tvalid;
  assign rx_cmdout_tready = cmdout_tready;
  // assign cmdout_tvalid = (policy[3]) ? rx_cmdout_tvalid : 0;
  // assign rx_cmdout_tready = (policy[3]) ? cmdout_tready : 1;

  assign resp_tready = 1'b1;


endmodule
