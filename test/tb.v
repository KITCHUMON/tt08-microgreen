`timescale 1ns / 1ps

module tb;

    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instantiate the DUT
    tt_um_microgreen_bnn uut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Clock generation: 10ns period = 100MHz
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $display("=== Starting BNN Testbench ===");
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);

        // Reset
        rst_n = 0;
        ena = 0;
        ui_in = 8'b0;
        uio_in = 8'b0;
        #20;

        rst_n = 1;
        ena = 1;

        // Test case 1: Growth stage
        ui_in = 8'b00110011;   // height=3, color=3
        uio_in = 8'b00110011;  // width=3, stem=3
        #100;
        $display("[Growth] uo_out = %b (class = %0d, ready = %b)", uo_out, uo_out[2:0], uo_out[3]);

        // Test case 2: Harvest stage
        ui_in = 8'b11111111;   // height=15, color=15
        uio_in = 8'b11111111;  // width=15, stem=15
        #100;
        $display("[Harvest] uo_out = %b (class = %0d, ready = %b)", uo_out, uo_out[2:0], uo_out[3]);

        $display("=== Testbench complete ===");
        #20;
        $finish;
    end
endmodule
