`include "weights.vh"  // Include the generated weights file

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Inputs
    output wire [7:0] uo_out,   // Outputs
    input  wire [7:0] uio_in,   // Bidirectional IOs (input side)
    output wire [7:0] uio_out,  // Bidirectional IOs (output side)
    output wire [7:0] uio_oe,   // Bidirectional IOs (output enable)
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

    // Enable all outputs by default
    assign uio_oe = 8'b11111111;
    assign uio_out = 8'b0;

    // Map inputs to feature signals
    wire [3:0] feature_height = ui_in[3:0];    // Height
    wire [3:0] feature_color = ui_in[7:4];    // Color
    wire [3:0] feature_width = uio_in[3:0];    // Width
    wire [3:0] feature_stem = uio_in[7:4];    // Stem thickness

    // Hidden layer and output layer signals
    reg [3:0] hidden_act;
    reg [2:0] output_class;
    
    // BNN computation logic (from your training script logic)
    // This uses the weights from weights.vh that you included
    // For example, you might have logic like this:
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            hidden_act <= 4'b0;
            output_class <= 3'b0;
        end else if (ena) begin
            // Perform your BNN computations here using XNOR-popcount, etc.
            // Use the weights like W_IH_0, W_HO_0, and biases from the included file
            // Set hidden_act and output_class accordingly
        end
    end

    // Output mapping
    assign uo_out[2:0] = output_class; // Classification result
    assign uo_out[3] = (state == DONE); // Ready signal
    assign uo_out[7:4] = hidden_act;  // Debug hidden layer state

endmodule
