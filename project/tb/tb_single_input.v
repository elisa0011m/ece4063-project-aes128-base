/*
tb_single_input.v - AES-128 testbench for user defined input

	Authors:
		Andrea Lee Mei Jin 		34367047
		Elisa Naily Mohd Yazid 	33590745
	
*/

`timescale 1ns/1ps

module tb_single_input;

	// DUT signals
	reg clk;
	reg rst_n;
	reg start;
	reg [127:0] plaintext;
	reg [127:0] key;
	wire busy;
	wire done;
	wire [127:0] ciphertext;
	
	// DUT instantiation
	aes_top dut(
		.clk(clk),
		.rst_n(rst_n),
		.start(start),
		.busy(busy),
		.done(done),
		.plaintext(plaintext),
		.key(key),
		.ciphertext(ciphertext)
	);
	
	// Clock - 100 MHz, 10 ns
	initial clk = 0;
	always #5 clk = ~clk;
	
	
	integer timeout;
	
	
	// Start the testbench
	initial begin
		
		// Initialise
		rst_n = 1'b0;
		start = 1'b0;
		plaintext = 128'b0;
		key = 128'b0;
		
		// Hold reset for 4 cycles
		repeat (4) @(posedge clk);
		rst_n = 1'b1;
		
	
		plaintext = 128'h1b1b25c63fe7bfaa72473d02056474b7;
		key = 128'h240fbbd2040c38b101724abe1f97cac0;
		
		// Start encryption
		@(negedge clk);
		start = 1'b1;

      @(negedge clk);
      start = 1'b0;
		
		// Wait for completion
		timeout = 0;
		while (!done && timeout < 50) begin
			@(posedge clk);
			timeout = timeout + 1;
		end
			
			
		@(posedge clk);
		$display("plaintext: %h", plaintext);
		$display("key: %h", key);
		$display("ciphertext: %h", ciphertext);
		
		$finish;
		
	end
	
	 
endmodule