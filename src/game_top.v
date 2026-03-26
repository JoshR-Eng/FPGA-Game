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
    output hsync, vsync,
    output [15:0] LED    // Heat display LEDs
    );

// Internal Wires
wire pixclk;
wire [3:0] pix_r_aux, pix_g_aux, pix_b_aux;
wire [3:0] draw_r, draw_g, draw_b;
wire [10:0] curr_x, curr_y;
wire frame_tick;

// Accelerometer data
wire [14:0] acl_data;

// Ship position
wire [10:0] ship_x, ship_y;

// Bullet data (arrays from bulletManager)
wire [10:0] bullet_x [0:15];
wire [10:0] bullet_y [0:15];
wire bullet_active [0:15];
wire [7:0] gun_heat;
// LED output already declared as port

// Scalar wires for drawcon (bullet[0] only for now)
wire [10:0] bullet0_x;
wire [10:0] bullet0_y;
wire bullet0_active;

// Extract bullet[0] from arrays
assign bullet0_x = bullet_x[0];
assign bullet0_y = bullet_y[0];
assign bullet0_active = bullet_active[0];


// ==========================================================
// --- CONFIGURATION
// ==========================================================

  // Screen Size
localparam SCREEN_X_MIN = 11'd10;
localparam SCREEN_X_MAX = 11'd1430;
localparam SCREEN_Y_MIN = 11'd10;
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
localparam HEAT_PER_SHOT = 8'd32;
localparam COOLDOWN_RATE = 8'd2;
localparam OVERHEAT_THRESHOLD = 8'd200;



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
// --- Accelerometer Abstraction
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
// --- Fire Button Assignment
// ==========================================================
// btn[1] = Fire bullet (using center button on board)
wire fire_trigger;
assign fire_trigger = btn[1];



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
  .START_Y(SHIP_START_Y) 
  ) ship_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .acl_data(acl_data),
  .ship_x(ship_x),
  .ship_y(ship_y)
  );

// Bullet Manager (Single bullet, moves right)
bulletManager #(
  .BULLET_SPEED(BULLET_SPEED),
  .HEAT_PER_SHOT(HEAT_PER_SHOT),
  .COOLDOWN_RATE(COOLDOWN_RATE),
  .OVERHEAT_THRESHOLD(OVERHEAT_THRESHOLD),
  .SCREEN_X_MAX(SCREEN_X_MAX),
  .SCREEN_Y_MAX(SCREEN_Y_MAX)
  ) bullet_inst(
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .fire_trigger(fire_trigger),
  .ship_x(ship_x),
  .ship_y(ship_y),
  .bullet_x(bullet_x),
  .bullet_y(bullet_y),
  .bullet_active(bullet_active),
  .gun_heat(gun_heat),
  .LED(LED)
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
  .bullet_x(bullet0_x),
  .bullet_y(bullet0_y),
  .bullet_active(bullet0_active),
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
