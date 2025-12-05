/*
 * Microgreen Classifier - BNN
 * Reads 4 inputs, applies weights from weights.vh, outputs decision.
 */

`default_nettype none

module tt_um_microgreen_classifier (
    input  wire [7:0] ui_in,    // Dedicated inputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset_n - low to reset
    output wire [7:0] uo_out    // Dedicated outputs
);

    // ==========================================
    // 1. LOAD WEIGHTS
    // ==========================================
    // This loads the parameter definitions from your uploaded file
    `include "weights.vh"

    // ==========================================
    // 2. INPUT MAPPING
    // ==========================================
    // Map the first 4 input bits to our features
    wire [3:0] features = ui_in[3:0]; 

    // ==========================================
    // 3. HIDDEN LAYER COMPUTATION
    // ==========================================
    // We declare the variables to hold the sums
    reg signed [7:0] h0_sum, h1_sum, h2_sum, h3_sum;
    
    // This 'always' block is CRITICAL. It tells the chip:
    // "Whenever inputs change, recalculate these math equations"
    always @(*) begin
        // Neuron 0
        h0_sum = BIAS_H0;
        if (features[0]) h0_sum = h0_sum + $signed(W_IH_0[3] ? -1 : 1); 
        if (features[1]) h0_sum = h0_sum + $signed(W_IH_0[2] ? -1 : 1);
        if (features[2]) h0_sum = h0_sum + $signed(W_IH_0[1] ? -1 : 1);
        if (features[3]) h0_sum = h0_sum + $signed(W_IH_0[0] ? -1 : 1);
        
        // Neuron 1
        h1_sum = BIAS_H1;
        if (features[0]) h1_sum = h1_sum + $signed(W_IH_1[3] ? -1 : 1); 
        if (features[1]) h1_sum = h1_sum + $signed(W_IH_1[2] ? -1 : 1);
        if (features[2]) h1_sum = h1_sum + $signed(W_IH_1[1] ? -1 : 1);
        if (features[3]) h1_sum = h1_sum + $signed(W_IH_1[0] ? -1 : 1);

        // Neuron 2
        h2_sum = BIAS_H2;
        if (features[0]) h2_sum = h2_sum + $signed(W_IH_2[3] ? -1 : 1); 
        if (features[1]) h2_sum = h2_sum + $signed(W_IH_2[2] ? -1 : 1);
        if (features[2]) h2_sum = h2_sum + $signed(W_IH_2[1] ? -1 : 1);
        if (features[3]) h2_sum = h2_sum + $signed(W_IH_2[0] ? -1 : 1);

        // Neuron 3
        h3_sum = BIAS_H3;
        if (features[0]) h3_sum = h3_sum + $signed(W_IH_3[3] ? -1 : 1); 
        if (features[1]) h3_sum = h3_sum + $signed(W_IH_3[2] ? -1 : 1);
        if (features[2]) h3_sum = h3_sum + $signed(W_IH_3[1] ? -1 : 1);
        if (features[3]) h3_sum = h3_sum + $signed(W_IH_3[0] ? -1 : 1);
    end

    // Activation (ReLU/Step): If sum > 0, the neuron fires (1), else silence (0)
    wire [3:0] hidden_out;
    assign hidden_out[0] = (h0_sum > 0);
    assign hidden_out[1] = (h1_sum > 0);
    assign hidden_out[2] = (h2_sum > 0);
    assign hidden_out[3] = (h3_sum > 0);

    // ==========================================
    // 4. OUTPUT LAYER COMPUTATION
    // ==========================================
    reg signed [7:0] out_growth_sum, out_harvest_sum;

    always @(*) begin
        // Growth Output Node
        out_growth_sum = 0;
        if (hidden_out[0]) out_growth_sum = out_growth_sum + $signed(W_HO_0[3] ? -1 : 1);
        if (hidden_out[1]) out_growth_sum = out_growth_sum + $signed(W_HO_0[2] ? -1 : 1);
        if (hidden_out[2]) out_growth_sum = out_growth_sum + $signed(W_HO_0[1] ? -1 : 1);
        if (hidden_out[3]) out_growth_sum = out_growth_sum + $signed(W_HO_0[0] ? -1 : 1);

        // Harvest Output Node
        out_harvest_sum = 0;
        if (hidden_out[0]) out_harvest_sum = out_harvest_sum + $signed(W_HO_1[3] ? -1 : 1);
        if (hidden_out[1]) out_harvest_sum = out_harvest_sum + $signed(W_HO_1[2] ? -1 : 1);
        if (hidden_out[2]) out_harvest_sum = out_harvest_sum + $signed(W_HO_1[1] ? -1 : 1);
        if (hidden_out[3]) out_harvest_sum = out_harvest_sum + $signed(W_HO_1[0] ? -1 : 1);
    end

    // ==========================================
    // 5. FINAL OUTPUTS
    // ==========================================
    // Compare the two sums. Whichever is higher wins.
    assign uo_out[0] = (out_growth_sum > out_harvest_sum); // LED 0 = Growth
    assign uo_out[1] = (out_harvest_sum > out_growth_sum); // LED 1 = Harvest
    
    // Tie off unused pins to 0 (Required by Tiny Tapeout)
    assign uo_out[7:2] = 0; 
    assign uio_out = 0;
    assign uio_oe  = 0;

endmodule
