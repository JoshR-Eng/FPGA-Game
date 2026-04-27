`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: J. Rawlinson 
// 
// Create Date: 09.02.2026 11:12:49
// Design Name: 
// Module Name: vga
// Project Name: 
// Target Devices: Nexys A7-100T 
// Tool Versions: 
// Description: 
// 
// Dependencies: This module recieves the RGB values from `drawcon.v` and
//               sends these values to the display over vga.
//               It operates at 60Hz for a 1440x900 display.
//               Once the entire frame has been drawn, a value `frame_tick`
//               is asserted to gate all the game logic and eliminate 
//               screen tear.
//
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module vga(
    input clk, rst, 
    input [3:0] draw_r, draw_g, draw_b,
    output [10:0] curr_x, curr_y,
    output [3:0] pix_r, pix_g, pix_b,
    output hsync, vsync,
    output frame_tick
    );

// ==========================================================
// --- Internal Signals
// ==========================================================

reg [10:0] hcount;
reg [9:0] vcount;
reg [10:0] curr_x_r;
reg [10:0] curr_y_r;

wire display_region;
wire line_end = (hcount == 11'd1903);
wire frame_end = (vcount == 10'd931);


// ==========================================================
// --- hsync & vsync logic
// ==========================================================

// hsync vsync assign combinational
assign hsync = ((hcount >= 11'd0) && (hcount <= 11'd151));
assign vsync = ((vcount >= 10'd0) && (vcount <= 11'd2));

assign display_region = ((hcount >= 11'd384) && (hcount <= 11'd1823) && 
                         (vcount >= 10'd31)  && (vcount <= 11'd930)  );

// pix assign combinational
assign pix_b = (display_region) ? draw_b : 4'b0000;
assign pix_g = (display_region) ? draw_g : 4'b0000;
assign pix_r = (display_region) ? draw_r : 4'b0000;


// hcount synchronous
    always @(posedge clk) begin
        if (!rst)
            hcount <= 11'd0;
        else begin
            if (line_end)
                hcount <= 11'd0;
            else
                hcount <= hcount + 11'd1;
        end
    end      

// vcount synchronous
    always @(posedge clk) begin
        if (!rst)
            vcount <= 10'd0;
        else begin
            if (frame_end)
                vcount <= 10'd0;
            else if (line_end)
                vcount <= vcount + 10'd1;
        end
    end   
    
    
    
// ==========================================================
// --- Current Pixel being drawn logic
// ==========================================================
    
// curr_x synchronous
    always @(posedge clk) begin
        if (!rst)
            curr_x_r <= 11'd0;
        else begin
            if( (hcount >= 11'd384) && (hcount <= 11'd1823) ) begin
                curr_x_r <= curr_x_r + 11'd1;
            end else begin
                curr_x_r <= 11'd0;
            end
        end
    end 


// curr_y synchronous
    always @(posedge clk) begin
        if (!rst)
            curr_y_r <= 11'd0;
        else begin
            if (line_end) begin
                if((vcount >= 11'd31) && (vcount <= 11'd930)) begin
                    curr_y_r <= curr_y_r + 11'd1;
                end else begin
                    curr_y_r <= 11'd0;
                end             
            end
        end
    end 

assign curr_x = curr_x_r;
assign curr_y = curr_y_r;


// ==========================================================
// --- 60Hz Frame tick 
// ==========================================================
reg frame_tick_r;
always @(posedge clk) begin
    frame_tick_r <= (vcount == 10'd931) && (hcount == 11'd0);
end

assign frame_tick = frame_tick_r;

// ==========================================================
// --- END
// ==========================================================
endmodule
