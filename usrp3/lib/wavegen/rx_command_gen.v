`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: MiXIL
// Engineer: Samuel Prager
//
// Create Date: 06/8/2016 02:25:19 PM
// Design Name:
// Module Name: rx_command_gen
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
module rx_command_gen #(
    parameter FIFO_SIZE = 5,
    parameter [7:0] SR_RX_CTRL_COMMAND      = 152,
    parameter [7:0] SR_RX_CTRL_TIME_HI      = 153,
    parameter  [7:0] SR_RX_CTRL_TIME_LO      = 154
    )(
      input clk,
      input reset,
      input clear,

      output [63:0] cmdout_tdata,
      output cmdout_tlast, cmdout_tvalid,
      input cmdout_tready,

      input [31:0] awg_data_len,
      input [31:0] num_adc_samples,
      input [63:0] vita_time,
      input [15:0] dst_sid,
      input [15:0] src_sid,
      input has_time,
      input send_cmds,

      input awg_init,
      input adc_run,
      input adc_enable          // high while adc samples saved

    );
    // State machine states
    localparam IDLE                 = 0;
    localparam SEND_CMD             = 1;
    localparam TIME_HI              = 2;
    localparam TIME_LO              = 3;

    reg [2:0] state;

    wire [1:0] pkt_type = 2'b10;
    wire        eob = 1'b1;
   // wire        has_time = 1'b0;
    wire [11:0] seqnum = 12'd0; // don't care
    wire [15:0] payload_length = 16'd16; //don't care (payload length in bytes)

    wire [63:0] cmd_tdata;
    wire cmd_tlast, cmd_tvalid, cmd_tready;
    wire [127:0] cmd_tuser;

    reg [63:0] cmd_tdata_r;
    reg cmd_tlast_r, cmd_tvalid_r;

    wire [31:0] numlines;

    wire send_imm = ~has_time;
    wire chain = 1'b0;
    wire reload = 1'b0;
    wire stop = 1'b0;

    reg run_wait;

    reg [31:0] command_i_r;
    reg [7:0]  addr_i_r;
    reg [63:0] time_i_r;

    assign numlines = awg_data_len + num_adc_samples;

    cvita_hdr_encoder cvita_hdr_encoder(
      .pkt_type(pkt_type),.eob(eob), .has_time(1'b0),
      .seqnum(seqnum),
      .payload_length(payload_length),
      .src_sid(src_sid), .dst_sid(dst_sid),
      .vita_time(vita_time),
      .header(cmd_tuser)
    );
    chdr_framer #(.SIZE(FIFO_SIZE), .WIDTH(64)) chdr_framer (
      .clk(clk), .reset(reset), .clear(clear),
      .i_tdata(cmd_tdata), .i_tuser(cmd_tuser), .i_tlast(cmd_tlast), .i_tvalid(cmd_tvalid), .i_tready(cmd_tready),
      .o_tdata(cmdout_tdata), .o_tlast(cmdout_tlast), .o_tvalid(cmdout_tvalid), .o_tready(cmdout_tready));

    always @(posedge clk) begin
      if (reset | clear) begin
        state      <= IDLE;
        command_i_r <= 'b0;
        addr_i_r <= 'b0;
        time_i_r <= 'b0;
        run_wait <= 1'b0;
        cmd_tvalid_r <= 0;
        cmd_tlast_r <= 0;
      end else begin
        case (state)
            IDLE : begin
            if(run_wait & adc_run) begin
                command_i_r <= {send_imm,chain,reload,stop,numlines[27:0]};
                time_i_r <= vita_time;
                addr_i_r <= SR_RX_CTRL_COMMAND;
                cmd_tvalid_r <= 1'b1;
                // cmd_tlast_r <= 0;
                cmd_tlast_r <= 1'b1;
                run_wait <= 0;
                state <= SEND_CMD;
            end else if (awg_init & send_cmds) begin
                run_wait <= 1;
                if (cmd_tready) begin
                    cmd_tvalid_r <= 0;
                    cmd_tlast_r <= 0;
                 end
            end
            else if (cmd_tready) begin
               cmd_tvalid_r <= 0;
               cmd_tlast_r <= 0;
             end
          end

          SEND_CMD : begin
            if (cmd_tready) begin
                if (send_imm) begin
                    state <= TIME_LO;
                    command_i_r <= time_i_r[31:0];
                    addr_i_r <= SR_RX_CTRL_TIME_LO;
                    cmd_tvalid_r <= 1;
                    cmd_tlast_r <= 1;
                end else begin
                    state <= TIME_HI;
                    command_i_r <= time_i_r[63:32];
                    addr_i_r <= SR_RX_CTRL_TIME_HI;
                    cmd_tvalid_r <= 1;
                    // cmd_tlast_r <= 0;
                    cmd_tlast_r <= 1;
                end
            end
          end

          // Wait for output to be ready
          TIME_HI : begin
              if (cmd_tready) begin
                  state <= TIME_LO;
                  command_i_r <= time_i_r[31:0];
                  addr_i_r <= SR_RX_CTRL_TIME_LO;
                  cmd_tvalid_r <= 1;
                  cmd_tlast_r <= 1;
              end
          end

          TIME_LO : begin
              if (cmd_tready) begin
                  state <= IDLE;
                  cmd_tvalid_r <= 0;
                  cmd_tlast_r <= 0;
              end
          end

          default : state <= IDLE;
        endcase
      end
    end

    assign cmd_tvalid = cmd_tvalid_r;
    assign cmd_tlast = cmd_tlast_r;
    assign cmd_tdata = {24'd0,addr_i_r,command_i_r};

endmodule
