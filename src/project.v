// Microgreen Harvest Classifier using Binary Neural Network
// Uses trained weights from Python training script
// Place weights.vh in the same directory as this file

`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Camera features: [7:4]=color, [3:0]=texture
    output wire [7:0] uo_out,   // Output: [7]=buzzer, [6]=LED, [5]=ready, [4]=prediction, [3:0]=hidden
    input  wire [7:0] uio_in,   // Height sensor (8 bits)
    output wire [7:0] uio_out,  // Not used
    output wire [7:0] uio_oe,   // Enable outputs
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

    // Configure IOs
    assign uio_oe = 8'b00000000;  // All inputs
    assign uio_out = 8'b0;

    // ========================================
    // INPUT PREPROCESSING
    // ========================================
    wire [3:0] camera_color = ui_in[7:4];
    wire [3:0] camera_texture = ui_in[3:0];
    wire [7:0] height_raw = uio_in;
    wire [3:0] height_scaled = height_raw[7:4];
    
    // Binarize inputs
    wire bin_height = (height_scaled > 4'd7);
    wire bin_texture = (camera_texture > 4'd7);
    wire bin_color = (camera_color > 4'd7);
    wire bin_density = (camera_color > 4'd5);  // Additional feature
    
    wire [3:0] input_binary = {bin_height, bin_density, bin_texture, bin_color};

    // ========================================
    // STATE MACHINE
    // ========================================
    reg [2:0] state;
    localparam IDLE = 3'd0;
    localparam COMPUTE_HIDDEN = 3'd1;
    localparam COMPUTE_OUTPUT = 3'd2;
    localparam DONE = 3'd3;
    
    reg [3:0] hidden_activations;
    reg [1:0] output_activations;  // 2 output neurons
    reg ready;

    // ========================================
    // BNN COMPUTATION
    // ========================================
    
    // Hidden layer computations (using trained weights)
    wire signed [4:0] hidden_sum [0:3];
    
    assign hidden_sum[0] = xnor_popcount_4bit(input_binary, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount_4bit(input_binary, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount_4bit(input_binary, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount_4bit(input_binary, W_IH_3) + BIAS_H3;
    
    // Output layer computations (2 neurons from training)
    wire signed [4:0] output_sum [0:1];
    
    assign output_sum[0] = xnor_popcount_4bit(hidden_activations, W_HO_0);
    assign output_sum[1] = xnor_popcount_4bit(hidden_activations, W_HO_1);
    
    // Final prediction: argmax(output_sum)
    wire prediction = (output_sum[1] > output_sum[0]);  // 1 = harvest, 0 = not ready

    // ========================================
    // BNN HELPER FUNCTIONS
    // ========================================
    function signed [4:0] xnor_popcount_4bit;
        input [3:0] a;
        input [3:0] b;
        reg [3:0] xnor_result;
        begin
            xnor_result = ~(a ^ b);
            xnor_popcount_4bit = xnor_result[0] + xnor_result[1] + 
                                  xnor_result[2] + xnor_result[3];
        end
    endfunction

    // ========================================
    // CONTROL LOGIC
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hidden_activations <= 4'b0;
            output_activations <= 2'b0;
            ready <= 1'b0;
        end else if (ena) begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    state <= COMPUTE_HIDDEN;
                end
                
                COMPUTE_HIDDEN: begin
                    // Apply sign activation
                    hidden_activations[0] <= (hidden_sum[0] >= 0);
                    hidden_activations[1] <= (hidden_sum[1] >= 0);
                    hidden_activations[2] <= (hidden_sum[2] >= 0);
                    hidden_activations[3] <= (hidden_sum[3] >= 0);
                    state <= COMPUTE_OUTPUT;
                end
                
                COMPUTE_OUTPUT: begin
                    output_activations[0] <= (output_sum[0] >= 0);
                    output_activations[1] <= (output_sum[1] >= 0);
                    ready <= 1'b1;
                    state <= DONE;
                end
                
                DONE: begin
                    ready <= 1'b1;
                    // Stay in DONE state
                end
            endcase
        end
    end

    // ========================================
    // OUTPUT MAPPING
    // ========================================
    assign uo_out[7] = ready & prediction;      // Buzzer (harvest ready)
    assign uo_out[6] = ready & prediction;      // LED (harvest ready)
    assign uo_out[5] = ready;                   // Ready flag
    assign uo_out[4] = prediction;              // Raw prediction
    assign uo_out[3:0] = hidden_activations;    // Debug: hidden layer

endmodule
