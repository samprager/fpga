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
  localparam NUM_CE         = 1;  // Number of Computation Engines / User RFNoC blocks to simulate
  localparam NUM_STREAMS    = 1;  // Number of test bench streams
  `RFNOC_SIM_INIT(NUM_CE, NUM_STREAMS, BUS_CLK_PERIOD, CE_CLK_PERIOD);
  //`RFNOC_ADD_BLOCK(noc_block_wavegen, 0);

  `RFNOC_ADD_BLOCK_CUSTOM(noc_block_wavegen, 0 /* xbar port 0 */);
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
    logic [27:0] numpulses;


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
    `RFNOC_CONNECT(noc_block_wavegen,noc_block_tb,SC16,SPP);
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 4 -- Send Single Packet Length Waveform immediately
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Test Sample Upload with immediate pulse and no rx command policy");

    /* Set Waveform samples via reload bus */
    // Read NUM_TAPS
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);

    $display("Changing policy");
    // Change CTRL Policy to dependent mode
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd1);

    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    $display("Read Policy: %16x", readback);
    $sformat(s, "Incorrect Policy Read! Expected: %0d, Received: %0d", 32'd1, readback);
    `ASSERT_ERROR(readback == 32'd1, s);

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
    ** Test 5 -- Send Multi Packet Length Waveform
    ********************************************************/
    // // Sending an impulse will readback the FIR filter coefficients
    // `TEST_CASE_START("Test Multi Packet Sample Upload");
    //
    // /* Set Waveform samples via reload bus */
    // // Read NUM_TAPS
    // tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    // $display("Read Policy: %16x", readback);
    //
    // $display("Changing policy");
    // // Change CTRL Policy to dependent mode
    // tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_POLICY, 32'd1);
    //
    // tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_POLICY, readback);
    // $display("Read Policy: %16x", readback);
    //
    // // Write a ramp to Waveform Samples
    // wfrm_id = wfrm_id + 1;
    // wfrm_len = WFRM_SPP*num_pkts;
    // $display("Uploading Waveform %d Samples in %d packets", wfrm_len, num_pkts);
    // for (int j = 0; j< num_pkts; j++) begin
    //     wfrm_ind = j;
    //     send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    //     for (int i = 0; i < num_samps-1; i++) begin
    //       tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {i[15:0],i[15:0]});
    //     end
    //     temp = num_samps-1;
    //     tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {temp[15:0],temp[15:0]});
    // end
    //
    // tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    // $display("Read Ctrl Word: %16x", readback);
    //
    // $display("Changing Ctrl Word");
    // // Change CTRL Policy to dependent mode
    // tb_streamer.write_reg(sid_noc_block_wavegen, SR_AWG_CTRL_WORD_ADDR, CTRL_WORD_SEL_AWG);
    //
    // tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_AWG_CTRL, readback);
    // $display("Read Ctrl Word: %16x", readback);
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);
    //
    // /* Send Immediate Pulse command */
    // /* Send and check impulse */
    // fork
    //   begin
    //     logic [31:0] recv_val;
    //     logic last;
    //     logic [15:0] i_samp, q_samp;
    //
    //     $display("Receive Wavegen output");
    //     for (int j = 0; j< num_pkts; j++) begin
    //         for (int i = 0; i < num_samps; i++) begin
    //           tb_streamer.pull_word({i_samp, q_samp}, last);
    //           // Check I / Q values, should be a ramp
    //           $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
    //           `ASSERT_ERROR(i_samp == i, s);
    //           $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
    //           `ASSERT_ERROR(q_samp == i, s);
    //           // Check tlast
    //           if ((i == num_samps-1) & (j==num_pkts-1)) begin
    //             `ASSERT_ERROR(last, "Last not asserted on final word!");
    //           end else begin
    //             `ASSERT_ERROR(~last, "Last asserted early!");
    //           end
    //         end
    //     end
    //   end
    // join
    // `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 6 -- Send Multi Packet Length Waveform Repeat ID - should fail
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    // `TEST_CASE_START("Test Repeat ID sample Upload");
    //
    // // Write a constant to Waveform Samples
    //
    // $display("Repeating Wfrm ID and Uploading %d Samples in %d packets", wfrm_len, num_pkts);
    // for (int j = 0; j< num_pkts; j++) begin
    //     wfrm_ind = j;
    //     send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    //     for (int i = 0; i < num_samps-1; i++) begin
    //       tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {28'hbadc0de,i[3:0]});
    //     end
    //     temp = num_samps-1;
    //     tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {28'hbadc0de,temp[3:0]});
    // end
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);
    //
    // /* Send Immediate Pulse command */
    // /* Send and check impulse */
    // fork
    //   begin
    //     logic [31:0] recv_val;
    //     logic last;
    //     logic [15:0] i_samp, q_samp;
    //
    //     $display("Receive Wavegen output - Should still be ramp");
    //     for (int j = 0; j< num_pkts; j++) begin
    //         for (int i = 0; i < num_samps; i++) begin
    //           tb_streamer.pull_word({i_samp, q_samp}, last);
    //           // Check I / Q values, should be a ramp
    //           $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
    //           `ASSERT_ERROR(i_samp == i, s);
    //           $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
    //           `ASSERT_ERROR(q_samp == i, s);
    //           // Check tlast
    //           if ((i == num_samps-1) & (j==num_pkts-1)) begin
    //             `ASSERT_ERROR(last, "Last not asserted on final word!");
    //           end else begin
    //             `ASSERT_ERROR(~last, "Last asserted early!");
    //           end
    //         end
    //     end
    //   end
    // join
    // `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 7 -- Send Multi Packet Length Waveform No Index Increment - should fail
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    // `TEST_CASE_START("Test Incorrect Index sample Upload");
    //
    // // Write a constant to Waveform Samples
    // wfrm_id = wfrm_id + 1;
    //
    // $display("Repeating Adding incorrect Ind and Uploading %d Samples in %d packets", wfrm_len, num_pkts);
    // for (int j = 0; j< num_pkts; j++) begin
    //     wfrm_ind = j;
    //     send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    //     for (int i = 0; i < num_samps-1; i++) begin
    //       tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {i[15:0],i[15:0]});
    //     end
    //     temp = num_samps-1;
    //     tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {temp[15:0],temp[15:0]});
    //
    //     send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    //     for (int i = 0; i < num_samps-1; i++) begin
    //       tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {28'hbadc0de,i[3:0]});
    //     end
    //     temp = num_samps-1;
    //     tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {28'hbadc0de,temp[3:0]});
    //
    //     wfrm_ind = j+2;
    //     send_waveform_sample_hdr(noc_block_wavegen.SR_AWG_RELOAD,{wfrm_cmd,wfrm_id,wfrm_ind,wfrm_len});
    //     for (int i = 0; i < num_samps-1; i++) begin
    //       tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD, {28'hbadc0de,i[3:0]});
    //     end
    //     temp = num_samps-1;
    //     tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_AWG_RELOAD_LAST, {28'hbadc0de,temp[3:0]});
    // end
    // $display("Now sending immediate commmand");
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_COMMAND,
    //                {1'b1 /* Start immediately */, 31'b0});
    // // Have to set time lower bytes to trigger the command being stored, although time is not used.
    // tb_streamer.write_reg(sid_noc_block_wavegen, noc_block_wavegen.SR_RADAR_CTRL_TIME_LO, 32'd0);
    //
    // /* Send Immediate Pulse command */
    // /* Send and check impulse */
    // fork
    //   begin
    //     logic [31:0] recv_val;
    //     logic last;
    //     logic [15:0] i_samp, q_samp;
    //
    //     $display("Receive Wavegen output - Should still be ramp");
    //     for (int j = 0; j< num_pkts; j++) begin
    //         for (int i = 0; i < num_samps; i++) begin
    //           tb_streamer.pull_word({i_samp, q_samp}, last);
    //           // Check I / Q values, should be a ramp
    //           $sformat(s, "Incorrect I value received! Expected: %0d, Received: %0d", i, i_samp);
    //           `ASSERT_ERROR(i_samp == i, s);
    //           $sformat(s, "Incorrect Q value received! Expected: %0d, Received: %0d", i, q_samp);
    //           `ASSERT_ERROR(q_samp == i, s);
    //           // Check tlast
    //           if ((i == num_samps-1) & (j==num_pkts-1)) begin
    //             `ASSERT_ERROR(last, "Last not asserted on final word!");
    //           end else begin
    //             `ASSERT_ERROR(~last, "Last asserted early!");
    //           end
    //         end
    //     end
    //   end
    // join
    // `TEST_CASE_DONE(1);

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
    ** Test 13 -- Send Chirp pulse with forward timestamp and chain command, to transmit 10 pulses and stop (manual mode). Also send command to rx
    ********************************************************/
    // Sending an impulse will readback the FIR filter coefficients
    `TEST_CASE_START("Chain multiple Manual pulses with forward time and forward timed rx command");
    // Write a constant to Waveform Samples
    wfrm_id = wfrm_id + 1;
    wfrm_ind = 0;
    wfrm_len = num_samps;
    numpulses = 4;

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

    $display("Reading Vita Time");
    tb_streamer.read_user_reg(sid_noc_block_wavegen, RB_VITA_TIME, readback);
    $display("Read Vita time: %d",readback);

    start_time = readback+64'ha00;
    $display("Sending command for %d pulse to start at time %d", numpulses,start_time);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_COMMAND,
                   {1'b0 /* Start at time */,1'b1 /*chain*/,1'b0 /* dont reload*/,1'b0 /*dont stop*/, numpulses /*28 bit numlines*/});
    // Set start time
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_HI, start_time[63:32]);
    tb_streamer.write_reg(sid_noc_block_wavegen, SR_RADAR_CTRL_TIME_LO, start_time[31:0]);
    $display("Command Sent");

    

    /* Send and check impulse */
    fork
      begin
        logic [31:0] recv_val;
        logic last;
        logic [15:0] i_samp, q_samp;
        /* Send Immediate Pulse command */
        /* Send and check impulse */
        $display("Receive Wavegen output.");
        for (int j = 0; j < numpulses; j++) begin
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
	        $display("Receive pulse: %d/%d",j+1,numpulses);
	    end
      end
    join
    `TEST_CASE_DONE(1);


    /********************************************************
    ** Test 14 -- Change Mode to Chirp Pulse
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
