# ============================================================
# run.do  –  ModelSim script for full 63-vector testbench
# ============================================================
# Run from project root:
#   vsim -do sim/run.do

vlib work
vmap work work

# Compile RTL (bottom of hierarchy first)
vlog -work work rtl/sbox.v
vlog -work work rtl/sub_bytes.v
vlog -work work rtl/shift_rows.v
vlog -work work rtl/mix_columns.v
vlog -work work rtl/key_expansion.v
vlog -work work rtl/aes_round.v
vlog -work work rtl/aes_top.v

# Compile testbench
vlog -work work tb/tb_aes_top.v

# Start simulation
vsim -t 1ns -novopt work.tb_aes_top

# Add signals to wave window
add wave -divider "Control"
add wave -radix bin      /tb_aes_top/clk
add wave -radix bin      /tb_aes_top/rst_n
add wave -radix bin      /tb_aes_top/start
add wave -radix bin      /tb_aes_top/busy
add wave -radix bin      /tb_aes_top/done

add wave -divider "Data"
add wave -radix hex      /tb_aes_top/plaintext
add wave -radix hex      /tb_aes_top/key
add wave -radix hex      /tb_aes_top/ciphertext

add wave -divider "Internal"
add wave -radix hex      /tb_aes_top/dut/state
add wave -radix unsigned /tb_aes_top/dut/round_num
add wave -radix unsigned /tb_aes_top/dut/state_fsm

# Run all
run -all

quit -sim
