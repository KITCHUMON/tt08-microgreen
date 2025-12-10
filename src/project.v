// SPDX-FileCopyrightText: © 2024 Tiny Tapeout
// SPDX-License-Identifier: Apache-2.0

// Microgreen Harvest Classifier with UART alert
`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // UART alert signal extracted from incoming UART stream
    wire uart_alert = uio_in[2];  // Example: use uio_in[2] as external alert input

    assign uio_oe = 8'b00011110;  // [4:1] outputs

    // Ensure all uio_out bits are driven
    assign uio_out[7] = 1'b0;
    assign uio_out[6] = 1'b0;
    assign uio_out[5] = 1'b0;
    assign uio_out[3] = 1'b0;
    assign uio_out[2] = 1'b0;
    assign uio_out[0] = 1'b0;

    // Inputs from sensors
    wire [7:0] camera_data = ui_in;
    wire vsync = uio_in[7];
    wire href = uio_in[6];
    wire pclk = uio_in[5];
    wire echo_pin = uio_in[0];

    // Outputs
    reg camera_clk_div;
    assign uio_out[4] = camera_clk_div;
    reg ultrasonic_trigger;
    assign uio_out[1] = ultrasonic_trigger;

    // Clock divider for camera
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) camera_clk_div <= 0;
        else if (ena) camera_clk_div <= ~camera_clk_div;
    end

    // Feature processing
    reg [15:0] green_accumulator, red_accumulator, brightness_accumulator, pixel_count;
    reg [7:0] max_row, min_row;
    reg [7:0] avg_green, avg_red, avg_brightness, height_pixels;
    reg vsync_prev, href_prev;
    reg [8:0] row_counter;
    reg [9:0] col_counter;
    reg frame_ready;

    wire vsync_rise = vsync && !vsync_prev;
    wire vsync_fall = !vsync && vsync_prev;
    wire href_rise = href && !href_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            green_accumulator <= 0; red_accumulator <= 0; brightness_accumulator <= 0;
            pixel_count <= 0; row_counter <= 0; col_counter <= 0;
            max_row <= 0; min_row <= 255;
            vsync_prev <= 0; href_prev <= 0;
        end else if (ena) begin
            vsync_prev <= vsync; href_prev <= href;
            if (vsync_rise) begin
                green_accumulator <= 0; red_accumulator <= 0; brightness_accumulator <= 0;
                pixel_count <= 0; row_counter <= 0; max_row <= 0; min_row <= 255;
            end
            if (href_rise) begin
                row_counter <= row_counter + 1;
                col_counter <= 0;
            end
            if (href) begin
                col_counter <= col_counter + 1;
                if (col_counter[0] == 0) begin
                    red_accumulator <= red_accumulator + {camera_data[7:3], 3'b0};
                    green_accumulator <= green_accumulator + {camera_data[2:0], 5'b0};
                end else begin
                    green_accumulator <= green_accumulator + {camera_data[7:5], 5'b0};
                    brightness_accumulator <= brightness_accumulator + camera_data;
                    pixel_count <= pixel_count + 1;
                    if (camera_data[7:5] > 3'b100) begin
                        if (row_counter < min_row) min_row <= row_counter[7:0];
                        if (row_counter > max_row) max_row <= row_counter[7:0];
                    end
                end
            end
            if (vsync_fall && pixel_count > 0) begin
                avg_green <= green_accumulator[15:8];
                avg_red <= red_accumulator[15:8];
                avg_brightness <= brightness_accumulator[15:8];
                height_pixels <= max_row - min_row;
                frame_ready <= 1;
            end else frame_ready <= 0;
        end
    end

    // Ultrasonic
    reg [15:0] echo_timer;
    reg [7:0] distance_cm;
    reg [19:0] trigger_counter;
    reg measuring;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ultrasonic_trigger <= 0; echo_timer <= 0; distance_cm <= 0;
            trigger_counter <= 0; measuring <= 0;
        end else if (ena) begin
            trigger_counter <= trigger_counter + 1;
            ultrasonic_trigger <= (trigger_counter < 16'd250);
            if (trigger_counter >= 20'd1500000) trigger_counter <= 0;
            if (echo_pin && !measuring) begin measuring <= 1; echo_timer <= 0; end
            else if (measuring) begin
                if (echo_pin) echo_timer <= echo_timer + 1;
                else begin measuring <= 0; distance_cm <= echo_timer[15:10]; end
            end
        end
    end

    // BNN
    wire [3:0] feature_greenness = avg_green[7:4];
    wire [3:0] feature_color_ratio = (avg_green[7:4] > avg_red[7:4]) ?
                                      (avg_green[7:4] - avg_red[7:4]) : 4'd0;
    wire [3:0] feature_height = height_pixels[7:4];
    wire [3:0] feature_distance = distance_cm[7:4];
    wire [3:0] feature_texture = avg_brightness[7:4];
    wire [3:0] feature_combined_height = (feature_height + feature_distance) >> 1;

    wire [3:0] input_binary = {
        (feature_combined_height > 4'd7),
        (feature_texture > 4'd7),
        (feature_color_ratio > 4'd3),
        (feature_greenness > 4'd7)
    };

    wire signed [4:0] hidden_sum [0:3];
    assign hidden_sum[0] = xnor_popcount_4bit(input_binary, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount_4bit(input_binary, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount_4bit(input_binary, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount_4bit(input_binary, W_IH_3) + BIAS_H3;

    reg [3:0] hidden;
    reg [1:0] output_act;
    reg bnn_ready;
    wire signed [4:0] output_sum [0:1];
    assign output_sum[0] = xnor_popcount_4bit(hidden, W_HO_0);
    assign output_sum[1] = xnor_popcount_4bit(hidden, W_HO_1);

    wire prediction = (output_sum[1] > output_sum[0]) | uart_alert;  // override with UART alert

    function signed [4:0] xnor_popcount_4bit(input [3:0] a, b);
        reg [3:0] x;
        begin
            x = ~(a ^ b);
            xnor_popcount_4bit = x[0] + x[1] + x[2] + x[3];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            hidden <= 0; output_act <= 0; bnn_ready <= 1;
        end else if (ena && frame_ready) begin
            hidden[0] <= (hidden_sum[0] >= 0);
            hidden[1] <= (hidden_sum[1] >= 0);
            hidden[2] <= (hidden_sum[2] >= 0);
            hidden[3] <= (hidden_sum[3] >= 0);
            output_act[0] <= (output_sum[0] >= 0);
            output_act[1] <= (output_sum[1] >= 0);
            bnn_ready <= 1;
        end
    end

    assign uo_out[7] = bnn_ready & prediction; // buzzer
    assign uo_out[6] = bnn_ready & prediction; // led
    assign uo_out[5] = bnn_ready;
    assign uo_out[4] = prediction;
    assign uo_out[3:0] = hidden;

endmodule
