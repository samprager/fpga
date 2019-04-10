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

module zero_crossing_detect #(
  parameter THRESHOLD_INIT = 512,
  parameter COUNTER_SIZE = 32,
  parameter N_DETECT = 2,
  parameter WIDTH = 16)
(
    input clk, input reset, input clear,
    input [WIDTH-1:0] threshold, input [$clog2(N_MOVAVG_MAX+1)-1:0] num_movavg, input [$clog2(N_ZCAVG_MAX+1)-1:0] num_zcavg,
    output [31:0] num_count,
    input [WIDTH-1:0] i_tdata, input i_tvalid, input i_tlast, output i_tready,
    output [WIDTH-1:0] o_tdata, output o_tvalid, output o_tlast, input o_tready
);
localparam     IDLE        = 3'b000,
               DETECT     = 3'b001
               WAIT     = 3'b010,
               WR_DATA     = 3'b010,
               RD_CMD      = 3'b011,
               RD_DATA     = 3'b100;

 reg [2:0] next_gen_state;
 reg [2:0] gen_state;

reg [COUNTER_SIZE-1:0] z_count;
reg [COUNTER_SIZE-1:0] z_count;

reg [31:0] r_pos, w_pos;

reg [63:0] zero_cross_count

wire [1:0] pkt_type;
wire 	  has_time;
wire 	  eob;
wire [11:0] seqnum;
wire [15:0] src_sid;
wire [15:0] dst_sid;
wire [63:0] vita_time;

wire p_sig_thresh_det = i_tready && i_tvalid && ($signed(i_tdata) >= $signed(threshold));
wire n_sig_thresh_det = i_tready && i_tvalid && (-$signed(i_tdata) >= $signed(threshold));

wire p_sig_det = i_tready && i_tvalid && ($signed(i_tdata) >= 0);
wire n_sig_det = i_tready && i_tvalid && ($signed(i_tdata) < 0);

reg [N_DETECT-1:0] p_sig_det_r;
reg [N_DETECT-1:0] n_sig_det_r;

reg p_sig_det_r;
reg n_sig_det_r;

always @(posedge clk) begin
  if (reset | clear) begin
    p_sig_det_r     <= 0;
    n_sig_det_r     <= 0;
  end else begin
    p_sig_det_r <= p_sig_det;
    n_sig_det_r <= n_sig_det;
  end
end

always @(gen_state or p_sig_thresh_det or n_sig_thresh_det or p_sig_det or n_sig_det)
begin
   next_gen_state = gen_state;
   case (gen_state)
      IDLE : begin
        if (p_sig_thresh_det)  //& (&fmc150_status_vector[3:1]))
            next_gen_state = P_SIG;
        else if (n_sig_thresh_det)  //& (&fmc150_status_vector[3:1]))
            next_gen_state = N_SIG;
      end
      P_SIG : begin
         if (n_sig_det) //& (&fmc150_status_vector[3:1]))
            next_gen_state = IDLE;
      end
      N_SIG : begin
          if (p_sig_det) //& (&fmc150_status_vector[3:1]))
             next_gen_state = IDLE;
       end
      default : begin
         next_gen_state = IDLE;
      end
   endcase
end

always @(posedge clk)
begin
   if (reset) begin
      gen_state <= IDLE;
   end
   else begin
       gen_state <= next_gen_state;
   end
end

always @(posedge clk)
begin
   if (reset | clear) begin
      zc_valid <= 0;
   end
   else if (begin
       gen_state <= next_gen_state;
   end
end

always @(posedge clk)
begin
   if (reset | clear) begin
      zc_count <= 0;
   end
   else if (begin
       gen_state <= next_gen_state;
   end
end


endmodule
