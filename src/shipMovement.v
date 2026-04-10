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
  parameter DEADZONE = 4'd8
  )(
  // System
  input clk,
  input rst,
  input frame_tick,

  // Accelerometer data (from hardware abstraction in top level)
  input [14:0] acl_data,

  // Ship Position Outputs
  output [10:0] ship_x,
  output [10:0] ship_y
  );



// ==========================================================
// --- Internal Signals 
// ==========================================================

  // Extract tilt info from accelerometer data
  // Data Format: [14:10]=X-axis, [9:5]=Y-axis, [4:0]=Z-axis
  // Each axis: [4]=sign, [3:0]=magnitude
  wire x_sign, y_sign;
  wire [3:0] x_data, y_data;

  // Position reg
  reg [10:0] ship_x_reg;
  reg [10:0] ship_y_reg;
  
  wire [3:0] vel_x = tilt_to_vel(x_data);
  wire [3:0] vel_y = tilt_to_vel(y_data);
  
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

  assign x_sign = acl_data[14];     // X-axis sign bit
  assign x_data  = acl_data[13:10];  // X-axis magnitude (4 bits)
  assign y_sign = acl_data[9];      // Y-axis sign bit  
  assign y_data  = acl_data[8:5];    // Y-axis magnitude (4 bits)


// ==========================================================
// --- Magnitude to Velocity Function
// ==========================================================
function automatic [3:0] tilt_to_vel;
    input [3:0] magnitude;
    begin
        if      (magnitude > 4'd14)          tilt_to_vel = 4'd4;
        else if (magnitude > 4'd12)          tilt_to_vel = 4'd3;
        else if (magnitude > 4'd10)           tilt_to_vel = 4'd2;
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
    end else if (frame_tick) begin
    

    
    // --- UP       /\
    if (x_sign) begin
        if ( (ship_y_reg + vel_y) < Y_MAX_EFF)
            ship_y_reg <= ship_y_reg + vel_y; 
        else
            ship_y_reg <= Y_MAX_EFF;
    end
    
    // DOWN         \/
    if (!x_sign) begin
        if ( ship_y_reg >  (Y_MIN + vel_y) )
            ship_y_reg <= ship_y_reg - vel_y;
        else
            ship_y_reg <= Y_MIN;
    end
    
    // --- LEFT     <-
    if (!y_sign) begin 
        if ( ship_x_reg > (X_MIN + vel_x) )
            ship_x_reg <= ship_x_reg - vel_x; 
        else
            ship_x_reg <= X_MIN;
    end
    
    // RIGHT        ->
    if (y_sign) begin
        if ( (ship_x_reg + vel_x) < X_MAX_EFF)
            ship_x_reg <= ship_x_reg + vel_x;
        else
            ship_x_reg <= X_MAX_EFF;
    end
    
    
 end
 end

// ==========================================================
// --- Output Assignment 
// ==========================================================

  assign ship_x = ship_x_reg;
  assign ship_y = ship_y_reg;



endmodule
