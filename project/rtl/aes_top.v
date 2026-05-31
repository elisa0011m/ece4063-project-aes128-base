/*
aes_top.v - AES-128 Encryption Core (top level)
	
	Architecture:
		Iterative one-cycle implementation
		One encryption round executed per clock cycle
		Sequential key expansion (generated each round)
		Start/ busy/done handshake interface
	
	Operation:
		1. On start, plaintext and key are loaded
		2. Initial AddRoundKey is applied immediately
		3. Rounds 1-9 perform SB -> SR -> MC -> ARK
		4. Round 10 perform SB -> SR -> ARK
		5. Ciphertext is produced and done is asserted
	
	Timing:
		Cycle 0	 	: start=1, plaintext and key loaded, initial AddRoundKey
		Cycle 1-10	: Rounds 1-10
		Cycle 11	 	: done=1, ciphertext valid
		
	Performance:
		Throughput	: 1 block every 11 clock cycles
		Latency		: 11 clock cycles from start to done
		Key size	 	: 128 bits
		Block size	: 128 bits
	
	Authors:
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


	// Internal registers
	reg [127:0] state;
	reg [127:0] current_key;
	reg [3:0] round_num;
	
	
	// Key schedule
	wire [127:0] next_rk;
	key_schedule key_sched_inst (
		.current_key(current_key),
		.round_num(round_num),
		.next_key(next_rk)
	);
	
	
	// Round datapath
	wire is_final;
	assign is_final = (round_num == 4'd10);
	wire [127:0] round_state_out;
	
	aes_round round_inst (
		.state_in(state),
		.round_key(next_rk),
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
			current_key <= 128'b0;
			round_num <= 4'd0;
			
		end else begin
			// Default deassert
			done <= 1'b0;
			
			case (state_fsm)
			
				S_IDLE: begin
				
					busy <= 1'b0;
					
					if (start) begin
						// Apply initial AddRoundKey immediately
						state <= plaintext ^ key;
						current_key <= key;
						round_num <= 4'd1;
						busy <= 1'b1;
						state_fsm <= S_ROUND;
						
					end
				end
				
				
				S_ROUND: begin
					// Apply round datapath result
					state <= round_state_out;
					current_key <= next_rk;
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
		
 
      