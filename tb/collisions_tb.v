`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: J. Rawlinson 
// 
// Create Date: 09.02.2026 11:41:29
// Design Name: 
// Module Name: collisions_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Test bench to ensure the `collision.v` module is fully
//              functional 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module collisions_tb();

//==========================================================
// --- Signals & Parameters
//==========================================================

// --- Inputs (reg)
reg         clk;
reg         rst;
reg         frame_tick;

reg [175:0] bul_x_packed;
reg [175:0] bul_y_packed;
reg [15:0]  bul_active_packed;

reg [10:0]  ship_x;
reg [10:0]  ship_y;

reg [175:0] astr_x_packed;
reg [175:0] astr_y_packed;
reg [15:0]  astr_active_packed;
reg [31:0]  astr_size_packed;

// --- Outputs (wire)
wire [15:0] bul_hit;
wire [15:0] astr_hit;
wire        ship_hit;

// --- Test tracking
integer test_pass;
integer test_fail;

// --- Parameters
parameter MAX_BULLETS   = 16;
parameter MAX_ASTEROIDS = 16;
parameter BULLET_WIDTH  = 10;
parameter BULLET_HEIGHT = 10;
parameter SHIP_WIDTH    = 100;
parameter SHIP_HEIGHT   = 100;
parameter ASTR_SMALL    = 12;
parameter ASTR_MEDIUM   = 24;
parameter ASTR_LARGE    = 48;

//==========================================================
// --- Clock Generation
//==========================================================

// --- 100 MHz Clock
initial clk = 0;
always #5 clk = ~clk;



//==========================================================
// --- Tests
//==========================================================

initial begin
  $dumpfile("waves.vcd");
  $dumpvars(1, collisions_tb);

  // --- Initialise
  test_pass  = 0;
  test_fail  = 0;
  rst        = 1'b0;
  frame_tick = 1'b0;
  clear_all();

  // Apply reset for 2 cycles then release
  @(posedge clk); @(posedge clk);
  rst = 1'b1;
  @(posedge clk); @(posedge clk);


  // -------------------------------------------------------
  // TEST 1: Direct bullet-asteroid hit (small asteroid)
  //
  //    Objective:
  //      Place a bullet within the area of an asteroid
  //
  //    Expectation
  //      Bullet & Asteroid are deactivated
  //      Hit flags are asserted
  // -------------------------------------------------------
  $display("\n --- TEST 1: Direct hit ---");
  clear_all();
  set_asteroid  (0, 11'd500, 11'd500, 2'b00, 1'b1); // small, active
  set_bullet    (0, 11'd494, 11'd494, 1'b1);        // active
  fire_frame_tick();

  check("T1: astr_hit[0] == 1", astr_hit[0] == 1'b1);
  check("T1: bul_hit[0]  == 1", bul_hit[0]  == 1'b1);
  check("T1: ship_hit    == 0", ship_hit     == 1'b0);
  check("T1: no other astr_hit", astr_hit[15:1] == 15'b0);
  check("T1: no other bul_hit",  bul_hit[15:1]  == 15'b0);



  // -------------------------------------------------------
  // TEST 2: Near Miss (bullet just outside astr. area)
  //
  //    Objective:
  //      Place a bullet just outside the area of an asteroid
  //
  //    Expectation
  //      Hit flags are NOT raised
  //      bullets & astroid remain active
  // -------------------------------------------------------
  $display("\n--- TEST 2: Near miss ---");
  clear_all();
  set_asteroid(0, 11'd500, 11'd500, 2'b00, 1'b1); // small, active
  set_bullet  (0, 11'd477, 11'd494, 1'b1);        // right edge at 487, just misses
  fire_frame_tick();

  check("T2: astr_hit[0] == 0", astr_hit[0] == 1'b0);
  check("T2: bul_hit[0]  == 0", bul_hit[0]  == 1'b0);
  check("T2: ship_hit    == 0", ship_hit    == 1'b0);



  // -------------------------------------------------------
  // TEST 3: Size Scaling 
  //
  //    Objective:
  //      Place a bullet at the same pos. but change astr size 
  //      Should prove `astr_half_size()` correctly maps size
  //
  //    Expectation
  //      Hit flags are ONLY raised for LARGE astr
  // -------------------------------------------------------
  $display("\n--- TEST 3: Astroid Size Scaling ---");
  // LARGE Asteroid 
  clear_all();
  set_asteroid(0, 11'd500, 11'd500, 2'b10, 1'b1);  // LARGE, active
  set_bullet  (0, 11'd477, 11'd494, 1'b1);
  fire_frame_tick();

  check("T3l: LARGE hit - astr_hit[0] == 1", astr_hit[0] == 1'b1);
  check("T3l: LARGE hit - bul_hit[0]  == 1", bul_hit[0]  == 1'b1);

  // SMALL Asteroid 
  clear_all();
  set_asteroid(0, 11'd500, 11'd500, 2'b00, 1'b1);  // SMALL, active
  set_bullet  (0, 11'd477, 11'd494, 1'b1);
  fire_frame_tick();

  check("T3s: SMALL miss - astr_hit[0] == 0", astr_hit[0] == 1'b0);
  check("T3s: SMALL miss - bul_hit[0]  == 0", bul_hit[0]  == 1'b0);

  // MEDIUM Asteroid 
  clear_all();
  set_asteroid(0, 11'd500, 11'd500, 2'b01, 1'b1);  // MEDIUM, active
  set_bullet  (0, 11'd466, 11'd494, 1'b1);
  fire_frame_tick();

  check("T3m: MEDIUM boundary miss - astr_hit[0] == 0", astr_hit[0] == 1'b0);
  check("T3m: MEDIUM boundary miss - bul_hit[0]  == 0", bul_hit[0]  == 1'b0);


  // -------------------------------------------------------
  // TEST 4: Ship-asteroid collision 
  //
  //    Objective:
  //      Place ship & asteroid in overlapping positions
  //      should validate the ship collides with astroid
  //
  //    Expectation
  //      Ship Hit flag is raised
  //      astroid is deactivated
  // -------------------------------------------------------
  $display("\n--- TEST 4: Ship–asteroid collision ---");

  // Part A: ship hit
  clear_all();
  ship_x = 11'd600;
  ship_y = 11'd400;
  set_asteroid(0, 11'd680, 11'd450, 2'b00, 1'b1);  // small, overlaps ship
  fire_frame_tick();

  check("T4a: ship overlap - ship_hit == 1",  ship_hit     == 1'b1);
  check("T4a: no bul_hit  - bul_hit == 0",   bul_hit      == 16'b0);

  // Part B: ship near miss
  clear_all();
  ship_x = 11'd600;
  ship_y = 11'd400;
  set_asteroid(0, 11'd712, 11'd450, 2'b00, 1'b1);  // left edge at 700 = ship right edge
  fire_frame_tick();

  check("T4b: ship near miss - ship_hit == 0", ship_hit == 1'b0);

  // Part C: inactive asteroid — ship_hit must remain 0 even when positions overlap
  clear_all();
  ship_x = 11'd600;
  ship_y = 11'd400;
  set_asteroid(0, 11'd680, 11'd450, 2'b00, 1'b0);  // INACTIVE — same pos as T4a
  fire_frame_tick();

  check("T4c: inactive asteroid - ship_hit == 0", ship_hit == 1'b0);


  // -------------------------------------------------------
  //                      SUMMARY
  // -------------------------------------------------------
  $display("\n--- `collision_tb` COMPLETE --- \n\t%0d PASS\n\t%0d FAIL",
            test_pass,
            test_fail);
  $finish;
end


//==========================================================
// --- Helper Tasks
//==========================================================

// Clear all inputs to a known inactivate state
task clear_all;
  begin
      bul_x_packed      = 0;
      bul_y_packed      = 0;
      bul_active_packed = 16'b0;
      astr_x_packed     = 0;
      astr_y_packed     = 0;
      astr_active_packed= 16'b0;
      astr_size_packed  = 32'b0;
      ship_x            = 11'd0;
      ship_y            = 11'd0;
      frame_tick        = 1'b0;
  end
endtask

// Drive bullet slot [index] with position and active state
task set_bullet;
  input [31:0]  index;
  input [10:0]  x;
  input [10:0]  y;
  input         active;
  begin
      bul_x_packed[(index*11)+10 -: 11] = x;
      bul_y_packed[(index*11)+10 -: 11] = y;
      bul_active_packed[index]           = active;
  end
endtask

// Drive asteroid slot [index] with position, size and active state
task set_asteroid;
    input [31:0]    index;
    input [10:0]    x;
    input [10:0]    y;
    input [1:0]     size;   // 2'b00=small, 2'b01=medium, 2'b10=large
    input           active;
    begin
        astr_x_packed[(index*11)+10 -: 11] = x;
        astr_y_packed[(index*11)+10 -: 11] = y;
        astr_size_packed[(index*2)+1  -: 2] = size;
        astr_active_packed[index]           = active;
    end
endtask

// Fire one frame_tick pulse then wait 2 cycles for registered outputs to settle
task fire_frame_tick;
    begin
        @(posedge clk);
        frame_tick = 1'b1;
        @(posedge clk);
        frame_tick = 1'b0;
        @(posedge clk);   // settle cycle 1
        @(posedge clk);   // settle cycle 2
    end
endtask

// Convenience assertion task — prints PASS/FAIL and updates counters
task check;
    input [127:0]   test_name;  // string label
    input           condition;  // 1 = pass
    begin
        if (condition) begin
            $display("[PASS] %s", test_name);
            test_pass = test_pass + 1;
        end else begin
            $display("[FAIL] %s", test_name);
            test_fail = test_fail + 1;
        end
    end
endtask


//==========================================================
// --- Instantiate Module being Tested
//==========================================================
collisions uut (
    .clk              (clk),
    .rst                (rst),
    .frame_tick         (frame_tick),
    .bul_x_packed       (bul_x_packed),
    .bul_y_packed       (bul_y_packed),
    .bul_active_packed  (bul_active_packed),
    .ship_x             (ship_x),
    .ship_y             (ship_y),
    .astr_x_packed      (astr_x_packed),
    .astr_y_packed      (astr_y_packed),
    .astr_active_packed(astr_active_packed),
    .astr_size_packed (astr_size_packed),
    .bul_hit          (bul_hit),
    .astr_hit         (astr_hit),
    .ship_hit         (ship_hit)
);

endmodule
