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
  parameter WIDTH = 16,
  parameter IS_Q_PART = 0)
(
    input clk, input reset, input clear,
    input [WIDTH-1:0] threshold,input [WIDTH-1:0] offset, output [WIDTH-1:0] offset_out,
    input init_cal,input auto_cal, input [31:0] log_cal_len,
    input [WIDTH-1:0] i_tdata, input i_tvalid, input i_tlast, output i_tready,
    output [COUNTER_SIZE-1:0] o_tdata, output o_tvalid, output o_tlast, input o_tready,
    output [COUNTER_SIZE-1:0] cycles_per_sec, output reg cycles_per_sec_valid, input cycles_per_sec_ready,
    input iq_sign,
    output zc_sign,
    input pps
);
localparam     IDLE      = 2'b00,
               P_SIG     = 2'b01,
               N_SIG     = 2'b10;

 reg [1:0] next_gen_state;
 reg [1:0] gen_state;

reg [COUNTER_SIZE-1:0] zc_count;
reg [COUNTER_SIZE-1:0] zc_count_r;
reg [COUNTER_SIZE-1:0] zc_persec;
reg [COUNTER_SIZE-1:0] zc_persec_r;
reg [COUNTER_SIZE-1:0] zc_count_period;
reg [COUNTER_SIZE-1:0] zc_persec_sign;
reg [COUNTER_SIZE-1:0] zc_persec_sign_r;

reg [31:0] log_cal_len_r;
reg init_cal_r;
reg [47:0] cal_len_r

// add one to correct counter value
wire [COUNTER_SIZE-1:0] zc_count_fixed;


reg zc_valid;
reg zc_valid_next;

reg o_tvalid_r;

reg p_sig_det_r;
reg n_sig_det_r;

wire iq_sign_s;
reg iq_sign_r;

reg use_cal;

reg [47:0] cal_counter;
reg signed [63:0] cal_sum;
reg signed [63:0] cal_result;
wire signed [63:0] offset_cal64;
wire signed [(WIDTH-1):0] offset_use;

wire cycles_per_sec_sign;

wire [47:0] cal_len = (48'b1 << log_cal_len_r);

wire p_sig_thresh_det = i_tready && i_tvalid && ($signed(i_tdata) >= ($signed(threshold)+offset_use));
wire n_sig_thresh_det = i_tready && i_tvalid && ($signed(i_tdata) < (offset_use-$signed(threshold)));

wire p_sig_det = i_tready && i_tvalid && ($signed(i_tdata) >= $signed(offset_use));
wire n_sig_det = i_tready && i_tvalid && ($signed(i_tdata) < $signed(offset_use));

// flip sign bit if we're looking at imaginary part
assign iq_sign_s = (IS_Q_PART==0) ? iq_sign : ~iq_sign;

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
    init_cal_r     <= 0;
  end else begin
    init_cal_r <= init_cal;
  end
end

always @(posedge clk) begin
  if (reset | clear) begin
    log_cal_len_r     <= 0;
  end else if (init_cal) begin
    log_cal_len_r <= log_cal_len;
  end
end

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
    cal_counter <= 0;
    cal_sum <= 0;
  end else if (init_cal_r || (auto_cal && (cal_counter==0))) begin
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
  end else if ((init_cal_r || (auto_cal && (cal_counter==0))) && (log_cal_len_r == 0)) begin
    use_cal <= 0;
  end else if ((cal_counter == 32'b1) && i_tready && i_tvalid) begin
    use_cal <= 1;
  end
end

assign offset_cal64 = (cal_result >>> log_cal_len_r);

assign offset_use = use_cal ? offset_cal64[(WIDTH-1):0] : $signed(offset);

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
  end else if ((gen_state == P_SIG && n_sig_det) || (gen_state == N_SIG && p_sig_det)) begin
      o_tvalid_r <= zc_valid;
  end else if (o_tready) begin
      o_tvalid_r <= 0;
  end
end


always @(posedge clk)
begin
   if (reset | clear) begin
      zc_count <= 0;
      zc_count_r <= 0;
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
   if (reset | clear) begin
      zc_persec <= 0;
      zc_persec_r <= 0;
      zc_persec_sign <= 0;
      zc_persec_sign_r <= 0;
   end else if (pps_edge) begin
      zc_persec <= 0;
      zc_persec_r <= zc_persec;
      zc_persec_sign <= 0;
      zc_persec_sign_r <= zc_persec_sign;
   end else if (gen_state == N_SIG && p_sig_det)begin
       zc_persec <= zc_persec  + 1;
       zc_persec_sign <= zc_persec_sign + iq_sign_s;
   end
end

always @(posedge clk)
begin
   if (reset | clear) begin
      cycles_per_sec_valid <= 1'b0;
   end else if (pps_edge) begin
      cycles_per_sec_valid <= 1'b1;
   end else if (cycles_per_sec_ready)begin
       cycles_per_sec_valid <= 1'b0;
   end
end

always @(posedge clk)
begin
   if (reset | clear) begin
      iq_sign_r <= 1; //assume freq is positive
   end else if (gen_state == N_SIG && p_sig_det)begin
       iq_sign_r <= iq_sign_s;
   end
end

assign o_tvalid = o_tvalid_r;

assign cycles_per_sec_sign = (zc_persec_sign_r >= (zc_persec_r>>1)) ? 1'b1 : 1'b0;

// If we're looking at the real part:
//  +freq: when I goes from - to +, Q should be -
//  -freq: when I goes from - to +, Q should be +
// If we're looking at the imag part:
//  +freq: when Q goes from - to +, I part should be +
//  -freq: when Q goes from - to +, I part should be -
assign zc_count_fixed = (zc_count_r + 32'b1);
assign o_tdata = (iq_sign_r==1) ? $signed(zc_count_fixed) : -$signed(zc_count_fixed);
// assign o_tdata = zc_count_fixed;
assign zc_sign = ~iq_sign_r;
assign o_tlast = 0;
// assign cycles_per_sec = (iq_sign_r==1) ? $signed(zc_persec_r) : -$signed(zc_persec_r);
assign cycles_per_sec = (cycles_per_sec_sign==1) ? $signed(zc_persec_r) : -$signed(zc_persec_r);
assign offset_out = offset_use;



endmodule
