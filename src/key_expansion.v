/*

key_expansion.v - AES-128 Key schedule
	
	Generates all 11 round keys from the 128-bit cipherkey
	Output is a flat 1408-bit bus:
		round_keys[1407:1280] = RK0 (original key)
		round_keys[1279:1152] = RK1
		...
		round_keys[127:0]		 = RK10
		
	Andrea Lee Mei Jin 		34367047
	Elisa Naily Mohd Yazid 	33590745
	
*/

module key_expansion (
	input wire [127:0] key,
	output wire [1407:0] round_keys	// 11 x 128
);

	
	// Rcon table for all rounds
	function [31:0] rcon;
		input [3:0] round;
		begin
			case (round)
				4'd1: rcon = 32'h01000000;
				4'd2: rcon = 32'h02000000;
				4'd3: rcon = 32'h04000000;
				4'd4: rcon = 32'h08000000;
				4'd5: rcon = 32'h10000000;
				4'd6: rcon = 32'h20000000;
				4'd7: rcon = 32'h40000000;
				4'd8: rcon = 32'h80000000;
				4'd9: rcon = 32'h1b000000;
				4'd10: rcon = 32'h36000000;
				default: rcon = 32'h00000000;
			endcase
		end
	endfunction
	
	
	
	// RotWord left rotate a 32-bit word by 8 bits
	function [31:0] rotword;
		input [31:0] w;
		begin
			rotword = {w[23:0], w[31:24]};
		end
	endfunction
	
	
	// Expanded key words, 11 keys x 4 words
	wire [31:0] W [0:43];
	
	// First 4 are the original key words
	assign W[0] = key[127:96];
	assign W[1] = key[95:64];
	assign W[2] = key[63:32];
	assign W[3] = key[31:0];
	
	
	// SubWord
	// Only when the word is a multiple of 4
	// 10 words x 4 sbox (1 per byte) = 40 sbox instances
	genvar i;
	generate
		// Start at w4
		for (i = 4; i < 44; i = i + 1) begin: key_sched
		
			// Only if multiple of 4
			if (i % 4 == 0) begin: subword_sched
			
				// Apply RotWord to previous word
				wire [31:0] rot = rotword(W[i - 1]);
	
				// SubWord by instantiating 4 sbox modules on rotated words
				wire [7:0] sw0, sw1, sw2, sw3;
				sbox sw0_inst (.in(rot[31:24]), .out(sw0));
				sbox sw1_inst (.in(rot[23:16]), .out(sw1));
				sbox sw2_inst (.in(rot[15:8]), .out(sw2));
				sbox sw3_inst (.in(rot[7:0]), .out(sw3));
	
				// W[i] = W[i-4] ^ SubWord(RotWord(W[i-1])) ^ Rcon[i/4]
				assign W[i] = W[i-4] ^ {sw0, sw1, sw2, sw3} ^ rcon(i/4);
				
			end else begin: simple_sched
			
				// W[i] = W[i-4] ^ W[i-1]
				assign W[i] = W[i-4] ^ W[i-1];
				
			end
		end
	endgenerate
	
	
	
	// Pack round keys into flat 1408-bit bus
	genvar rk;
	generate 
		for (rk = 0; rk <= 10; rk = rk + 1) begin: rk_pack
			assign round_keys[1407 - rk*128 -: 128] = {W[rk*4], W[rk*4 + 1], W[rk*4 + 2], W[rk*4 +3]};
		end
	endgenerate
	
	
endmodule
				
				
				
	