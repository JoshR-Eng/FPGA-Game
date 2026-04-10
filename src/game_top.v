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

// VGA
wire [3:0] draw_r, draw_g, draw_b;
wire [10:0] curr_x, curr_y;

// Ship Position
wire [10:0] ship_x, ship_y;

// Accelerometer data
wire [14:0] acl_data;

// Bullet drawing signal
wire on_bullet;

// Cross hair drawing signal
wire on_cursor;

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

  // Accelerometer Deadzone
localparam DEADZONE = 4'd2;


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
  .SHIP_HEIGHT(SHIP_HEIGHT)
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

//// --- 60 Hz Game Clock
//// Game clocok Generation
//always @(posedge clk) begin
//    if(!rst) begin
//        clk_div <= 0;
//        game_clk <= 0;
//    end else begin
//        if(clk_div == 20'hffff ) begin
//            clk_div <= 0;
//            game_clk <= !game_clk;
//        end else begin
//            clk_div <= clk_div + 1;
//        end
//    end
//end


//// ==========================================================
//// --- Block Movement
//// ==========================================================
//always @(posedge pixclk) begin
//    if (!rst) begin
//        ship_x <= 11'd720;
//        ship_y <= 11'd450;
//    end else if (frame_tick) begin
//        if (btn[0]) begin
//            ship_x <= 11'd10;
//            ship_y <= 11'd10;
//        end else begin
//            case(btn[4:1])
//                4'b0010: begin                          // left
//                         if(ship_x > 11'd10) begin
//                            ship_x <= ship_x - 4; 
//                         end end
//               4'b0100: begin                          // right
//                         if(ship_x < 11'd1430 - 11'd100) begin
//                            ship_x <= ship_x + 4; 
//                         end end
//               4'b1000: begin                          // down
//                        if(ship_y < (11'd890 - 11'd100)) begin
//                            ship_y <= ship_y + 4; 
//                         end end
//               4'b0001: begin                          // up
//                         if(ship_y > 11'd10 ) begin
//                            ship_y <= ship_y - 4; 
//                         end end
//               default: begin
//                            ship_x <= ship_x;
//                            ship_y <= ship_y;
//                        end
//            endcase
//        end
//    end
//end


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
drawcon drawcon_inst(
    .clk(pixclk), .rst(rst),
    .ship_x(ship_x), .ship_y(ship_y),
    .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
    .curr_x(curr_x), .curr_y(curr_y),
    .on_bullet(on_bullet),
    .on_cursor(on_cursor)
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
