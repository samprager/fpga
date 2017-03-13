//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MiXIL
// Engineer: Samuel Prager
//
// Create Date: 08/14/2016 03:54:31 PM
// Design Name:
// Module Name: waveform_formatter
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
// Modified version of waveform_formatter to work with 64 bit headers
//////////////////////////////////////////////////////////////////////////////////

`timescale 1 ps/1 ps

module waveform_decoder(
   input                   clk,
   input                   reset,
   input                   clear,

   input [63:0] vita_time, input [31:0] resp_sid,
   // Error packets
   output reg [63:0] resp_tdata, output reg [127:0] resp_tuser, output reg resp_tlast, output reg resp_tvalid, input resp_tready,

   input                   wf_write_ready,
   output                  [127:0] waveform_parameters,
   output                  init_wf_write,
       // data from ADC Data fifo
    input       [31:0]                    wfrm_axis_tdata,
    input                                 wfrm_axis_tvalid,
    input                                 wfrm_axis_tlast,
    input       [3:0]                     wfrm_axis_tkeep,
    input       [3:0]                     wfrm_axis_tdest,
    input       [3:0]                     wfrm_axis_tid,
    input      [31:0]                     wfrm_axis_tuser,
    output                                wfrm_axis_tready,

    output    [31:0] tdata,
    output           tvalid,
    output           tlast,
    output    [3:0]  tkeep,
    output    [3:0]  tdest,
    output    [3:0]  tid,
    output    [31:0] tuser,
    input            tready

  //  output reg  [8*REG_WIDTH-1:0]        reg_map_axis_tdata,
  //  output reg                           reg_map_axis_tvalid,
  //  output reg                           reg_map_axis_tlast,
  //  input                                reg_map_axis_tready
   );



localparam     IDLE        = 3'b000,
               NEXT_CMD    = 3'b001,
               HEADER       = 3'b010,
               DATA        = 3'b011,
               OVERHEAD    = 3'b100;

localparam     DATA_WRITE_COMMAND = 16'h5744;       //Ascii WD

reg [15:0]                 next_wfrm_id;
reg [15:0]                 next_wfrm_ind;
reg [15:0]                 next_wfrm_len;

reg [15:0]                 curr_wfrm_id;
reg [15:0]                 curr_wfrm_ind;
reg [15:0]                 curr_wfrm_len;

reg         [2:0]          state;
reg         [4:0]          overhead_count;
reg         [31:0]         data_count;

wire                         wfrm_axis_tready_int;

reg                         init_wf_write_reg;
reg         [127:0]         waveform_parameters_reg;

reg       [31:0]                   tdata_reg;
reg                                tvalid_reg;
reg                                tlast_reg;
reg       [3:0]                    tdest_reg;
reg       [3:0]                    tid_reg;
reg       [3:0]                    tkeep_reg;
reg       [31:0]                   tuser_reg;

reg                       has_waveform;

wire [63:0] CODE_TLAST_SUCCESS      = {32'd1,curr_wfrm_id,curr_wfrm_len};
wire [63:0] CODE_TLAST_ERR    = {32'd2,curr_wfrm_id,curr_wfrm_len};

wire [127:0] error_header     = {2'b11, 1'b1, 1'b1, 12'd0 /* don't care */, 16'd0 /* don't care */, resp_sid, vita_time};
wire [127:0] resp_header      = {2'b11, 1'b1, 1'b0, 12'd0 /* don't care */, 16'd0 /* don't care */, resp_sid, vita_time};


always @(posedge clk) begin
  if (reset | clear) begin
    state      <= IDLE;
    tvalid_reg <= 0;
    tdata_reg <= 0;
    tuser_reg <= 0;
    tkeep_reg <= 0;
    tid_reg <= 0;
    tdest_reg <= 0;
    tlast_reg <= 0;

    curr_wfrm_id <= 0;
    curr_wfrm_ind <= 0;
    curr_wfrm_len <= 0;
    next_wfrm_id <= 0;
    next_wfrm_ind <= 0;
    next_wfrm_len <= 0;
    has_waveform <= 0;

    data_count <= 0;
    overhead_count <= 0;

    waveform_parameters_reg <= 0;
    init_wf_write_reg <= 0;

    resp_tvalid <= 1'b0;
    resp_tlast  <= 1'b0;
    resp_tuser  <= 'd0;
    resp_tdata  <= 'd0;

  end else begin

  // Deassert tvalid after response packet is consumed
  if (resp_tvalid & resp_tlast & resp_tready) begin
    resp_tvalid <= 1'b0;
    resp_tlast  <= 1'b0;
  end

    case (state)
        IDLE : begin
        overhead_count <= 24;
        if ((!tvalid_reg & tready) | wf_write_ready) begin
            state <= NEXT_CMD;
        end

        if (tready) begin
             tvalid_reg <= 0;
             tlast_reg <= 0;
        end

        if (wf_write_ready) begin
          init_wf_write_reg <= 0;
        end
      end

      NEXT_CMD : begin
        if (wfrm_axis_tvalid & wfrm_axis_tready_int & wfrm_axis_tdata[31:16] == DATA_WRITE_COMMAND) begin
             next_wfrm_id <= wfrm_axis_tdata[15:0];
             state <= HEADER;
        end

        if (tready) begin
             tvalid_reg <= 0;
             tlast_reg <= 0;
        end

        if (wf_write_ready) begin
          init_wf_write_reg <= 0;
        end

      end

      // Wait for output to be ready
      HEADER : begin
          if (wfrm_axis_tvalid & wfrm_axis_tready_int) begin
            if ((next_wfrm_id != curr_wfrm_id) | (~has_waveform)) begin
                if(|wfrm_axis_tdata[31:16]) begin
                    state <= NEXT_CMD;
                    if (wf_write_ready) begin
                      init_wf_write_reg <= 0;
                    end
                end else begin
                    curr_wfrm_id <= next_wfrm_id;
                    curr_wfrm_ind <= wfrm_axis_tdata[31:16];
                    curr_wfrm_len <= wfrm_axis_tdata[15:0];
                    has_waveform <= 1;
                    data_count <= wfrm_axis_tdata[15:0];
                    init_wf_write_reg <= 1;
                    waveform_parameters_reg[15:0] <= wfrm_axis_tdata[15:0];
                    state <= DATA;
                end
            end else if ((wfrm_axis_tdata[31:16] == curr_wfrm_ind + 1) & (wfrm_axis_tdata[15:0] == curr_wfrm_len)) begin
                if (wf_write_ready) begin
                    init_wf_write_reg <= 0;
                end
                curr_wfrm_ind <= wfrm_axis_tdata[31:16];
                state <= DATA;
            end else begin
                state <= NEXT_CMD;
                if (wf_write_ready) begin
                  init_wf_write_reg <= 0;
                end
            end
          end

          if (tready) begin
               tvalid_reg <= 0;
               tlast_reg <= 0;
          end
      end

      DATA : begin
          if (wfrm_axis_tvalid & wfrm_axis_tready_int) begin
              tdata_reg <= wfrm_axis_tdata;
              tvalid_reg <= 1'b1;
              tuser_reg[15:0] <= curr_wfrm_len;
              tkeep_reg <= 4'hf;
              tdest_reg <= 4'b0010;

              if (|data_count) begin
                data_count <= data_count - 1'b1;
              end

              if (wfrm_axis_tlast) begin
                if(data_count == 1)
                    state <= OVERHEAD;
                else
                    state <= NEXT_CMD;
               end

               if (data_count == 1) begin
                   tlast_reg <= 1;
                   if (wfrm_axis_tlast) begin
                        resp_tvalid <= 1'b1;
                        resp_tlast  <= 1'b1;
                        resp_tuser  <= resp_header;
                        resp_tdata  <= CODE_TLAST_SUCCESS;
                        state <= OVERHEAD;
                   end else begin
                        resp_tvalid <= 1'b1;
                        resp_tlast  <= 1'b1;
                        resp_tuser  <= error_header;
                        resp_tdata  <= CODE_TLAST_ERR;
                        state <= OVERHEAD;
                   end
               end else begin
                 if (wfrm_axis_tlast) begin
                    state <= NEXT_CMD;
                end
               end
          end
          else if (tready) begin
            tvalid_reg <= 0;
            tlast_reg <= 0;
          end

          if (wf_write_ready) begin
            init_wf_write_reg <= 0;
          end
      end
      OVERHEAD : begin
           if (|overhead_count) begin
                overhead_count <= overhead_count - 1'b1;
            end

           if (overhead_count == 1) begin
              state <= IDLE;
           end

           if (tready) begin
                tvalid_reg <= 0;
                tlast_reg <= 0;
           end

           if (wf_write_ready) begin
             init_wf_write_reg <= 0;
           end
      end

      default : state <= IDLE;
    endcase
  end
end


assign wfrm_axis_tready_int = ((state == DATA & tready) | (state == NEXT_CMD | state == HEADER));

//assign tvalid = wr_fifo_rx_axis_tvalid_reg;
//assign tlast = wr_fifo_rx_axis_tlast_reg;
//assign tdata = wr_fifo_rx_axis_tdata_reg;

assign tvalid = tvalid_reg;
assign tlast = tlast_reg;
assign tdata = tdata_reg;
assign tuser = tuser_reg;
assign tdest = tdest_reg;
assign tkeep = tkeep_reg;
assign tid = tid_reg;

assign wfrm_axis_tready = wfrm_axis_tready_int;
assign init_wf_write = init_wf_write_reg;

assign waveform_parameters = waveform_parameters_reg;


endmodule
