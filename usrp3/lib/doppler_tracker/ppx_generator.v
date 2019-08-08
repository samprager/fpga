// Company:MiXIL
// Engineer: Samuel Prager
//
// Create Date: 08/08/19:29:14 PM
// Design Name:
// Module Name: ppx_generator
// Project Name:
// Target Devices:
// Tool Versions:
// Description:
//  Simple pulse generator for arbitrary count. Used to generate A pulse per X seconds (ppx).
//
//  For example:
//    - to generate pulse /sec (1 Hz) xcount = clk_freq
//    - to generate 20 pulse /sec (20 Hz) xcount = clk_freq/20
//    - to generate with a 25% duty cycle, .25=1/4 -> xduty_log2 = log2(4) = 2
//    - to generate single clock width pulse, set xduty_log2 = 0

// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

module ppx_generator #(
   parameter CLK_FREQ  = 32'd10_000_000, //Min:10kHz, Max:4GHz
) (
   input  clk,
   input  reset,
   input [31:0] xcount,
   input [4:0] xduty_log2,

   output ppx
);
    reg [31:0] count;
    wire [31:0] count_max;

    always @(posedge clk) begin
        if (reset) begin
            count <= 32'd0;
        end else if (count >= (count_max - 1)) begin
            count <= 32'd0;
        end else begin
            count <= count + 32'd1;
        end
    end

    assign count_max = (xcount==0) ? CLK_FREQ : xcount;

    assign ppx = (xduty_log2==0) ? ((count==0) & (count_max>0)) : (count < (count_max >> xduty_log2));

endmodule //ppx_generator
