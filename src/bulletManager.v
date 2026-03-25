`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 24.03.2026 16:32:11 
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


module bulletManager #(
  parameter BULLET_SPEED = 8,
  parameter SCREEN_X_MAX = 11'd1430
  )(
  // System
  input clk,
  input rst,
  input frame_tick,

  // Mouse Input
  input fire_trigger,

  // Ship Position
  input [10:0] ship_x, ship_y,

  // Bullet Position & existance
  output [10:0] bullet_x, bullet_y,
  output bullet_active
  );


// ==========================================================
// --- Internal Signals 
// ==========================================================

// Bullets
reg [10:0] bullet_x_reg;
reg [10:0] bullet_y_reg;
reg        bullet_active_reg;




// ==========================================================
// --- Bullet Logic 
// ==========================================================
  always @(posedge clk) begin
    if (!rst) begin
      // Reset State
      bullet_active_reg <= 1'b0;
      bullet_x_reg <= 11'd0;
      bullet_y_reg <= 11'd0;
    end else if (frame_tick) begin

      // Spawning Logic
      if (fire_trigger && !bullet_active_reg) begin
          bullet_active_reg <= 1'b1;
          bullet_x_reg <= ship_x;
          bullet_y_reg <= ship_y;
      end
      
      // Movement Logic
      if (bullet_active_reg) begin
        // Move Bullet
        bullet_x_reg <= bullet_x_reg + BULLET_SPEED;
        // Check bounds
        if ( bullet_x_reg > SCREEN_X_MAX ) begin
          bullet_active_reg <= 1'b0;
        end
      end
    end
  end

// ==========================================================
// --- Final Assignment 
// ==========================================================
  assign bullet_x = bullet_x_reg;
  assign bullet_y = bullet_y_reg;
  assign bullet_active = bullet_active_reg;


endmodule
