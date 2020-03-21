module axi_sign_moving_avg #(
  parameter MAX_LEN = 255,
  )(
  input clk, input reset,
  input [$clog2(MAX_LEN+1)-1:0] len, input [31:0] divisor, input clear,
  input  [1:0] i_tdata, input  i_tlast, input  i_tvalid, output i_tready,
  output [1:0] o_tdata, output o_tlast, output o_tvalid, input  o_tready);

   // I sum
   wire [39:0] sum_tdata;
   wire isum_tlast, isum_tvalid, isum_tready;

   wire [47:0] avg_uncorrected_tdata;
   wire signed [46:0] avg_tdata;
   wire avg_tlast, avg_tvalid, avg_tready;
   wire divisor_tready, dividend_tready;
   wire [9:0] divisor40 = {8'b0,divisor};

   moving_sum #(
     .MAX_LEN(MAX_LEN),
     .WIDTH(2))
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
   divide_int10 divide_inst (
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

endmodule
