`timescale 1ns/1ps
`default_nettype none

module tb;
    reg  clk, rst_n, ena;
    reg  [7:0] ui_in, uio_in;
    wire [7:0] uo_out, uio_out, uio_oe;

    // Instantiate DUT
    tt_um_anomaly_detector dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // ── Helper task ──────────────────────────────────────────────────
    task send_sample;
        input [7:0] val;
        begin
            ui_in = val;
            @(posedge clk); #1;
            $display("IN=%0d | READY=%b ALERT=%b | mean[7:2]=%0d",
                     val, uo_out[1], uo_out[0], uo_out[7:2]);
        end
    endtask

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        // Init
        rst_n = 0; ena = 1;
        ui_in = 8'd0; uio_in = 8'd5;   // threshold = 5
        repeat(3) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("--- Loading window (normal values) ---");
        send_sample(8'd10);
        send_sample(8'd12);
        send_sample(8'd11);
        send_sample(8'd13);   // window full after this

        $display("--- Normal samples (should stay NORMAL) ---");
        send_sample(8'd12);
        send_sample(8'd11);

        $display("--- Anomaly injection (should ALERT) ---");
        send_sample(8'd40);   // << spike!

        $display("--- Back to normal ---");
        send_sample(8'd12);
        send_sample(8'd11);
        send_sample(8'd13);

        $display("DONE");
        $finish;
    end
endmodule
