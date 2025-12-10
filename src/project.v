// Microgreen Harvest Classifier with UART High-Alert Override

`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Camera data bus D[7:0]
    output wire [7:0] uo_out,   // Outputs: buzzer, LED, status
    input  wire [7:0] uio_in,   // [7:4]=Camera ctrl, [3:0]=Ultrasonic + UART
    output wire [7:0] uio_out,  // Camera clock + control signals
    output wire [7:0] uio_oe,   // I/O enable configuration
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock (25MHz for camera)
    input  wire       rst_n     // Reset (active low)
);

    assign uio_oe = 8'b00011110;

    // UART input filter (uio_in[3])
    reg [7:0] uart_shift;
    wire uart_rx = uio_in[3];
    wire high_priority_alert = (uart_shift[7:4] == 4'b1111);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) uart_shift <= 8'd0;
        else       uart_shift <= {uart_shift[6:0], uart_rx};
    end

    // Camera clock generation
    reg camera_clk_div;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) camera_clk_div <= 0;
        else if (ena) camera_clk_div <= ~camera_clk_div;
    end

    wire [7:0] camera_data = ui_in;
    wire vsync = uio_in[7];
    wire href  = uio_in[6];
    wire pclk  = uio_in[5];

    reg [15:0] green_accumulator, red_accumulator, brightness_accumulator;
    reg [15:0] pixel_count, green_pixel_count;
    reg [31:0] brightness_square_sum;
    reg [7:0] max_row, min_row;
    reg frame_ready;

    reg [7:0] avg_green, avg_red, avg_brightness, height_pixels;

    reg vsync_sync1, vsync_sync2, vsync_sync3;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) {vsync_sync1, vsync_sync2, vsync_sync3} <= 0;
        else if (ena) begin
            vsync_sync1 <= vsync;
            vsync_sync2 <= vsync_sync1;
            vsync_sync3 <= vsync_sync2;
        end
    end
    wire vsync_falling = !vsync_sync2 && vsync_sync3;

    reg vsync_prev, href_prev;
    reg [8:0] row_counter;
    reg [9:0] col_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            green_accumulator <= 0; red_accumulator <= 0; brightness_accumulator <= 0;
            brightness_square_sum <= 0; pixel_count <= 0; green_pixel_count <= 0;
            row_counter <= 0; col_counter <= 0; max_row <= 0; min_row <= 255;
            vsync_prev <= 0; href_prev <= 0;
        end else if (ena) begin
            vsync_prev <= vsync;
            href_prev <= href;
            if (vsync && !vsync_prev) begin
                green_accumulator <= 0; red_accumulator <= 0; brightness_accumulator <= 0;
                brightness_square_sum <= 0; pixel_count <= 0; green_pixel_count <= 0;
                max_row <= 0; min_row <= 255; row_counter <= 0;
            end
            if (href && !href_prev) begin
                row_counter <= row_counter + 1; col_counter <= 0;
            end
            if (href) begin
                col_counter <= col_counter + 1;
                if (col_counter[0] == 0) begin
                    red_accumulator <= red_accumulator + {camera_data[7:3], 3'b0};
                    green_accumulator <= green_accumulator + {camera_data[2:0], 5'b0};
                end else begin
                    green_accumulator <= green_accumulator + {camera_data[7:5], 5'b0};
                    brightness_accumulator <= brightness_accumulator + camera_data;
                    brightness_square_sum <= brightness_square_sum + camera_data * camera_data;
                    pixel_count <= pixel_count + 1;
                    if (camera_data[7:5] > 3'b100) begin
                        green_pixel_count <= green_pixel_count + 1;
                        if (row_counter < min_row) min_row <= row_counter[7:0];
                        if (row_counter > max_row) max_row <= row_counter[7:0];
                    end
                end
            end
            if (!vsync && vsync_prev && pixel_count > 0) begin
                avg_green <= green_accumulator / pixel_count;
                avg_red <= red_accumulator / pixel_count;
                avg_brightness <= brightness_accumulator / pixel_count;
                height_pixels <= max_row - min_row;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) frame_ready <= 0;
        else if (ena) frame_ready <= vsync_falling ? 1'b1 : 1'b0;
    end

    // Ultrasonic sensor
    reg ultrasonic_trigger;
    reg [15:0] echo_timer;
    reg [7:0] distance_cm;
    reg measuring;
    reg [19:0] trigger_counter;
    wire echo_pin = uio_in[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ultrasonic_trigger <= 0; echo_timer <= 0; distance_cm <= 0;
            measuring <= 0; trigger_counter <= 0;
        end else if (ena) begin
            trigger_counter <= trigger_counter + 1;
            ultrasonic_trigger <= (trigger_counter < 16'd250);
            if (trigger_counter >= 20'd1500000) trigger_counter <= 0;
            if (echo_pin && !measuring) begin measuring <= 1; echo_timer <= 0; end
            else if (measuring) begin
                if (echo_pin) echo_timer <= echo_timer + 1;
                else begin distance_cm <= echo_timer[15:10]; measuring <= 0; end
            end
        end
    end

    // Feature Extraction
    wire [3:0] feature_greenness = avg_green[7:4];
    wire [3:0] feature_color_ratio = (avg_green[7:4] > avg_red[7:4]) ? (avg_green[7:4] - avg_red[7:4]) : 4'd0;
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
    reg [2:0] bnn_state;
    localparam BNN_IDLE = 3'd0, BNN_COMPUTE_HIDDEN = 3'd1, BNN_COMPUTE_OUTPUT = 3'd2, BNN_DONE = 3'd3;
    reg [3:0] hidden_activations;
    reg [1:0] output_activations;
    reg bnn_ready;
    reg frame_ready_prev;
    wire inference_trigger = frame_ready && !frame_ready_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) frame_ready_prev <= 0;
        else if (ena) frame_ready_prev <= frame_ready;
    end

    wire signed [4:0] hidden_sum [0:3];
    assign hidden_sum[0] = xnor_popcount_4bit(input_binary, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount_4bit(input_binary, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount_4bit(input_binary, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount_4bit(input_binary, W_IH_3) + BIAS_H3;

    wire signed [4:0] output_sum [0:1];
    assign output_sum[0] = xnor_popcount_4bit(hidden_activations, W_HO_0);
    assign output_sum[1] = xnor_popcount_4bit(hidden_activations, W_HO_1);

    wire prediction = (output_sum[1] > output_sum[0]);

    function signed [4:0] xnor_popcount_4bit;
        input [3:0] a, b;
        reg [3:0] x;
        begin
            x = ~(a ^ b);
            xnor_popcount_4bit = x[0] + x[1] + x[2] + x[3];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bnn_state <= BNN_IDLE; hidden_activations <= 0; output_activations <= 0; bnn_ready <= 1;
        end else if (ena) begin
            case (bnn_state)
                BNN_IDLE: if (inference_trigger) begin bnn_ready <= 0; bnn_state <= BNN_COMPUTE_HIDDEN; end
                BNN_COMPUTE_HIDDEN: begin
                    hidden_activations[0] <= (hidden_sum[0] >= 0);
                    hidden_activations[1] <= (hidden_sum[1] >= 0);
                    hidden_activations[2] <= (hidden_sum[2] >= 0);
                    hidden_activations[3] <= (hidden_sum[3] >= 0);
                    bnn_state <= BNN_COMPUTE_OUTPUT;
                end
                BNN_COMPUTE_OUTPUT: begin
                    output_activations[0] <= (output_sum[0] >= 0);
                    output_activations[1] <= (output_sum[1] >= 0);
                    bnn_ready <= 1; bnn_state <= BNN_DONE;
                end
                BNN_DONE: if (inference_trigger) bnn_state <= BNN_COMPUTE_HIDDEN;
            endcase
        end
    end

    // Outputs
    wire buzzer = bnn_ready & (prediction | high_priority_alert);
    assign uo_out[7] = buzzer;
    assign uo_out[6] = buzzer;
    assign uo_out[5] = bnn_ready;
    assign uo_out[4] = prediction;
    assign uo_out[3:0] = hidden_activations;

    assign uio_out[7:5] = 3'b000;
    assign uio_out[4] = camera_clk_div;
    assign uio_out[3:2] = 2'b00;
    assign uio_out[1] = ultrasonic_trigger;
    assign uio_out[0] = 1'b0;

endmodule
