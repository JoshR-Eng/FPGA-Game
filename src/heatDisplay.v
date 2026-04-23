`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 16.04.2026 21:39:40 
// Design Name: 
// Module Name: heatDisplay 
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


module heatDisplay #(
  parameter OVERHEAT_THRESHOLD = 8'd200,
  parameter BLINK_BIT      = 3,
  parameter STEP           = 25
  )(
    input clk, 
    input rst,
    input frame_tick,

    input nightmare_en,

    input [7:0] gun_heat,
    output [15:0] LED
    );

// ==========================================================
// --- Blink Counter 
// ==========================================================
reg [4:0] blink_counter;
always @(posedge clk)
  if (!rst)
    blink_counter <= 4'b0;
  else if (frame_tick) 
    blink_counter <= blink_counter + 1'b1;

wire overheat = (gun_heat >= OVERHEAT_THRESHOLD);
wire blink = blink_counter[BLINK_BIT] && overheat; // toggles every 2^BLINK_BIT frames 


// ==========================================================
// --- Heat to LED Mapping 
// ==========================================================

wire [3:0] level = gun_heat / STEP;
reg [15:0] LED_reg;

always @(posedge clk) begin
  if (frame_tick) begin

    if ((gun_heat >= OVERHEAT_THRESHOLD) || (nightmare_en))
      LED_reg <= blink ? 16'hFFFF: 16'h0000;
    else 
      case (level)
        4'd1  :   LED_reg = 16'b1100_0000_0000_0000;
        4'd2  :   LED_reg = 16'b1111_0000_0000_0000;
        4'd3  :   LED_reg = 16'b1111_1100_0000_0000;
        4'd4  :   LED_reg = 16'b1111_1111_0000_0000;
        4'd5  :   LED_reg = 16'b1111_1111_1100_0000;
        4'd6  :   LED_reg = 16'b1111_1111_1111_0000;
        4'd7  :   LED_reg = 16'b1111_1111_1111_1100;
        4'd8  :   LED_reg = 16'b1111_1111_1111_1111;
        default:  LED_reg = 16'h0000;
      endcase
  end
end

assign LED = LED_reg;

// ==========================================================
// --- END
// ==========================================================
endmodule
