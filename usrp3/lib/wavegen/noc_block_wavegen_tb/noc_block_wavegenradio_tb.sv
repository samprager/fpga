`timescale 1ns/1ps
`define SIM_TIMEOUT_US 20000
`define NS_PER_TICK 1
`define NUM_TEST_CASES 13


`include "sim_exec_report.vh"
`include "sim_clks_rsts.vh"
`include "sim_rfnoc_lib.svh"


module noc_block_wavegen_tb();
  `TEST_BENCH_INIT("noc_block_wavegen",`NUM_TEST_CASES,`NS_PER_TICK);
  localparam BUS_CLK_PERIOD = $ceil(1e9/50e6);
  localparam CE_CLK_PERIOD  = $ceil(1e9/50e6);//$ceil(1e9/200e6);
  localparam RADIO_CLK_PERIOD = $ceil(1e9/56e6);
  localparam NUM_CE         = 2;  // Number of Computation Engines / User RFNoC blocks to simulate
  localparam NUM_STREAMS    = 1;  // Number of test bench streams
  `RFNOC_SIM_INIT(NUM_CE, NUM_STREAMS, BUS_CLK_PERIOD, CE_CLK_PERIOD);
  //`RFNOC_ADD_BLOCK(noc_block_wavegen, 0);

  `RFNOC_ADD_BLOCK_CUSTOM(noc_block_wavegen, 0 /* xbar port 0 */)
noc_block_wavegen noc_block_wavegen(
  .bus_clk(bus_clk),
  .bus_rst(bus_rst),
  .ce_clk(ce_clk),
  .ce_rst(ce_rst),
  .i_tdata(noc_block_wavegen_i_tdata),
  .i_tlast(noc_block_wavegen_i_tlast),
  .i_tvalid(noc_block_wavegen_i_tvalid),
  .i_tready(noc_block_wavegen_i_tready),
  .o_tdata(noc_block_wavegen_o_tdata),
  .o_tlast(noc_block_wavegen_o_tlast),
  .o_tvalid(noc_block_wavegen_o_tvalid),
  .o_tready(noc_block_wavegen_o_tready),
  .pps(0), .sync_in(0), .sync_out(), .rx_stb(1'b1),
  .debug());



  // Add radio block downstream
  `RFNOC_ADD_BLOCK_CUSTOM(noc_block_radio_core, 1 /* xbar port 1 */)
  `DEFINE_CLK(radio_clk, RADIO_CLK_PERIOD, 50);
  `DEFINE_RESET(radio_rst, 0, 1000);

  /********************************************************
  ** DUT, due to non-standard I/O we cannot use `RFNOC_ADD_BLOCK()
  ********************************************************/
  localparam NUM_CHANNELS = 2;
  localparam TX_STB_RATE = 2;
  localparam RX_STB_RATE = 2;
  logic rx_stb, tx_stb, rx_stb_int, tx_stb_dly;
  logic [32*NUM_CHANNELS-1:0] rx, tx, rx_int;
  logic pps = 1'b0;
  logic sync_in = 1'b0;
  logic [NUM_CHANNELS-1:0] sync;
  logic [NUM_CHANNELS*32-1:0] misc_ins = 'd0;
  logic [NUM_CHANNELS*32-1:0] misc_outs, leds;
  logic [NUM_CHANNELS*32-1:0] fp_gpio_in = 'd0, fp_gpio_fab = 'd0;
  logic [NUM_CHANNELS*32-1:0] db_gpio_in = 'd0, db_gpio_fab = 'd0;
  logic [NUM_CHANNELS*32-1:0] fp_gpio_out, fp_gpio_ddr, db_gpio_out, db_gpio_ddr;
  logic [NUM_CHANNELS*8-1:0] sen;
  logic [NUM_CHANNELS-1:0] sclk, mosi, miso = 'd0;

  wire [NUM_CHANNELS-1:0]    rx_running, tx_running;
  wire [NUM_CHANNELS-1:0]    db_fe_set_stb, db_fe_rb_stb;
  wire [NUM_CHANNELS*8-1:0]  db_fe_set_addr, db_fe_rb_addr;
  wire [NUM_CHANNELS*32-1:0] db_fe_set_data;
  wire [NUM_CHANNELS*64-1:0] db_fe_rb_data;

  noc_block_radio_core #(
    .NUM_CHANNELS(NUM_CHANNELS)
  ) noc_block_radio_core (
    .bus_clk(bus_clk), .bus_rst(bus_rst),
    .ce_clk(radio_clk), .ce_rst(radio_rst),
    // noc_block_radio_core_* signals created by `RFNOC_BLOCK_CUSTOM() above
    .i_tdata(noc_block_radio_core_i_tdata), .i_tlast(noc_block_radio_core_i_tlast),
    .i_tvalid(noc_block_radio_core_i_tvalid), .i_tready(noc_block_radio_core_i_tready),
    .o_tdata(noc_block_radio_core_o_tdata), .o_tlast(noc_block_radio_core_o_tlast),
    .o_tvalid(noc_block_radio_core_o_tvalid), .o_tready(noc_block_radio_core_o_tready),
    .rx_stb({NUM_CHANNELS{rx_stb}}), .rx(rx),
    .tx_stb({NUM_CHANNELS{tx_stb}}), .tx(tx),
    .rx_running(rx_running), .tx_running(tx_running),
    .pps(pps), .sync_in(sync_in), .sync_out(),
    .db_fe_set_stb(db_fe_set_stb), .db_fe_set_addr(db_fe_set_addr), .db_fe_set_data(db_fe_set_data),
    .db_fe_rb_stb(db_fe_rb_stb), .db_fe_rb_addr(db_fe_rb_addr), .db_fe_rb_data(db_fe_rb_data),
    .debug()
  );

  genvar i;
  generate for (i = 0; i < NUM_CHANNELS; i++) begin: dbch
    db_control #(
      .USE_SPI_CLK(1), .SR_BASE(160), .RB_BASE(16)
    ) db_control_i (
      .clk(radio_clk), .reset(radio_rst),
      .set_stb(db_fe_set_stb[i]), .set_addr(db_fe_set_addr[i*8+7:i*8]), .set_data(db_fe_set_data[i*32+31:i*32]),
      .rb_stb(db_fe_rb_stb[i]), .rb_addr(db_fe_rb_addr[i*8+7:i*8]), .rb_data(db_fe_rb_data[i*64+63:i*64]),
      .run_rx(rx_running[i]), .run_tx(tx_running[i]),
      .misc_ins(misc_ins[i*32+31:i*32]), .misc_outs(misc_outs[i*32+31:i*32]),
      .fp_gpio_in(fp_gpio_in[i*32+31:i*32]), .fp_gpio_out(fp_gpio_out[i*32+31:i*32]),
      .fp_gpio_ddr(fp_gpio_ddr[i*32+31:i*32]), .fp_gpio_fab(fp_gpio_fab[i*32+31:i*32]),
      .db_gpio_in(db_gpio_in[i*32+31:i*32]), .db_gpio_out(db_gpio_out[i*32+31:i*32]),
      .db_gpio_ddr(db_gpio_ddr[i*32+31:i*32]), .db_gpio_fab(db_gpio_fab[i*32+31:i*32]),
      .leds(leds[i*32+31:i*32]),
      .spi_clk(bus_clk), .spi_rst(bus_rst), .sen(sen[i*8+7:i*8]), .sclk(sclk[i]), .mosi(mosi[i]), .miso(miso[i])
    );
  end endgenerate

  // Mux to emulate frontend loopback test
  logic rxtx_loopback;
  assign rx = rxtx_loopback ? tx : rx_int;
  assign rx_stb = rxtx_loopback ? tx_stb : rx_stb_int;

  // Create TX / RX strobes and RX input test data
  logic set_rx = 1'b0;
  logic [31:0] set_rx_val[0:NUM_CHANNELS-1];
  integer ramp_val, rx_stb_cnt, tx_stb_cnt;
  logic tx_capture_stb;
  logic [31:0] tx_capture[0:NUM_CHANNELS-1];
  always @(posedge radio_clk) begin
    if (radio_rst) begin
      ramp_val       <= 0;
      rx_int         <= {NUM_CHANNELS{32'h1}};
      rx_stb_int     <= 1'b0;
      tx_stb         <= 1'b0;
      tx_capture     <= '{NUM_CHANNELS{32'd0}};
      tx_capture_stb <= 1'b0;
      rx_stb_cnt     <= 1;
      tx_stb_cnt     <= 1;
    end else begin
      if (rx_stb_cnt == RX_STB_RATE) begin
        rx_stb_int   <= 1'b1;
        rx_stb_cnt   <= 1'b1;
      end else begin
        rx_stb_int   <= 1'b0;
        rx_stb_cnt   <= rx_stb_cnt + 1;
      end
      if (tx_stb_cnt == TX_STB_RATE) begin
        tx_stb       <= 1'b1;
        tx_stb_cnt   <= 1'b1;
      end else begin
        tx_stb       <= 1'b0;
        tx_stb_cnt   <= tx_stb_cnt + 1;
      end
      tx_capture_stb <= tx_stb;
      for (int i = 0; i < NUM_CHANNELS; i++) begin
        if (tx_stb) begin
          tx_capture[i] <= tx[32*i +: 32];
        end
      end
      if (rx_stb_int) begin
        ramp_val   <= ramp_val + 2;
      end
      for (int i = 0; i < NUM_CHANNELS; i++) begin
        // Fixed value or ramp
        rx_int[32*i +: 32] <= set_rx ? set_rx_val[i] : {ramp_val[15:0],ramp_val[15:0]+1'b1};
      end
    end
  end

 /********************************************************
 ** DUT, due to non-standard I/O we cannot use `RFNOC_ADD_BLOCK()
 ** Require vita_time syncing
 ********************************************************/
//  `RFNOC_ADD_BLOCK_CUSTOM(noc_block_wavegen, 0 /* xbar port 0 */)
`include "wavegen_regs.vh"
`include "radio_core_regs.vh"

  // logic pps = 1'b0;
  // logic sync_in = 1'b0;
  // logic sync_out;
  //
  // noc_block_wavegen noc_block_wavegen(
  //   .bus_clk(bus_clk), .bus_rst(bus_rst),
  //   .ce_clk(ce_clk), .ce_rst(ce_clk),
  //   // noc_block_radio_core_* signals created by `RFNOC_BLOCK_CUSTOM() above
  //   .i_tdata(noc_block_wavegen_i_tdata), .i_tlast(noc_block_wavegen_i_tlast),
  //   .i_tvalid(noc_block_wavegen_i_tvalid), .i_tready(noc_block_wavegen_i_tready),
  //   .o_tdata(noc_block_wavegen_o_tdata), .o_tlast(noc_block_wavegen_o_tlast),
  //   .o_tvalid(noc_block_wavegen_o_tvalid), .o_tready(noc_block_wavegen_o_tready),
  //   .rx_stb(1'b1),
  //   .pps(pps), .sync_in(sync_in), .sync_out(sync_out),
  //   .debug());

  /********************************************************
  ** Useful Tasks / Functions
  ** Note: Several signals are created via
  **       `RFNOC_SIM_INIT(). See sim_rfnoc_lib.vh.
  ********************************************************/
  localparam SPP = 18;
  localparam PKT_SIZE_BYTES = SPP*4;   // In bytes
  localparam WFRM_HDR_LEN_S = 2;
  localparam WFRM_SPP = SPP-WFRM_HDR_LEN_S;

  localparam CTRL_WORD_SEL_CHIRP = 32'h00000010;
  localparam CTRL_WORD_SEL_AWG = 32'h00000310;

  task automatic send_waveform_sample_hdr;
    input [7:0] addr;
    input [63:0] wfrm_hdr;
    begin
      tb_streamer.write_reg(sid_noc_block_wavegen,addr,wfrm_hdr[63:32] /*wfrm_cmd, wfrm_id*/);
      tb_streamer.write_reg(sid_noc_block_wavegen,addr,wfrm_hdr[31:0] /*wfrm_ind, wfrm_len*/);
    end
  endtask

  /********************************************************
  ** Verification
  ********************************************************/
  initial begin : tb_main
    string s;
    logic [31:0] random_word;
    logic [63:0] readback;
    int num_samps = WFRM_SPP;
    int num_pkts = 2;
    int temp;

    logic [15:0] wfrm_cmd = 16'h5744;
    logic [15:0] wfrm_id = 'b0;
    logic [15:0] wfrm_ind = 'b0;
    logic [15:0] wfrm_len = WFRM_SPP;

    logic [63:0] start_time;


    /********************************************************
    ** Test 1 -- Reset
    ********************************************************/
    `TEST_CASE_START("Wait for Reset");
    while (bus_rst) @(posedge bus_clk);
    while (ce_rst) @(posedge ce_clk);
    `TEST_CASE_DONE(~bus_rst & ~ce_rst);

    /********************************************************
    ** Test 2 -- Check for correct NoC IDs
    ********************************************************/
    `TEST_CASE_START("Check NoC ID");
    // Read NOC IDs
    tb_streamer.read_reg(sid_noc_block_wavegen, RB_NOC_ID, readback);
    $display("Read FIR Filter NOC ID: %16x", readback);
    `ASSERT_ERROR(readback == noc_block_wavegen.NOC_ID, "Incorrect NOC ID");
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 3 -- Connect RFNoC blocks
    ********************************************************/
    `TEST_CASE_START("Connect RFNoC blocks");
    `RFNOC_CONNECT(noc_block_tb,noc_block_wavegen,SC16,SPP);
    `RFNOC_CONNECT_BLOCK_PORT(noc_block_wavegen,0,noc_block_radio_core,0,SC16,SPP);
    `RFNOC_CONNECT_BLOCK_PORT(noc_block_radio_core,0,noc_block_tb,0,SC16,SPP);

    // `RFNOC_CONNECT(noc_block_wavegen,noc_block_tb,SC16,SPP);
    //      `RFNOC_CONNECT(noc_block_tb,noc_block_fir,SC16,256);  // Connect test bench to FIR
    //      `RFNOC_CONNECT(noc_block_fir,noc_block_fft,SC16,256); // Connect FIR to FFT. Packet size 256, stream's data type SC16
    `TEST_CASE_DONE(1);

    // write radio loopbback reg
    rxtx_loopback = 1;
    tb_streamer.write_reg(sid_noc_block_radio_core,SR_LOOPBACK,32'b1,0);
    $display("Set radio loopback");
    /********************************************************
    ** Test 4 -- Send Single Packet Length Waveform immediately
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Test Sample Upload with immediate pulse and fwd rx command policy");

    /* Set Waveform samples via reload bus */
    // Read NUM_TAPS
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);

    $display("Changing policy");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd5);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd5, readback);
    `ASSERT_ERROR(readback == 32'd5, s);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_STATE, readback);
    $display("Read AWG State: %16x", readback);

    $display("Uploading Waveform %d Samples in 1 packet", wfrm_len);
    // Write a ramp to Waveform Samples
    send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});

    for (int i = 0; i < num_samps-1; i++) begin
      tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {i[15:0],i[15:0]});
    end
    temp = num_samps-1;
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {temp[15:0],temp[15:0]});

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    $display("Read Ctrl Word: %16x", readback);

    $display("Changing Ctrl Word");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_AWG_CTRL_WORD_ADDR, CTRL_WORD_SEL_AWG);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    $display("Read Ctrl Word: %16x", readback);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_STATE, readback);
    $display("Read AWG State: %16x", readback);

    $display("Now sending immediate commmand");
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
                   {1'b1 /* Start immediately */, 31'b0});
    // Have to set time lower bytes to trigger the command being stored, although time is not used.
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);

    /* Send Immediate Pulse command */
    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;

        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == i, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (i == num_samps-1) begin
            `ASSERT_ERROR(last, "Last not asserted on final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);




    /********************************************************
    ** Test 8 -- Send Delayed Pulse Command
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Send Delayed Pulse Command");

    // Write a constant to Waveform Samples
    wfrm_id = wfrm_id + 1;
    wfrm_ind = 0;
    wfrm_len = num_samps;

    $display("Uploading %d Samples in 1 packet", wfrm_len);
    send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    for (int i = 0; i < num_samps-1; i++) begin
      tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {16'hFEED,i[15:0]});
    end
    temp = num_samps-1;
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {16'hFEED,temp[15:0]});

    $display("Reading Vita Time");
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_VITA_TIME, readback);
    $display("Read Vita time: %d",readback);

    start_time = readback+64'ha00;
    $display("Sending command for pulse to start at time %d", start_time);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_COMMAND,
                   {1'b0 /* Start at time */, 31'b0});
    // Set start time
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_HI, start_time[63:32]);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_LO, start_time[31:0]);
    $display("Command Sent");
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);

    /* Send Immediate Pulse command */
    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == 16'hFEED, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (i == num_samps-1) begin
            `ASSERT_ERROR(last, "Last not asserted on final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 9 -- Send Delay Pulse at time and send command to rx
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Send Delayed Pulse Command and forward immediate rx command");

    // Write a constant to Waveform Samples
    wfrm_id = wfrm_id + 1;
    wfrm_ind = 0;
    wfrm_len = num_samps;

    $display("Uploading %d Samples in 1 packet", wfrm_len);
    send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    for (int i = 0; i < num_samps-1; i++) begin
      tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {16'hFEED,i[15:0]});
    end
    temp = num_samps-1;
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {16'hFEED,temp[15:0]});

    $display("Changing policy to Manual, Use Time, and Fwd RX Command");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd5);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd5, readback);
    `ASSERT_ERROR(readback == 32'd5, s);


    $display("Reading Vita Time");
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_VITA_TIME, readback);
    $display("Read Vita time: %d",readback);

    start_time = readback+64'ha00;
    $display("Sending command for pulse to start at time %d", start_time);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_COMMAND,
                   {1'b0 /* Start at time */, 31'b0});
    // Set start time
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_HI, start_time[63:32]);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_LO, start_time[31:0]);
    $display("Command Sent");
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);

    /* Send Immediate Pulse command */
    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == 16'hFEED, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (i == num_samps-1) begin
            `ASSERT_ERROR(last, "Last not asserted on final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);


    /********************************************************
    ** Test 10 -- Send Delay Pulse and forward time and send timed command to rx
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Send Delayed Pulse Command to forward time and forward timed rx command");

    // Write a constant to Waveform Samples
    wfrm_id = wfrm_id + 1;
    wfrm_ind = 0;
    wfrm_len = num_samps;

    $display("Uploading %d Samples in 1 packet", wfrm_len);
    send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    for (int i = 0; i < num_samps-1; i++) begin
      tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {16'hFEED,i[15:0]});
    end
    temp = num_samps-1;
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {16'hFEED,temp[15:0]});

    $display("Changing policy to Manual, Fwd Time, and Fwd RX Command");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd7);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd7, readback);
    `ASSERT_ERROR(readback == 32'd7, s);


    $display("Reading Vita Time");
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_VITA_TIME, readback);
    $display("Read Vita time: %d",readback);

    start_time = readback+64'ha00;
    $display("Sending command for pulse to start at time %d", start_time);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_COMMAND,
                   {1'b0 /* Start at time */, 31'b0});
    // Set start time
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_HI, start_time[63:32]);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_LO, start_time[31:0]);
    $display("Command Sent");
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);

    /* Send Immediate Pulse command */
    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == 16'hFEED, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (i == num_samps-1) begin
            `ASSERT_ERROR(last, "Last not asserted on final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 11 -- Send Chirp pulse with forward timestamp and send rx command
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Automatic pulse with forward time and forward timed rx command");
    // Write a constant to Waveform Samples
    wfrm_id = wfrm_id + 1;
    wfrm_ind = 0;
    wfrm_len = num_samps;

    $display("Uploading %d Samples in 1 packet", wfrm_len);
    send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    for (int i = 0; i < num_samps-1; i++) begin
      tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {16'hFEED,i[15:0]});
    end
    temp = num_samps-1;
    tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {16'hFEED,temp[15:0]});

    $display("Changing policy to Manual, Fwd Time, and Fwd RX Command");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd7);
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd7, readback);
    `ASSERT_ERROR(readback == 32'd7, s);

    // $display("Changing Ctrl Word to Chirp");
    // // Change CTRL Policy to dependent mode
    // tb_streamer.write_reg(sid_noc_block_wavegen, SR_AWG_CTRL_WORD_ADDR, CTRL_WORD_SEL_CHIRP);
    // tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    // $display("Read Ctrl Word: %16x", readback);
    // $sformat(s, "Incorrect Ctrl Word Read! Expected: %0d, Received: %0d", CTRL_WORD_SEL_CHIRP, readback);
    // `ASSERT_ERROR(readback == CTRL_WORD_SEL_CHIRP, s);
    //
    // $display("Changing Chirp Length");
    // // Change CTRL Policy to dependent mode
    // tb_streamer.write_reg(sid_noc_block_wavegen, SR_CH_COUNTER_ADDR, 32'd3);

    $display("Changing PRF Count");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_PRF_INT_ADDR, 32'b0);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_PRF_FRAC_ADDR, 32'h9ff);
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_PRF, readback);
    $display("Read PRF Word: %16x", readback);
    $sformat(s, "Incorrect PRF Read! Expected: %0d, Received: %0d", 64'h9ff, readback);
    `ASSERT_ERROR(readback == 64'h9ff, s);

    $display("Changing policy to Auto, Fwd Time, and Fwd RX Command");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd6);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd6, readback);
    `ASSERT_ERROR(readback == 32'd6, s);

    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == 16'hFEED, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (i == num_samps-1) begin
            `ASSERT_ERROR(last, "Last not asserted on final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 12 -- Change SPP
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Changing SPP");

    $display("Changing SPP to 6");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_MAXLEN, 32'd6);

    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < num_samps; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check I / Q values, should be a ramp
          $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
          `ASSERT_ERROR(i_samp == 16'hFEED, s);
          $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
          `ASSERT_ERROR(q_samp == i, s);
          // Check tlast
          if (((i+1)%6 == 0)|(i==num_samps-1)) begin
            `ASSERT_ERROR(last, "Last not asserted on 6th or final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);


    /********************************************************
    ** Test 13 -- Change Mode to Chirp Pulse
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Changing to Chirp Source");


    wfrm_len = 10;

    $display("Changing Chirp Counter Length to %16x (max count = %16x)",wfrm_len,wfrm_len-1);
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_CH_COUNTER_ADDR, {16'd0,wfrm_len-1});

    $display("Changing Ctrl Word to Chirp: %16x", CTRL_WORD_SEL_CHIRP);
    // Change CTRL word to CTRL_WORD_SEL_CHIRP mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_AWG_CTRL_WORD_ADDR, CTRL_WORD_SEL_CHIRP);
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    $display("Read Ctrl Word: %16x", readback);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_LEN, readback);
    $display("AWG Length Word: %16x", readback);
    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output");
        for (int i = 0; i < wfrm_len; i++) begin
          tb_streamer.pull_word({i_samp, q_samp}, last);
          // Check tlast
          if (((i+1)%6 == 0)|(i == wfrm_len-1)) begin
            `ASSERT_ERROR(last, "Last not asserted on 6th or final word!");
          end else begin
            `ASSERT_ERROR(~last, "Last asserted early!");
          end
        end
      end
    join
    `TEST_CASE_DONE(1);


    `TEST_BENCH_DONE;

  end
endmodule
