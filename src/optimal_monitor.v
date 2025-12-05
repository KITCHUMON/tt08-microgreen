module optimal_parameter_monitor (
    input wire clk,
    input wire rst_n,
    input wire [7:0] temperature,    // From DHT22 (°C)
    input wire [7:0] humidity,       // From DHT22 (% RH)
    input wire [7:0] light_level,    // From BH1750
    input wire [7:0] moisture,       // From capacitive sensor
    
    output reg temp_optimal,
    output reg humidity_optimal,
    output reg light_optimal,
    output reg moisture_optimal,
    output reg [7:0] system_health   // 0-100% health score
);

    // Optimal ranges (can be adjusted)
    localparam TEMP_MIN = 8'd18;
    localparam TEMP_MAX = 8'd24;
    localparam HUMID_MIN = 8'd50;
    localparam HUMID_MAX = 8'd70;
    localparam LIGHT_MIN = 8'd40;    // Scaled 0-100
    localparam LIGHT_MAX = 8'd80;
    localparam MOISTURE_MIN = 8'd60;
    localparam MOISTURE_MAX = 8'd80;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            temp_optimal <= 1'b0;
            humidity_optimal <= 1'b0;
            light_optimal <= 1'b0;
            moisture_optimal <= 1'b0;
            system_health <= 8'd0;
        end else begin
            // Check each parameter
            temp_optimal <= (temperature >= TEMP_MIN && 
                            temperature <= TEMP_MAX);
            humidity_optimal <= (humidity >= HUMID_MIN && 
                                humidity <= HUMID_MAX);
            light_optimal <= (light_level >= LIGHT_MIN && 
                             light_level <= LIGHT_MAX);
            moisture_optimal <= (moisture >= MOISTURE_MIN && 
                                moisture <= MOISTURE_MAX);
            
            // Calculate health score (0-100)
            system_health <= (temp_optimal * 25) + 
                            (humidity_optimal * 25) +
                            (light_optimal * 25) +
                            (moisture_optimal * 25);
        end
    end
    
endmodule
