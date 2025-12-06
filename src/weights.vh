// AUTO-GENERATED WEIGHTS
// Training acc: 0.894
// Test acc: 0.867

// Input to Hidden (4x4)
parameter [3:0] W_IH_0 = 4'b1001;
parameter [3:0] W_IH_1 = 4'b1011;
parameter [3:0] W_IH_2 = 4'b1100;
parameter [3:0] W_IH_3 = 4'b1110;

// Hidden to Output (4x2)
parameter [3:0] W_HO_0 = 4'b1010;
parameter [3:0] W_HO_1 = 4'b0101;

// Hidden Layer Biases
parameter signed [3:0] BIAS_H0 = 4'sd1;
parameter signed [3:0] BIAS_H1 = 4'sd1;
parameter signed [3:0] BIAS_H2 = 4'sd-1;
parameter signed [3:0] BIAS_H3 = 4'sd1;
