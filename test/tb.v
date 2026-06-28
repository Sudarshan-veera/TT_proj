`timescale 1ns/1ps

module tb;

    reg clk, rst_n, ena;
    reg [7:0] ui_in, uio_in;
    wire [7:0] uo_out, uio_out, uio_oe;

    tt_um_anomaly_detector dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out),
        .uio_oe(uio_oe), .ena(ena),
        .clk(clk), .rst_n(rst_n)
    );

    always #5 clk = ~clk;
    initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end

    // sens[1:0], nshot, alimit[3:0], hold
    task send;
        input [7:0] val;
        input [1:0] sens;
        input       nshot;
        input [3:0] alimit;
        input       hold;
        begin
            ui_in  = val;
            uio_in = {hold, sens, nshot, alimit};
            @(posedge clk); #1;
            $display("IN=%3d SENS=%0d NSHOT=%0b ALIM=%2d HOLD=%0b | RDY=%b ALERT=%b LOCK=%b mean~=%0d",
                val, sens, nshot, alimit, hold,
                uo_out[1], uo_out[0], uo_out[2], {uo_out[7:3], 3'b0});
        end
    endtask

    integer i;

    initial begin
        clk=0; rst_n=0; ena=1; ui_in=0; uio_in=0;
        repeat(2) @(posedge clk); #1;
        rst_n = 1;

        // ── TEST 1: ONE-SHOT, sens=1 (25%) ──────────────
        $display("\n=== TEST 1: One-shot mode, sens=1 (25%) ===");
        send(10, 2'd1, 0, 4'd0, 0);
        send(12, 2'd1, 0, 4'd0, 0);
        send(11, 2'd1, 0, 4'd0, 0);
        send(13, 2'd1, 0, 4'd0, 0);  // ready goes high

        $display("-- Normal ramp --");
        for (i=11; i<=16; i=i+1)
            send(i[7:0], 2'd1, 0, 4'd0, 0);

        $display("-- Spike: should latch alert --");
        send(60, 2'd1, 0, 4'd0, 0);  // ALERT=1, LOCK=1

        $display("-- After lock: alert stays --");
        send(12, 2'd1, 0, 4'd0, 0);
        send(12, 2'd1, 0, 4'd0, 0);

        // Reset for next test
        rst_n = 0; repeat(2) @(posedge clk); #1; rst_n = 1;

        // ── TEST 2: N-SHOT, alimit=3, sens=2 (12.5%) ───
        $display("\n=== TEST 2: N-shot mode, alimit=3, sens=2 (12.5%) ===");
        send(20, 2'd2, 1, 4'd3, 0);
        send(22, 2'd2, 1, 4'd3, 0);
        send(21, 2'd2, 1, 4'd3, 0);
        send(23, 2'd2, 1, 4'd3, 0);  // ready

        $display("-- 1 anomaly: no alert yet --");
        send(60, 2'd2, 1, 4'd3, 0);  // anomaly_count=1
        send(20, 2'd2, 1, 4'd3, 0);  // resets count

        $display("-- 3 consecutive: alert on 3rd --");
        send(60, 2'd2, 1, 4'd3, 0);  // count=1
        send(60, 2'd2, 1, 4'd3, 0);  // count=2
        send(60, 2'd2, 1, 4'd3, 0);  // ALERT=1, LOCK=1

        $display("-- Locked --");
        send(20, 2'd2, 1, 4'd3, 0);

        // Reset for next test
        rst_n = 0; repeat(2) @(posedge clk); #1; rst_n = 1;

        // ── TEST 3: Gradual ramp — zero alerts ───────────
        $display("\n=== TEST 3: Gradual ramp 10→25, sens=1, one-shot ===");
        send(10, 2'd1, 0, 4'd0, 0);
        send(11, 2'd1, 0, 4'd0, 0);
        send(12, 2'd1, 0, 4'd0, 0);
        send(13, 2'd1, 0, 4'd0, 0);
        for (i=11; i<=25; i=i+1)
            send(i[7:0], 2'd1, 0, 4'd0, 0);

        // Reset for hold mode test
        rst_n = 0; repeat(2) @(posedge clk); #1; rst_n = 1;

        // ── TEST 4: Hold mode freezes mean ───────────────
        $display("\n=== TEST 4: Hold mode ===");
        send(10, 2'd1, 0, 4'd0, 0);
        send(12, 2'd1, 0, 4'd0, 0);
        send(11, 2'd1, 0, 4'd0, 0);
        send(13, 2'd1, 0, 4'd0, 0);

        $display("-- Freeze window, inject spikes --");
        send(40, 2'd1, 0, 4'd0, 1);  // hold=1, mean frozen, ALERT fires
        send(40, 2'd1, 0, 4'd0, 1);  // still frozen
        $display("-- Release hold --");
        send(12, 2'd1, 0, 4'd0, 0);  // window resumes

        $display("\nDONE");
        $finish;
    end

endmodule
