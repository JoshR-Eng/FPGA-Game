`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.02.2026 11:52:08
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


module game_top(
    input clk, rst, 
    input [2:0] sw,
    input [4:0] btn,
    
    // Accelerometer pins
    input ACL_MISO,
    output ACL_MOSI,
    output ACL_SCLK,
    output ACL_CSN,
    
    output [3:0] pix_r, pix_g, pix_b,
    output hsync, vsync
    );

// Internal Wires
wire pixclk;
wire [3:0] pix_r_aux, pix_g_aux, pix_b_aux;
wire [3:0] draw_r, draw_g, draw_b;
wire [10:0] curr_x, curr_y;
wire frame_tick;

// Ship position
wire [10:0] ship_x, ship_y;

// Bullet data
wire [10:0] bullet_x, bullet_y;
wire bullet_active;


// ==========================================================
// --- CONFIGURATION
// ==========================================================

  // Screen Size
localparam SCREEN_X_MIN = 11'd10;
localparam SCREEN_X_MAX = 11'd1430;
localparam  SCREEN_Y_MIN = 11'd10;
localparam SCREEN_Y_MAX = 11'd890;

  // Ship Starting Position
localparam SHIP_START_X = 11'd720;
localparam SHIP_START_Y = 11'd450;

  // Ship Size
localparam SHIP_WIDTH   = 11'd100;
localparam SHIP_HEIGHT  = 11'd100;

  // Bullet parameters
localparam BULLET_SPEED = 8'd8;
localparam MAX_BULLETS  = 16;



// ==========================================================
// --- Clock Generation 
// ==========================================================

// 106.5 MHz Clock Generator 
  clk_wiz_0 inst
  (
  // Clock out ports  
  .clk_out1(pixclk),
 // Clock in ports
  .clk_in1(clk)
  );



// ==========================================================
// --- Fire Button Assignment
// ==========================================================
// btn[1] = Fire bullet (using center button on board)
wire fire_trigger;
assign fire_trigger = btn[1];



// ==========================================================
// --- Game Logic Modules
// ==========================================================

// Ship Movement (Uses Accelerometer to move)
shipMovement #(
  .X_MIN(SCREEN_X_MIN),
  .X_MAX(SCREEN_X_MAX),
  .Y_MIN(SCREEN_Y_MIN),
  .Y_MAX(SCREEN_Y_MAX),
  .START_X(SHIP_START_X),
  .START_Y(SHIP_START_Y) 
  ) ship_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .ACL_MISO(ACL_MISO),
  .ACL_MOSI(ACL_MOSI),
  .ACL_SCLK(ACL_SCLK),
  .ACL_CSN(ACL_CSN),
  .ship_x(ship_x),
  .ship_y(ship_y)
  );

// Bullet Manager (Single bullet, moves right)
bulletManager #(
  .BULLET_SPEED(BULLET_SPEED),
  .SCREEN_X_MAX(SCREEN_X_MAX)
  ) bullet_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .fire_trigger(fire_trigger),
  .ship_x(ship_x),
  .ship_y(ship_y),
  .bullet_x(bullet_x),
  .bullet_y(bullet_y),
  .bullet_active(bullet_active)
  );



// ==========================================================
// --- Display Modules
// ==========================================================

    // Drawcon Module
    //        For drawing ship and bullet at given positions     
drawcon #(
  .SHIP_WIDTH(SHIP_WIDTH),
  .SHIP_HEIGHT(SHIP_HEIGHT)
  ) drawcon_inst(
  .clk(pixclk), 
  .rst(rst),
  .blkpos_x(ship_x), 
  .blkpos_y(ship_y),
  .bullet_x(bullet_x),
  .bullet_y(bullet_y),
  .bullet_active(bullet_active),
  .draw_r(draw_r), 
  .draw_g(draw_g), 
  .draw_b(draw_b),
  .curr_x(curr_x), 
  .curr_y(curr_y)
  );

    // Instantiate VGA Module
    //        For sending drawing data to the vga
vga #(
  .X_MIN(SCREEN_X_MIN),
  .X_MAX(SCREEN_X_MAX),
  .Y_MIN(SCREEN_Y_MIN),
  .Y_MAX(SCREEN_Y_MAX)
  ) vga_inst(
  .draw_r(draw_r), 
  .draw_g(draw_g), 
  .draw_b(draw_b),
  .clk(pixclk), 
  .rst(rst),
  .pix_r(pix_r), 
  .pix_g(pix_g), 
  .pix_b(pix_b),
  .curr_x(curr_x), 
  .curr_y(curr_y),
  .hsync(hsync), 
  .vsync(vsync),
  .frame_tick(frame_tick)
  );
 
endmodule
