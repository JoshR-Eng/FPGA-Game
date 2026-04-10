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
      // Crosshair
  parameter CURSOR_ARM          = 8,   // Half-length of each bar
  parameter CURSOR_THICK        = 1, // Half-width of each bar
  parameter CURSOR_SPEED        = 10
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
  output reg on_bullet,

  // Boolean if curr_x/y is on cursor
  output on_cursor
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
    if (fire_pending && (gun_heat_reg<OVERHEAT_THRESHOLD)
        && (dominant > 0) ) begin
    for (j=0; j<MAX_BULLETS; j=j+1) begin
      if (!bullet_active[j] && !spawned) begin
        // Spawn bullet at ship loc
        bullet_x[j] <= ship_x + (SHIP_WIDTH / 2);
        bullet_y[j] <= ship_y + (SHIP_HEIGHT / 2);
        // Assign speed based on crosshair
        vel_x[j] <= spawn_vx;
        vel_y[j] <= spawn_vy;
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
        // Deactivate if out of bounds
        if (bullet_x[j] + vel_x[j] > SCREEN_X_MAX) || 
           (bullet_x[j] + vel_x[j] < SCREEN_X_MIN) ||
           (bullet_y[j] + vel_y[j] > SCREEN_Y_MAX) || 
           (bullet_y[j] + vel_y[j] < SCREEN_Y_MIN) )
            bullet_active[j] <= 1'b0;
        else begin
            bullet_x[j] <= bullet_x[j] + vel_x[j];
            bullet_y[j] <= bullet_y[j] + vel_y[j];
        end
      end
    end
  end
end




// ==========================================================
// --- Crosshair 
// ==========================================================

// Should very soon take this out of the bulletManager module
// for now I will control direction with the buttons
// but eventually I want to use the mouse for this

reg [10:0] cursor_x, cursor_y;

assign on_cursor = (
  // Horizontal bar
  (curr_x >= (cursor_x - CURSOR_ARM)   ) && (curr_x <= (cursor_x + CURSOR_ARM)   ) &&
  (curr_y >= (cursor_y - CURSOR_THICK) ) && (curr_y <= (cursor_y + CURSOR_THICK) ) 
  ||
  // Vertical bar
  (curr_x >= (cursor_x - CURSOR_THICK) )  && (curr_x <= (cursor_x + CURSOR_THICK) ) &&
  (curr_y >= (cursor_y - CURSOR_ARM)   )  && (curr_y <= (cursor_y + CURSOR_ARM)   ) 
  );

// Crosshair movement
// Crosshair movement
always @(posedge clk) begin
  if (!rst) begin
    cursor_x <= 11'd720;
    cursor_y <= 11'd440;
  end else if (frame_tick) begin

    // X axis 
    if      (btn[2] && cursor_x > (SCREEN_X_MIN + CURSOR_ARM + CURSOR_SPEED))
        cursor_x <= cursor_x - CURSOR_SPEED;
    else if (btn[2])
        cursor_x <= SCREEN_X_MIN + CURSOR_ARM;    // clamp — guarantees cursor_x >= CURSOR_ARM
    else if (btn[3] && cursor_x < (SCREEN_X_MAX - CURSOR_ARM - CURSOR_SPEED))
        cursor_x <= cursor_x + CURSOR_SPEED;
    else if (btn[3])
        cursor_x <= SCREEN_X_MAX - CURSOR_ARM;

    // Y axis 
    if      (btn[1] && cursor_y > (SCREEN_Y_MIN + CURSOR_ARM + CURSOR_SPEED))
        cursor_y <= cursor_y - CURSOR_SPEED;
    else if (btn[1])
        cursor_y <= SCREEN_Y_MIN + CURSOR_ARM;    // clamp — guarantees cursor_y >= CURSOR_ARM
    else if (btn[4] && cursor_y < (SCREEN_Y_MAX - CURSOR_ARM - CURSOR_SPEED))
        cursor_y <= cursor_y + CURSOR_SPEED;
    else if (btn[4])
        cursor_y <= SCREEN_Y_MAX - CURSOR_ARM;

  end
end



// ==========================================================
// --- Bullet Velocity Calculation 
// ==========================================================

// 1. Determine distance between cursor and ship
wire signed [11:0] raw_dx = {1'b0, cursor_x} - {1'b0, (ship_x + SHIP_WIDTH/2)}
wire signed [11:0] raw_dy = {1'b0, cursor_y} - {1'b0, (ship_y + SHIP_WIDTH/2)}

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
  if      (dominant >= 10'd512) shift_n = 7;
  else if (dominant >= 10'd256) shift_n = 6;
  else if (dominant >= 10'd128) shift_n = 5;
  else if (dominant >= 10'd64)  shift_n = 4;
  else if (dominant >= 10'd32)  shift_n = 3;
  else if (dominant >= 10'd16)  shift_n = 2;
  else if (dominant >= 10'd8)   shift_n = 1;
  else                          shift_n = 0;
end

// 5. Scale velocities
wire signed [10:0] scaled_dx = raw_dx >>> shift_n; // arithmetic right shift
wire signed [10:0] scaled_dy = raw_dy >>> shift_n; 

// 6. Camp to +- BULLET_SPEED
wire signed [3:0] spawn_vx = (scaled_dx > 7) ? 4'd7 : (scaled_dx < -7) ? -4'd7 : scaled_dx[3:0];
wire signed [3:0] spawn_vy = (scaled_dy > 7) ? 4'd7 : (scaled_dy < -7) ? -4'd7 : scaled_dy[3:0];


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
