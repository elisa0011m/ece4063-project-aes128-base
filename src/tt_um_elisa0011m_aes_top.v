/*
tt_um_elisa0011m_aes_top.v - AES-128 (TinyTapeout, on-the-fly key schedule)

    Key schedule change: replaces key_expansion (1407-bit precomputed bus)
    with key_schedule (128-bit on-the-fly derivation, one round key per cycle).
    All ports and serial protocol unchanged.

    Internal key timing:
        S_IDLE  + start : state    <= pt_reg ^ key_reg  (AddRoundKey, RK0)
                          crk      <= key_reg            (seed for RK1)
                          round_num <= 1
        S_ROUND cycle N : next_key  = key_schedule(crk, round_num)  [comb]
                          aes_round uses next_key as round_key
                          crk      <= next_key
                          round_num <= round_num + 1

    Andrea Lee Mei Jin      34367047
    Elisa Naily Mohd Yazid  33590745
*/
`timescale 1ns/1ps
module tt_um_elisa0011m_aes_top (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire [7:0] data_in   = ui_in;
    wire       load_key  = uio_in[0];
    wire       load_pt   = uio_in[1];
    wire       start     = uio_in[2];
    wire       out_shift = uio_in[3];

    wire       busy;
    wire       done;
    wire [7:0] data_out;

    assign uo_out  = data_out;
    assign uio_out = {2'b00, done, busy, 4'b0000};
    assign uio_oe  = 8'hF0;

    // input shift register
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

    // on-the-fly key schedule
    reg  [127:0] current_round_key;
    wire [127:0] next_key;

    key_schedule ks_inst (
        .current_key (current_round_key),
        .round_num   (round_num),
        .next_key    (next_key)
    );

    // round datapath
    reg  [127:0] state;
    reg  [3:0]   round_num;

    wire         is_final        = (round_num == 4'd10);
    wire [127:0] round_state_out;

    aes_round round_inst (
        .state_in       (state),
        .round_key      (next_key),       // was rk(round_num) from precomputed bus
        .is_final_round (is_final),
        .state_out      (round_state_out)
    );


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
            state_fsm         <= S_IDLE;
            busy_r            <= 1'b0;
            done_r            <= 1'b0;
            state             <= 128'b0;
            round_num         <= 4'd0;
            current_round_key <= 128'b0;

        end else begin
            done_r <= 1'b0;

            case (state_fsm)

                S_IDLE: begin
                    busy_r <= 1'b0;
                    if (start) begin
                        // AddRoundKey with RK0 (original key) directly
                        state             <= pt_reg ^ key_reg;
                        current_round_key <= key_reg;
                        round_num         <= 4'd1;
                        busy_r            <= 1'b1;
                        state_fsm         <= S_ROUND;
                    end
                end

                S_ROUND: begin
                    // next_key (combinational) = key_schedule(current_round_key, round_num)
                    // aes_round already consumed next_key this cycle
                    state             <= round_state_out;
                    current_round_key <= next_key;      // advance key for next round

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

    // serial ciphertext output
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
                data_out_r <= state[127:120];
            end else if (out_shift) begin
                out_idx    <= out_idx + 4'd1;
                data_out_r <= (state >> (120 - 8*out_idx)) & 8'hFF;
            end
        end
    end


endmodule