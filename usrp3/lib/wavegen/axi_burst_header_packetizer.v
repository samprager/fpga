//
// Written by Samuel Prager
//
// 2017
// MiXIL
// University of Southern California
//

module axi_burst_header_packetizer
   (input clk, input reset,
    input [31:0] max_spp,
    input [31:0] burst_len,
    input [31:0] i_tdata, input [127:0] i_tuser, input i_tlast, input i_tvalid, output i_tready,
    output [31:0] o_tdata, output [127:0] o_tuser, output o_tlast, output o_tvalid, input o_tready);

    reg[31:0] samp_count_r;
    reg[31:0] pkt_count_r;
    reg eob_r;
    reg [31:0] last_pkt_len_r;
   // Parse i_tuser
   wire [1:0] 	  pkt_type;
   wire 	  has_time;
   wire 	  eob;
   wire [11:0] 	  seqnum;
   wire [15:0] src_sid;
   wire [15:0] dst_sid;
   wire [63:0] vita_time;

   wire [15:0] payload_length_in; //doesn't matter replaced with burst_len
   wire [15:0] payload_length_out;

   // wire [31:0] burst_len = {2'b0,payload_length_in[15:2]};
   wire [31:0] payload_length;

cvita_hdr_decoder cvita_hdr_decoder (
     .header(i_tuser),
     .pkt_type(pkt_type), .eob(), .has_time(has_time),
     .seqnum(seqnum), .length(), .payload_length(payload_length_in),
     .src_sid(src_sid), .dst_sid(dst_sid),
     .vita_time(vita_time)
   );

   cvita_hdr_encoder cvita_hdr_encoder (
     .pkt_type(pkt_type), .eob(eob), .has_time(has_time),
     .seqnum(seqnum), .payload_length(payload_length_out), .dst_sid(dst_sid), .src_sid(src_sid),
     .vita_time(vita_time),
     .header(o_tuser));

   // Pass nearly everything through unchanged
   assign o_tdata = i_tdata;
   assign o_tlast = (pkt_count_r == max_spp) |  i_tlast;
   assign o_tvalid = i_tvalid;
   assign i_tready = o_tready;
   //assign payload_length_out = {payload_length[13:0],2'b00};
   assign payload_length_out = payload_length[15:0];


   always @(posedge clk) begin
      if (reset)
         samp_count_r <= 32'b1;
      else if (i_tvalid & o_tready & i_tlast)
          samp_count_r <= 32'b1;
      else if (i_tvalid & o_tready)
          samp_count_r <= samp_count_r + 1'b1;
   end

   always @(posedge clk) begin
      if (reset) begin
         pkt_count_r <= 32'b1;
      end else if (i_tvalid & o_tready) begin
         if (i_tlast | pkt_count_r == max_spp)
             pkt_count_r <= 32'b1;
         else
          pkt_count_r <= pkt_count_r + 1'b1;
     end
   end

   always @(posedge clk) begin
      if (reset) begin
         eob_r <= 32'b0;
         last_pkt_len_r <= 32'b0;
      end else if (i_tvalid & o_tready) begin
         if (pkt_count_r == max_spp & (burst_len <= (samp_count_r + max_spp)) & (burst_len>samp_count_r)) begin
             eob_r <= 32'b1;
             last_pkt_len_r <= burst_len - samp_count_r;
         end else if (i_tlast) begin
             eob_r <= 32'b0;
          end
     end
   end

   assign payload_length = ((max_spp == 0) | (max_spp >= burst_len)) ? {burst_len[13:0],2'b00} : (eob) ? {last_pkt_len_r[13:0],2'b00} : {max_spp[13:0],2'b00};
   assign eob = ((max_spp == 0) |(max_spp >= burst_len)) ? 1'b1 : eob_r;

endmodule // packet_resizer
