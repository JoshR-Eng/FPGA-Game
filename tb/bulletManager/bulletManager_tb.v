`timescale 1ns / 1ps

module bulletManager_tb;
  reg clk, rst, frame_tick, fire_trigger;
  reg [10:0] ship_x, ship_y;
  wire [10:0] bullet_x, bullet_y;
  wire bullet_active;

  // instatiate bulletManager
  bulletManager #(
    .BULLET_SPEED(8),
    .SCREEN_X_MAX(11'd100) // small value for easy test
  ) uut (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .fire_trigger(fire_trigger),
    .ship_x(ship_x),
    .ship_y(ship_y),
    .bullet_x(bullet_x),
    .bullet_y(bullet_y),
    .bullet_active(bullet_active)
  );

  // 100 MHz clock generator
  initial clk = 0;
  always #5 clk = ~clk;

  // Test sequence
  initial begin
    $dumpfile("waves.vcd");
    $dumpvars(0, bulletManager_tb);

    // Init
    rst = 0;
    frame_tick = 0;
    fire_trigger = 0;
    ship_x = 11'd50;
    ship_y = 11'd200;

    // ========================= TEST 1 ========================= 
    #20 rst = 1;
    #20;
    if (bullet_active == 0) $display("[PASS] Test 1: Reset clears bullet");
    else $display("[FAIL] Test 1: Reset did not clear bullet (bullet_active = %b", bullet_active);



    // ========================= TEST 2 ========================= 
    #10 fire_trigger = 1;
    #10 frame_tick = 1;
    #10 frame_tick = 0;
    #10 fire_trigger = 0;
    #10;
    if (bullet_active && bullet_x == 50 && bullet_y == 200)
      $display("[PASS] Test 2: Bullet spawns at ship pos.");
    else
      $display("[FAIL] Test 2: Bullet did not spawn as ship pos.\n active=%b, x=%d (exp. 50), y=%d (exp. 200)", bullet_active, bullet_x, bullet_y);



    // ========================= TEST 3 ========================= 
    #10 frame_tick = 1;
    #10 frame_tick = 0;
    #10;
    if (bullet_x == 58)  // 50 + 8
      $display("[PASS] Test 3: Bullet moves right");
    else
      $display("[FAIL] Test 3: x=%d (exp 58)", bullet_x);

    // ========================= TEST 4 ========================= 
    repeat(10) begin
      #10 frame_tick = 1;
      #10 frame_tick = 0;
    end
    #10;
    if (bullet_active == 0)
      $display("[PASS] Test 4: Bullet deactivates off-screen");
    else
      $display("[FAIL] Test 4: Still active at x=%d", bullet_x); 


    // ========================= TEST 5 ========================= 
    #10 fire_trigger = 1;
    #10 frame_tick = 1;
    #10 frame_tick = 0;
    #10 fire_trigger = 0;
    #10;
      if (bullet_active && bullet_x == 50)
        $display("[PASS] Test 5: Can spawn new bullet");
      else
        $display("[FAIL] Test 5: active=%b, x=%d", bullet_active, bullet_x);
      $display("\n=== Testbench Complete ===");
      $finish;
  
  end

endmodule
