`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.04.2026 16:25:32 
// Design Name: 
// Module Name: collisions 
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


module collisions #(
  parameter MAX_BULLETS   = 16,
  parameter MAX_ASTEROIDS = 16,
  parameter BULLET_WIDTH  = 11'd10,
  parameter BULLET_HEIGHT = 11'd10,
  parameter SHIP_WIDTH    = 11'd100,
  parameter SHIP_HEIGHT   = 11'd100
  )(
   // System
  input clk,
  input rst,
  input frame_tick,

    // Bullet State
  input [175:0] bul_x_packed,
  input [175:0] bul_y_packed,
  input [15:0] bul_active_packed,

    // Ship state
  input [10:0] ship_x,
  input [10:0] ship_y,

    // Asteroid Position
  input [175:0] astr_x_packed,
  input [175:0] astr_y_packed,
  input [15:0] astr_active_packed
    );
 

endmodule
