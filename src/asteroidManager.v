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
  parameter SCREEN_Y_MAX  = 11'd900
  )(
    // System
  input clk,
  input rst,
  input frame_tick,

    // Difficulty
  input [1:0] difficulty,

    // Asteroid States & Positions
  input  [15:0]   astr_hit,
  output [175:0]  astr_x_packed,
  output [175:0]  astr_y_packed,
  output [15:0]   astr_active_packed,
  output          on_asteroid
  );
 

// ==========================================================
// --- Internal Wires 
// ==========================================================

  // Position
reg [10:0]        astr_x      [0:MAX_ASTEROIDS-1];
reg [10:0]        astr_y      [0:MAX_ASTEROIDS-1];
  // Velocity
reg signed [3:0]  vel_x       [0:MAX_ASTEROIDS-1];       
reg signed [3:0]  vel_y       [0:MAX_ASTEROIDS-1];       
  // Size & Activity
reg        [1:0]  astr_size   [0:MAX_ASTEROIDS-1];  // 00=SM, 01=MD, 10=LG
reg               astr_active [0:MAX_ASTEROIDS-1];


// ==========================================================
// --- LFSR 
// ==========================================================

// This is to generate a sudo-random position for each metorite to spawn from

// --- Seed is generated from the clock cycle
reg [15:0] seed_counter;
always @(posedge clk) begin
  if (!rst) 
    seed_counter <= 16'd1;    // a zero value will cause a fault
  else
    seed_counter <= seed_counter + 1'b1;
end

// --- 16-bit Fibonacci LFSR
// Tap polynomial: x^16 + x^14 + x^13 + x^11 + 1 (maximal length)
reg [15:0]  lfsr_reg;
wire        lfsr_feedback = lfsr_reg[15] ^ lfsr_reg[13]
                            ^ lfsr_reg[12] ^ lfsr_reg[10];

always @(posedge clk) begin
  if (!rst) begin
    lfsr_reg <= seed_counter;
  end else if (frame_tick) begin
    // Shift register left, feed new bit at [0]
    // also, if register becomes 0, need to force non-zero
    if (lfsr_reg == 16'0000)
      lfsr_reg <= 16'd1;
    else
      lfsr_reg <= {lfsr_reg[14:0], lfsr_feedback};
  end
end


// --- Map lfsr_reg to screen width
//      Can do this with "bit-field extraction with a multiply-then-shift"
//      For a target range [0,N], with random value r in [0, 2^{-16}-1]...
//      pos = (r * N)/2^{16}






// ==========================================================
// --- Difficulty Logic
// ==========================================================

reg [9:0] spawn_interval;

always @* begin
    case (difficulty)
        2'b00:    spawn_interval = 10'd180; // easy:   3s
        2'b01:    spawn_interval = 10'd120; // normal: 2s
        2'b10:    spawn_interval = 10'd60;  // hard:   1s
        2'b11:    spawn_interval = 10'd30;  // overdrive: 0.5s
        default:  spawn_interval = 10'd180; // Failsafe
    endcase
end


// ==========================================================
// --- Asteroid Spawner FSM
// ==========================================================

reg [9:0] spawn_timer;
reg       spawn_done; // check spawning flag

// Randomly determine Starting States
wire [10:0] rand_x = (lfsr_reg * SCREEN_X_MAX) >> 16; // Spawning X pos.
wire [10:0] rand_y = (lfsr_reg * SCREEN_Y_MAX) >> 16; // Spawning Y pos.
wire [1:0] spawn_edge = lfsr_reg[1:0];                // Spawning Edge
wire [1:0] spawn_size = lfsr_reg[2:0];                // Spawning Size

// Signed drift component: lfsr_reg[4:3] gives 0-3, subtract 1 = range -1 to +2
// Use only 2 values: lfsr_reg[3] gives 0 or 1, subtract 0 gives gentle drift
wire signed [3:0] drift = {2'b00, lfsr_reg[4:3]} - 4'sd1;

// Loop Counter
integer   s;


always @(posedge clk) begin

  // If reset is pressed, reset all asteroids
  if (!rst) begin
    spawn_timer <= 10'd0;
    // reset all asteroid slots to inactive
    for (s=0; s<MAX_ASTEROIDS; s=s+1) begin
      astr_active[s] <= 1'b0;
    end

  // Asteroid spawning logic
  end else if (frame_tick) begin
    spawn_done = 1'b0;
    if (spawn_timer == 10'd0) begin
      for (s=0; s<MAX_ASTEROIDS; s=s+1) begin   
        if (!astr_active[s] && !spawn_done) begin

          // Active Asteroid
          astr_size[s]    = spawn_size;
          astr_active[s]  = 1'b1;
          spawn_timer    <= spawn_interval;
          spawn_done      = 1'b1;

          case (spawn_edge)
            2'b00:begin    // Top Edge
                  astr_x[s] <= rand_x;
                  astr_y[s] <= SCREEN_Y_MIN;
                  vel_x[s]  <= drift;
                  vel_y[s]  <= 4'sd2;
                  end

            2'b01:begin    // Bottom Edge
                  astr_x[s] <= rand_x;
                  astr_y[s] <= SCREEN_Y_MAX;
                  vel_x[s]  <= drift;
                  vel_y[s]  <= -4'sd2;
                  end

            2'b10:begin    // Left Edge
                  astr_x[s] <= SCREEN_X_MIN;
                  astr_y[s] <= rand_y;
                  vel_x[s]  <= 4'sd2;
                  vel_y[s]  <= drift;
                  end

            2'b11:begin    // Left Edge
                  astr_x[s] <= SCREEN_X_MAX;
                  astr_y[s] <= rand_y;
                  vel_x[s]  <= -4'sd2;
                  vel_y[s]  <= drift;
                  end
          endcase

        end
      end
    end else begin
      spawn_time <= spawn_timer - 1'b1;
    end
  end
end



endmodule
