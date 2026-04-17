`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02.02.2026 14:31:41
// Design Name: 
// Module Name: scoreDisplay 
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module scoreDisplay(
    // System
    input clk, 
    input rst,

    // Display Value
    input [16:0] score, 
    input [1:0]  health,

    // Seven-seg Pin
    output a, b, c, d, e, f, g,
    output [7:0] an 
    );
    
// ==========================================================
// --- Internal Wiring
// ==========================================================
    wire led_clk;
    
    reg [3:0] dig_sel;
    reg [16:0] clk_count = 11'd0;
    
// ==========================================================
// --- Ring Counter 
// ==========================================================

    // Make a counter that uses the clock
    always @(posedge clk) 
        clk_count <= clk_count + 1'b1;
    assign led_clk = clk_count[16]; // 2^16 slower than clk_count
    
    // Ring Counter
    //  Since 7-seg is active low, 0 turns the digit on
    //  The index of image on is then shifted up
    reg [7:0] led_strobe = 8'b11111110;
    always @(posedge led_clk)
        led_strobe <= {led_strobe[6:0],led_strobe[7]};
    assign an = led_strobe;
    
    // Index Counter
    //  Acts as pointer to identify which one is on
    reg [2:0] led_index = 3'd0;
        always @(posedge led_clk)
    led_index <= led_index + 1'b1;
    
    
// ==========================================================
// --- Binary -> Decimal Mapping 
// ==========================================================

wire [3:0] thousands  = score           /1000;
wire [3:0] hundreds   = (score % 1000)  /100;
wire [3:0] tens       = (score % 100 )  /10;
wire [3:0] units      = (score % 10);


// ==========================================================
// --- Seven-Seg Assignment 
// ==========================================================

    // 
    always@*    
        case (led_index)
            3'd0: dig_sel = units;
            3'd1: dig_sel = tens;
            3'd2: dig_sel = hundreds;
            3'd3: dig_sel = thousands;
            3'd4: dig_sel = 4'b0;
            3'd5: dig_sel = 4'b0;
            3'd6: dig_sel = 4'b0;
            3'd7: dig_sel = { 2'b0, health};
        endcase        
    
    sevenseg inst (.num(dig_sel), .a(a), .b(b), .c(c), .d(d), .e(e), .f(f), .g(g));
    
   
endmodule
