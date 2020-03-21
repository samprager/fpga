module axi_moving_avg #(
  parameter MAX_LEN = 255,
  parameter COMPLEX_IQ = 0
  )(
  input clk, input reset,
  input [$clog2(MAX_LEN+1)-1:0] len, input [31:0] divisor, input clear,
  input  [31:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [31:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready);

   generate
   if (COMPLEX_IQ==1) begin
   // I part
    wire [15:0] ipart_tdata;
    wire ipart_tlast, ipart_tvalid, ipart_tready;

    // Q part
    wire [15:0] qpart_tdata;
    wire qpart_tlast, qpart_tvalid, qpart_tready;

    // I sum
    wire [23:0] isum_tdata;
    wire isum_tlast, isum_tvalid, isum_tready;

    // Q sum
    wire [23:0] qsum_tdata;
    wire qsum_tlast, qsum_tvalid, qsum_tready;

    // I average
    wire [47:0] iavg_uncorrected_tdata;
    wire signed [46:0] iavg_tdata;
    wire iavg_tlast, iavg_tvalid, iavg_tready;
    wire [15:0] iavg_rnd_tdata;
    wire iavg_rnd_tlast, iavg_rnd_tvalid, iavg_rnd_tready;
    wire idivisor_tready, idividend_tready;

    // Q average
    wire [47:0] qavg_uncorrected_tdata;
    wire signed [46:0] qavg_tdata;
    wire qavg_tlast, qavg_tvalid, qavg_tready;
    wire [15:0] qavg_rnd_tdata;
    wire qavg_rnd_tlast, qavg_rnd_tvalid, qavg_rnd_tready;
    wire qdivisor_tready, qdividend_tready;

    wire [23:0] divisor24 = divisor[23:0];

  // Split incoming data into I and Q parts
   split_complex #(
     .WIDTH(16))
   split_complex_inst (
     .i_tdata(i_tdata),
     .i_tlast(i_tlast),
     .i_tvalid(i_tvalid),
     .i_tready(i_tready),
     .oi_tdata(ipart_tdata),
     .oi_tlast(ipart_tlast),
     .oi_tvalid(ipart_tvalid),
     .oi_tready(ipart_tready),
     .oq_tdata(qpart_tdata),
     .oq_tlast(qpart_tlast),
     .oq_tvalid(qpart_tvalid),
     .oq_tready(qpart_tready),
     .error());

   // Accumulate I values
   moving_sum #(
     .MAX_LEN(MAX_LEN),
     .WIDTH(16))
   moving_isum_inst (
     .clk(clk),
     .reset(reset),
     .clear(clear),
     .len(len),
     .i_tdata(ipart_tdata),
     .i_tlast(ipart_tlast),
     .i_tvalid(ipart_tvalid),
     .i_tready(ipart_tready),
     .o_tdata(isum_tdata),
     .o_tlast(isum_tlast),
     .o_tvalid(isum_tvalid),
     .o_tready(isum_tready));

   // Accumulate Q values
   moving_sum #(
     .MAX_LEN(MAX_LEN),
     .WIDTH(16))
   moving_qsum_inst (
     .clk(clk),
     .reset(reset),
     .clear(clear),
     .len(len),
     .i_tdata(qpart_tdata),
     .i_tlast(qpart_tlast),
     .i_tvalid(qpart_tvalid),
     .i_tready(qpart_tready),
     .o_tdata(qsum_tdata),
     .o_tlast(qsum_tlast),
     .o_tvalid(qsum_tvalid),
     .o_tready(qsum_tready));

   // Divide I part by divisor from settings register
   divide_int24 divide_i_inst (
     .aclk(clk),
     .aresetn(~reset),
     .s_axis_divisor_tvalid(isum_tvalid),
     .s_axis_divisor_tready(idivisor_tready),
     .s_axis_divisor_tlast(isum_tlast),
     .s_axis_divisor_tdata(divisor24),
     .s_axis_dividend_tvalid(isum_tvalid),
     .s_axis_dividend_tready(idividend_tready),
     .s_axis_dividend_tlast(isum_tlast),
     .s_axis_dividend_tdata(isum_tdata),
     .m_axis_dout_tvalid(iavg_tvalid),
     .m_axis_dout_tready(iavg_tready),
     .m_axis_dout_tuser(),
     .m_axis_dout_tlast(iavg_tlast),
     .m_axis_dout_tdata(iavg_uncorrected_tdata));
   // Xilinx divider separates integer and fraction parts. Combine into fixed point value Q23.23.
   assign iavg_tdata = $signed({iavg_uncorrected_tdata[47:24],23'd0}) + $signed(iavg_uncorrected_tdata[23:0]);

   // Divide Q part by divisor from settings register
   divide_int24 divide_q_inst (
     .aclk(clk),
     .aresetn(~reset),
     .s_axis_divisor_tvalid(qsum_tvalid),
     .s_axis_divisor_tready(qdivisor_tready),
     .s_axis_divisor_tlast(qsum_tlast),
     .s_axis_divisor_tdata(divisor24),
     .s_axis_dividend_tvalid(qsum_tvalid),
     .s_axis_dividend_tready(qdividend_tready),
     .s_axis_dividend_tlast(qsum_tlast),
     .s_axis_dividend_tdata(qsum_tdata),
     .m_axis_dout_tvalid(qavg_tvalid),
     .m_axis_dout_tready(qavg_tready),
     .m_axis_dout_tuser(),
     .m_axis_dout_tlast(qavg_tlast),
     .m_axis_dout_tdata(qavg_uncorrected_tdata));
   assign qavg_tdata = $signed({qavg_uncorrected_tdata[47:24],23'd0}) + $signed(qavg_uncorrected_tdata[23:0]);

   axi_round_and_clip #(
     .WIDTH_IN(47),
     .WIDTH_OUT(16),
     .CLIP_BITS(8))
   axi_round_and_clip_i (
     .clk(clk), .reset(reset),
     .i_tdata(iavg_tdata), .i_tlast(iavg_tlast), .i_tvalid(iavg_tvalid), .i_tready(iavg_tready),
     .o_tdata(iavg_rnd_tdata), .o_tlast(iavg_rnd_tlast), .o_tvalid(iavg_rnd_tvalid), .o_tready(iavg_rnd_tready));

   axi_round_and_clip #(
     .WIDTH_IN(47),
     .WIDTH_OUT(16),
     .CLIP_BITS(8))
   axi_round_and_clip_q (
     .clk(clk), .reset(reset),
     .i_tdata(qavg_tdata), .i_tlast(qavg_tlast), .i_tvalid(qavg_tvalid), .i_tready(qavg_tready),
     .o_tdata(qavg_rnd_tdata), .o_tlast(qavg_rnd_tlast), .o_tvalid(qavg_rnd_tvalid), .o_tready(qavg_rnd_tready));

   // Concatenate I and Q part again
   join_complex #(
     .WIDTH(16))
   join_complex_inst (
     .ii_tdata(iavg_rnd_tdata),
     .ii_tlast(iavg_rnd_tlast),
     .ii_tvalid(iavg_rnd_tvalid),
     .ii_tready(iavg_rnd_tready),
     .iq_tdata(qavg_rnd_tdata),
     .iq_tlast(qavg_rnd_tlast),
     .iq_tvalid(qavg_rnd_tvalid),
     .iq_tready(qavg_rnd_tready),
     .o_tdata(o_tdata),
     .o_tlast(o_tlast),
     .o_tvalid(o_tvalid),
     .o_tready(o_tready),
     .error());

   //----------------------------------------------------------------------------
   // Combinational Logic
   //----------------------------------------------------------------------------

   // Make sure dividers are ready
   assign isum_tready = idivisor_tready & idividend_tready;
   assign qsum_tready = qdivisor_tready & qdividend_tready;

   end else begin


   // I sum
   wire [39:0] sum_tdata;
   wire isum_tlast, isum_tvalid, isum_tready;

   wire [47:0] avg_uncorrected_tdata;
   wire signed [46:0] avg_tdata;
   wire avg_tlast, avg_tvalid, avg_tready;
   wire divisor_tready, dividend_tready;
   wire [39:0] divisor40 = {8'b0,divisor};

   moving_sum #(
     .MAX_LEN(MAX_LEN),
     .WIDTH(32))
   moving_isum_inst (
     .clk(clk),
     .reset(reset),
     .clear(clear),
     .len(len),
     .i_tdata(i_tdata),
     .i_tlast(i_tlast),
     .i_tvalid(i_tvalid),
     .i_tready(i_tready),
     .o_tdata(sum_tdata),
     .o_tlast(sum_tlast),
     .o_tvalid(sum_tvalid),
     .o_tready(sum_tready));

     // Divide part by divisor from settings register
   divide_int40 divide_inst (
     .aclk(clk),
     .aresetn(~reset),
     .s_axis_divisor_tvalid(sum_tvalid),
     .s_axis_divisor_tready(divisor_tready),
     .s_axis_divisor_tlast(sum_tlast),
     .s_axis_divisor_tdata(divisor40),
     .s_axis_dividend_tvalid(sum_tvalid),
     .s_axis_dividend_tready(dividend_tready),
     .s_axis_dividend_tlast(sum_tlast),
     .s_axis_dividend_tdata(sum_tdata),
     .m_axis_dout_tvalid(avg_tvalid),
     .m_axis_dout_tready(avg_tready),
     .m_axis_dout_tuser(),
     .m_axis_dout_tlast(avg_tlast),
     .m_axis_dout_tdata(avg_uncorrected_tdata));
     // Xilinx divider separates integer and fraction parts. Combine into fixed point value Q23.23.
     assign avg_tdata = $signed({avg_uncorrected_tdata[47:8],7'd0}) + $signed(avg_uncorrected_tdata[7:0]);

     axi_round_and_clip #(
       .WIDTH_IN(47),
       .WIDTH_OUT(32),
       .CLIP_BITS(8))
     axi_round_and_clip (
       .clk(clk), .reset(reset),
       .i_tdata(avg_tdata), .i_tlast(avg_tlast), .i_tvalid(avg_tvalid), .i_tready(avg_tready),
       .o_tdata(o_tdata), .o_tlast(o_tlast), .o_tvalid(o_tvalid), .o_tready(o_tready));

      assign sum_tready = divisor_tready & dividend_tready;
   end
   endgenerate
endmodule
