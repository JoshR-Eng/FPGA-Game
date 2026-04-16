`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.04.2026 21:39:40 
// Design Name: 
// Module Name: heatDisplay 
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


module heatDisplay #(
  parameter HEAT_THRESHOLD = 8'd200,
  parameter BLINK_BIT      = 4
  )(
    input clk, 
    input rst,
    input frame_tick,

    input [7:0] gun_heat,
    output reg [15:0] LED
    );

// ==========================================================
// --- Blink Counter 
// ==========================================================
reg [4:0] blink_counter;
always @(posedge clk)
  if (frame_tick) 
    blink_counter <= blink_counter + 1'b1;

wire blink = blink_counter[BLINK_BIT]; // toggles every 2^BLINK_BIT frames 

// ==========================================================
// --- Heat to LED Mapping 
// ==========================================================
:

// ==========================================================
// --- END
// ==========================================================
endmodule
