`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 11:52:08
// Design Name: 
// Module Name: game_top
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


module game_top(
    // System
  input clk,
  input rst,
  input frame_tick

    // Bullet State
  input [175:0] bul_x_packed,
  input [175:0] bul_y_packed,
  input [15:0] bul_active_packed,

    // Ship state
  input [10:0] ship_x,
  input [10:0] ship_y,

    // Asteroid Position
  input [175:0] astr_x_packed,
  input [175:0] astr_x_packed,
  input [15:0] astr_active_packed
    );
 
endmodule
