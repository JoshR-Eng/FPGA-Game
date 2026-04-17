`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.04.2026 17:26:30
// Design Name: 
// Module Name: crosshairMovement 
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


module crosshairMovement #(
    // Screen Size
  parameter X_MIN = 11'd10,
  parameter X_MAX = 11'd1430,
  parameter Y_MIN = 11'd10,
  parameter Y_MAX = 11'd890,

  // Crosshair Starting Position
  parameter START_X = 11'd720,
  parameter START_Y = 11'd450,
      
  // Crosshair Drawing
  parameter CURSOR_ARM          = 8,   // Half-length of each bar
  parameter CURSOR_THICK        = 1, // Half-width of each bar
  parameter CURSOR_SPEED        = 10
  )(
  input clk,
  input rst,
  input frame_tick,
  input new_game,

  input [4:0] btn,

  output [10:0] cursor_x,
  output [10:0] cursor_y,

  output on_cursor
);
    

// ==========================================================
// --- Internal Wiring
// ==========================================================    

reg [10:0] cursor_x_reg, cursor_y_reg;



// ==========================================================
// --- Crosshair 
// ==========================================================

// Crosshair movement
always @(posedge clk) begin
  if (!rst) begin
    cursor_x <= 11'd720;
    cursor_y <= 11'd440;
  end else if (frame_tick) begin

    // X axis 
    if      (btn[2] && cursor_x > (SCREEN_X_MIN + CURSOR_ARM + CURSOR_SPEED))
        cursor_x <= cursor_x - CURSOR_SPEED;
    else if (btn[2])
        cursor_x <= SCREEN_X_MIN + CURSOR_ARM;    // clamp — guarantees cursor_x >= CURSOR_ARM
    else if (btn[3] && (cursor_x + CURSOR_ARM + CURSOR_SPEED) <= SCREEN_X_MAX)
        cursor_x <= cursor_x + CURSOR_SPEED;
    else if (btn[3])
        cursor_x <= SCREEN_X_MAX - CURSOR_ARM;

    // Y axis 
    if      (btn[1] && cursor_y > (SCREEN_Y_MIN + CURSOR_ARM + CURSOR_SPEED))
        cursor_y <= cursor_y - CURSOR_SPEED;
    else if (btn[1])
        cursor_y <= SCREEN_Y_MIN + CURSOR_ARM;    // clamp — guarantees cursor_y >= CURSOR_ARM
    else if (btn[4] && (cursor_y + CURSOR_ARM + CURSOR_SPEED) <= SCREEN_Y_MAX )
        cursor_y <= cursor_y + CURSOR_SPEED;
    else if (btn[4])
        cursor_y <= SCREEN_Y_MAX - CURSOR_ARM;

  end
end



// ==========================================================
// --- Assignment 
// ==========================================================

assign on_cursor = (
  // Horizontal bar
  (curr_x >= (cursor_x - CURSOR_ARM)   ) && (curr_x <= (cursor_x + CURSOR_ARM)   ) &&
  (curr_y >= (cursor_y - CURSOR_THICK) ) && (curr_y <= (cursor_y + CURSOR_THICK) ) 
  ||
  // Vertical bar
  (curr_x >= (cursor_x - CURSOR_THICK) )  && (curr_x <= (cursor_x + CURSOR_THICK) ) &&
  (curr_y >= (cursor_y - CURSOR_ARM)   )  && (curr_y <= (cursor_y + CURSOR_ARM)   ) 
  );


assign cursor_x = cursor_x_reg;
assign cursor_y = cursor_y_reg;


endmodule
