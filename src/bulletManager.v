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
  parameter BULLET_WIDTH        = 4'd10,
  parameter BULLET_HEIGHT       = 4'd10,
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
  input [4:0] btn, // Temporary use of buttons before mouse

  // Drawing Position
  input [10:0] curr_x, curr_y,

  // Ship Position
  input [10:0] ship_x, ship_y,

  // Boolean if curr_x/y is on bullet pos
  output reg on_bullet
  );


// ==========================================================
// --- Internal Signals 
// ==========================================================

// Bullets Position
reg [10:0] bullet_x       [0:MAX_BULLETS-1];
reg [10:0] bullet_y       [0:MAX_BULLETS-1];

// Bullet Velocity
reg signed [3:0] vel_x    [0:MAX_BULLETS-1];
reg signed [3:0] vel_y    [0:MAX_BULLETS-1];

// Bullet Spawning
reg        bullet_active  [0:MAX_BULLETS-1];
reg        spawned;

// Bullet Heating
reg [7:0]  gun_heat_reg;  // Current heat level




// ==========================================================
// --- Bullet Logic 
// ==========================================================

// --- Ensure fire_trigger is only enabled for a single clock cycle
reg fire_prev;
wire fire_pulse = fire_trigger && !fire_prev;
reg fire_pending;
always @(posedge clk) begin
  fire_prev <= fire_trigger;
  if (!rst)
      fire_pending <= 1'b0;
  else if (fire_pulse)
      fire_pending <= 1'b1;
  else if (frame_tick)
      fire_pending <= 1'b0;
end


// --- Spawn bullet on trigger
integer j;
always @(posedge clk) begin
  // Reset Logic
  if (!rst) begin
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      bullet_active[j] <= 1'b0;
      bullet_x[j] <= 11'd0;
      bullet_y[j] <= 11'd0;
    end
    gun_heat_reg <= 8'd0;

  end else if (frame_tick) begin
    spawned = 1'b0;

    // Spawning bullet logic
    if (fire_pending && (gun_heat_reg<OVERHEAT_THRESHOLD)) begin
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      if (!bullet_active[j] && !spawned) begin
        // Spawn bullet at ship loc
        bullet_x[j] <= ship_x;
        bullet_y[j] <= ship_y;
        // Toggle bullet as active 
        bullet_active[j]  <= 1'b1;
        spawned = 1'b1;
        // Add bullet heat
        gun_heat_reg <= gun_heat_reg + HEAT_PER_SHOT;
      end
    end

    // Cooldown bullet otherwise 
    end else begin
      if (gun_heat_reg >= COOLDOWN_RATE)
        gun_heat_reg <= gun_heat_reg - COOLDOWN_RATE;
      else
        gun_heat_reg <= 8'd0;
    end

    // Bullet Movement Logic ...
    // Should start with basic movement to the right first?
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      if (bullet_active[j]) begin
        if ( (bullet_x[j]+BULLET_SPEED) > SCREEN_X_MAX) begin
          bullet_active[j] <= 1'b0;
        end else
          bullet_x[j] <= bullet_x[j] + BULLET_SPEED;
      end
    end
  end
end


// ==========================================================
// --- Drawing Bullet
// ==========================================================

integer i;
always @* begin
  on_bullet = 1'b0;
  for (i=0; i<MAX_BULLETS; i=i+1) begin
    if (bullet_active[i] &&
        (curr_x >= bullet_x[i]) && (curr_x < bullet_x[i]+BULLET_WIDTH) &&
        (curr_y >= bullet_y[i]) && (curr_y < bullet_y[i]+BULLET_HEIGHT))
        on_bullet = 1'b1;
  end
end


endmodule
