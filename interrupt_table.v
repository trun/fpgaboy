`default_nettype none
`timescale 1ns / 1ps

module interrupt_table(
	input  wire        clock,
	input  wire  [3:0] A,
	output reg   [7:0] Do
);

	always @(posedge clock)
	begin
		case (A)
			4'h0: Do <= 8'h40; // V-Blank
			4'h1: Do <= 8'h00;
			4'h2: Do <= 8'h48; // LCD STAT
			4'h3: Do <= 8'h00;
			4'h4: Do <= 8'h50; // Timer
			4'h5: Do <= 8'h00;
			4'h6: Do <= 8'h58; // Serial
			4'h7: Do <= 8'h00;
			4'h8: Do <= 8'h60; // Joypad
			4'h9: Do <= 8'h00;
			default: Do <= 8'h00;
		endcase
	end

endmodule
