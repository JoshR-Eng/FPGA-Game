`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 11:52:08
// Design Name: 
// Module Name: asteroidManager
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


module asteroidManager#(
  parameter MAX_ASTEROIDS = 16,
  parameter SCREEN_X_MIN  = 11'd0,
  parameter SCREEN_X_MAX  = 11'd1440,
  parameter SCREEN_Y_MIN  = 11'd100,
  parameter SCREEN_Y_MAX  = 11'900
  )(
    // System
  input clk,
  input rst,
  input frame_tick,

    // Difficulty
  input [1:0] difficulty,

    // Collision feedback

    // Asteroid States & Positions
  input  [31:0]   ast_hit,
  output [175:0]  astr_x_packed,
  output [175:0]  astr_y_packed,
  output [15:0]   astr_active_packed,
  output          on_asteroid
  );
 
endmodule
