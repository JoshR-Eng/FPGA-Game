`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2026 14:12:10
// Design Name: 
// Module Name: drawcon
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


module drawcon #(
    parameter SHIP_WIDTH = 100,
    parameter SHIP_HEIGHT = 100,
    parameter SCREEN_Y_MIN = 11'd100
    )(
    input clk, rst,
    input on_bullet,
    input on_cursor,
    input on_asteroid,
    input blink,
    input [1:0] game_state,
    input [10:0] curr_x, curr_y,
    input [10:0] ship_x, ship_y,
    output [3:0] draw_r, draw_g, draw_b
    );
    

// ==========================================================
// --- Internal Wiring
// ==========================================================    

reg [3:0] blk_r = 0, blk_g = 0, blk_b = 0;  // Initialize at power-up
reg [3:0] bg_r=4'h0, bg_g=4'h0, bg_b=4'h0;

// Signals for the ship image
reg [13:0] addr = 0;  // Initialize at power-up to prevent garbage
wire [11:0] rom_pixel;


// Object Detection
wire ship_on;
reg ship_on_delay;
wire on_gamebar;
integer i;

// Draw Multiplexer
reg [3:0] mux_r;
reg [3:0] mux_g;
reg [3:0] mux_b;

// ==========================================================
// --- Determine if current pixel is over an item
// ==========================================================

// Check for ship
assign ship_on = (curr_x >= ship_x) && ( curr_x < (ship_x + SHIP_WIDTH)) &&
                 (curr_y >= ship_y) && ( curr_y < (ship_y + SHIP_HEIGHT));

assign on_gamebar = (curr_y <= SCREEN_Y_MIN);

// ==========================================================
// --- Draw Priority Multiplexer
// ==========================================================

always @* begin
  // Default: BACKGROUND
  //  Standard black space background
  mux_r = 4'h0;
  mux_g = 4'h0;
  mux_b = 4'h1;

  // Layer 1: ASTEROIDS (grey)
  if (on_asteroid) begin
    mux_r = 4'hA;
    mux_g = 4'hA;
    mux_b = 4'hA;
  end

  // Layer 2: BULLET (red)
  if (on_bullet) begin
    mux_r = 4'hF;
    mux_g = 4'h0;
    mux_b = 4'h0;
  end

  // Layer 3: SHIP
  if (ship_on_delay && (rom_pixel[11:0] != 12'h000) && !blink) begin
      mux_r = rom_pixel[11:8];
      mux_g = rom_pixel[7:4];
      mux_b = rom_pixel[3:0];
  end
  
  // Layer 4: Crosshair
  if (on_cursor) begin
    mux_r = 4'hF;
    mux_g = 4'hF;
    mux_b = 4'hF;
  end

  // Layer 5: Gamebar
  if (on_gamebar) begin
    case (game_state)
      2'd0: begin mux_r = 4'h0; mux_g = 4'h0; mux_b = 4'hF; end  // IDLE — blue
      2'd1: begin mux_r = 4'h0; mux_g = 4'h5; mux_b = 4'h0; end  // PLAYING — dark green
      2'd2: begin mux_r = 4'hF; mux_g = 4'h0; mux_b = 4'h0; end  // GAME_OVER — red
    endcase
  end
end


// Final continous assignment to the output ports
assign draw_r = mux_r;
assign draw_g = mux_g;
assign draw_b = mux_b;


// ==========================================================
// --- BRAM Address Calculation (The Math Way)
// ==========================================================
wire [10:0] local_ship_x = curr_x - ship_x;
wire [10:0] local_ship_y = curr_y - ship_y;

always @(posedge clk) begin
    // Delay ship_on_delay by one clock to match
    // BRAM read latency
    ship_on_delay <= ship_on;

    // Retrieve BRAM address
    if (ship_on) begin
        // Address = (Y * Width) + X
        addr <= (local_ship_y * SHIP_WIDTH) + local_ship_x;
    end else begin
        addr <= 0;
    end
end



// ==========================================================
// --- Block Memory Assignment 
// ==========================================================

blk_mem_gen_0 inst
(
.clka(clk),
.addra(addr),
.douta(rom_pixel)
);


endmodule
