`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.02.2026 11:41:29
// Design Name: 
// Module Name: vga_tb
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


module vga_tb();

//==========================================================
// --- Signals & Parameters
//==========================================================

// --- Inputs ( = reg)
reg clk;
reg rst;
reg [3:0] draw_r, draw_g, draw_b;

// --- Outputs ( = wire)
wire [10:0] curr_x, curr_y;
wire [3:0] pix_r, pix_g, pix_b;
wire hsync, vsync;
wire frame_tick;

// --- Integers
integer frame_count;

// --- Parameters
parameter PERIOD        = 10;           // ns per clock
parameter FRAME_CYCLES  = 1904 * 932;   // cycles per frame
parameter NUM_FRAMES    = 1;           

//==========================================================
// --- Clock Generation
//==========================================================

// --- 100 MHz Clock
always #5 clk = ~clk;



//==========================================================
// --- Tests
//==========================================================

// MONITOR
//  continously check number of frame_tick's
always @(posedge clk) begin
    if (frame_tick)
        frame_count <= frame_count + 1;
end

// PULSE WIDTH CHECK
//  continously check frame_tick is high for only 1 tick
reg frame_tick_prev;
always @(posedge clk) begin
    frame_tick_prev <= frame_tick;
    if (frame_tick_prev && frame_tick)
        $display("[FAIL] frame_tick held high for >1 cycle at time %0t", $time);
end


// STIMULUS + CHECKER
//  force input values and check results
initial begin
    $dumpfile("tb_vga.vcd");
    $dumpvars(0, tb_vga);
    
    frame_count = 0;
    clk = 0;
    rst = 0;
    
    #20;
    rst = 1;
    
    // Run for N complete frames
    #(PERIOD * FRAME_CYCLES * NUM_FRAMES);
    // Check results
    if (frame_count == NUM_FRAMES)
        $display("[PASS] ...");
    else
        $display("[FAIL] ...");
    
    $finish;
end


//==========================================================
// --- Instantiate Module being Tested
//==========================================================
vga uut(
    .clk(clk), .rst(rst),
    .draw_r(draw_r), .draw_g(draw_g), .draw_b(draw_b),
    .curr_x(curr_x), .curr_y(curr_y),
    .pix_r(pix_r), .pix_g(pix_g), .pix_b(pix_b),
    .hsync(hsync), .vsync(vsync),
    .frame_tick(frame_tick)
    );

endmodule
