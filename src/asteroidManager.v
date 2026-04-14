`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 11:52:08
// Design Name: 
// Module Name: asteroidManager
// Promect Name: 
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
  parameter SCREEN_X_MAX  = 11'd1439,
  parameter SCREEN_Y_MIN  = 11'd100,
  parameter SCREEN_Y_MAX  = 11'd899,
  parameter ASTR_SMALL    = 7'd12,
  parameter ASTR_MEDIUM   = 7'd24,
  parameter ASTR_LARGE    = 7'd48
  )(
    // System
  input clk,
  input rst,
  input frame_tick,

    // Display
  input [10:0] curr_x,
  input [10:0] curr_y,
  output reg   on_asteroid,
    // Difficulty
  input [1:0] difficulty,

    // Asteroid States & Positions
  input  [15:0]   astr_hit,
  output [175:0]  astr_x_packed,
  output [175:0]  astr_y_packed,
  output [15:0]   astr_active_packed
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
    if (lfsr_reg == 16'h0000)
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
wire [9:0] rand_bits  = lfsr_reg[15:6];
wire [20:0] rand_x_full = {11'b0, rand_bits} * SCREEN_X_MAX;
wire [10:0] rand_x      = rand_x_full[20:10];   // upper 11 bits after >> 10
wire [20:0] rand_y_full = {11'b0, rand_bits} * SCREEN_Y_MAX;
wire [10:0] rand_y      = rand_y_full[20:10];
wire [1:0] spawn_edge = lfsr_reg[1:0];                // Spawning Edge
wire [1:0] spawn_size = lfsr_reg[5:4];                // Spawning Size

// Signed drift component: lfsr_reg[4:3] gives 0-3, subtract 1 = range -1 to +2
// Use only 2 values: lfsr_reg[3] gives 0 or 1, subtract 0 gives gentle drift
wire signed [3:0] drift = {2'b00, lfsr_reg[3:2]} - 4'sd1;

// Loop Counter
integer   s;


always @(posedge clk) begin

  // If reset is pressed, reset all asteroids
  if (!rst) begin
    spawn_timer <= 10'd0;
    // reset all asteroid slots to inactive
    for (s=0; s<MAX_ASTEROIDS; s=s+1) begin
      astr_active[s] <= 1'b0;
      astr_x[s]      <= 11'b0;
      astr_y[s]      <= 11'b0;
    end

  // Asteroid spawning logic
  end else if (frame_tick) begin
    spawn_done = 1'b0;
    if (spawn_timer == 10'd0) begin
      spawn_timer <= spawn_interval;
      for (s=0; s<MAX_ASTEROIDS; s=s+1) begin   
        if (!astr_active[s] && !spawn_done) begin

          // Active Asteroid
          astr_size[s]    <= (spawn_size == 2'b11) ? 2'b10 : spawn_size;
          astr_active[s]  <= 1'b1;
          spawn_done       = 1'b1;

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

            2'b11:begin    // Right Edge
                  astr_x[s] <= SCREEN_X_MAX;
                  astr_y[s] <= rand_y;
                  vel_x[s]  <= -4'sd2;
                  vel_y[s]  <= drift;
                  end
          endcase

        end
      end
    end else begin
      spawn_timer <= spawn_timer - 1'b1;
    end
  end
end



// ==========================================================
// --- Movement 
// ==========================================================

/*
First compute the next position since when it spawns it starts off
at the edge of the screen. Because of this the deactivation logic
would force all asteroids to be disabled as they're spawned
*/
wire signed [11:0] astr_x_next [0:MAX_ASTEROIDS-1];
wire signed [11:0] astr_y_next [0:MAX_ASTEROIDS-1];
genvar n;
generate
    for (n=0; n<MAX_ASTEROIDS; n=n+1) begin : next_pos
        assign astr_x_next[n] = $signed({1'b0, astr_x[n]}) + vel_x[n];
        assign astr_y_next[n] = $signed({1'b0, astr_y[n]}) + vel_y[n];
    end
endgenerate



integer m;

always @(posedge clk) begin
  if (frame_tick) begin
    for (m=0; m<MAX_ASTEROIDS; m=m+1) begin
      if (astr_active[m]) begin

        // Deactivate if off screen
        if ((astr_x_next[m] < -12'sd64)                                 ||
            (astr_x_next[m] > $signed({1'b0, SCREEN_X_MAX}) + 12'sd64)  ||
            (astr_y_next[m] < $signed({1'b0, SCREEN_Y_MIN}))            || 
            (astr_y_next[m] > $signed({1'b0, SCREEN_Y_MAX}) + 12'sd64)  )
          astr_active[m] <= 1'b0;
        else begin
            astr_x[m] <= astr_x_next[m][10:0];
            astr_y[m] <= astr_y_next[m][10:0];
        end        
      end
    end
  end
end



// ==========================================================
// --- Drawning Logic 
// ==========================================================

integer i;
reg [6:0] half_size; // max LARGE half-width

reg [10:0] draw_x_min, draw_x_max, draw_y_min, draw_y_max;

always @* begin
    on_asteroid = 1'b0;
    for (i = 0; i < MAX_ASTEROIDS; i = i+1) begin

        // Resolve half-size from 2-bit size field
        case (astr_size[i])
            2'b10:   half_size = ASTR_LARGE;   // LARGE:  96px
            2'b01:   half_size = ASTR_MEDIUM;  // MEDIUM: 48px
            2'b00:   half_size = ASTR_SMALL;   // SMALL:  24px
            default: half_size = ASTR_SMALL;   // 
        endcase

        draw_x_min = (astr_x[i] > {4'b0, half_size}) ? astr_x[i] - {4'b0, half_size} : 11'd0;
        draw_x_max = astr_x[i] + {4'b0, half_size};
        draw_y_min = (astr_y[i] > {4'b0, half_size}) ? astr_y[i] - {4'b0, half_size} : 11'd0;
        draw_y_max = astr_y[i] + {4'b0, half_size};

        if (astr_active[i] &&
            curr_x >= draw_x_min && curr_x < draw_x_max &&
            curr_y >= draw_y_min && curr_y < draw_y_max)
            on_asteroid = 1'b1;    
    end
end



// ==========================================================
// --- Flatten Arrays 
// ==========================================================
genvar k;
generate
  for (k=0; k< MAX_ASTEROIDS; k=k+1 ) begin : pack_asteroids
    assign astr_x_packed[ (11*k)+10 -: 11] = astr_x[k];
    assign astr_y_packed[ (11*k)+10 -: 11] = astr_y[k];
    assign astr_active_packed[k]           = astr_active[k];
  end
endgenerate

endmodule
