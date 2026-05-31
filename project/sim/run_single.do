# ============================================================
# run_single.do – Interactive AES testbench
# ============================================================

vlib work
vmap work work

# Compile RTL
vlog -work work rtl/sbox.v
vlog -work work rtl/sub_bytes.v
vlog -work work rtl/shift_rows.v
vlog -work work rtl/mix_columns.v
vlog -work work rtl/key_expansion.v
vlog -work work rtl/aes_round.v
vlog -work work rtl/aes_top.v

# Compile single-input testbench
vlog -work work tb/tb_single_input.v

# Start simulation
vsim -t 1ns -novopt work.tb_single_input

# Waveforms
add wave -divider "Control"
add wave sim:/tb_single_input/clk
add wave sim:/tb_single_input/rst_n
add wave sim:/tb_single_input/start
add wave sim:/tb_single_input/busy
add wave sim:/tb_single_input/done

add wave -divider "Data"
add wave -radix hex sim:/tb_single_input/plaintext
add wave -radix hex sim:/tb_single_input/key
add wave -radix hex sim:/tb_single_input/ciphertext

add wave -divider "Internal"
add wave -radix hex sim:/tb_single_input/dut/state
add wave -radix unsigned sim:/tb_single_input/dut/round_num
add wave -radix unsigned sim:/tb_single_input/dut/state_fsm

# Run simulation
run -all