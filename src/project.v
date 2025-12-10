// Microgreen Harvest Classifier - Camera + Ultrasonic + UART Alert Override
// Connects OV7670 camera + HC-SR04 ultrasonic + UART override directly to ASIC

`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Camera data bus D[7:0]
    output wire [7:0] uo_out,   // Outputs: buzzer, LED, status
    input  wire [7:0] uio_in,   // [7:4]=Camera ctrl, [3]=UART, [2:0]=Ultrasonic
    output wire [7:0] uio_out,  // Camera clock + control signals
    output wire [7:0] uio_oe,   // I/O enable configuration
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock (25MHz)
    input  wire       rst_n     // Reset (active low)
);

    assign uio_oe = 8'b00011110;  // [4:1] outputs, [7,6,5,0,3] inputs

    // CAMERA CLOCK (XCLK)
    reg camera_clk_div;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            camera_clk_div <= 0;
        else if (ena)
            camera_clk_div <= ~camera_clk_div;
    end

    assign uio_out[4] = camera_clk_div;

    // CAMERA INPUTS
    wire [7:0] camera_data = ui_in;
    wire vsync = uio_in[7];
    wire href  = uio_in[6];
    wire pclk  = uio_in[5];

    // FEATURE EXTRACTION (simplified for brevity)
    reg [7:0] avg_green, avg_red, avg_brightness, height_pixels;
    reg [7:0] distance_cm;
    wire [3:0] feature_greenness = avg_green[7:4];
    wire [3:0] feature_color_ratio = (avg_green[7:4] > avg_red[7:4]) ? 
                                       (avg_green[7:4] - avg_red[7:4]) : 4'd0;
    wire [3:0] feature_height = height_pixels[7:4];
    wire [3:0] feature_distance = distance_cm[7:4];
    wire [3:0] feature_combined_height = (feature_height + feature_distance) >> 1;
    wire [3:0] feature_texture = avg_brightness[7:4];

    wire bin_greenness = (feature_greenness > 4'd7);
    wire bin_color = (feature_color_ratio > 4'd3);
    wire bin_height = (feature_combined_height > 4'd7);
    wire bin_texture = (feature_texture > 4'd7);
    wire [3:0] input_binary = {bin_height, bin_texture, bin_color, bin_greenness};

    // BNN
    wire signed [4:0] hidden_sum [0:3];
    assign hidden_sum[0] = xnor_popcount_4bit(input_binary, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount_4bit(input_binary, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount_4bit(input_binary, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount_4bit(input_binary, W_IH_3) + BIAS_H3;

    reg [3:0] hidden_activations;
    reg [1:0] output_activations;
    reg bnn_ready;
    reg frame_ready;
    reg frame_ready_prev;
    wire inference_trigger = frame_ready && !frame_ready_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_ready_prev <= 0;
            bnn_ready <= 0;
        end else if (ena) begin
            frame_ready_prev <= frame_ready;
            if (inference_trigger) begin
                hidden_activations[0] <= (hidden_sum[0] >= 0);
                hidden_activations[1] <= (hidden_sum[1] >= 0);
                hidden_activations[2] <= (hidden_sum[2] >= 0);
                hidden_activations[3] <= (hidden_sum[3] >= 0);

                output_activations[0] <= (xnor_popcount_4bit(hidden_activations, W_HO_0) >= 0);
                output_activations[1] <= (xnor_popcount_4bit(hidden_activations, W_HO_1) >= 0);

                bnn_ready <= 1;
            end
        end
    end

    wire prediction = (xnor_popcount_4bit(hidden_activations, W_HO_1) >
                       xnor_popcount_4bit(hidden_activations, W_HO_0));

    // UART RECEIVER FOR OVERRIDE (on uio_in[3])
    reg [9:0] uart_shift;
    reg [3:0] uart_bit_count;
    reg [12:0] uart_clk_count;
    reg uart_receiving;
    reg uart_alert_active;

    parameter UART_BAUD_DIV = 2604;  // for 9600 baud
    wire uart_rx = uio_in[3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_receiving <= 0;
            uart_bit_count <= 0;
            uart_clk_count <= 0;
            uart_alert_active <= 0;
        end else if (ena) begin
            if (!uart_receiving && !uart_rx) begin
                uart_receiving <= 1;
                uart_clk_count <= UART_BAUD_DIV / 2;
                uart_bit_count <= 0;
            end else if (uart_receiving) begin
                if (uart_clk_count == UART_BAUD_DIV - 1) begin
                    uart_clk_count <= 0;
                    uart_bit_count <= uart_bit_count + 1;
                    uart_shift <= {uart_rx, uart_shift[9:1]};
                    if (uart_bit_count == 9) begin
                        uart_receiving <= 0;
                        if (uart_shift[7:0] == 8'h41)
                            uart_alert_active <= 1;
                        else if (uart_shift[7:0] == 8'h4F || uart_shift[7:0] == 8'h00)
                            uart_alert_active <= 0;
                    end
                end else begin
                    uart_clk_count <= uart_clk_count + 1;
                end
            end
        end
    end

    // OUTPUTS
    wire prediction_effective = prediction | uart_alert_active;
    wire buzzer = bnn_ready & prediction_effective;

    assign uo_out[7] = buzzer;
    assign uo_out[6] = buzzer;
    assign uo_out[5] = bnn_ready;
    assign uo_out[4] = prediction_effective;
    assign uo_out[3:0] = hidden_activations;

    assign uio_out[3:2] = 2'b00;
    assign uio_out[0] = 1'b0;

    function signed [4:0] xnor_popcount_4bit;
        input [3:0] a, b;
        reg [3:0] x;
        begin
            x = ~(a ^ b);
            xnor_popcount_4bit = x[0] + x[1] + x[2] + x[3];
        end
    endfunction

endmodule
