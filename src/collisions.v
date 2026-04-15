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
  input [31:0]  astr_size_packed,


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
wire [10:0] bul_x      [0:MAX_BULLETS-1];
wire [10:0] bul_y      [0:MAX_BULLETS-1];
wire        bul_active [0:MAX_BULLETS-1];

// Asteroid
wire [10:0] astr_x      [0:MAX_ASTEROIDS-1];
wire [10:0] astr_y      [0:MAX_ASTEROIDS-1];
wire        astr_active [0:MAX_ASTEROIDS-1];
wire [1:0]  astr_size   [0:MAX_ASTEROIDS-1];
wire [6:0]  half        [0:MAX_ASTEROIDS-1]; // No. of Pixels for astr. half-size 


//==========================================================
// --- Collision Logic 
//==========================================================

integer b, a; // Loop counters

always @* begin

  // Default 'Hit Flags' to 0
  bul_hit   = 16'b0;
  astr_hit  = 16'b0;
  ship_hit  = 1'b0;


  // --- Bullet vs. Asteroid
  for (b=0; b<MAX_BULLETS; b=b+1) begin
    for (a=0; a<MAX_ASTEROIDS; a=a+1) begin
      
      // Determine if bullet is within asteroid 
      if  (bul_active[b] && astr_active[a] &&
          (bul_x[b] + BULLET_WIDTH  > astr_x[a] - half[a]) &&
          (bul_x[b]                 < astr_x[a] + half[a]) &&
          (bul_y[b] + BULLET_HEIGHT > astr_y[a] - half[a]) &&
          (bul_y[b]                 < astr_y[a] + half[a])) 
      begin
        bul_hit[b]  = 1'b1;
        astr_hit[a] = 1'b1;
      end
    end
  end


  // --- Ship vs. Asteroid
  for (a=0; a<MAX_ASTEROIDS; a=a+1) begin
    if  (astr_active[a] &&
        (ship_x + SHIP_WIDTH  > astr_x[a] - half[a]) &&
        (ship_x               < astr_x[a] + half[a]) &&
        (ship_y + SHIP_HEIGHT > astr_y[a] - half[a]) &&
        (ship_y               < astr_y[a] + half[a]))
    begin
      ship_hit = 1'b1;
    end  
  end

end



//==========================================================
// --- Determine asteroid sizes 
//==========================================================

// Resolve half-size for asteroid
function [6:0] astr_half_size;
    input [1:0] size;
    begin
        case (size)
            2'b10:   astr_half_size = ASTR_LARGE;
            2'b01:   astr_half_size = ASTR_MEDIUM;
            default: astr_half_size = ASTR_SMALL;
        endcase
    end
endfunction



//==========================================================
// --- Unflatten Arrays 
//==========================================================

// --- Bullet Arrays
genvar i;
generate
  for (i=0; i<MAX_BULLETS; i=i+1) begin : unflatten_bullets
    assign bul_x[i]      = bul_x_packed[(i*11)+10 -: 11] ;
    assign bul_y[i]      = bul_y_packed[(i*11)+10 -: 11] ;
    assign bul_active[i] = bul_active_packed[i] ;
  end
endgenerate

// --- Asteroid Arrays
genvar j;
generate
  for (j=0; j<MAX_ASTEROIDS; j=j+1) begin : unflatten_asteroids
    assign astr_x[j]      = astr_x_packed[(j*11)+10 -: 11] ;
    assign astr_y[j]      = astr_y_packed[(j*11)+10 -: 11] ;
    assign astr_active[j] = astr_active_packed[j] ;
    assign astr_size[j]   = astr_size_packed[(j*2)+1 -: 2];

    // This then takes `astr_size` into pixel size
    assign half[j]        = astr_half_size(astr_size[j]);
  end
endgenerate



endmodule
