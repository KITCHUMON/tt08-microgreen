`include "weights.vh"

module tt_um_microgreen_bnn (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path
    input  wire       ena,      // Enable
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset (active low)
);

    // All outputs enabled
    assign uio_oe = 8'b11111111;
    assign uio_out = 8'b0;

    // Input mapping (4-bit inputs, 4 features)
    wire [3:0] feature_height = ui_in[3:0];
    wire [3:0] feature_color = ui_in[7:4];
    wire [3:0] feature_width = uio_in[3:0];
    wire [3:0] feature_stem = uio_in[7:4];

    // Internal state
    reg [2:0] state;
    localparam IDLE = 3'd0, LOAD_INPUT = 3'd1, COMPUTE_HIDDEN = 3'd2, COMPUTE_OUTPUT = 3'd3, DONE = 3'd4;

    reg [3:0] hidden_act;
    reg [2:0] output_class;

    wire [3:0] input_bin = {binarize(feature_stem), binarize(feature_width), binarize(feature_color), binarize(feature_height)};

    wire signed [4:0] hidden_sum [0:3];
    assign hidden_sum[0] = xnor_popcount(input_bin, W_IH_0) + BIAS_H0;
    assign hidden_sum[1] = xnor_popcount(input_bin, W_IH_1) + BIAS_H1;
    assign hidden_sum[2] = xnor_popcount(input_bin, W_IH_2) + BIAS_H2;
    assign hidden_sum[3] = xnor_popcount(input_bin, W_IH_3) + BIAS_H3;

    wire signed [4:0] output_sum [0:1];
    assign output_sum[0] = xnor_popcount(hidden_act, W_HO_0);
    assign output_sum[1] = xnor_popcount(hidden_act, W_HO_1);

    function [4:0] xnor_popcount;
        input [3:0] a;
        input [3:0] b;
        reg [3:0] x;
        integer i;
        begin
            x = ~(a ^ b);
            xnor_popcount = 0;
            for (i = 0; i < 4; i = i + 1)
                xnor_popcount = xnor_popcount + x[i];
        end
    endfunction

    function binarize;
        input [3:0] val;
        begin
            binarize = (val > 4'd7) ? 1'b1 : 1'b0;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hidden_act <= 4'b0000;
            output_class <= 3'b000;
        end else if (ena) begin
            case (state)
                IDLE: state <= LOAD_INPUT;
                LOAD_INPUT: state <= COMPUTE_HIDDEN;
                COMPUTE_HIDDEN: begin
                    hidden_act[0] <= (hidden_sum[0] >= 0);
                    hidden_act[1] <= (hidden_sum[1] >= 0);
                    hidden_act[2] <= (hidden_sum[2] >= 0);
                    hidden_act[3] <= (hidden_sum[3] >= 0);
                    state <= COMPUTE_OUTPUT;
                end
                COMPUTE_OUTPUT: begin
                    output_class <= (output_sum[0] >= output_sum[1]) ? 0 : 1;
                    state <= DONE;
                end
                DONE: state <= IDLE;
            endcase
        end
    end

    assign uo_out[2:0] = (state == DONE) ? output_class : 3'b000;
    assign uo_out[3] = (state == DONE);
    assign uo_out[7:4] = (state == DONE) ? hidden_act : 4'b0000;

endmodule
