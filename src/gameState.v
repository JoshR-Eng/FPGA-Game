`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.04.2026 13:26:15
// Design Name: 
// Module Name: gameState
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


module gameState #(
  parameter INVIS_FRAMES   = 7'd120 // 2s invisibility cooldown @ 60Hz
  )(
  input clk,
  input rst,
  input frame_tick,
  input fire_trigger,

    // Hit Flags
  input [15:0] astr_hit,
  input        ship_hit,

    // Game State logic
  output [1:0]  health,
  output [15:0] score,
  output        blink,
  output        game_active,  // Gates other modules
  output [1:0]  game_state,   // IDLE/PLAYING/GAME_OVER
  output        new_game
);
    

// ==========================================================
// --- Internal Wiring
// ==========================================================    

reg [1:0]  health_reg;
reg [15:0] score_reg;
reg [6:0]  invis_timer;
reg [1:0]  state_reg;


// ==========================================================
// --- State Encoding 
// ==========================================================    

localparam IDLE      = 2'd0;
localparam PLAYING   = 2'd1;
localparam GAME_OVER = 2'd2;

// Rising edge detection for fire_trigger
reg fire_prev;
wire fire_pulse = fire_trigger & ~fire_prev;

// ==========================================================
// --- Game Score Counter
// ==========================================================  

integer i;
reg [4:0] hit_count;
always @* begin
  hit_count = 5'd0;
  for (i=0; i<16; i=i+1)
    hit_count = hit_count + astr_hit[i];
end

// ==========================================================
// --- Score/Health FSM 
// ==========================================================


always @(posedge clk) begin
  if (!rst) begin
    health_reg  <= 2'd3;
    score_reg   <= 16'd0;
    invis_timer <= 7'd0;
    state_reg   <= IDLE;
  end else if (frame_tick) begin
    fire_prev <= fire_trigger;
    case (state_reg) 
      

      // IDLE STATE
      IDLE: begin
        if (fire_pulse)
          state_reg <= PLAYING;
      end


      // PLAYING STATE
      PLAYING: begin

        // 'Ship Hit' logic 
        //    Start Invisibility timer & Lower health
        if (invis_timer != 7'd0)
          invis_timer <= invis_timer - 7'd1;
        if (ship_hit && invis_timer == 7'd0) begin
          invis_timer <= INVIS_FRAMES;
          health_reg  <= health_reg - 2'b1;
        end

        // 'Score Increase' Logic
        if (hit_count > 5'd0)
          score_reg <= score_reg + hit_count;

        // '0 Health' Logic
        if (health_reg == 2'b0)
          state_reg <= GAME_OVER;
      end


      // GAME OVER STATE
      GAME_OVER: begin 
        if (fire_pulse)
          state_reg <= IDLE;
          health_reg <= 2'd3;      // restore lives
          score_reg  <= 16'd0;     // reset score
          invis_timer <= 7'd0;     // clear any invincibility
      end

       
    endcase
  end
end


// ==========================================================
// --- Assignments 
// ==========================================================
assign health       = health_reg;
assign score        = score_reg;
assign game_state   = state_reg;
assign game_active  = (state_reg == PLAYING);
assign blink        = invis_timer[3]; // Toggles every 8 frames

// new game pulse
reg  [1:0]  game_state_prev;
always @(posedge clk) game_state_prev <= game_state;
assign new_game = (game_state == 2'd1) && (game_state_prev != 2'd1);


endmodule
