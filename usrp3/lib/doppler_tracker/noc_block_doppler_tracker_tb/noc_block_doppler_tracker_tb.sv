`timescale 1ns/1ps
`define SIM_TIMEOUT_US 20000
`define NS_PER_TICK 1
`define NUM_TEST_CASES 13


`include "sim_exec_report.vh"
`include "sim_clks_rsts.vh"
`include "sim_rfnoc_lib.svh"

typedef logic pn_seq_t[$];
typedef logic[31:0] sample_t[$];


module noc_block_doppler_tracker_tb();
//import dpi task      C Name = SV function name
import "DPI-C" pure function real cos (input real rTheta);
import "DPI-C" pure function real sin (input real rTheta);

function sample_t get_random_samples(int num_samples);
  sample_t sample;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
      sample[i] = $random;
    end
  end
  return sample;
endfunction;

function sample_t get_repeatramp_samples(int num_samples, int num_ramp);
  sample_t sample;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
      sample[i] = (i % num_ramp);
    end
  end
  return sample;
endfunction;

function sample_t get_repeatrampIQ_samples(int num_samples, int num_ramp);
  sample_t sample;
  shortint sI, sQ;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
      sI = (i % num_ramp)-num_ramp/2;
      sQ = num_ramp/2 - (i % num_ramp);
      sample[i] = {sI,sQ};
    end
  end
  return sample;
endfunction;

function sample_t get_sin_samples(int num_samples, int fc, int fs, int ampl);
  sample_t sample;
  const real pi = 3.1416;
  real       fc_r = $itor(fc);
  real       fs_r = $itor(fs);
  real       ampl_r = $itor(ampl);
  real       offset = 0;
  real x;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
        x = 2.0*pi*$itor(i)*(fc_r/fs_r);
      sample[i] = $rtoi(offset + (ampl_r * (x - (x**3)/6 + (x**5)/120 - (x**7)/5040)));
    end
  end
  return sample;
endfunction;

function sample_t get_cos_samples(int num_samples, int fc, int fs, int ampl);
  sample_t sample;
  const real pi = 3.1416;
  real       fc_r = $itor(fc);
  real       fs_r = $itor(fs);
  real       ampl_r = $itor(ampl);
  real       offset = 0;
  real x;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
      x = 2.0*pi*$itor(i)*(fc_r/fs_r);
      sample[i] = $rtoi(offset + (ampl_r * (1 - (x**2)/2 + (x**4)/24 - (x**6)/720)));
    end
  end
  return sample;
endfunction;

function sample_t get_sincos_samples(int num_samples, int fc, int fs, int ampl);
  sample_t sample;
  const real pi = 3.1416;
  real       fc_r = $itor(fc);
  real       fs_r = $itor(fs);
  real       ampl_r = $itor(ampl);
  real       offset = 0;
  real x;
  int mval = $rtoi(fs_r/fc_r);
  shortint sI, sQ;
  begin
    for(int i = 0; i<num_samples; i++)
    begin
      x = 2.0*pi*$itor((i%mval))*(fc_r/fs_r);
//      sI = $rtoi(offset + (ampl_r * (x - (x**3)/6 + (x**5)/120 - (x**7)/5040)));
//      sQ = $rtoi(offset + (ampl_r * (1 - (x**2)/2 + (x**4)/24 - (x**6)/720)));
      sQ = $rtoi(offset + (ampl_r * (x - (x**3)/6 + (x**5)/120 - (x**7)/5040 + (x**9)/362880 - (x**11)/39916800 + ((x**13)/39916800)/(13*12) - ((x**15)/39916800)/(15*14*13*12) + ((x**17)/39916800)/(17*16*15*14*13*12))));
      sI = $rtoi(offset + (ampl_r * (1 - (x**2)/2 + (x**4)/24 - (x**6)/720 + (x**8)/40320 - (x**10)/3628800 + (x**12)/479001600 - ((x**14)/479001600)/(14*13) + ((x**16)/479001600)/(16*15*14*13))));
      sample[i] = {sI,sQ};
    end
  end
  return sample;
endfunction;

function cvita_payload_t get_payload(sample_t sample, int num_samples);
  cvita_payload_t payload;
  begin
    for(int i = 0; i<num_samples/2; i++)
    begin
      payload[i] = {sample[2*i], sample[2*i + 1]};
      if((2*i + 1) == num_samples-2) // when num_samples is odd
      begin
        payload[i+1] = {sample[2*i + 2],32'd0};
      end
    end
  end
  return payload;
endfunction


  `TEST_BENCH_INIT("noc_block_doppler_tracker",`NUM_TEST_CASES,`NS_PER_TICK);
  localparam BUS_CLK_PERIOD = $ceil(1e9/166.67e6);
  localparam CE_CLK_PERIOD  = $ceil(1e9/200e6);
  localparam NUM_CE         = 1;  // Number of Computation Engines / User RFNoC blocks to simulate
  localparam NUM_STREAMS    = 1;  // Number of test bench streams
  `RFNOC_SIM_INIT(NUM_CE, NUM_STREAMS, BUS_CLK_PERIOD, CE_CLK_PERIOD);
  //`RFNOC_ADD_BLOCK(noc_block_doppler_tracker, 0);

  `RFNOC_ADD_BLOCK_CUSTOM(noc_block_doppler_tracker, 0 /* xbar port 0 */)
  
  reg pps;
  reg [7:0] pps_counter;
  
noc_block_doppler_tracker noc_block_doppler_tracker(
  .bus_clk(bus_clk),
  .bus_rst(bus_rst),
  .ce_clk(ce_clk),
  .ce_rst(ce_rst),
  .i_tdata(noc_block_doppler_tracker_i_tdata),
  .i_tlast(noc_block_doppler_tracker_i_tlast),
  .i_tvalid(noc_block_doppler_tracker_i_tvalid),
  .i_tready(noc_block_doppler_tracker_i_tready),
  .o_tdata(noc_block_doppler_tracker_o_tdata),
  .o_tlast(noc_block_doppler_tracker_o_tlast),
  .o_tvalid(noc_block_doppler_tracker_o_tvalid),
  .o_tready(noc_block_doppler_tracker_o_tready),
  .pps(pps),
  .debug());



  localparam SPP = 32;
  localparam MAX_SUM_LENGTH = SPP/2;

  localparam num_samples = 128;
  localparam freq_wfrm = 10e6;
  localparam freq_clk = 200e6;
  localparam ampl_wfrm = 1024;
  
always @(posedge ce_clk) begin
    if (ce_rst) begin
        pps <= 0;
        pps_counter = 0;
    end else begin
        pps_counter <= pps_counter + 1;
        if (pps_counter>=8'd192)
            pps <= 1;
        else
            pps <= 0;
    end
 end

  /********************************************************
  ** Verification
  ********************************************************/
  initial begin : tb_main
    string s;
    shortint i_send[$], i_recv[$];
    shortint q_send[$], q_recv[$];
    shortint moving_avg_recv_i, moving_avg_recv_q;
    shortint moving_sum_i, moving_avg_i, moving_sum_q, moving_avg_q;
    logic [63:0] readback, recv_value;

    pn_seq_t seq;
    sample_t sample;

    cvita_payload_t send_payload, recv_payload;
    cvita_metadata_t tx_md, rx_md;

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
    tb_streamer.read_reg(sid_noc_block_doppler_tracker, RB_NOC_ID, readback);
    $display("Read Moving Average NOC ID: %16x", readback);
    `ASSERT_ERROR(readback == noc_block_doppler_tracker.NOC_ID, "Incorrect NOC ID");
    `TEST_CASE_DONE(1);

    /********************************************************
    ** Test 3 -- Connect RFNoC blocks
    ********************************************************/
    `TEST_CASE_START("Connect RFNoC blocks");
    `RFNOC_CONNECT(noc_block_tb,noc_block_doppler_tracker,SC16,SPP);
    `RFNOC_CONNECT(noc_block_doppler_tracker,noc_block_tb,SC16,SPP);
    `TEST_CASE_DONE(1);

    // /********************************************************
    // ** Test 4 -- Test moving averages of various lengths
    // ********************************************************/
    // `TEST_CASE_START("Moving Averages");
    // for (int n = 1; n <= MAX_SUM_LENGTH; n++) begin
    //   i_send.delete();
    //   q_send.delete();
    //   i_recv.delete();
    //   q_recv.delete();
    //   moving_sum_i = 0;
    //   moving_sum_q = 0;
    //   $display("Test moving average length %0d", n);
    //   tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_SUM_LEN, n);
    //   tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_DIVISOR, n);
    //   for (shortint k = 0; k < SPP; k++) begin
    //     i_send.push_back(k);
    //     q_send.push_back(-k);
    //   end
    //   send_payload.delete();
    //   for (int k = 0; k < SPP/2; k++) begin
    //     send_payload.push_back({i_send[2*k],q_send[2*k],i_send[2*k+1],q_send[2*k+1]});
    //   end
    //   tx_md.eob = 1;
    //   tb_streamer.send(send_payload,tx_md);
    //   tb_streamer.recv(recv_payload,rx_md);
    //   `ASSERT_ERROR(rx_md.eob == 1'b1, "EOB bit not set!");
    //   for (int k = 0; k < SPP/2; k++) begin
    //     recv_value = recv_payload[k];
    //     i_recv.push_back(recv_value[63:48]);
    //     i_recv.push_back(recv_value[31:16]);
    //     q_recv.push_back(recv_value[47:32]);
    //     q_recv.push_back(recv_value[15:0]);
    //   end
    //   for (int k = 0; k < SPP; k++) begin
    //     if (k < n) begin
    //       moving_sum_i = moving_sum_i + i_send[k];
    //       moving_sum_q = moving_sum_q + q_send[k];
    //     end else begin
    //       moving_sum_i = moving_sum_i + i_send[k] - i_send[k-n];
    //       moving_sum_q = moving_sum_q + q_send[k] - q_send[k-n];
    //     end
    //     // Same as round to nearest in axi_round
    //     moving_avg_i = shortint'($floor(real'(moving_sum_i)/n + 0.5));
    //     moving_avg_q = shortint'($floor(real'(moving_sum_q)/n + 0.5));
    //     moving_avg_recv_i = i_recv[k];
    //     moving_avg_recv_q = q_recv[k];
    //     $sformat(s, "Incorrect moving average on I! N: %0d, Expected %0d, Received: %0d", n, moving_avg_i, moving_avg_recv_i);
    //     `ASSERT_ERROR(moving_avg_i == moving_avg_recv_i, s);
    //     $sformat(s, "Incorrect moving average on Q! N: %0d, Expected %0d, Received: %0d", n, moving_avg_q, moving_avg_recv_q);
    //     `ASSERT_ERROR(moving_avg_q == moving_avg_recv_q, s);
    //   end
    // end
    /********************************************************
    ** Test 4 -- Test moving averages of various lengths
    ********************************************************/
    `TEST_CASE_START("Setting Moving Average Length to 1");
    tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_SUM_LEN, 1);
    tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_DIVISOR, 1);
    tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_ZC_SUM_LEN, 2);

    `TEST_CASE_START("Writing threshold and offset regs");
    tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_THRESHOLD, 1);
    tb_streamer.write_user_reg(sid_noc_block_doppler_tracker, noc_block_doppler_tracker.SR_OFFSET, 5);


    /********************************************************
    ** Test 5 -- Send Samples
    ********************************************************/
    `TEST_CASE_START("Send samples");
    fork
    begin
      sample = get_sincos_samples(num_samples, freq_wfrm, freq_clk, ampl_wfrm );
      send_payload = get_payload(sample, num_samples); // 64 bit word i.e., one payload word = 2 samples
      tb_streamer.send(send_payload);
    end
//    begin
//      tb_streamer.recv(recv_payload,rx_md);
//    end
    join
    `TEST_CASE_DONE(1);
    
        /********************************************************
    ** Test 2 -- Check for correct NoC IDs
    ********************************************************/
    `TEST_CASE_START("Sin/Cos Waveform: Readback ZC registers");
    // Read NOC IDs
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 2, readback);
    $display("Read Cycles per Sec: %16x", readback);
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 3, readback);
    $display("Read ZC Count: %16x", readback);
        
        /********************************************************
    ** Test 5 -- Send Samples
    ********************************************************/
    `TEST_CASE_START("Send samples");
    fork
    begin
      sample = get_repeatrampIQ_samples(num_samples,16);
      send_payload = get_payload(sample, num_samples); // 64 bit word i.e., one payload word = 2 samples
      tb_streamer.send(send_payload);
    end
//    begin
//      tb_streamer.recv(recv_payload,rx_md);
//    end
    join
    `TEST_CASE_DONE(1);
    
        /********************************************************
    ** Test 2 -- Check for correct NoC IDs
    ********************************************************/
    `TEST_CASE_START("Ramp 16 Waveform: Readback ZC registers");
    // Read NOC IDs
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 2, readback);
    $display("Read Cycles per Sec: %16x", readback);
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 3, readback);
    $display("Read ZC Count: %16x", readback);
        
        /********************************************************
    ** Test 5 -- Send Samples
    ********************************************************/
    `TEST_CASE_START("Send samples");
    fork
    begin
      sample = get_repeatrampIQ_samples(num_samples,8);
      send_payload = get_payload(sample, num_samples); // 64 bit word i.e., one payload word = 2 samples
      tb_streamer.send(send_payload);
    end
//    begin
//      tb_streamer.recv(recv_payload,rx_md);
//    end
    join
    `TEST_CASE_DONE(1);
    
        /********************************************************
    ** Test 2 -- Check for correct NoC IDs
    ********************************************************/
    `TEST_CASE_START("Ramp8 Waveform: Readback ZC registers");
    // Read NOC IDs
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 2, readback);
    $display("Read Cycles per Sec: %16x", readback);
    tb_streamer.read_user_reg(sid_noc_block_doppler_tracker, 3, readback);
    $display("Read ZC Count: %16x", readback);
    
    `TEST_BENCH_DONE;
  end

endmodule
