`ifdef SIM
`default_nettype none
`endif

module pulse_mem #(
	parameter integer AWIDTH = 12,
    parameter integer DWIDTH = 32
)(
	input  wire [AWIDTH-1:0] rd_addr,
	output reg  [DWIDTH-1:0] rd_data,
	input  wire rd_ena,

	input  wire [AWIDTH-1:0] wr_addr,
	input  wire [DWIDTH-1:0] wr_data,
	input  wire wr_ena,

	input  wire clk,
	input  wire rst
);

	// Signals
	reg [DWIDTH-1:0] ram [(1<<AWIDTH)-1:0];
	reg [DWIDTH-1:0] rd_data_r;
	reg rd_ena_r;

`ifdef SIM
	integer i;
	initial
		for (i=0; i<(1<<AWIDTH); i=i+1)
			ram[i] = 0;
`endif

	always @(posedge clk)
	begin
		// Read
		rd_data_r <= ram[rd_addr];

		// Write
		if (wr_ena)
			ram[wr_addr] <= wr_data;

		// Register the enable flag
		rd_ena_r <= rd_ena;

		// Final read register
		if (rd_ena_r)
			rd_data <= rd_data_r;
		else
			rd_data <= 0;
	end

endmodule // pulse_mem
