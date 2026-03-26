`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Comprehensive Bullet System Testbench
// Tests: bulletManager + drawcon integration
// Validates: spawning, movement, rendering, heat system, LEDs
//////////////////////////////////////////////////////////////////////////////////

module bullet_system_tb;

  // Clock and control
  reg clk, rst, frame_tick;
  
  // Inputs
  reg fire_trigger;
  reg [10:0] ship_x, ship_y;
  
  // bulletManager outputs
  wire [10:0] bullet_x, bullet_y;
  wire bullet_active;
  wire [7:0] gun_heat;
  wire [15:0] LED;
  
  // drawcon outputs
  wire [3:0] draw_r, draw_g, draw_b;
  reg [10:0] curr_x, curr_y;
  
  // Test counters
  integer test_num = 0;
  integer pass_count = 0;
  integer fail_count = 0;
  
  //==========================================================
  // DUT Instantiation
  //==========================================================
  
  // bulletManager instance
  bulletManager #(
    .BULLET_SPEED(8'd2),      // Slow for testing
    .HEAT_PER_SHOT(8'd32),
    .COOLDOWN_RATE(8'd2),
    .OVERHEAT_THRESHOLD(8'd200),
    .SCREEN_X_MAX(11'd1430),
    .SCREEN_Y_MAX(11'd890)
  ) bullet_mgr (
    .clk(clk),
    .rst(rst),
    .frame_tick(frame_tick),
    .fire_trigger(fire_trigger),
    .ship_x(ship_x),
    .ship_y(ship_y),
    .bullet_x(bullet_x),
    .bullet_y(bullet_y),
    .bullet_active(bullet_active),
    .gun_heat(gun_heat),
    .LED(LED)
  );
  
  // drawcon instance (simplified - no BRAM)
  drawcon #(
    .SHIP_WIDTH(100),
    .SHIP_HEIGHT(100),
    .BULLET_SIZE(50)  // Large for visibility
  ) draw_inst (
    .clk(clk),
    .rst(rst),
    .curr_x(curr_x),
    .curr_y(curr_y),
    .blkpos_x(ship_x),
    .blkpos_y(ship_y),
    .bullet_x(bullet_x),
    .bullet_y(bullet_y),
    .bullet_active(bullet_active),
    .draw_r(draw_r),
    .draw_g(draw_g),
    .draw_b(draw_b)
  );
  
  //==========================================================
  // Clock Generation
  //==========================================================
  initial clk = 0;
  always #5 clk = ~clk;  // 100MHz
  
  //==========================================================
  // Test Tasks
  //==========================================================
  
  task check;
    input condition;
    input [200*8:1] test_name;
    begin
      test_num = test_num + 1;
      if (condition) begin
        $display("[PASS] Test %0d: %0s", test_num, test_name);
        pass_count = pass_count + 1;
      end else begin
        $display("[FAIL] Test %0d: %0s", test_num, test_name);
        fail_count = fail_count + 1;
      end
    end
  endtask
  
  task wait_frame;
    begin
      @(posedge clk);
      frame_tick = 1;
      @(posedge clk);
      frame_tick = 0;
      @(posedge clk);
    end
  endtask
  
  task fire_bullet;
    begin
      fire_trigger = 1;
      wait_frame();
      fire_trigger = 0;
    end
  endtask
  
  task check_pixel_color;
    input [10:0] x, y;
    input [3:0] expected_r, expected_g, expected_b;
    input [200*8:1] test_name;
    begin
      curr_x = x;
      curr_y = y;
      #1;  // Wait for combinational logic
      check((draw_r == expected_r) && (draw_g == expected_g) && (draw_b == expected_b), 
            test_name);
      if ((draw_r != expected_r) || (draw_g != expected_g) || (draw_b != expected_b)) begin
        $display("    Expected: RGB(%h,%h,%h), Got: RGB(%h,%h,%h) at (%0d,%0d)",
                 expected_r, expected_g, expected_b, draw_r, draw_g, draw_b, x, y);
      end
    end
  endtask
  
  //==========================================================
  // Main Test Sequence
  //==========================================================
  initial begin
    $display("\n========================================");
    $display("Comprehensive Bullet System Test");
    $display("========================================\n");
    
    // Initialize
    rst = 0;
    fire_trigger = 0;
    frame_tick = 0;
    ship_x = 11'd200;
    ship_y = 11'd200;
    curr_x = 0;
    curr_y = 0;
    
    #20;
    rst = 1;
    #20;
    
    //========================================
    // TEST GROUP 1: Initial State
    //========================================
    $display("\n--- Test Group 1: Initial State ---");
    
    check(bullet_active == 0, "Bullet initially inactive");
    check(gun_heat == 0, "Gun heat initially zero");
    check(LED == 16'h0000, "LEDs initially off");
    
    //========================================
    // TEST GROUP 2: Bullet Spawning
    //========================================
    $display("\n--- Test Group 2: Bullet Spawning ---");
    
    fire_bullet();
    
    check(bullet_active == 1, "Bullet spawned after fire trigger");
    check(bullet_x == 200, "Bullet spawned at correct X (200)");
    check(bullet_y == 200, "Bullet spawned at correct Y (200)");
    check(gun_heat == 32, "Gun heat increased by 32 after shot");
    check(LED[1] == 1, "LED[1] lit at heat=32");
    
    $display("  Bullet state: active=%b, x=%0d, y=%0d, heat=%0d, LED=%b",
             bullet_active, bullet_x, bullet_y, gun_heat, LED);
    
    //========================================
    // TEST GROUP 3: Bullet Movement
    //========================================
    $display("\n--- Test Group 3: Bullet Movement ---");
    
    // Move for 5 frames
    repeat(5) wait_frame();
    
    check(bullet_active == 1, "Bullet still active after movement");
    check(bullet_x == 210, "Bullet moved right (200 + 5*2 = 210)");
    check(bullet_y == 200, "Bullet Y unchanged");
    
    $display("  After 5 frames: x=%0d (expected 210)", bullet_x);
    
    //========================================
    // TEST GROUP 4: Rendering - Bullet Visible
    //========================================
    $display("\n--- Test Group 4: Rendering - Bullet Should Be Visible ---");
    
    // Check pixel inside bullet (at 210,200 - bullet is 50x50)
    check_pixel_color(11'd210, 11'd200, 4'hF, 4'h0, 4'h0, 
                      "Pixel at bullet position is RED");
    
    check_pixel_color(11'd225, 11'd215, 4'hF, 4'h0, 4'h0,
                      "Pixel in middle of bullet is RED");
    
    check_pixel_color(11'd259, 11'd249, 4'hF, 4'h0, 4'h0,
                      "Pixel at bullet edge (210+49, 200+49) is RED");
    
    //========================================
    // TEST GROUP 5: Rendering - Outside Bullet
    //========================================
    $display("\n--- Test Group 5: Rendering - Outside Bullet Should Be Black ---");
    
    check_pixel_color(11'd100, 11'd100, 4'h0, 4'h0, 4'h0,
                      "Pixel far from bullet is BLACK");
    
    check_pixel_color(11'd209, 11'd200, 4'h0, 4'h0, 4'h0,
                      "Pixel just before bullet (x=209) is BLACK");
    
    check_pixel_color(11'd260, 11'd200, 4'h0, 4'h0, 4'h0,
                      "Pixel just after bullet (x=260) is BLACK");
    
    //========================================
    // TEST GROUP 6: Heat Accumulation
    //========================================
    $display("\n--- Test Group 6: Heat Accumulation ---");
    
    // Fire 5 more bullets (total 6)
    repeat(5) begin
      fire_bullet();
    end
    
    check(gun_heat == 192, "Gun heat = 192 after 6 shots (6*32)");
    check(LED[11] == 1, "LED[11] lit at heat=192");
    check(LED[12] == 0, "LED[12] off (threshold 208)");
    
    $display("  Gun heat: %0d, LED pattern: %b", gun_heat, LED);
    
    //========================================
    // TEST GROUP 7: Overheat Protection
    //========================================
    $display("\n--- Test Group 7: Overheat Protection ---");
    
    // Try to fire one more (would be 224 heat, over threshold)
    fire_bullet();
    
    check(gun_heat == 224, "Gun heat = 224 (7*32)");
    
    // Try to fire when overheated
    fire_bullet();
    
    check(gun_heat == 224, "Gun heat unchanged when overheated");
    
    $display("  Overheat state: heat=%0d (threshold=200)", gun_heat);
    
    //========================================
    // TEST GROUP 8: Cooldown
    //========================================
    $display("\n--- Test Group 8: Heat Cooldown ---");
    
    // Wait for cooldown (no firing)
    repeat(10) wait_frame();
    
    check(gun_heat == 204, "Gun cooled down (224 - 10*2 = 204)");
    check(LED[12] == 1, "LED[12] still lit at heat=204");
    
    // Wait for more cooldown
    repeat(100) wait_frame();
    
    check(gun_heat == 4, "Gun nearly cooled (204 - 100*2 = 4)");
    check(LED[0] == 0, "LED[0] off at heat=4");
    
    $display("  After cooldown: heat=%0d, LED=%b", gun_heat, LED);
    
    //========================================
    // TEST GROUP 9: Bullet Bounds Checking
    //========================================
    $display("\n--- Test Group 9: Bullet Bounds Checking ---");
    
    // Move bullet way off screen
    repeat(700) wait_frame();  // Move 700*2 = 1400 pixels
    
    check(bullet_active == 0, "Bullet deactivated after going off screen");
    
    $display("  Bullet final state: active=%b, x=%0d", bullet_active, bullet_x);
    
    //========================================
    // TEST GROUP 10: Respawn After Deactivation
    //========================================
    $display("\n--- Test Group 10: Bullet Respawn ---");
    
    fire_bullet();
    
    check(bullet_active == 1, "New bullet spawned after old one deactivated");
    check(bullet_x == 200, "New bullet at correct position");
    
    //========================================
    // Test Summary
    //========================================
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Total Tests: %0d", test_num);
    $display("Passed:      %0d", pass_count);
    $display("Failed:      %0d", fail_count);
    
    if (fail_count == 0) begin
      $display("\n*** ALL TESTS PASSED ***");
    end else begin
      $display("\n*** %0d TESTS FAILED ***", fail_count);
    end
    
    $display("========================================\n");
    $finish;
  end
  
  // Timeout watchdog
  initial begin
    #50000000;  // 50ms timeout
    $display("\n[ERROR] Testbench timeout!");
    $finish;
  end

endmodule
