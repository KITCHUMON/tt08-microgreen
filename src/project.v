// Microgreen Harvest Classifier - Direct Camera Interface
// Connects OV7670 camera + HC-SR04 ultrasonic directly to ASIC
// No microcontroller needed!

`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Camera data bus D[7:0]
    output wire [7:0] uo_out,   // Outputs: buzzer, LED, status
    input  wire [7:0] uio_in,   // [7:4]=Camera ctrl, [3:0]=Ultrasonic
    output wire [7:0] uio_out,  // Camera clock + control signals
    output wire [7:0] uio_oe,   // I/O enable configuration
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock (25MHz for camera)
    input  wire       rst_n     // Reset (active low)
);

    // ========================================
    // I/O CONFIGURATION
    // ========================================
    assign uio_oe = 8'b00011110;  // [4:1] outputs, [7:5,0] inputs
    
    // ========================================
    // CAMERA CLOCK GENERATION
    // ========================================
    // Generate XCLK for camera (12.5MHz from 25MHz system clock)
    reg camera_clk_div;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            camera_clk_div <= 0;
        else if (ena)
            camera_clk_div <= ~camera_clk_div;
    end
    
    // ========================================
    // CAMERA INTERFACE
    // ========================================
    wire [7:0] camera_data = ui_in;
    wire vsync = uio_in[7];  // Frame start
    wire href = uio_in[6];   // Line valid
    wire pclk = uio_in[5];   // Pixel clock
    
    // Feature accumulators for real-time processing
    reg [15:0] green_accumulator;
    reg [15:0] red_accumulator;
    reg [15:0] brightness_accumulator;
    reg [15:0] pixel_count;
    reg [7:0] max_row, min_row;
    reg frame_ready;
    
    // Extracted features (averaged over frame)
    reg [7:0] avg_green;
    reg [7:0] avg_red;
    reg [7:0] avg_brightness;
    reg [7:0] height_pixels;
    
    // Process incoming pixels on PCLK
    reg vsync_prev, href_prev;
    wire vsync_rising = vsync && !vsync_prev;
    wire vsync_falling = !vsync && vsync_prev;
    wire href_active = href && !href_prev;
    
    reg [8:0] row_counter;
    reg [9:0] col_counter;
    
    always @(posedge pclk or negedge rst_n) begin
        if (!rst_n) begin
            green_accumulator <= 0;
            red_accumulator <= 0;
            brightness_accumulator <= 0;
            pixel_count <= 0;
            row_counter <= 0;
            col_counter <= 0;
            max_row <= 0;
            min_row <= 255;
            frame_ready <= 0;
            vsync_prev <= 0;
            href_prev <= 0;
        end else if (ena) begin
            vsync_prev <= vsync;
            href_prev <= href;
            
            // Start of new frame
            if (vsync_rising) begin
                green_accumulator <= 0;
                red_accumulator <= 0;
                brightness_accumulator <= 0;
                pixel_count <= 0;
                max_row <= 0;
                min_row <= 255;
                row_counter <= 0;
                frame_ready <= 0;
            end
            
            // New line
            if (href_active) begin
                row_counter <= row_counter + 1;
                col_counter <= 0;
            end
            
            // Process pixel data during HREF
            if (href) begin
                col_counter <= col_counter + 1;
                
                // Extract RGB from pixel data (RGB565 format)
                if (col_counter[0] == 0) begin
                    // First byte has R[4:0] G[5:3]
                    red_accumulator <= red_accumulator + {camera_data[7:3], 3'b0};
                    green_accumulator <= green_accumulator + {camera_data[2:0], 5'b0};
                end else begin
                    // Second byte has G[2:0] B[4:0]
                    green_accumulator <= green_accumulator + {camera_data[7:5], 5'b0};
                    brightness_accumulator <= brightness_accumulator + camera_data;
                    pixel_count <= pixel_count + 1;
                    
                    // Detect green pixels for height estimation
                    if (camera_data[7:5] > 3'b100) begin
                        if (row_counter < min_row) min_row <= row_counter[7:0];
                        if (row_counter > max_row) max_row <= row_counter[7:0];
                    end
                end
            end
            
            // End of frame
            if (vsync_falling) begin
                if (pixel_count > 0) begin
                    avg_green <= green_accumulator[15:8];
                    avg_red <= red_accumulator[15:8];
                    avg_brightness <= brightness_accumulator[15:8];
                    height_pixels <= max_row - min_row;
                    frame_ready <= 1;
                end
            end
        end
    end
    
    // ========================================
    // ULTRASONIC SENSOR INTERFACE
    // ========================================
    reg ultrasonic_trigger;
    reg [15:0] echo_timer;
    reg [7:0] distance_cm;
    reg measuring;
    reg [19:0] trigger_counter;
    
    // Generate trigger pulse (10us every 60ms)
    localparam TRIGGER_PERIOD = 20'd1500000;  // 60ms @ 25MHz
    localparam TRIGGER_WIDTH = 16'd250;       // 10us @ 25MHz
    
    wire echo_pin = uio_in[0];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ultrasonic_trigger <= 0;
            echo_timer <= 0;
            distance_cm <= 0;
            measuring <= 0;
            trigger_counter <= 0;
        end else if (ena) begin
            trigger_counter <= trigger_counter + 1;
            
            if (trigger_counter < TRIGGER_WIDTH)
                ultrasonic_trigger <= 1;
            else
                ultrasonic_trigger <= 0;
            
            if (trigger_counter >= TRIGGER_PERIOD)
                trigger_counter <= 0;
            
            // Echo measurement
            if (echo_pin && !measuring) begin
                measuring <= 1;
                echo_timer <= 0;
            end else if (measuring) begin
                if (echo_pin) begin
                    echo_timer <= echo_timer + 1;
                end else begin
                    distance_cm <= echo_timer[15:10];
                    measuring <= 0;
                end
            end
        end
    end
    
    // ========================================
    // FEATURE EXTRACTION & PREPROCESSING
    // ========================================
    wire [3:0] feature_greenness = avg_green[7:4];
    wire [3:0] feature_color_ratio = (avg_green[7:4] > avg_red[7:4]) ? 
                                      (avg_green[7:4] - avg_red[7:4]) : 4'd0;
    wire [3:0] feature_height = height_pixels[7:4];
    wire [3:0] feature_distance = distance_cm[7:4];
    wire [3:0] feature_combined_height = (feature_height + feature_distance) >> 1;
    wire [3:0] feature_texture = avg_brightness[7:4];
    
    // Binarize features
    wire bin_greenness = (feature_greenness > 4'd7);
    wire bin_color = (feature_color_ratio > 4'd3);
    wire bin_height = (feature_combined_height > 4'd7);
    wire bin_texture = (feature_texture > 4'd7);
    
    wire [3:0] input_binary = {bin_height, bin_texture, bin_color, bin_greenness};
    
    // ========================================
    // BINARY NEURAL NETWORK
    // ========================================
    reg [2:0] bnn_state;
    localparam BNN_IDLE = 3'd0;
    localparam BNN_COMPUTE_HIDDEN = 3'd1;
    localparam BNN_COMPUTE_OUTPUT = 3'd2;
    localparam BNN_DONE = 3'd3;
    
    reg [3:0] hidden_activations;
    reg [1:0] output_activations;
    reg bnn_ready;
    
    // Trigger inference on frame ready
    reg frame_ready_prev;
    wire inference_trigger = frame_ready && !frame_ready_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            frame_ready_prev <= 0;
        else if (ena)
            frame_ready_prev <= frame_ready;
    end
    
    // Hidden layer computations
    wire signed [4:0] hidden_sum [0:3];
    assign hidden_sum[0] = xnor_popcount_4bit(input_binary, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount_4bit(input_binary, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount_4bit(input_binary, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount_4bit(input_binary, W_IH_3) + BIAS_H3;
    
    // Output layer computations
    wire signed [4:0] output_sum [0:1];
    assign output_sum[0] = xnor_popcount_4bit(hidden_activations, W_HO_0);
    assign output_sum[1] = xnor_popcount_4bit(hidden_activations, W_HO_1);
    
    wire prediction = (output_sum[1] > output_sum[0]);
    
    // XNOR popcount function
    function signed [4:0] xnor_popcount_4bit;
        input [3:0] a, b;
        reg [3:0] xnor_result;
        begin
            xnor_result = ~(a ^ b);
            xnor_popcount_4bit = xnor_result[0] + xnor_result[1] + 
                                  xnor_result[2] + xnor_result[3];
        end
    endfunction
    
    // BNN state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bnn_state <= BNN_IDLE;
            hidden_activations <= 4'b0;
            output_activations <= 2'b0;
            bnn_ready <= 1'b0;
        end else if (ena) begin
            case (bnn_state)
                BNN_IDLE: begin
                    if (inference_trigger) begin
                        bnn_ready <= 1'b0;
                        bnn_state <= BNN_COMPUTE_HIDDEN;
                    end
                end
                
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
                    bnn_ready <= 1'b1;
                    bnn_state <= BNN_DONE;
                end
                
                BNN_DONE: begin
                    bnn_ready <= 1'b1;
                    if (inference_trigger)
                        bnn_state <= BNN_COMPUTE_HIDDEN;
                end
            endcase
        end
    end
    
    // ========================================
    // OUTPUT MAPPING
    // ========================================
    wire buzzer = bnn_ready & prediction;
    
    assign uo_out[7] = buzzer;               // Buzzer
    assign uo_out[6] = buzzer;               // LED
    assign uo_out[5] = bnn_ready;            // Ready flag
    assign uo_out[4] = prediction;           // Raw prediction
    assign uo_out[3:0] = hidden_activations; // Debug
    
    // Assign all uio_out bits to prevent 'z' values
    assign uio_out[7:5] = 3'b000;           // Unused inputs
    assign uio_out[4] = camera_clk_div;     // XCLK to camera
    assign uio_out[3:2] = 2'b00;            // Reserved (future I2C)
    assign uio_out[1] = ultrasonic_trigger; // Ultrasonic trigger
    assign uio_out[0] = 1'b0;               // Unused (echo is input)

endmodule
