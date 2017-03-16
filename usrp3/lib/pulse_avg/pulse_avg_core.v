//////////////////////////////////////////////////////////////////////////////////
// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 03/14/2017 07:29:14 PM
// Design Name:
// Module Name: pulse_avg_core
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

module pulse_avg_core #(
  parameter MAX_PULSE_SIZE = 8192,
  parameter WIDTH = 32)
(
    input clk, input reset, input clear,
    input [31:0] pulse_size, input [31:0] num_avg, output [31:0] num_count,
    input [31:0] i_tdata, input [127:0] i_tuser, input i_tvalid, input i_tlast, output i_tready,
    output [31:0] o_tdata, output [127:0] o_tuser, output o_tvalid, output o_tlast, input o_tready
);
localparam     IDLE        = 3'b000,
               WR_CMD      = 3'b001,
               WR_DATA     = 3'b010,
               RD_CMD      = 3'b011,
               RD_DATA     = 3'b100;

reg [31:0] num_count_r;
reg [31:0] r_pos, w_pos;

wire [1:0] pkt_type;
wire 	  has_time;
wire 	  eob;
wire [11:0] seqnum;
wire [15:0] src_sid;
wire [15:0] dst_sid;
wire [63:0] vita_time;

cvita_hdr_decoder cvita_hdr_decoder (
     .header(i_tuser),
     .pkt_type(pkt_type), .eob(eob), .has_time(has_time),
     .seqnum(seqnum), .length(), .payload_length(payload_length_in),
     .src_sid(src_sid), .dst_sid(dst_sid),
     .vita_time(vita_time)
   );

always @(posedge clk) begin
    if(reset | clear)
        num_count_r <= 0;
    else if ()    
end
endmodule
