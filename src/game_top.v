`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Josh Rawlinson u502778
// 
// Create Date: 16.02.2026 11:52:08
// Design Name: 
// Module Name: game_top
// Project Name: 
// Target Devices: Nexys A7-100T
// Tool Versions: 
// Description: Master top-level module that instantiates and wires together
//              all game components, inputs, outputs and the VGA display
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
    input [7:0] sw,
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

    // Mouse
//    input PS2_CLK,
//    input PS2_DATA
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

// Mouse
//wire [7:0]  mouse_dx;
//wire [7:0]  mouse_dy;
//wire        mouse_x_sign;
//wire        mouse_y_sign;
//wire        mouse_valid;
//wire        left_btn;
//wire        right_btn;

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
localparam SHIP_WIDTH   = 11'd80;
localparam SHIP_HEIGHT  = 11'd80;

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
// --- Special Features
// ==========================================================

// Difficulty: Change the spawn rate of asteroids
wire [1:0] difficulty_en = {sw[7], sw[4]}; 

// Power Up Switches
wire speed_boost_en = sw[1];      // Ship moves faster
wire shield_en      = sw[3];      // Suppresses life loss on hit
wire rapid_fire_en  = sw[5];      // Faster gun cooldown

// Hidden Easter Eggs: Nightmare Mode
//  Activated if player tries to use multiple power ups
//  but if sw[2] also deactivated then don't active
wire nightmare_en = (sw[5] & sw[3] & sw[1] & ~sw[2]);

// Final effective signals - nightmare overrides shield, locks diff to max
wire [1:0]  difficulty  = nightmare_en  ? 2'b11 : difficulty_en;
wire        shield      = shield_en     & ~nightmare_en;
wire        rapid_fire  = rapid_fire_en | nightmare_en;

// ==========================================================
// --- Game Logic Modules
// ==========================================================

// Game State Logic
gameState game_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick_ungated),
  .start_trigger(btn[1]),
  .astr_active_packed(astr_active_packed),
  .ship_hit(ship_hit),
  .astr_hit(astr_hit),
  .health(health),
  .score(score),
  .blink(blink),
  .game_active(game_active),
  .game_state(game_state),
  .new_game(new_game),
  .shield_en(shield)
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

// Heat Display
heatDisplay #(
  .OVERHEAT_THRESHOLD(OVERHEAT_THRESHOLD),
  .STEP(OVERHEAT_THRESHOLD / 8)
) heat_inst (
  .clk(pixclk),
  .rst(rst),
  .frame_tick(frame_tick_ungated),
  .gun_heat(gun_heat),
  .LED(LED),
  .nightmare_en(nightmare_en)
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

// ==========================================================
// --- Game Objects 
// ==========================================================

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
  .ship_y(ship_y),
  .speed_boost_en(speed_boost_en)
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
  .gun_heat(gun_heat),
  .rapid_fire_en(rapid_fire)
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
// --- Hardware 
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
// --- Display Modules 
// ==========================================================

    // Instantiate Drawcon Module
drawcon #(
  .SCREEN_Y_MIN(SCREEN_Y_MIN),
  .MAX_ASTEROIDS(MAX_ASTEROIDS),
  .ASTR_SMALL(ASTR_SMALL),
  .ASTR_MEDIUM(ASTR_MEDIUM),
  .ASTR_LARGE(ASTR_LARGE),
  .SHIP_WIDTH(SHIP_WIDTH),
  .SHIP_HEIGHT(SHIP_HEIGHT)
  ) drawcon_inst(
  .clk(pixclk), .rst(rst),
  .ship_x(ship_x), .ship_y(ship_y),
  .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
  .curr_x(curr_x), .curr_y(curr_y),
  .on_bullet(on_bullet),
  .on_cursor(on_cursor),
  .on_asteroid(on_asteroid),
  .astr_x_packed(astr_x_packed),       
  .astr_y_packed(astr_y_packed),       
  .astr_active_packed(astr_active_packed), 
  .astr_size_packed(astr_size_packed), 
  .health(health),                     
  .score(score),                       
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
