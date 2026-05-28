/*
aes_round.v - Single AES-128 round datapath

	Performs one full AES round: SubBytes -> ShiftRows -> [MixColumns] -> AddRoundKey
	Set a flag to skip MixColumns at round 10
	
	Andrea Lee Mei Jin 		34367047
	Elisa Naily Mohd Yazid 	33590745
	
*/

module aes_round (
	input wire [127:0] state_in,
	input wire [127:0] round_key,
	input wire is_final_round,
	output wire [127:0] state_out
);

	wire [127:0] after_sb;
	wire [127:0] after_sr;
	wire [127:0] after_mc;
	
	sub_bytes sb_inst (
		.state_in(state_in),
		.state_out(after_sb)
	);
	
	shift_rows sr_inst (
		.state_in(after_sb),
		.state_out(after_sr)
	);
	
	mix_columns mc_inst (
		.state_in(after_sr),
		.state_out(after_mc)
	);
	
	// Final round bypass MixColumns
	wire [127:0] before_ark = is_final_round ? after_sr : after_mc;
	
	// AddRoundKey
	assign state_out = before_ark ^ round_key;
	
	
endmodule
		
	