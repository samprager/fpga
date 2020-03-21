`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 07/14/2016 04:32:51 PM
// Design Name:
// Module Name: chirp_sim_tb
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


module chirp_sim_tb;

localparam CLK_PERIOD          = 5000;         // 200 MHz
localparam RESET_PERIOD = 20000; //in pSec

localparam PRF_MAX = 32'h00000aff;
localparam DDS_LATENCY = 2;


reg reset_i;
reg clk_i;
wire clk;
wire reset;

reg dds_init_r;

  wire dds_ready;
  wire dds_done;
  wire dds_active;
  wire dds_init;
  wire dds_enable;

reg awg_data_ready_r;
wire awg_data_ready;

reg [3:0] ready_count;
reg stay_ready;

reg next_pulse;

wire [31:0] chirp_count_max = 32'hf;

wire [31:0] chirp_out_size;
reg [31:0] prf_count_r;
wire [31:0] chirp_data_iq;
wire chirp_data_valid;
wire chirp_data_last;

initial
begin
      clk_i = 1'b0;
end

initial begin
  reset_i = 1'b1;
  #RESET_PERIOD
    reset_i = 1'b0;
 end

always
  begin
      clk_i = #(CLK_PERIOD/2.0) ~clk_i;
end

assign clk = clk_i;
assign reset = reset_i;

initial begin
      repeat(4096)@(posedge clk); // wait for reset
      $finish;
end

always @(posedge clk) begin
    if (reset) begin
        prf_count_r <= 32'b0;
        dds_init_r <= 0;
        next_pulse <= 0;
        ready_count <= 'b0;
        awg_data_ready_r <= 0;
        stay_ready <= 1'b0;
    end
    else begin
        ready_count <= ready_count + 1'b1;
        
        if ((ready_count <  4'b1000) | stay_ready)
            awg_data_ready_r <= 1;
        else
            awg_data_ready_r <= 0;


        if((prf_count_r == 32'b0) & (dds_ready)) begin
            dds_init_r <= 1'b1;
            prf_count_r <= PRF_MAX;
            next_pulse <= 0;
            ready_count <= 0;
            stay_ready <= ~stay_ready;
        end else begin
            if (dds_active) begin
                dds_init_r <= 0;
            end

            if (dds_done)
                next_pulse <= 1;

            if(next_pulse & |prf_count_r)
               prf_count_r <= prf_count_r - 1'b1;
        end
    end
end

chirpgen #(.DDS_LATENCY(DDS_LATENCY)) chirpgen_inst(
    .clk  (clk),
	.rst	(reset),
	.chirp_out_i  (chirp_data_iq[31:16]),			//i data to dac, 16-bit
	.chirp_out_q  (chirp_data_iq[15:0]),		    // q data to dac, 16-bit,
    .chirp_out_valid (chirp_data_valid),
    .chirp_out_last(chirp_data_last),
    .chirp_out_ready(awg_data_ready),

  .chirp_ready (dds_ready),
  .chirp_done (dds_done),
  .chirp_active (dds_active),
  .chirp_init  (dds_init),
  .chirp_enable  (1'b1),
  .freq_offset_in (32'h0b00),
  .tuning_word_coeff_in (32'd1),
  .chirp_count_max_in (chirp_count_max)
);
assign chirp_out_size = chirp_count_max+1'b1;
assign dds_init = dds_init_r;
assign awg_data_ready = awg_data_ready_r;

endmodule
