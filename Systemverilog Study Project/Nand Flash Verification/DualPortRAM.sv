`include "definitions.sv"


`timescale 1ns / 1fs

module ebr_buffer
(
	input [7:0] data_a, data_b,
	input [10:0] addr_a, addr_b,
	input we_a, we_b, clk,
	input reset_a, reset_b,// take care later
	input clk_en_a, clk_en_b, // check
	output [7:0] OutA, OutB
	);
	// Declare the RAM variable
	reg [7:0] ram[2047:0];
	
	reg [7:0] q_a, q_b;
	
	assign OutA = q_a;
	assign OutB = q_b;
	
	// Port A
	always_ff @ (posedge clk)
	begin
	if(clk_en_a)
	begin
		if (we_a) 
		begin
			ram[addr_a] <= data_a;
			q_a <= data_a;
			 //$display ($time, ": written to mem[%0d] = %0d", addr_a, data_a); // ***

		end
		else 
		begin
			q_a <= ram[addr_a];
			 //$display ($time, ": read from mem[%0d] = %0d", addr_a, ram[addr_a]); // ***

		end
	end
	end
	
	// Port B
	always_ff @ (posedge clk)
	begin
	if (clk_en_b)
	begin
	if (we_b)
		begin
			ram[addr_b] <= data_b;
			q_b <= data_b;
		end
		else
		begin
			q_b <= ram[addr_b];
		end
	end
	end
	    
	
endmodule