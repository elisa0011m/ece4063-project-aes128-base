/*

sub_bytes.v - AES-128 SubBytes transformation
	
	Applies the S-box independently to all 16 bytes of the state
	State is represented as a flat 128-bit bus, MSB is byte 0
	
	Andrea Lee Mei Jin 		34367047
	Elisa Naily Mohd Yazid 	33590745
	
*/

module sub_bytes (
	input wire [127:0] state_in,
	output wire [127:0] state_out
);


	genvar i;
	generate
		for (i = 0; i < 16; i = i + 1) begin: sb_loop
			sbox sbox_inst(
				.in (state_in[(127 - i*8) -: 8]),	// i=0, [127-:8] = [127:119]
				.out (state_out[(127 - i*8) -: 8])
			);
		end
	endgenerate
	
endmodule
		