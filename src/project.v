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

    // Disable bidirectional IO
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // -------------------------
    // Registers
    // -------------------------
    reg [7:0] w0, w1, w2, w3;
    reg [1:0] wr_ptr;
    reg [2:0] count;

    reg [7:0] mean;
    reg [7:0] mean_reg;   // IMPORTANT: stable previous mean

    reg alert;
    reg ready;

    // -------------------------
    // Difference uses OLD mean
    // -------------------------
    wire [7:0] diff =
        (ui_in >= mean_reg) ? (ui_in - mean_reg) : (mean_reg - ui_in);

    // -------------------------
    // Compute next sum
    // -------------------------
    wire [9:0] sum_next =
        (wr_ptr == 2'd0) ?
            ({2'b00, ui_in} + {2'b00, w1} + {2'b00, w2} + {2'b00, w3}) :
        (wr_ptr == 2'd1) ?
            ({2'b00, w0} + {2'b00, ui_in} + {2'b00, w2} + {2'b00, w3}) :
        (wr_ptr == 2'd2) ?
            ({2'b00, w0} + {2'b00, w1} + {2'b00, ui_in} + {2'b00, w3}) :
            ({2'b00, w0} + {2'b00, w1} + {2'b00, w2} + {2'b00, ui_in});

    // -------------------------
    // Sequential logic
    // -------------------------
    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin
            w0 <= 0; w1 <= 0; w2 <= 0; w3 <= 0;
            wr_ptr <= 0;
            count <= 0;

            mean <= 0;
            mean_reg <= 0;

            alert <= 0;
            ready <= 0;
        end

        else if (ena) begin

            // Save previous mean for stable comparison
            mean_reg <= mean;

            // Store input into circular buffer
            case (wr_ptr)
                2'd0: w0 <= ui_in;
                2'd1: w1 <= ui_in;
                2'd2: w2 <= ui_in;
                2'd3: w3 <= ui_in;
            endcase

            // update pointer
            wr_ptr <= (wr_ptr == 2'd3) ? 2'd0 : wr_ptr + 1;

            // sample counter
            if (count < 3'd4)
                count <= count + 1;

            // after enough samples
            if (count >= 3'd2) begin
                ready <= 1'b1;

                // update mean
                mean <= sum_next[9:2];

                // anomaly detection using OLD mean
                if (diff > 8'd20)
                    alert <= 1'b1;
                else
                    alert <= 1'b0;

            end
            else begin
                ready <= 1'b0;
                alert <= 1'b0;
            end

        end
    end

    // -------------------------
    // Output mapping
    // -------------------------
    assign uo_out[0]   = alert;
    assign uo_out[1]   = ready;
    assign uo_out[7:2] = mean[7:2];

endmodule
