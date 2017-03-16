`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer: Samuel Prager
//
// Create Date: 07/14/2016 03:15:50 PM
// Design Name:
// Module Name: axi_bram_stream
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


module axi_bram_stream # (
    parameter WRITE_BEFORE_READ = 1'b1
)(
    input reset,
    input clk,
    input clear,
    input [31:0] in_size,
    input init_write,
    output write_ready,
    output read_ready,

    output [31:0] out_size,
    // data to BRAM
    input       [31:0]                    in_axis_tdata,
    input                                 in_axis_tvalid,
    input                                 in_axis_tlast,
    input       [3:0]                     in_axis_tkeep,
    output                                in_axis_tready,

    // data from BRAM
    output       [31:0]                    out_axis_tdata,
    output                                 out_axis_tvalid,
    output                                 out_axis_tlast,
    output       [3:0]                     out_axis_tkeep,
    input                                out_axis_tready

);
localparam     IDLE        = 3'b000,
               WR_CMD        = 3'b001,
               WR_DATA    = 3'b010,
               RD_CMD        = 3'b011,
               RD_DATA    = 3'b100,
               RW_CMD        = 3'b101,
               RW_DATA    = 3'b110;

localparam FIXED = 1'b0;
localparam INCR = 1'b1;


wire [7:0]m_axis_mm2s_sts_tdata;
wire [0:0]m_axis_mm2s_sts_tkeep;
wire m_axis_mm2s_sts_tlast;
wire m_axis_mm2s_sts_tready;
wire m_axis_mm2s_sts_tvalid;
wire [31:0]m_axis_mm2s_tdata;
wire [3:0]m_axis_mm2s_tkeep;
wire m_axis_mm2s_tlast;
wire m_axis_mm2s_tready;
wire m_axis_mm2s_tvalid;
wire [7:0]m_axis_s2mm_sts_tdata;
wire [0:0]m_axis_s2mm_sts_tkeep;
wire m_axis_s2mm_sts_tlast;
wire m_axis_s2mm_sts_tready;
wire m_axis_s2mm_sts_tvalid;
wire [71:0]s_axis_mm2s_cmd_tdata;
wire s_axis_mm2s_cmd_tready;
wire s_axis_mm2s_cmd_tvalid;
wire [71:0]s_axis_s2mm_cmd_tdata;
wire s_axis_s2mm_cmd_tready;
wire s_axis_s2mm_cmd_tvalid;
wire [31:0]s_axis_s2mm_tdata;
wire [3:0]s_axis_s2mm_tkeep;
wire s_axis_s2mm_tlast;
wire s_axis_s2mm_tready;
wire s_axis_s2mm_tvalid;
wire mm2s_err;
wire s2mm_err;

reg m_axis_mm2s_sts_tready_reg;
reg m_axis_mm2s_tready_reg;
reg m_axis_s2mm_sts_tready_reg;

reg [71:0]s_axis_mm2s_cmd_tdata_reg;
reg s_axis_mm2s_cmd_tvalid_reg;
reg [71:0]s_axis_s2mm_cmd_tdata_reg; //{RSVD(4b),TAG(4b),SADDR(32b),DRR(1b),EOF(1b),DSA(6b),Type(1b),BTT(23b)}
reg s_axis_s2mm_cmd_tvalid_reg;

//reg [31:0]s_axis_s2mm_tdata_reg;
//reg [3:0]s_axis_s2mm_tkeep_reg;
//reg s_axis_s2mm_tlast_reg;
//reg s_axis_s2mm_tvalid_reg;

reg write_ready_reg;
reg read_ready_reg;
reg write_cmd_stop, read_cmd_stop;
reg [31:0] new_size;  // bytes to transfer
reg [31:0] cur_size;  // bytes to transfer

reg         [2:0]          next_gen_state;
reg         [2:0]          gen_state;

reg [31:0] rd_addr = 32'hC0000000;
reg [31:0] wr_addr = 32'hC0000000;
reg [31:0] wr_counter;
reg [31:0] rd_counter;
reg [2:0] wr_cmd_counter;
reg [1:0] rd_cmd_counter;

reg written = 1'b0;

// register that tracks whether or not we have written to the bram...
always @(posedge clk) begin
    if(reset)
        written <= 0;
    else if ((gen_state == WR_CMD) | (!WRITE_BEFORE_READ))
        written <= 1;
    else
        written <= written;
end


always @(posedge clk) begin
    if(reset)
        write_ready_reg <= 0;
    else if (gen_state == IDLE)
        write_ready_reg <= 1;
   else
        write_ready_reg <= 0;
end

always @(posedge clk) begin
    if(reset)
        read_ready_reg <= 0;
    else if (gen_state == IDLE)
        read_ready_reg <= 1;
   else
        read_ready_reg <= 0;
end

always @(posedge clk) begin
    if(reset)
        new_size <= 0;
    else if (gen_state == IDLE & write_ready_reg & init_write)
        new_size <= in_size;
end

always @(posedge clk) begin
    if(reset)
        cur_size <= 0;
    else if (gen_state == WR_CMD & (s_axis_s2mm_cmd_tvalid_reg & s_axis_s2mm_cmd_tready))
        cur_size <= new_size;
end

always @(posedge clk)begin
    if(reset) begin
        m_axis_mm2s_sts_tready_reg <= 0;
        m_axis_s2mm_sts_tready_reg <= 0;
    end
    else begin
        m_axis_mm2s_sts_tready_reg <= 1;
        m_axis_s2mm_sts_tready_reg <= 1;
    end
end

always @(posedge clk)begin
    if(reset) begin
        wr_cmd_counter <= 0;
    end
    else if (gen_state == WR_CMD & ((s_axis_s2mm_cmd_tvalid_reg & s_axis_s2mm_cmd_tready) | (|wr_cmd_counter))) begin
        wr_cmd_counter <= wr_cmd_counter+1;
    end
    else if (gen_state == RW_CMD & ((s_axis_s2mm_cmd_tvalid_reg & s_axis_s2mm_cmd_tready) | (|wr_cmd_counter))) begin
        wr_cmd_counter <= wr_cmd_counter+1;
    end
    else begin
        wr_cmd_counter <= 0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        wr_cmd_stop <= 0;
    end
    else if (gen_state == WR_CMD & (&wr_cmd_counter)) begin
        wr_cmd_stop <= 1;
    end
    else if (gen_state == RW_CMD & (&wr_cmd_counter)) begin
        wr_cmd_stop <= 1;
    end
    else if (gen_state != WR_CMD | gen_state != RW_CMD) begin
        wr_cmd_stop <= 0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        s_axis_s2mm_cmd_tvalid_reg <= 0;
    end
    else if (gen_state == WR_CMD & !(s_axis_s2mm_cmd_tvalid_reg & s_axis_s2mm_cmd_tready) & (wr_cmd_counter == 0)) begin
        s_axis_s2mm_cmd_tvalid_reg <= 1;
    end
    else if (gen_state == RW_CMD & !(s_axis_s2mm_cmd_tvalid_reg & s_axis_s2mm_cmd_tready) & (wr_cmd_counter == 0)) begin
        s_axis_s2mm_cmd_tvalid_reg <= 1;
    end
    else begin
        s_axis_s2mm_cmd_tvalid_reg <= 0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        s_axis_s2mm_cmd_tdata_reg <= 0;
    end
    else if (gen_state == WR_CMD & (wr_cmd_counter == 0)) begin
        s_axis_s2mm_cmd_tdata_reg[67:64] <= 4'hE;   //test tag
        s_axis_s2mm_cmd_tdata_reg[63:32] <= wr_addr;
         s_axis_s2mm_cmd_tdata_reg[30] <= 1'b1;    // eof
        s_axis_s2mm_cmd_tdata_reg[23] <= INCR;
        s_axis_s2mm_cmd_tdata_reg[22:0] <= {new_size[20:0],2'b0};  // shift left two places for size in bytes
    end
    else if (gen_state == RW_CMD & (wr_cmd_counter == 0)) begin
        s_axis_s2mm_cmd_tdata_reg[67:64] <= 4'hE;   //test tag
        s_axis_s2mm_cmd_tdata_reg[63:32] <= wr_addr;
         s_axis_s2mm_cmd_tdata_reg[30] <= 1'b1;    // eof
        s_axis_s2mm_cmd_tdata_reg[23] <= INCR;
        s_axis_s2mm_cmd_tdata_reg[22:0] <= {new_size[20:0],2'b0};  // shift left two places for size in bytes
    end
end
always @(posedge clk)begin
    if(reset) begin
        rd_cmd_counter <= 0;
    end
    else if (gen_state == RD_CMD & ((s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready) | (|rd_cmd_counter))) begin
        rd_cmd_counter <= rd_cmd_counter+1;
    end
    else if (gen_state == RW_CMD & ((s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready) | (|rd_cmd_counter))) begin
        rd_cmd_counter <= rd_cmd_counter+1;
    end
    else begin
        rd_cmd_counter <= 0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        rd_cmd_stop <= 0;
    end
    else if (gen_state == RD_CMD & (s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)) begin
        rd_cmd_stop <= 1;
    end
    else if (gen_state == RW_CMD & (s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)) begin
        rd_cmd_stop <= 1;
    end
    else if (gen_state != RD_CMD | gen_state != RW_CMD) begin
        rd_cmd_stop <= 0;
    end
end

always @(posedge clk)begin
    if(reset) begin
        s_axis_mm2s_cmd_tvalid_reg <= 0;
    end
    else if ((gen_state == RD_CMD)&!(s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)&(rd_cmd_counter == 0))begin
        s_axis_mm2s_cmd_tvalid_reg <= 1;
    end
    else if ((gen_state == RW_CMD)&!(s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)&(rd_cmd_counter == 0))begin
        s_axis_mm2s_cmd_tvalid_reg <= 1;
    end
    else begin
        s_axis_mm2s_cmd_tvalid_reg <= 0;
    end
end
always @(posedge clk)begin
    if(reset) begin
        s_axis_mm2s_cmd_tdata_reg <= 0;
    end
    else if (gen_state == RD_CMD) begin
        s_axis_mm2s_cmd_tdata_reg[67:64] <= 4'hE;   //test tag
        s_axis_mm2s_cmd_tdata_reg[63:32] <= rd_addr;
        s_axis_mm2s_cmd_tdata_reg[30] <= 1'b1;      // eof
        s_axis_mm2s_cmd_tdata_reg[23] <= INCR;
        s_axis_mm2s_cmd_tdata_reg[22:0] <= {cur_size[20:0],2'b0};
    end
    else if (gen_state == RW_CMD) begin
        s_axis_mm2s_cmd_tdata_reg[67:64] <= 4'hE;   //test tag
        s_axis_mm2s_cmd_tdata_reg[63:32] <= rd_addr;
        s_axis_mm2s_cmd_tdata_reg[30] <= 1'b1;      // eof
        s_axis_mm2s_cmd_tdata_reg[23] <= INCR;
        s_axis_mm2s_cmd_tdata_reg[22:0] <= {cur_size[20:0],2'b0};
    end
end

//always @(posedge clk)begin
//    if(reset) begin
//        s_axis_s2mm_tvalid_reg <= 0;
//    end
//    else if (gen_state == WR_DATA) begin
//        s_axis_s2mm_tvalid_reg <= 1;
//    end
//    else if(s_axis_s2mm_tready) begin
//       s_axis_s2mm_tvalid_reg <= 0;
//    end
//end

//always @(posedge clk)begin
//    if(reset) begin
//        s_axis_s2mm_tkeep_reg <= 0;
//    end
//    else if (gen_state == WR_DATA) begin
//        s_axis_s2mm_tkeep_reg <= 4'hf;
//    end
//    else begin
//       s_axis_s2mm_tkeep_reg <= 0;
//    end
//end

always @(posedge clk)begin
    if(reset) begin
        wr_counter <= 0;
    end
    else if(gen_state == WR_DATA & s_axis_s2mm_tready & s_axis_s2mm_tvalid) begin
        wr_counter <= wr_counter + 1'b1;
    end
    else if(gen_state == RW_DATA & s_axis_s2mm_tready & s_axis_s2mm_tvalid) begin
        wr_counter <= wr_counter + 1'b1;
    end
    else if(gen_state != WR_DATA & en_state != RW_DATA) begin
        wr_counter <= 1'b0;
    end
end

//always @(posedge clk)begin
//    if(reset) begin
//        s_axis_s2mm_tlast_reg <= 0;
//    end
//    else if(gen_state == WR_DATA & (wr_counter == (cur_size-1)) & s_axis_s2mm_tready) begin
//        s_axis_s2mm_tlast_reg <= 1;
//    end
//    else if(s_axis_s2mm_tready) begin
//        s_axis_s2mm_tlast_reg <= 0;
//    end
//end

always @(posedge clk)begin
    if(reset) begin
        rd_counter <= 0;
    end
    else if(gen_state == RD_DATA & m_axis_mm2s_tready_reg & m_axis_mm2s_tvalid) begin
        rd_counter <= rd_counter + 1'b1;
    end
    else if(gen_state == RW_DATA & m_axis_mm2s_tready_reg & m_axis_mm2s_tvalid) begin
        rd_counter <= rd_counter + 1'b1;
    end
    else if(gen_state != RD_DATA & gen_state != RW_DATA) begin
        rd_counter <= 0;
    end
end
always @(posedge clk)begin
    if(reset) begin
        m_axis_mm2s_tready_reg <= 0;
    end
    else if ((gen_state == RD_DATA)| (gen_state == RD_CMD & s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)) begin
        m_axis_mm2s_tready_reg <= 1;
    end
    else if ((gen_state == RW_DATA)| (gen_state == RW_CMD & s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)) begin
        m_axis_mm2s_tready_reg <= 1;
    end
    else begin
        m_axis_mm2s_tready_reg <= 0;
    end
end
always @(gen_state or wr_counter or rd_counter  or s_axis_mm2s_cmd_tvalid_reg or s_axis_mm2s_cmd_tready or s_axis_s2mm_cmd_tvalid_reg or s_axis_s2mm_cmd_tready or m_axis_mm2s_tlast or out_axis_tready or write_ready_reg or init_write or read_ready or wr_cmd_counter or rd_cmd_counter or wr_cmd_stop or rd_cmd_stop)
begin
   next_gen_state = gen_state;
   case (gen_state)
      IDLE : begin
        if (init_write & out_axis_tready & write_ready_reg & read_ready) begin
          next_gen_state = RW_CMD;
        end
        else if (init_write & write_ready_reg) begin
            next_gen_state = WR_CMD;
        end
        else if (out_axis_tready & read_ready) begin
            next_gen_state = RD_CMD;
         end
      end
      RW_CMD : begin
        if (wr_cmd_stop & rd_cmd_stop)
            next_gen_state = RW_DATA;
      end
      RW_DATA : begin
         if (wr_counter == cur_size)
            next_gen_state = IDLE;
      end
      WR_CMD : begin
        if (&wr_cmd_counter)
            next_gen_state = WR_DATA;
      end
      WR_DATA : begin
         if (wr_counter == cur_size)
            next_gen_state = IDLE;
      end
      RD_CMD : begin
         if (s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready)
            next_gen_state = RD_DATA;
      end
      RD_DATA : begin
        if (out_axis_tready & m_axis_mm2s_tlast)
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

assign write_cmd_stop = ((gen_state == WR_CMD | gen_state == RW_CMD) & (&wr_cmd_counter));
assign read_cmd_stop = ((gen_state == RD_CMD | gen_state == RW_CMD) & (s_axis_mm2s_cmd_tvalid_reg & s_axis_mm2s_cmd_tready));

assign read_ready = read_ready_reg & written;
assign write_ready = write_ready_reg;
assign out_size = cur_size;

assign s_axis_s2mm_tvalid = (gen_state == WR_DATA | gen_state == RW_DATA)? in_axis_tvalid : 0;
assign s_axis_s2mm_tdata = in_axis_tdata;
assign s_axis_s2mm_tkeep = in_axis_tkeep;
assign s_axis_s2mm_tlast = in_axis_tlast;
assign in_axis_tready = (gen_state == WR_DATA | gen_state == RW_DATA)? s_axis_s2mm_tready : 0;

assign out_axis_tvalid = (gen_state == RD_DATA | gen_state == RW_DATA)? m_axis_mm2s_tvalid : 0;
assign out_axis_tdata = m_axis_mm2s_tdata;
assign out_axis_tkeep = m_axis_mm2s_tkeep;
assign out_axis_tlast = m_axis_mm2s_tlast;
assign m_axis_mm2s_tready = (gen_state == RD_DATA | gen_state == RW_DATA)? out_axis_tready : 0;


//assign m_axis_mm2s_tready = m_axis_mm2s_tready_reg;
assign m_axis_mm2s_sts_tready =  m_axis_mm2s_sts_tready_reg;
assign m_axis_s2mm_sts_tready = m_axis_s2mm_sts_tready_reg;

assign s_axis_mm2s_cmd_tdata = s_axis_mm2s_cmd_tdata_reg;
assign s_axis_mm2s_cmd_tvalid = s_axis_mm2s_cmd_tvalid_reg;
assign s_axis_s2mm_cmd_tdata = s_axis_s2mm_cmd_tdata_reg; //{RSVD(4b),TAG(4b),SADDR(32b),DRR(1b),EOF(1b),DSA(6b),Type(1b),BTT(23b)}
assign s_axis_s2mm_cmd_tvalid = s_axis_s2mm_cmd_tvalid_reg;

// assign s_axis_s2mm_tdata = s_axis_s2mm_tdata_reg;
// assign s_axis_s2mm_tkeep = s_axis_s2mm_tkeep_reg;
// assign s_axis_s2mm_tlast = s_axis_s2mm_tlast_reg;
// assign s_axis_s2mm_tvalid = s_axis_s2mm_tvalid_reg;

 //   design_1 design_1_i (
 bram_stream_wrapper bram_stream_wrapper_inst(
         .m_axis_mm2s_sts_tdata(m_axis_mm2s_sts_tdata),
         .m_axis_mm2s_sts_tkeep(m_axis_mm2s_sts_tkeep),
         .m_axis_mm2s_sts_tlast(m_axis_mm2s_sts_tlast),
         .m_axis_mm2s_sts_tready(m_axis_mm2s_sts_tready),
         .m_axis_mm2s_sts_tvalid(m_axis_mm2s_sts_tvalid),
         .m_axis_mm2s_tdata(m_axis_mm2s_tdata),
         .m_axis_mm2s_tkeep(m_axis_mm2s_tkeep),
         .m_axis_mm2s_tlast(m_axis_mm2s_tlast),
         .m_axis_mm2s_tready(m_axis_mm2s_tready),
         .m_axis_mm2s_tvalid(m_axis_mm2s_tvalid),
         .m_axis_s2mm_sts_tdata(m_axis_s2mm_sts_tdata),
         .m_axis_s2mm_sts_tkeep(m_axis_s2mm_sts_tkeep),
         .m_axis_s2mm_sts_tlast(m_axis_s2mm_sts_tlast),
         .m_axis_s2mm_sts_tready(m_axis_s2mm_sts_tready),
         .m_axis_s2mm_sts_tvalid(m_axis_s2mm_sts_tvalid),
         .s_axis_mm2s_cmd_tdata(s_axis_mm2s_cmd_tdata),
         .s_axis_mm2s_cmd_tready(s_axis_mm2s_cmd_tready),
         .s_axis_mm2s_cmd_tvalid(s_axis_mm2s_cmd_tvalid),
         .s_axis_s2mm_cmd_tdata(s_axis_s2mm_cmd_tdata),
         .s_axis_s2mm_cmd_tready(s_axis_s2mm_cmd_tready),
         .s_axis_s2mm_cmd_tvalid(s_axis_s2mm_cmd_tvalid),
         .s_axis_s2mm_tdata(s_axis_s2mm_tdata),
         .s_axis_s2mm_tkeep(s_axis_s2mm_tkeep),
         .s_axis_s2mm_tlast(s_axis_s2mm_tlast),
         .s_axis_s2mm_tready(s_axis_s2mm_tready),
         .s_axis_s2mm_tvalid(s_axis_s2mm_tvalid),
         .aresetn(!reset),
         .clk(clk),
         .mm2s_err(mm2s_err),
         .s2mm_err(s2mm_err)
     );


endmodule
