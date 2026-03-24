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


module drawcon(
    input clk, rst,
    input [10:0] curr_x, curr_y,
    input [10:0] blkpos_x, blkpos_y,
    output [3:0] draw_r, draw_g, draw_b
    );
    
reg [3:0] blk_r, blk_g, blk_b;
reg [3:0] bg_r, bg_g, bg_b;

// Signals for the image
parameter blk_size_x = 100, blk_size_y = 100;
reg [13:0] addr;
wire [11:0] rom_pixel;


// Background Colour
always @* begin
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

// Image Block
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

assign draw_r = (blk_r != 4'b0000) ? blk_r : bg_r;
assign draw_g = (blk_g != 4'b0000) ? blk_g : bg_g;
assign draw_b = (blk_b != 4'b0000) ? blk_b : bg_b;



// Instatitate Memory
blk_mem_gen_0 inst
(
.clka(clk),
.addra(addr),
.douta(rom_pixel)
);


endmodule
