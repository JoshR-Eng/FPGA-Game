`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 12:21:21
// Design Name: 
// Module Name: PlayerMovement
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

module shipMovement #(
  // Screen Size
  parameter X_MIN = 11'd10,
  parameter X_MAX = 11'd1430,
  parameter Y_MIN = 11'd10,
  parameter Y_MAX = 11'd890,

  // Ship Starting Position
  parameter START_X = 11'd720,
  parameter START_Y = 11'd450,
  
  // Ship Size
  parameter SHIP_WIDTH  = 11'd100,
  parameter SHIP_HEIGHT = 11'd100,
  
  // Movement deadzone
  parameter DEADZONE = 4'd2
  )(
  // System
  input clk,
  input rst,
  input frame_tick,
  input new_game,

  // Accelerometer data (from hardware abstraction in top level)
  input [14:0] acl_data,

  // Ship Position Outputs
  output [10:0] ship_x,
  output [10:0] ship_y,
  input         speed_boost_en
  );



// ==========================================================
// --- Internal Signals 
// ==========================================================


  // Position reg
  reg [10:0] ship_x_reg;
  reg [10:0] ship_y_reg;
  
  
  // Consider Ship size
  localparam X_MAX_EFF = X_MAX - SHIP_WIDTH + 1;
  localparam Y_MAX_EFF = Y_MAX - SHIP_HEIGHT + 1;


// ==========================================================
// --- Raw Tilt Value -> Per-axis Tilt 
// ==========================================================

// Note: Accelerometer is 90 degree rotated on board
// Physical tilt maps to screen coordinates as:
//    Accel X-axis => Screen Y-axis (up/down)
//    Accel Y-axis => Screen X-axis (left/right)

wire signed [4:0] acl_x = acl_data[14:10]; // maps to screen Y (90 rotation)
wire signed [4:0] acl_y = acl_data[9:5];  // maps to screen X

// --- Turn two-complement into sign-magnitude format
//      X-axis
wire x_neg = acl_x[4];
wire [3:0] x_mag = x_neg ? (~acl_x[3:0] + 1'b1) : acl_x[3:0];

wire y_neg = acl_y[4];
wire [3:0] y_mag = y_neg ? (~acl_y[3:0] + 1'b1) : acl_y[3:0];

// --- Feed mag into tilt_to_vel function
wire [3:0] vel_x = tilt_to_vel(y_mag);
wire [3:0] vel_y = tilt_to_vel(x_mag);

// --- Speed multiplier
// Speed boost: doubles the per-frame step when enabled
wire [3:0] vel_x_eff = speed_boost_en ? {vel_x[2:0], 1'b0} : vel_x;
wire [3:0] vel_y_eff = speed_boost_en ? {vel_y[2:0], 1'b0} : vel_y;


// ==========================================================
// --- Magnitude to Velocity Function
// ==========================================================
function automatic [3:0] tilt_to_vel;
    input [3:0] magnitude;
    begin
        if      (magnitude > 4'd12)          tilt_to_vel = 4'd4;
        else if (magnitude > 4'd8)          tilt_to_vel = 4'd3;
        else if (magnitude > 4'd4)           tilt_to_vel = 4'd2;
        else if (magnitude > DEADZONE)       tilt_to_vel = 4'd1;
        else                                 tilt_to_vel = 4'd0;
    end
endfunction


// ==========================================================
// --- Movement Logic
// ==========================================================

// Accelerometer is at 90 degrees to the board orientation so the accelerometer x and y are swapped.
always@(posedge clk) begin
    if (!rst) begin
    ship_x_reg <= START_X;
    ship_y_reg <= START_Y;
    end else if (new_game) begin
    ship_x_reg <= START_X;
    ship_y_reg <= START_Y;

    end else if (frame_tick) begin
    
    // Y axis (controlled by acl_x)
    if (x_neg && vel_y_eff > 0) begin
        ship_y_reg <= (ship_y_reg + vel_y_eff < Y_MAX_EFF) ? (ship_y_reg + vel_y_eff) 
                                                           : (Y_MAX_EFF);
    end else if (!x_neg && vel_y_eff > 0) begin
        ship_y_reg <= (ship_y_reg > Y_MIN + vel_y_eff)     ? (ship_y_reg - vel_y_eff) 
                                                           : (Y_MIN);
    end

    // X axis (controlled by acl_y)
    if (y_neg && vel_x_eff > 0) begin
        ship_x_reg <= (ship_x_reg + vel_x_eff < X_MAX_EFF) ? (ship_x_reg + vel_x_eff) 
                                                           : (X_MAX_EFF);
    end else if (!y_neg && vel_x_eff > 0) begin
        ship_x_reg <= (ship_x_reg > X_MIN + vel_x_eff)     ? (ship_x_reg - vel_x_eff) 
                                                           : (X_MIN);
    end
   
    
    end
 end

// ==========================================================
// --- Output Assignment 
// ==========================================================

  assign ship_x = ship_x_reg;
  assign ship_y = ship_y_reg;



endmodule
