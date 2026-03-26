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
      // Bullet Config
  parameter MAX_BULLETS         = 16,
  parameter BULLET_SPEED        = 8,
  parameter HEAT_PER_SHOT       = 8'd32,
  parameter COOLDOWN_RATE       = 8'd2,
  parameter OVERHEAT_THRESHOLD  = 8'd200,
      // Screen Size
  parameter SCREEN_X_MAX        = 11'd1430,
  parameter SCREEN_Y_MAX        = 11'd890
  )(
  // System
  input clk,
  input rst,
  input frame_tick,

  // Mouse Input
  input fire_trigger,

  // Ship Position
  input [10:0] ship_x, ship_y,

  // Bullet Position & existence (single bullet outputs for synthesis)
  output [10:0] bullet_x,
  output [10:0] bullet_y,
  output bullet_active,
  output [7:0] gun_heat,
  output [15:0] LED
  );


// ==========================================================
// --- Internal Signals 
// ==========================================================

// Bullets
reg [10:0] bullet_x_reg       [0:MAX_BULLETS-1];
reg [10:0] bullet_y_reg       [0:MAX_BULLETS-1];
reg        bullet_active_reg  [0:MAX_BULLETS-1];
reg [3:0]  spawn_slot;    // Which spot to spawn bullet? (0-15)
reg [7:0]  gun_heat_reg;  // Current heat level
integer i;                // Loop counter block




// ==========================================================
// --- Bullet Logic 
// ==========================================================
  always @(posedge clk) begin
    if (!rst) begin
      for (i=0; i < MAX_BULLETS; i=i+1) begin
        // Reset State
        bullet_active_reg[i] <= 1'b0;
        bullet_x_reg[i] <= 11'd0;
        bullet_y_reg[i] <= 11'd0;
      end
      spawn_slot <= 4'd0;
      gun_heat_reg <= 8'd0;
    end else if (frame_tick) begin

      // Spawning Logic
      if (fire_trigger && (gun_heat_reg < OVERHEAT_THRESHOLD)
                       && !bullet_active_reg[spawn_slot]) begin
          bullet_active_reg[spawn_slot] <= 1'b1;
          bullet_x_reg[spawn_slot] <= ship_x;
          bullet_y_reg[spawn_slot] <= ship_y;
          gun_heat_reg <= gun_heat_reg + HEAT_PER_SHOT;
          spawn_slot <= spawn_slot + 1'b1; // Round Robin
      end
      
      // Movement Logic
      for (i=0; i < MAX_BULLETS; i=i+1) begin
        if (bullet_active_reg[i]) begin
          // Move Bullet
          bullet_x_reg[i] <= bullet_x_reg[i] + BULLET_SPEED;
          // Check bounds
          if ( bullet_x_reg[i] > SCREEN_X_MAX ) begin
            bullet_active_reg[i] <= 1'b0;
          end
        end
      end

      // Heat Cooldown Logic
    if (gun_heat_reg >= COOLDOWN_RATE)
      gun_heat_reg <= gun_heat_reg - COOLDOWN_RATE;
    else
      gun_heat_reg <= 8'd0;

  end  // Close else if (frame_tick)
end    // Close always @(posedge clk)

// ==========================================================
// --- Final Assignment 
// ==========================================================
 
  // Output only bullet[0] for synthesis compatibility
  // Internal arrays still handle 16 bullets
  assign bullet_x = bullet_x_reg[0];
  assign bullet_y = bullet_y_reg[0];
  assign bullet_active = bullet_active_reg[0];

  assign gun_heat = gun_heat_reg;


  // Map 16 LEDs to number of LEDs
  //      Could work on this logic?
  //      LED[13:0]: Linear Increase as Temp increase
  //      LED[14]  : Warning LED - lights when close to max temp
  //      LED[15]  : Overheat LED - Can't shoot when this is on
  assign LED[0]  = (gun_heat_reg >= 8'd16);
  assign LED[1]  = (gun_heat_reg >= 8'd32);
  assign LED[2]  = (gun_heat_reg >= 8'd48);
  assign LED[3]  = (gun_heat_reg >= 8'd64);
  assign LED[4]  = (gun_heat_reg >= 8'd80);
  assign LED[5]  = (gun_heat_reg >= 8'd96);
  assign LED[6]  = (gun_heat_reg >= 8'd112);
  assign LED[7]  = (gun_heat_reg >= 8'd128);
  assign LED[8]  = (gun_heat_reg >= 8'd144);
  assign LED[9]  = (gun_heat_reg >= 8'd160);
  assign LED[10] = (gun_heat_reg >= 8'd176);
  assign LED[11] = (gun_heat_reg >= 8'd192);
  assign LED[12] = (gun_heat_reg >= 8'd208);
  assign LED[13] = (gun_heat_reg >= 8'd224);
  assign LED[14] = (gun_heat_reg >= 8'd192);
  assign LED[15] = (gun_heat_reg >= OVERHEAT_THRESHOLD);

endmodule
