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
  parameter COUNTER_SIZE = 32,
  parameter WIDTH = 16)
(
    input clk, input reset, input clear,
    input [WIDTH-1:0] threshold,input [WIDTH-1:0] offset,
    input init_cal, input [31:0] cal_len,
    input [WIDTH-1:0] i_tdata, input i_tvalid, input i_tlast, output i_tready,
    output [COUNTER_SIZE-1:0] o_tdata, output o_tvalid, output o_tlast, input o_tready,
    output [COUNTER_SIZE-1:0] cycles_per_sec,
    input pps
);
localparam     IDLE      = 2'b00,
               P_SIG     = 2'b01
               N_SIG     = 2'b10;

 reg [1:0] next_gen_state;
 reg [1:0] gen_state;

reg [COUNTER_SIZE-1:0] zc_count;
reg [COUNTER_SIZE-1:0] zc_count_r;
reg [COUNTER_SIZE-1:0] zc_persec;
reg [COUNTER_SIZE-1:0] zc_persec_r;
reg [COUNTER_SIZE-1:0] zc_count_period

reg zc_valid;
reg zc_valid_next;

reg o_tvalid_r;

reg p_sig_det_r;
reg n_sig_det_r;

reg cal_good;
reg [31:0] cal_counter;
reg signed [63:0] cal_sum;
reg signed [63:0] cal_result;
wire signed [63:0] offset_cal64;
wire signed [15:0] offset_cal;
wire signed [15:0] offset_use;

wire p_sig_thresh_det = i_tready && i_tvalid && ($signed(i_tdata) >= ($signed(threshold)+offset_use));
wire n_sig_thresh_det = i_tready && i_tvalid && ($signed(i_tdata) < (offset_use-$signed(threshold));

wire p_sig_det = i_tready && i_tvalid && ($signed(i_tdata) >= $signed(offset_use));
wire n_sig_det = i_tready && i_tvalid && ($signed(i_tdata) < $signed(offset_use));

//////////////////////////////////////////////////////////////////////////
// PPS edge detection logic
//////////////////////////////////////////////////////////////////////////
reg pps_del, pps_del2;
always @(posedge clk)
  {pps_del2,pps_del} <= {pps_del, pps};

wire pps_edge = !pps_del2 & pps_del;

assign i_tready = 1'b1;

always @(posedge clk) begin
  if (reset | clear) begin
    p_sig_det_r     <= 0;
    n_sig_det_r     <= 0;
  end else begin
    p_sig_det_r <= p_sig_det;
    n_sig_det_r <= n_sig_det;
  end
end

always @(posedge clk) begin
  if (reset | clear) begin
    cal_counter     <= 0;
    cal_sum <= 0;
  end else if (init_cal) begin
    cal_sum <= 0;
    cal_counter <= cal_len;
  end else if ((|cal_counter) && i_tready && i_tvalid) begin
    cal_counter <= cal_counter - 1'b1;
    cal_sum <= cal_sum + $signed(i_tdata);
  end
end

always @(posedge clk) begin
  if (reset | clear) begin
    cal_result <= 0;
  end else if ((cal_counter == 32'b1) && i_tready && i_tvalid) begin
    cal_result <= cal_sum+ $signed(i_tdata);
  end
end

always @(posedge clk) begin
  if (reset | clear) begin
    use_cal <= 0;
  end else if (init_cal && (cal_len == 0)) begin
    use_cal <= 0;
  end else if ((cal_counter == 32'b1) && i_tready && i_tvalid) begin
    use_cal <= 1;
  end
end

assign offset_cal64 = (cal_result >>> $clog2(cal_len));
assign offset_use = use_cal ? offset_cal64[15:0] : $signed(offset);

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
      zc_valid_next <= 0;
  end else if (gen_state == IDLE && (p_sig_thresh_det || n_sig_thresh_det)) begin
      zc_valid_next <= 1;
  end else if ((gen_state == P_SIG && n_sig_det) || (gen_state == N_SIG && p_sig_det))begin
      zc_valid <= zc_valid_next;
      zc_valid_next <= 0;
   end
end

always @(posedge clk)
begin
   if (reset | clear) begin
      o_tvalid_r <= 0;
  end else if ((gen_state == P_SIG && n_sig_det) || (gen_state == N_SIG && p_sig_det))begin
      o_tvalid_r <= zc_valid
  end else if (o_tready) begin
      o_tvalid_r <= 0;
  end
end


always @(posedge clk)
begin
   if (reset | clear) begin
      zc_count <= 0;
      zc_count_r = <= 0;
      zc_count_period <= 0;
   end else if (gen_state == P_SIG && n_sig_det)begin
       zc_count <= 0;
       zc_count_r <= zc_count;
   end else if (gen_state == N_SIG && p_sig_det)begin
       zc_count <= 0;
       zc_count_r <= zc_count;
       zc_count_period <= zc_count + zc_count_r;
   end else if (zc_valid && i_tready && i_tvalid) begin
      zc_count <= zc_count + 1;
   end
end

always @(posedge clk)
begin
   if (reset | clear | pps_edge) begin
      zc_persec <= 0;
      zc_persec_r <= 0;
   end else if (pps_edge) begin
      zc_persec <= 0;
      zc_persec_r <= zc_persec;
   end else if (gen_state == N_SIG && p_sig_det)begin
       zc_persec <= zc_persec  + 1;
   end
end

assign o_tvalid = o_tvalid_r;
assign o_tdata = zc_count_r;
assign o_tlast = 0;
assign cycles_per_sec = zc_persec_r;



endmodule
