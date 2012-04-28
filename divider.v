`default_nettype none
`timescale 1ns / 1ps

module divider #(parameter DELAY=27000000) (
	input wire reset,
	input wire clock,
	output wire enable);
	
	reg[24:0] count;
	wire[24:0] next_count;

	always @(posedge clock)
	begin
		if (reset)
			count <= 0;
		else
			count <= next_count;
	end
	
	assign enable = (count == DELAY - 1) ? 1 : 0;
	assign next_count = (count == DELAY - 1) ? 0 : count + 1;

endmodule
