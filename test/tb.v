`timescale 1ns/1ps

module tb;
    reg clk;
    reg rst_n;
    reg ena;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // Instantiate your design
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

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period => 100MHz
    end

    // Test sequence
    initial begin
        // Initialize inputs
        rst_n = 0;
        ena = 0;
        ui_in = 8'b0;
        uio_in = 8'b0;

        // Reset the design
        #20 rst_n = 1;
        ena = 1;

        // Apply a test vector
        #10 ui_in = 8'b00110011;
        #10 uio_in = 8'b00110011;

        // Wait and observe outputs
        #50;

        // Add more test vectors as needed

        // Finish simulation
        #100 $finish;
    end
endmodule
