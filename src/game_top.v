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
    // System
    input clk, rst, 
    input [2:0] sw,
    input [4:0] btn,
    
    // VGA
    output [3:0] pix_r, pix_g, pix_b,
    output hsync, vsync,

    
    // Accelerometer 
    input ACL_MISO,
    output ACL_MOSI,
    output ACL_SCLK,
    output ACL_CSN
    );

// ==========================================================
// --- Internal Wiring
// ==========================================================

// Internal Clocks & Timing
wire pixclk;
wire frame_tick;
wire [1:0] difficulty;
assign difficulty = sw[1:0];

// VGA
wire [3:0] draw_r, draw_g, draw_b;
wire [10:0] curr_x, curr_y;

// Ship Position
wire [10:0] ship_x, ship_y;
wire        ship_hit;

// Accelerometer data
wire [14:0] acl_data;

// Drawing signal
wire on_bullet;
wire on_cursor;
wire on_asteroid;

// Bullet Position & State
wire [175:0] bul_x_packed;
wire [175:0] bul_y_packed;
wire [15:0] bul_active_packed;
wire [15:0] bul_hit;

// Asteroid Position & State
wire [175:0] astr_x_packed;
wire [175:0] astr_y_packed;
wire [15:0] astr_active_packed;
wire [31:0] astr_size_packed;
wire [15:0] astr_hit;


// ==========================================================
// --- CONFIGURATION
// ==========================================================

  // Screen Size
localparam SCREEN_X_MIN = 11'd0;
localparam SCREEN_X_MAX = 11'd1440;
localparam SCREEN_Y_MIN = 11'd100;
localparam SCREEN_Y_MAX = 11'd900;

  // Ship Starting Position
localparam SHIP_START_X = 11'd720;
localparam SHIP_START_Y = 11'd450;

  // Ship Size
localparam SHIP_WIDTH   = 11'd100;
localparam SHIP_HEIGHT  = 11'd100;

  // Accelerometer Deadzone
localparam DEADZONE = 4'd2;

  // Bullet config
localparam  MAX_BULLETS = 16;

  // Asteroid config
localparam MAX_ASTEROIDS = 16;
localparam ASTR_SMALL    = 7'd12;
localparam ASTR_MEDIUM   = 7'd24;
localparam ASTR_LARGE    = 7'd48;

// ==========================================================
// --- Game Logic Modules
// ==========================================================

// Ship Movement (Uses Accelerometer data to move)
shipMovement #(
  .X_MIN(SCREEN_X_MIN),
  .X_MAX(SCREEN_X_MAX),
  .Y_MIN(SCREEN_Y_MIN),
  .Y_MAX(SCREEN_Y_MAX),
  .START_X(SHIP_START_X),
  .START_Y(SHIP_START_Y),
  .SHIP_HEIGHT(SHIP_HEIGHT),
  .SHIP_WIDTH(SHIP_WIDTH),
  .DEADZONE(DEADZONE)
  ) ship_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .acl_data(acl_data),
  .ship_x(ship_x),
  .ship_y(ship_y)
  );

// Bullet Manager
bulletManager #(
  .SCREEN_X_MAX(SCREEN_X_MAX),
  .SCREEN_X_MIN(SCREEN_X_MIN),
  .SCREEN_Y_MAX(SCREEN_Y_MAX),
  .SCREEN_Y_MIN(SCREEN_Y_MIN),
  .SHIP_WIDTH(SHIP_WIDTH),
  .SHIP_HEIGHT(SHIP_HEIGHT),
  .MAX_BULLETS(MAX_BULLETS)
  ) bullet_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .fire_trigger(btn[0]),
  .btn(btn),
  .curr_x(curr_x),
  .curr_y(curr_y),
  .ship_x(ship_x),
  .ship_y(ship_y),
  .on_bullet(on_bullet),
  .on_cursor(on_cursor),
  .bul_x_packed(bul_x_packed),
  .bul_y_packed(bul_y_packed),
  .bul_active_packed(bul_active_packed),
  .bul_hit(bul_hit)
);

// Asteroid Manager
asteroidManager #(
  .MAX_ASTEROIDS(MAX_ASTEROIDS),
  .SCREEN_X_MIN(SCREEN_X_MIN),
  .SCREEN_X_MAX(SCREEN_X_MAX),
  .SCREEN_Y_MIN(SCREEN_Y_MIN),
  .SCREEN_Y_MAX(SCREEN_Y_MAX),
  .ASTR_SMALL(ASTR_SMALL),
  .ASTR_MEDIUM(ASTR_MEDIUM),
  .ASTR_LARGE(ASTR_LARGE)
  )asteroid_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .curr_x(curr_x),
  .curr_y(curr_y),
  .on_asteroid(on_asteroid),
  .difficulty(difficulty),
  .astr_hit(astr_hit),
  .astr_x_packed(astr_x_packed),
  .astr_y_packed(astr_y_packed),
  .astr_active_packed(astr_active_packed),
  .astr_size_packed(astr_size_packed)
);

// Collision Logic
collisions #(
  .MAX_BULLETS(MAX_BULLETS),
  .MAX_ASTEROIDS(MAX_ASTEROIDS),
  .SHIP_WIDTH(SHIP_WIDTH),
  .SHIP_HEIGHT(SHIP_HEIGHT)
  ) collisions_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .bul_x_packed(bul_x_packed),
  .bul_y_packed(bul_y_packed),
  .bul_active_packed(bul_active_packed),
  .ship_x(ship_x),
  .ship_y(ship_y),
  .astr_x_packed(astr_x_packed),
  .astr_y_packed(astr_y_packed),
  .astr_active_packed(astr_active_packed),
  .astr_size_packed(astr_size_packed),
  .bul_hit(bul_hit),
  .astr_hit(astr_hit),
  .ship_hit(ship_hit)
);


// ==========================================================
// --- Clock Generators
// ==========================================================

// --- 106 MHz Clock
// Clock Generator
  clk_wiz_0 inst
  (
  // Clock out ports  
  .clk_out1(pixclk),
 // Clock in ports
  .clk_in1(clk)
  );



// ==========================================================
// --- Accelerometer
// ==========================================================

// Accelerometer SPI Interface
accOutput accel_inst (
  .CLK100MHZ(clk),
  .ACL_MISO(ACL_MISO),
  .ACL_MOSI(ACL_MOSI),
  .ACL_SCLK(ACL_SCLK),
  .ACL_CSN(ACL_CSN),
  .acl_data(acl_data)  // {X[14:10], Y[9:5], Z[4:0]}
);



// ==========================================================
// --- Display Logic
// ==========================================================

    // Instantiate Drawcon Module
drawcon #(
  .SCREEN_Y_MIN(SCREEN_Y_MIN)
) drawcon_inst(
    .clk(pixclk), .rst(rst),
    .ship_x(ship_x), .ship_y(ship_y),
    .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
    .curr_x(curr_x), .curr_y(curr_y),
    .on_bullet(on_bullet),
    .on_cursor(on_cursor),
    .on_asteroid(on_asteroid)
    );
    // Instantiate VGA Module
vga vga_inst(
    .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
    .clk(pixclk), .rst(rst),
    .pix_r(pix_r), .pix_g(pix_g), .pix_b(pix_b),
    .curr_x(curr_x), .curr_y(curr_y),
    .hsync(hsync), .vsync(vsync),
    .frame_tick(frame_tick)
    );
 
endmodule
