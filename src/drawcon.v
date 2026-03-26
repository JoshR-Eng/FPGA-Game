`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 22.02.2026 14:12:10
// Design Name: 
// Module Name: drawcon
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


module drawcon #(
    parameter SHIP_WIDTH = 100,
    parameter SHIP_HEIGHT = 100,
    parameter BULLET_SIZE = 10
    )(
    input clk, rst,
    input [10:0] curr_x, curr_y,
    input [10:0] blkpos_x, blkpos_y,
    input [10:0] bullet_x, bullet_y,
    input bullet_active,
    output [3:0] draw_r, draw_g, draw_b
    );
    
reg [3:0] blk_r = 0, blk_g = 0, blk_b = 0;  // Initialize at power-up
reg [3:0] bg_r, bg_g, bg_b;
reg [3:0] bullet_r = 0, bullet_g = 0, bullet_b = 0;  // Initialize at power-up

// Signals for the ship image
parameter blk_size_x = SHIP_WIDTH, blk_size_y = SHIP_HEIGHT;
reg [13:0] addr = 0;  // Initialize at power-up to prevent garbage
wire [11:0] rom_pixel;


// ==========================================================
// --- Background Colour
// ==========================================================

always @* begin
  // Creates an all black background &
  // a white border of 10px around the edge
    if((curr_x < 11'd10) || (curr_x > 11'd1430) ||
       (curr_y < 11'd10) || (curr_y > 11'd890)) begin
        bg_r = 4'b1111;
        bg_g = 4'b1111;
        bg_b = 4'b1111;
    end else begin
        bg_r = 4'b0000;
        bg_g = 4'b0000;
        bg_b = 4'b0000;
    end
end


// ==========================================================
// --- Source Mario Head
// ==========================================================
always @ (posedge clk) begin
    if (!rst) begin
        blk_r <= 4'b0000;
        blk_g <= 4'b0000;
        blk_b <= 4'b0000;
        addr <= 0;
    end else if ((curr_x < blkpos_x) || (curr_x > blkpos_x + blk_size_x - 1) ||
                 (curr_y < blkpos_y) || (curr_y > blkpos_y + blk_size_y - 1)) begin
        blk_r <= 4'b0000;
        blk_g <= 4'b0000;
        blk_b <= 4'b0000;
    end else begin
        blk_r <= rom_pixel[11:8];
        blk_g <= rom_pixel[7:4];
        blk_b <= rom_pixel[3:0];
        if ((curr_x == blkpos_x) && (curr_y == blkpos_y))
            addr <= 0;
        else
            addr <= addr + 1;
    end
end


// ==========================================================
// --- Bullet Rendering (White Square)
// ==========================================================
always @* begin
    if (bullet_active &&
        (curr_x >= bullet_x) && (curr_x < bullet_x + BULLET_SIZE) &&
        (curr_y >= bullet_y) && (curr_y < bullet_y + BULLET_SIZE)) begin
        bullet_r = 4'b1111;
        bullet_g = 4'b1111;
        bullet_b = 4'b1111;
    end else begin
        bullet_r = 4'b0000;
        bullet_g = 4'b0000;
        bullet_b = 4'b0000;
    end
end


// ==========================================================
// --- Priority Layering: Bullet > Ship > Background
// ==========================================================
assign draw_r = (bullet_r != 4'b0000) ? bullet_r :
                (blk_r != 4'b0000) ? blk_r : bg_r;
assign draw_g = (bullet_g != 4'b0000) ? bullet_g :
                (blk_g != 4'b0000) ? blk_g : bg_g;
assign draw_b = (bullet_b != 4'b0000) ? bullet_b :
                (blk_b != 4'b0000) ? blk_b : bg_b;



// ==========================================================
// --- Block Memory Assignment 
// ==========================================================

  // Mario Head Image
blk_mem_gen_0 inst
(
.clka(clk),
.addra(addr),
.douta(rom_pixel)
);


endmodule
