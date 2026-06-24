`default_nettype none
module tt_um_anomaly_detector(
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    output wire [7:0] uo_out,
    input  wire clk,
    input  wire rst_n,
    input  wire ena
);
    assign uio_out = 0;
    assign uio_oe  = 0;
    assign uo_out = ui_in; 
endmodule
