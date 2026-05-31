/*
tb_aes_top.v - AES-128 testbench

	Reads plaintext, key, and expected ciphertext from .txt files
	Runs all test vectors and reporting PASS/FAIL
	
	Vector sources:
		Tests  1-21 : Fixed plaintext (all-zero), varying key
		Tests 22-42 : Fixed key (all-zero), varying plaintext
		Tests 43-63 : Fixed plaintext (all-zero), varying key
		
	Files:
		tb/pt_vectors.txt	 - 63 x 128-bit plaintext values
		tb/key_vectors.txt - 63 x 128-bit key values
		tb/ct_vectors.txt	 - 63 x 128-bit ciphertext values
	
	Andrea Lee Mei Jin 		34367047
	Elisa Naily Mohd Yazid 	33590745
	
*/

`timescale 1ns/1ps

module tb_aes_top;

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
	
	// Test vectors
	parameter NUM_VECTORS = 63;				// hardcoded
	reg [127:0] test_pt [0:NUM_VECTORS-1];
	reg [127:0] test_key [0:NUM_VECTORS-1];
	reg [127:0] test_ct [0:NUM_VECTORS-1];
	
	// Counters
	integer i;
	integer pass_count;
	integer fail_count;
	integer timeout;
	
	
	// Task to run a vector
	task run_vector;
		input integer idx;
		begin
			// Apply inputs
			@(negedge clk);
			plaintext = test_pt[idx];
			key = test_key[idx];
			start = 1'b1;
			
			@(negedge clk);
			start = 1'b0;
			
			// Wait for done with timeout
			timeout = 0;
			while (!done && timeout < 50) begin
				@(posedge clk);
				timeout = timeout + 1;
			end
			
			// Allow outputs to settle
			@(negedge clk);
			
			// Check outputs
			if (ciphertext == test_ct[idx]) begin
				$display("TEST %02d PASS: pt=%032h key=%032h ct=%032h", idx+1, test_pt[idx], test_key[idx], ciphertext);
				pass_count = pass_count + 1;
			end else begin
				$display("[TEST#%02d] FAIL: pt=%032h key=%032h", idx+1, test_pt[idx], test_key[idx]);
				$display("Expected: %032h, Got: %032h", test_ct[idx], ciphertext);
				fail_count = fail_count + 1;
			end
			
			repeat (3) @(posedge clk);
			
		end
		
	endtask
	
	
	// Start the testbench
	initial begin
		
		// Load vectors
		$readmemh("tb/pt_vectors.txt", test_pt);
		$readmemh("tb/key_vectors.txt", test_key);
		$readmemh("tb/ct_vectors.txt", test_ct);
		
		// Initialise
		rst_n = 1'b0;
		start = 1'b0;
		plaintext = 128'b0;
		key = 128'b0;
		pass_count = 0;
		fail_count = 0;
		
		// Hold reset for 4 cycles
		repeat (4) @(posedge clk);
		@(negedge clk);
		rst_n = 1'b1;
		
		
		$display("==========================================================================");
		$display("AES-128 Encryption Testbench");
		$display("==========================================================================");
		$display("Tests 1-21: Fixed plaintext (all-zero), varying key");
		$display("Tests 22-42: Fixed key (all-zero), varying plaintext");
		$display("Tests 43-63: Fixed plaintext (all-zero), varying key");
		$display("--------------------------------------------------------------------------");
		
		
		// Run all vectors
		for (i = 0; i < NUM_VECTORS; i = i + 1) begin
			run_vector(i);
		end
		
		$display("--------------------------------------------------------------------------");
		$display("[SUMMARY] Total: %0d/%0d tests passed", pass_count, NUM_VECTORS);
		
		if (fail_count == 0)
			$display("ALL TESTS PASSED");
		else
			$display("%0d TEST(S) FAILED", fail_count);
			
		$display("==========================================================================");
		
		$finish;
		
	end
	
	
	// Waveform dump
	initial begin
        $dumpfile("sim/aes_top_sim.vcd");
        $dumpvars(0, tb_aes_top);
    end
	 
	 
endmodule