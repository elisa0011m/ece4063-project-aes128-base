/*
aes_top.v - AES-128 Encryption Core (top level)
	
	Architecture: Iterative, one round per clock cycle
	Interface	: Start/busy/done flags handshake
	
	Timing:
		Cycle 0		: start=1, load the plaintext and key
		Cycle 1		: Initial AddRoundKey (RK0)
		Cycles 2..10: Main rounds 1-9
		Cycle 11		: Final round 10 (no MixColumns)
		Cycle 12		: done=1, ciphertext valid
		
	Total latency: 12 clock cycles after start
	
	Andrea Lee Mei Jin 		34367047
	Elisa Naily Mohd Yazid 	33590745
	
*/


`timescale 1ns/1ps

module aes_top (
	input wire clk,
	input wire rst_n,
	
	// Control signals
	input wire start,		// high for one cycle to begin
	output reg busy,		// high while encryption is in progress
	output reg done,		// high for one cycle when ciphertext is valid
	
	// Data
	input wire [127:0] plaintext,
	input wire [127:0] key,
	output reg [127:0] ciphertext
	
);


	// Key schedule
	wire [1407:0] round_keys;
	key_expansion key_exp_inst (
		.key(key),
		.round_keys(round_keys)
	);
	
	
	// Extract round key N
	function [127:0] rk;
		input [3:0] n;
		begin
			rk = round_keys[1407 - n*128 -: 128];
		end
	endfunction
	
	
	
	// Round datapath
	
	reg [127:0] state;
	reg [3:0] round_num;
	
	wire [127:0] round_key_in = rk(round_num);
	wire is_final = (round_num == 4'd10);
	wire [127:0] round_state_out;
	
	aes_round round_inst (
		.state_in(state),
		.round_key(round_key_in),
		.is_final_round(is_final),
		.state_out(round_state_out)
	);
	
	
	
	// FSM
	
	localparam [1:0]
		S_IDLE = 2'd0,			// wait for start
		S_ROUND = 2'd1;		// iterating through rounds
	
	reg [1:0] state_fsm;
	
	
	always @(posedge clk) begin
		if (!rst_n) begin
			state_fsm <= S_IDLE;
			busy <= 1'b0;
			done <= 1'b0;
			ciphertext <= 128'b0;
			state <= 128'b0;
			round_num <= 4'd0;
			
		end else begin
			// Default deassert
			done <= 1'b0;
			
			case (state_fsm)
			
				S_IDLE: begin
				
					busy <= 1'b0;
					
					if (start) begin
						// Apply initial AddRoundKey immediately
						state <= plaintext ^ rk(4'd0);
						round_num <= 4'd1;
						busy <= 1'b1;
						state_fsm <= S_ROUND;
						
					end
				end
				
				
				S_ROUND: begin
					// Apply round datapath result
					state <= round_state_out;
					
					// Final round just completed
					if (round_num == 4'd10) begin
						ciphertext <= round_state_out;
						done <= 1'b1;
						busy <= 1'b0;
						state_fsm <= S_IDLE;
					
					end else begin
						round_num <= round_num + 4'd1;
					end
				end
				
				default: state_fsm <= S_IDLE;
				
			endcase
			
		end
		
	end
	
endmodule		
		
 
       