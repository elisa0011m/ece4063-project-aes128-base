/*

key_schedule.v - AES-128 key schedule
	
	Generates a single round key on demand given the original key and round number
		
	Authors:
		Andrea Lee Mei Jin 		34367047
		Elisa Naily Mohd Yazid 	33590745
	
*/

module key_schedule (
	input wire [127:0] current_key,
	input wire [3:0] round_num,
	output wire [127:0] next_key
);

	
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
	
	
	// RotWord
	function [31:0] rotword;
		input [31:0] w;
		begin
			rotword = {w[23:0], w[31:24]};
		end
	endfunction
	
	
	// Expanded key words
	wire [31:0] w0, w1, w2, w3;

	// Initial key words
	assign w0 = current_key[127:96];
   assign w1 = current_key[95:64];
   assign w2 = current_key[63:32];
   assign w3 = current_key[31:0];
	
	
	wire [31:0] rot;
	assign rot = rotword(w3);
	
	wire [7:0] sw0, sw1, sw2, sw3;
	sbox sw0_inst (.in(rot[31:24]), .out(sw0));
	sbox sw1_inst (.in(rot[23:16]), .out(sw1));
	sbox sw2_inst (.in(rot[15:8]), .out(sw2));
	sbox sw3_inst (.in(rot[7:0]), .out(sw3));
	
	wire [31:0] subrot;
	assign subrot = {sw0, sw1, sw2, sw3};
	
	wire [31:0] t0, t1, t2, t3;
	
	assign t0 = w0 ^ subrot ^ rcon(round_num);
	assign t1 = w1 ^ t0;
	assign t2 = w2 ^ t1;
	assign t3 = w3 ^ t2;
	
	assign next_key = {t0, t1, t2, t3};

endmodule

	