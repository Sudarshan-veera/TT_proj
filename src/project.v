`default_nettype none

module tt_um_anomaly_detector (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    assign uio_oe  = 8'b00000000;
    assign uio_out = 8'b00000000;

    // ── Pin map ──────────────────────────────────────────
    // uio_in[7]     hold_mode  : 1 = freeze sliding window
    // uio_in[6:5]   sens       : 00=50% 01=25% 10=12.5% 11=6.25%
    // uio_in[4]     nshot_mode : 0=one-shot  1=n-shot
    // uio_in[3:0]   alimit     : anomalies needed to latch alert (n-shot)
    //                            0 treated as 1
    // ─────────────────────────────────────────────────────
    wire       hold_mode  = uio_in[7];
    wire [1:0] sens       = uio_in[6:5];
    wire       nshot_mode = uio_in[4];
    wire [3:0] alimit     = uio_in[3:0];   // 0-15

    // ── Sliding window (4 samples) ───────────────────────
    reg [7:0] w0, w1, w2, w3;
    reg [9:0] sum;
    reg [1:0] count;
    reg       ready;
    reg [7:0] mean_r;
    reg       alert;
    reg       locked;        // one-shot latch
    reg [3:0] anomaly_count; // consecutive anomaly counter

    wire [7:0] mean_c = sum[9:2];   // sum / 4

    // ── Absolute difference |input - mean| ───────────────
    wire [8:0] diff_s  = {1'b0, ui_in} - {1'b0, mean_c};
    wire [7:0] diff_ab = diff_s[8] ? (~diff_s[7:0] + 8'd1) : diff_s[7:0];

    // ── Adaptive threshold from sensitivity bits ──────────
    reg [7:0] adaptive_thr;
    always @(*) begin
        case (sens)
            2'd0: adaptive_thr = (mean_c >> 1 < 8'd2) ? 8'd2 : mean_c >> 1; // 50%
            2'd1: adaptive_thr = (mean_c >> 2 < 8'd2) ? 8'd2 : mean_c >> 2; // 25%
            2'd2: adaptive_thr = (mean_c >> 3 < 8'd2) ? 8'd2 : mean_c >> 3; // 12.5%
            2'd3: adaptive_thr = (mean_c >> 4 < 8'd2) ? 8'd2 : mean_c >> 4; // 6.25%
        endcase
    end

    wire is_anomaly = ready && (diff_ab > adaptive_thr);

    // ── Effective limit: treat 0 as 1 ────────────────────
    wire [3:0] eff_limit = (alimit == 4'd0) ? 4'd1 : alimit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0            <= 8'd0; w1 <= 8'd0;
            w2            <= 8'd0; w3 <= 8'd0;
            sum           <= 10'd0;
            count         <= 2'd0;
            ready         <= 1'b0;
            alert         <= 1'b0;
            mean_r        <= 8'd0;
            locked        <= 1'b0;
            anomaly_count <= 4'd0;
        end else if (ena) begin

            // ── Window shift (stream mode only) ──────────
            if (!hold_mode) begin
                sum <= sum - {2'b00, w3} + {2'b00, ui_in};
                w3 <= w2; w2 <= w1; w1 <= w0; w0 <= ui_in;
                if (!ready) begin
                    if (count == 2'd3) ready <= 1'b1;
                    else               count <= count + 2'd1;
                end
            end

            mean_r <= mean_c;

            // ── Alert logic ──────────────────────────────
            if (ready) begin
                if (!nshot_mode) begin
                    // ONE-SHOT: first anomaly latches alert forever
                    if (is_anomaly && !locked) begin
                        alert  <= 1'b1;
                        locked <= 1'b1;
                    end else if (!locked) begin
                        alert <= 1'b0;
                    end

                end else begin
                    // N-SHOT: need eff_limit consecutive anomalies
                    if (!locked) begin
                        if (is_anomaly) begin
                            if (anomaly_count >= eff_limit - 4'd1) begin
                                alert  <= 1'b1;
                                locked <= 1'b1;
                            end else begin
                                anomaly_count <= anomaly_count + 4'd1;
                            end
                        end else begin
                            anomaly_count <= 4'd0;
                            alert         <= 1'b0;
                        end
                    end
                    // once locked, alert stays until rst_n
                end
            end else begin
                alert         <= 1'b0;
                anomaly_count <= 4'd0;
            end

        end
    end

    assign uo_out[0]   = alert;
    assign uo_out[1]   = ready;
    assign uo_out[2]   = locked;
    assign uo_out[7:3] = mean_r[7:3];

endmodule
