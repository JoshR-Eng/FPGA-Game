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
    output ACL_CSN,

    // LED
    output [15:0] LED,

    // Seven-seg display
    output a,b,c,d,e,f,g,
    output [7:0] an
    );

// ==========================================================
// --- Internal Wiring
// ==========================================================

// Internal Clocks & Timing
wire pixclk;
wire frame_tick_ungated;
wire frame_tick = frame_tick_ungated && game_active;

// VGA
wire [3:0] draw_r;
wire [3:0] draw_g;
wire [3:0] draw_b;
wire [10:0] curr_x;
wire [10:0] curr_y;

// Ship Position
wire [10:0] ship_x, ship_y;
wire        ship_hit;

// Crosshair
wire [10:0] cursor_x;
wire [10:0] cursor_y;

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

// Game State
wire [1:0]  health;
wire [15:0] score;
wire        blink;
wire        new_game;
wire        game_active;
wire [1:0]  game_state;
wire [7:0]  gun_heat;     
wire [1:0] difficulty;
assign difficulty = sw[1:0];



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
localparam MAX_BULLETS         = 16;
localparam OVERHEAT_THRESHOLD  = 8'd200;
localparam HEAT_PER_SHOT       = 8'd48;
localparam COOLDOWN_RATE       = 8'd1;

  // Asteroid config
localparam MAX_ASTEROIDS = 16;
localparam ASTR_SMALL    = 7'd12;
localparam ASTR_MEDIUM   = 7'd24;
localparam ASTR_LARGE    = 7'd48;

  // Crosshair Config
localparam CURSOR_START_X = 11'd720;
localparam CURSOR_START_Y = 11'd450;
localparam CURSOR_ARM     = 8;   // Half-length of each bar
localparam CURSOR_THICK   = 1;   // Half-width of each bar
localparam CURSOR_SPEED   = 10;


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
  .new_game(new_game),
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
  .MAX_BULLETS(MAX_BULLETS),
  .OVERHEAT_THRESHOLD(OVERHEAT_THRESHOLD),
  .HEAT_PER_SHOT(HEAT_PER_SHOT),
  .COOLDOWN_RATE(COOLDOWN_RATE)
  ) bullet_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick),
  .new_game(new_game),
  .fire_trigger(btn[0]),
  .curr_x(curr_x),
  .curr_y(curr_y),
  .ship_x(ship_x),
  .ship_y(ship_y),
  .cursor_x(cursor_x),
  .cursor_y(cursor_y),
  .on_bullet(on_bullet),
  .bul_x_packed(bul_x_packed),
  .bul_y_packed(bul_y_packed),
  .bul_active_packed(bul_active_packed),
  .bul_hit(bul_hit),
  .gun_heat(gun_heat)
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
  .astr_size_packed(astr_size_packed),
  .new_game(new_game)
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

// Game State Logic
gameState game_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick_ungated),
  .fire_trigger(btn[0]),
  .astr_hit(astr_hit),
  .ship_hit(ship_hit),
  .health(health),
  .score(score),
  .blink(blink),
  .game_active(game_active),
  .game_state(game_state),
  .new_game(new_game)
);

// Heat Display
heatDisplay #(
  .OVERHEAT_THRESHOLD(OVERHEAT_THRESHOLD),
  .STEP(OVERHEAT_THRESHOLD / 8)
) heat_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick_ungated),
  .gun_heat(gun_heat),
  .LED(LED)
);

// Score Display on Seven-seg Display
scoreDisplay score_inst(
  .clk(pixclk),
  .score(score),
  .health(health),
  .a(a), .b(b), .c(c),
  .d(d), .e(e), .f(f),
  .g(g),
  .an(an)
);

// Crosshair Movement
crosshairMovement #(
  .SCREEN_X_MIN(SCREEN_X_MIN),
  .SCREEN_X_MAX(SCREEN_X_MAX),
  .SCREEN_Y_MIN(SCREEN_Y_MIN),
  .SCREEN_Y_MAX(SCREEN_Y_MAX),
  .START_X(CURSOR_START_X),
  .START_Y(CURSOR_START_Y),
  .CURSOR_ARM(CURSOR_ARM),
  .CURSOR_THICK(CURSOR_THICK),
  .CURSOR_SPEED(CURSOR_SPEED)
  ) cursor_inst(
  .clk(pixclk),
  .rst(rst),
  .new_game(new_game),
  .frame_tick(frame_tick),
  .cursor_x(cursor_x),
  .cursor_y(cursor_y),
  .curr_x(curr_x),
  .curr_y(curr_y),
  .btn(btn),
  .on_cursor(on_cursor)
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
    .on_asteroid(on_asteroid),
    .blink(blink),
    .game_state(game_state)
    );
    // Instantiate VGA Module
vga vga_inst(
    .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
    .clk(pixclk), .rst(rst),
    .pix_r(pix_r), .pix_g(pix_g), .pix_b(pix_b),
    .curr_x(curr_x), .curr_y(curr_y),
    .hsync(hsync), .vsync(vsync),
    .frame_tick(frame_tick_ungated)
    );
 
endmodule
