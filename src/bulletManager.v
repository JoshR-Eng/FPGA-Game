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
  parameter SCREEN_X_MIN        = 11'd10,
  parameter SCREEN_Y_MAX        = 11'd890,
  parameter SCREEN_Y_MIN        = 11'd10,
      // Ship Size
  parameter SHIP_WIDTH          = 11'd100,
  parameter SHIP_HEIGHT         = 11'd100,
  )(
    // System
  input clk,
  input rst,
  input frame_tick,
  input new_game,

    // Mouse Input
  input fire_trigger,
  input [10:0] cursor_x,
  input [10:0] cursor_y,

    // Drawing Position
  input [10:0] curr_x, curr_y,

    // Ship Position
  input [10:0] ship_x, ship_y,

    // Boolean if curr_x/y is on bullet or cursor
  output reg on_bullet,

    // Bullet Position & State
  input  [15:0]  bul_hit,
  output [175:0] bul_x_packed,
  output [175:0] bul_y_packed,
  output [15:0] bul_active_packed,
  output [7:0] gun_heat
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
reg        spawned = 1'b0;
reg signed [3:0] spawn_vx_reg, spawn_vy_reg;

reg [7:0] gun_heat_reg;
assign gun_heat = gun_heat_reg;


// ==========================================================
// --- Bullet Velocity Calculation 
// ==========================================================

// 1. Determine distance between cursor and ship
wire signed [11:0] raw_dx = {1'b0, cursor_x} - {1'b0, (ship_x + SHIP_WIDTH/2)};
wire signed [11:0] raw_dy = {1'b0, cursor_y} - {1'b0, (ship_y + SHIP_HEIGHT/2)};

// 2. Get absolute value from signed value
wire [11:0] abs_dx = raw_dx[11] ? {~raw_dx + 12'd1} : raw_dx;
wire [11:0] abs_dy = raw_dy[11] ? {~raw_dy + 12'd1} : raw_dy;

// 3. Determine dominant component
wire [11:0] dominant = (abs_dx >= abs_dy) ? abs_dx : abs_dy;

// 4. Next Downscale both values by a common ratio
//      It's putting an signed 11-bit -> signed 4-bit
//      so just find the MSB and shift that down 
//      so that it's in bit position [2]
//      Bit shifting is most efficient so need to determine
//      suitable power of 2 to shift by
reg [3:0] shift_n;
always @* begin
  if      (dominant_reg >= 10'd512) shift_n = 4'd8;
  else if (dominant_reg >= 10'd256) shift_n = 4'd7;
  else if (dominant_reg >= 10'd128) shift_n = 4'd6;
  else if (dominant_reg >= 10'd64)  shift_n = 4'd5;
  else if (dominant_reg >= 10'd32)  shift_n = 4'd4;
  else if (dominant_reg >= 10'd16)  shift_n = 4'd3;
  else if (dominant_reg >= 10'd8)   shift_n = 4'd2;
  else                          shift_n = 4'd0;
end

// 5. Pipeline stages 
//      Breaks the barrel shifter timing path
reg [3:0]   shift_n_reg;
reg [11:0]  dominant_reg;
always @(posedge clk) begin
  shift_n_reg   <= shift_n;
  dominant_reg  <= dominant;
end

// 5. Scale velocities
wire signed [10:0] scaled_dx = raw_dx >>> shift_n_reg; // arithmetic right shift
wire signed [10:0] scaled_dy = raw_dy >>> shift_n_reg; 




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

  end else if (new_game) begin
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      bullet_active[j] <= 1'b0;
      bullet_x[j] <= 11'd0;
      bullet_y[j] <= 11'd0;
    end
    gun_heat_reg <= 8'd0;

  end else if (frame_tick) begin
    spawned = 1'b0;

    // Pipeline the velocity calculation
    spawn_vx_reg <= (scaled_dx > 7)  ? 4'd7  : 
                    (scaled_dx < -7) ? -4'd7 : scaled_dx[3:0];
    spawn_vy_reg <= (scaled_dy > 7)  ? 4'd7  :
                    (scaled_dy < -7) ? -4'd7 : scaled_dy[3:0];

    // Spawning bullet logic
    if (fire_pending && (gun_heat_reg<OVERHEAT_THRESHOLD)
        && (dominant_reg > 0) ) begin
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      if (!bullet_active[j] && !spawned) begin
        // Spawn bullet at ship loc
        bullet_x[j] <= ship_x + (SHIP_WIDTH / 2);
        bullet_y[j] <= ship_y + (SHIP_HEIGHT / 2);
        // Assign speed based on crosshair
        vel_x[j] <= spawn_vx_reg;
        vel_y[j] <= spawn_vy_reg;
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
      // Deactivate Bullet if it's hit an asteroid
      if (bul_hit[j]) begin
        bullet_active[j] <= 1'b0;
      // Else move the bullet
      end else if (bullet_active[j]) begin
        // Deactivate if out of bounds
        if (($signed({1'b0, bullet_x[j]}) + vel_x[j] > $signed({1'b0, SCREEN_X_MAX})) ||
            ($signed({1'b0, bullet_x[j]}) + vel_x[j] < $signed({1'b0, SCREEN_X_MIN})) ||
            ($signed({1'b0, bullet_y[j]}) + vel_y[j] > $signed({1'b0, SCREEN_Y_MAX})) ||
            ($signed({1'b0, bullet_y[j]}) + vel_y[j] < $signed({1'b0, SCREEN_Y_MIN})) )
            bullet_active[j] <= 1'b0;
        else begin
            bullet_x[j] <= $unsigned($signed({1'b0, bullet_x[j]}) + vel_x[j]);
            bullet_y[j] <= $unsigned($signed({1'b0, bullet_y[j]}) + vel_y[j]);
        end
      end
    end
  end
end


// ==========================================================
// --- Flatten Arrays for IO 
// ==========================================================

// --- Flatten Arrays so it can be passed outside the module
genvar k;
generate
  for (k=0; k< MAX_BULLETS; k=k+1 ) begin : pack_bullets
    assign bul_x_packed[ (11*k)+10 -: 11] = bullet_x[k];
    assign bul_y_packed[ (11*k)+10 -: 11] = bullet_y[k];
    assign bul_active_packed[k]           = bullet_active[k];
  end
endgenerate



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
