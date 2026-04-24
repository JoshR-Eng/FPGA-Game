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
integer hcount_ticks;          // counts cycles where hsync is high
integer vsync_ticks;           // counts cycles where vsync is high  
integer active_pixel_count;    // counts cycles where display_region should be active
integer curr_x_errors;         // counts curr_x sequencing violations
integer curr_y_errors;         // counts curr_y sequencing violations
integer blank_colour_errors;   // counts non-zero pixel output during blanking

// --- Testing Registers
reg [10:0] prev_curr_x;
reg [9:0]  prev_curr_y;
reg        in_display_region;  // software model of display_region

// --- Parameters
parameter PERIOD        = 10;           // ns per clock
parameter FRAME_CYCLES  = 1904 * 932;   // cycles per frame
parameter NUM_FRAMES    = 3;           

//==========================================================
// --- Clock Generation
//==========================================================

// --- 100 MHz Clock
always #5 clk = ~clk;



//==========================================================
// --- Tests
//==========================================================

// --- MONITOR ---------------------------------------------
//  1. continously check number of frame_tick's
//  2. ensure hsync is never high during the active display window
//  3. vsync must never be high when curr_y >0
//  4. ensure all pixel outputs must be 0 outside `display_region`
always @(posedge clk) begin

    // 1.
    if (frame_tick)
        frame_count <= frame_count + 1;

    // 2.
    if (hsync && (pix_r !=0 || pix_g !=0 || pix_b !=0))
      $display("[FAIL] T=%0t: hsync asserted but px outputs are non-zero",
              $time);

    // 3.
    if (vsync && (pix_r !=0 || pix_g !=0 || pix_b !=0))
      $display("[FAIL] T=%0t: vsync asserted but px outputs are non-zero",
              $time);

    // 4.
    always @(posedge clk) begin
    if (curr_x == 11'd0 && (pix_r != 0 || pix_g != 0 || pix_b != 0))
        blank_colour_errors <= blank_colour_errors + 1;
    end
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
    $dumpfile("vga_tb.vcd");
    $dumpvars(0, vga_tb);

    // Initialise
    frame_count         = 0;
    blank_colour_errors = 0;
    clk  = 0;
    rst  = 0;
    draw_r = 4'h0; draw_g = 4'h0; draw_b = 4'h0;
    #20;
    rst = 1;
    
    $dumpoff; // pausing dumping during bulk frame runs
   
    // --- TEST 1: frame count -----------------------------
    // Run for N complete frames
    #(PERIOD * FRAME_CYCLES * NUM_FRAMES);
    // Check results
    if (frame_count == NUM_FRAMES)
        $display("[PASS] frame_tick: Correct Count");
    else
        $display("[FAIL] frame_tick: expected %0d ticks, got %0d",
                  NUM_FRAMES, 
                  frame_count);
    
    
    // --- Test 2: hsync timing ---------------------------- 
    // Expected: hsync is high for hcount 0-151 = 152 cycles per line
    // With 932 lines per frame and 3 frames = 932 * 3 = 2796 rising edges of hsync
    // Count them:
    begin : test_hsync
      integer hsync_rise_count;
      reg hsync_prev_t2;
      hsync_rise_count    =0;
      hsync_prev_t2       =0;

      // Re-run for 1 frame, counting hsync rising edge
      rst =0;   #20;    rst =1;

      repeat (1904 * 932) begin
        @(posedge clk);
        if (hsync && !hsync_prev_t2)
          hsync_rise_count = hsync_rise_count + 1;
        hsync_prev_t2 =hsync;
      end

      if (hsync_rise_count == 932)
        $display("[PASS] hsync: %0d rising edges in 1 frame (expected 932)", 
                    hsync_rise_count);
      else
        $display("[FAIL] hsync: %0d rising edges in 1 frame (expected 932)", 
                    hsync_rise_count);
    end


    // --- Test 3: curr_x sequencing ----------------------- 
    // curr_x should:
    //  * count 0,1,2,...,1439 then reset to 0
    //  * Never > 1439
    //  * Constant step of +1 or reset to 0
    begin : test_curr_x
        integer cx_errors;
        reg [10:0] cx_prev;
        reg [10:0] cx_expected;
        
        cx_errors   = 0;
        cx_prev     = 0;
        cx_expected = 0;
        
        rst = 0; #20; rst = 1;
        
        // Warm-up: skip 1 full frame after reset before checking
        repeat (1904 * 932) @(posedge clk);


        // Run 2 full frames
        repeat (1904 * 932 * 2) begin
            @(posedge clk);
            
            // curr_x should never exceed screen width
            if (curr_x > 11'd1440) begin
                $display("[FAIL] T=%0t: curr_x=%0d exceeds 1439", $time, curr_x);
                cx_errors = cx_errors + 1;
            end
            
            // curr_x must either increment by 1 or reset to 0
            if (curr_x != 0 && curr_x != (cx_prev + 1)) begin
                $display("[FAIL] T=%0t: curr_x jumped from %0d to %0d", 
                          $time, cx_prev, curr_x);
                cx_errors = cx_errors + 1;
            end
            
            cx_prev = curr_x;
        end
        
        if (cx_errors == 0)
            $display("[PASS] curr_x: monotonic, in-bounds over 2 frames");
        else
            $display("[FAIL] curr_x: %0d sequencing errors", cx_errors);
    end

    // --- TEST 4: Active pixel count ----------------------
    // Count cycles where pix_r/g/b are non-zero 
    // Expected: exactly 1440 * 900 = 1,296,000 non-zero cycles per frame

    $dumpon; // resume dumping for test 4
    begin : test_active_count
        integer active_count;
        integer ft_count;
        
        active_count = 0;
        ft_count     = 0;
        
        // Set a known non-zero draw input
        draw_r = 4'hF;
        draw_g = 4'h0;
        draw_b = 4'h0;
        
        rst = 0; #20; rst = 1;
        
        // Run exactly 1 frame: wait for frame_tick to start clean
        @(posedge frame_tick);
        // Count from start of next frame to the following frame_tick
        @(posedge frame_tick);   // now at frame boundary
        
        active_count = 0;
        repeat (1904 * 932) begin
            @(posedge clk);
            if (pix_r == 4'hF)   // only our colour counts
                active_count = active_count + 1;
        end
        
        if (active_count == 1_296_000)
            $display("[PASS] Active pixel count: %0d (expected 1,296,000)", 
                        active_count);
        else
            $display("[FAIL] Active pixel count: %0d (expected 1,296,000)", 
                        active_count);
        
        draw_r = 4'h0;  // restore
    end

    $dumpoff;
    // --- Test 5: Blanking Colour Check -------------------
    if (blank_colour_errors == 0)
        $display("[PASS] No non-zero pixels during blanking");
    else
        $display("[FAIL] %0d blanking violations detected", blank_colour_errors);







    $display("--- tb_vga complete ---");
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
