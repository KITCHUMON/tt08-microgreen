`timescale 1ns / 1ps

module tb;
    reg clk;
    reg rst_n;
    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    
    // Instantiate DUT
    tt_um_microgreen_bnn dut (
        .clk(clk),
        .rst_n(rst_n),
        .ena(1'b1),
        .ui_in(ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    // Generate 25 MHz clock
    initial clk = 0;
    always #20 clk = ~clk;

    // Camera and echo simulation
    reg vsync, href, pclk, echo;
    reg [7:0] pixel_data;

    assign uio_in = {vsync, href, pclk, 5'b0000} | {7'b0, echo};

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        // Reset
        rst_n = 0;
        ui_in = 0;
        vsync = 0; href = 0; pclk = 0; echo = 0;
        #200;
        rst_n = 1;
        #200;

        // Simulate a frame
        simulate_camera_frame();

        // Simulate ultrasonic echo
        simulate_ultrasonic_echo(16'd600); // approx 15 cm

        // Wait for BNN output
        #2000;
        $display("uo_out: %b", uo_out);
        $finish;
    end

    task simulate_camera_frame;
        integer i;
        begin
            // VSYNC pulse
            vsync = 1;
            #100;
            vsync = 0;
            #100;

            // Simulate a few lines with green pixels
            for (i = 0; i < 10; i = i + 1) begin
                href = 1;
                send_pixel(8'h3C);  // greenish
                send_pixel(8'hA0);
                href = 0;
                #100;
            end

            // End of frame
            vsync = 1;
            #100;
            vsync = 0;
        end
    endtask

    task send_pixel;
        input [7:0] data;
        begin
            pclk = 0;
            ui_in = data;
            #20;
            pclk = 1;
            #20;
            pclk = 0;
        end
    endtask

    task simulate_ultrasonic_echo;
        input [15:0] pulse_width;
        begin
            echo = 1;
            #(pulse_width);
            echo = 0;
        end
    endtask
endmodule
