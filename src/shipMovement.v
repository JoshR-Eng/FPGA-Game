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
  parameter START_Y = 11'd450
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
  wire [3:0] x_mag, y_mag;

  // Position reg
  reg [10:0] ship_x_reg;
  reg [10:0] ship_y_reg;




// ==========================================================
// --- Extract Tilt from Accelerometer Data
// ==========================================================
// acl_data comes from game_top (hardware abstraction layer)
// Format: {X[14:10], Y[9:5], Z[4:0]}




// ==========================================================
// --- Raw Tilt Value -> Per-axis Tilt 
// ==========================================================

// Note: Accelerometer is 90 degree rotated on board
// Physical tilt maps to screen coordinates as:
//    Accel X-axis => Screen Y-axis (up/down)
//    Accel Y-axis => Screen X-axis (left/right)

  assign x_sign = acl_data[14];     // X-axis sign bit
  assign x_mag  = acl_data[13:10];  // X-axis magnitude (4 bits)
  assign y_sign = acl_data[9];      // Y-axis sign bit  
  assign y_mag  = acl_data[8:5];    // Y-axis magnitude (4 bits)




// ==========================================================
// --- Movement Logic
// ==========================================================

// Convert tilt mag. to ship velocity
//    Deadzone prevents drif when board is flat
  function [2:0] tilt_to_velocity;
    input [3:0] magnitude;
    begin
      if      (magnitude <= 4'd2)    tilt_to_velocity = 3'd0;// Deadzone
      else if (magnitude <= 4'd5)  tilt_to_velocity = 3'd1;  // Slow
      else if (magnitude <= 4'd9)  tilt_to_velocity = 3'd2;  // Medium
      else if (magnitude <= 4'd13) tilt_to_velocity = 3'd3;  // Fast
      else                         tilt_to_velocity = 3'd4;  // Very fast
      end
  endfunction

// Calculate velocities for current frame
wire [2:0] vel_x = tilt_to_velocity(y_mag); // Y accel -> X screen
wire [2:0] vel_y = tilt_to_velocity(x_mag); // X accel -> Y screen

// Position update logic
//    synchronised with frame_tick so that update only 
//    happens once new screen begins drawing
  always @(posedge clk) begin
    if (!rst) begin
      // Reset to center of screen
      ship_x_reg <= START_X;
      ship_y_reg <= START_Y;
    end else if (frame_tick) begin
      // Update position at frame reset

      // ===    X-axis    ===
      if (y_sign == 1'b1) begin
        // Tilt right
        if (ship_x_reg < X_MAX)
          ship_x_reg <= ship_x_reg + vel_x;
        else if ( (ship_x_reg + vel_x) > X_MAX)
            ship_x_reg <= X_MAX;
      end else begin
        // Tile left
        if (ship_x_reg > X_MIN) 
          ship_x_reg <= ship_x_reg - vel_x;
        else if (ship_x_reg < (X_MIN + vel_x) )
            ship_x_reg <= X_MIN;
      end

      // ===    Y-axis    ===
      if (x_sign == 1'b1) begin
        // Tilt back (move up)
        if (ship_y_reg > Y_MIN)
          ship_y_reg <= ship_y_reg - vel_y;
        else if (ship_y_reg < (Y_MIN + vel_y) )
            ship_y_reg <= Y_MIN;
      end else begin
        // Tile forward (move down)
        if (ship_y_reg < Y_MAX) 
          ship_y_reg <= ship_y_reg + vel_y;
        else if ( (ship_y_reg + vel_y) > Y_MAX)
            ship_y_reg <= Y_MAX;
      end
    end
  end



// ==========================================================
// --- Output Assignment 
// ==========================================================

  assign ship_x = ship_x_reg;
  assign ship_y = ship_y_reg;



endmodule
