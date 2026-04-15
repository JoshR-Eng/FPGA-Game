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
  parameter SHIP_HEIGHT   = 11'd100,
  parameter ASTR_SMALL    = 7'd12,
  parameter ASTR_MEDIUM   = 7'd24,
  parameter ASTR_LARGE    = 7'd48
  )(
   // System
  input frame_tick,

    // Bullet State
  input [175:0] bul_x_packed,
  input [175:0] bul_y_packed,
  input [15:0]  bul_active_packed,

    // Ship state
  input [10:0] ship_x,
  input [10:0] ship_y,

    // Asteroid Position
  input [175:0] astr_x_packed,
  input [175:0] astr_y_packed,
  input [15:0]  astr_active_packed,


    // Object Hit Flags
  output reg [15:0] bul_hit,
  output reg [15:0] astr_hit,
  output reg        ship_hit
    );
 
//==========================================================
// --- Internal Wires 
//==========================================================

// --- Unflattened arrays
// Bullet
reg [15:0] bul_x      [0:MAX_BULLETS-1];
reg [15:0] bul_y      [0:MAX_BULLETS-1];
reg        bul_active [0:MAX_BULLETS-1];

// Asteroid
reg [15:0] astr_x      [0:MAX_ASTEROIDS-1];
reg [15:0] astr_y      [0:MAX_ASTEROIDS-1];
reg        astr_active [0:MAX_ASTEROIDS-1];



//==========================================================
// --- Collision Logic 
//==========================================================

always @* begin



end


//==========================================================
// --- Unflatten Arrays 
//==========================================================

// --- Bullet Arrays
genvar i;
generate
  for (i=0; i<MAX_BULLETS; i=i+1) begin : unflatten_bullets
    assign bul_x[i]      = bul_x_packed[(i*16)+15 -: (i*16)] ;
    assign bul_y[i]      = bul_y_packed[(i*16)+15 -: (i*16)] ;
    assign bul_active[i] = bul_y_packed[i] ;
  end
endgenerate

// --- Asteroid Arrays
genvar j;
generate
  for (j=0; j<MAX_ASTEROIDS; j=j+1) begin : unflatten_asteroids
    assign astr_x[j]      = astr_x_packed[(j*16)+15 -: (j*16)] ;
    assign astr_y[j]      = astr_y_packed[(j*16)+15 -: (j*16)] ;
    assign astr_active[j] = astr_y_packed[j] ;
  end
endgenerate



endmodule
