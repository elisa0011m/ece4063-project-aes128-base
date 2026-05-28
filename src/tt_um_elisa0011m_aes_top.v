/*
aes_top.v - AES-128 Encryption Core (TinyTapeout top level)

    Architecture: Iterative, one round per clock cycle
    Interface   : TinyTapeout standard port map with byte-serial
                  load/unload for plaintext, key, and ciphertext

    Pin mapping:
        ui_in[7:0]  - data_in    : byte to shift in (key or plaintext)
        uio_in[0]   - load_key   : pulse high each cycle to shift a key byte
        uio_in[1]   - load_pt    : pulse high each cycle to shift a plaintext byte
        uio_in[2]   - start      : high for one cycle to begin encryption
        uio_in[3]   - out_shift  : pulse high to advance to next output byte
        uio_oe      - 8'hF0      : lower nibble input, upper nibble output
        uio_out[4]  - busy       : high while encryption is in progress
        uio_out[5]  - done       : high for one cycle when ciphertext is valid
        uo_out[7:0] - data_out   : current ciphertext output byte (MSB-first)

    Serial protocol:
        1. Pulse load_key=1 for 16 cycles, presenting key bytes MSB-first
        2. Pulse load_pt=1  for 16 cycles, presenting plaintext bytes MSB-first
        3. Pulse start=1 for one cycle to begin encryption
        4. Wait for done=1, then pulse out_shift=1 for 15 cycles to read
           remaining ciphertext bytes (first byte is valid on the done cycle)

    Timing (encryption, unchanged):
        Cycle 0    : start=1, load plaintext and key
        Cycle 1    : Initial AddRoundKey (RK0)
        Cycles 2-10: Main rounds 1-9
        Cycle 11   : Final round 10 (no MixColumns)
        Cycle 12   : done=1, ciphertext valid

    Total encryption latency: 12 clock cycles after start

    Andrea Lee Mei Jin      34367047
    Elisa Naily Mohd Yazid  33590745

*/
`timescale 1ns/1ps
module tt_um_elisa0011m_aes_top (
    input  wire [7:0] ui_in,    // data_in[7:0]
    output wire [7:0] uo_out,   // data_out[7:0]
    input  wire [7:0] uio_in,   // [0]=load_key [1]=load_pt [2]=start [3]=out_shift
    output wire [7:0] uio_out,  // [4]=busy [5]=done
    output wire [7:0] uio_oe,   // [3:0]=0 (input), [7:4]=1 (output)
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // ----------------------------------------------------------------
    // Pin mapping
    // ----------------------------------------------------------------

    wire [7:0] data_in   = ui_in;
    wire       load_key  = uio_in[0];
    wire       load_pt   = uio_in[1];
    wire       start     = uio_in[2];
    wire       out_shift = uio_in[3];

    wire       busy;
    wire       done;
    wire [7:0] data_out;

    assign uo_out      = data_out;
    assign uio_out     = {2'b00, done, busy, 4'b0000};  // [5]=done [4]=busy
    assign uio_oe      = 8'hF0;                          // upper nibble out, lower in


    // ----------------------------------------------------------------
    // Serial input shift registers
    // Shift in MSB-first: after 16 pulses the first byte sent is at [127:120]
    // ----------------------------------------------------------------

    reg [127:0] key_reg;
    reg [127:0] pt_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg <= 128'b0;
            pt_reg  <= 128'b0;
        end else begin
            if (load_key) key_reg <= {key_reg[119:0], data_in};
            if (load_pt)  pt_reg  <= {pt_reg[119:0],  data_in};
        end
    end


    // ----------------------------------------------------------------
    // Key schedule (driven from key_reg)
    // ----------------------------------------------------------------

    wire [1407:0] round_keys;
    key_expansion key_exp_inst (
        .key(key_reg),
        .round_keys(round_keys)
    );


    // Extract round key N
    function [127:0] rk;
        input [3:0] n;
        begin
            rk = round_keys[1407 - n*128 -: 128];
        end
    endfunction


    // ----------------------------------------------------------------
    // Round datapath (unchanged)
    // ----------------------------------------------------------------

    reg  [127:0] state;
    reg  [3:0]   round_num;

    wire [127:0] round_key_in    = rk(round_num);
    wire         is_final        = (round_num == 4'd10);
    wire [127:0] round_state_out;

    aes_round round_inst (
        .state_in       (state),
        .round_key      (round_key_in),
        .is_final_round (is_final),
        .state_out      (round_state_out)
    );


    // ----------------------------------------------------------------
    // FSM (unchanged — identical to original S_IDLE/S_ROUND structure)
    // ----------------------------------------------------------------

    localparam [1:0]
        S_IDLE  = 2'd0,
        S_ROUND = 2'd1;

    reg [1:0] state_fsm;
    reg       busy_r;
    reg       done_r;

    assign busy = busy_r;
    assign done = done_r;

    always @(posedge clk) begin
        if (!rst_n) begin
            state_fsm <= S_IDLE;
            busy_r    <= 1'b0;
            done_r    <= 1'b0;
            state     <= 128'b0;
            round_num <= 4'd0;

        end else begin
            done_r <= 1'b0;

            case (state_fsm)

                S_IDLE: begin
                    busy_r <= 1'b0;
                    if (start) begin
                        state     <= pt_reg ^ rk(4'd0);
                        round_num <= 4'd1;
                        busy_r    <= 1'b1;
                        state_fsm <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    state <= round_state_out;
                    if (round_num == 4'd10) begin
                        done_r    <= 1'b1;
                        busy_r    <= 1'b0;
                        state_fsm <= S_IDLE;
                    end else begin
                        round_num <= round_num + 4'd1;
                    end
                end

                default: state_fsm <= S_IDLE;

            endcase
        end
    end


    // ----------------------------------------------------------------
    // Serial ciphertext output
    // First byte presented on data_out the same cycle done fires.
    // Each out_shift pulse advances by one byte (15 pulses for all 16).
    // ----------------------------------------------------------------

    reg [3:0]  out_idx;
    reg [7:0]  data_out_r;

    assign data_out = data_out_r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_idx    <= 4'd0;
            data_out_r <= 8'b0;
        end else begin
            if (done_r) begin
                out_idx    <= 4'd1;
                data_out_r <= round_state_out[127:120];
            end else if (out_shift) begin
                out_idx    <= out_idx + 4'd1;
                data_out_r <= (state >> (120 - 8*out_idx)) & 8'hFF;
            end
        end
    end


endmodule