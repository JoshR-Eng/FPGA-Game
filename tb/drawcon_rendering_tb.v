`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Rendering Debug Testbench
// Isolates drawcon module to debug bullet rendering
// Tests priority layering, bullet detection, color output
//////////////////////////////////////////////////////////////////////////////////

module drawcon_rendering_tb;

  // Inputs
  reg clk, rst;
  reg [10:0] curr_x, curr_y;
  reg [10:0] ship_x, ship_y;
  reg [10:0] bullet_x, bullet_y;
  reg bullet_active;
  
  // Outputs
  wire [3:0] draw_r, draw_g, draw_b;
  
  // Test counters
  integer test_num = 0;
  integer pass_count = 0;
  integer fail_count = 0;
  
  // Simplified drawcon (no BRAM for simulation)
  drawcon #(
    .SHIP_WIDTH(100),
    .SHIP_HEIGHT(100),
    .BULLET_SIZE(50)
  ) dut (
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
  
  // Clock
  initial clk = 0;
  always #5 clk = ~clk;
  
  //==========================================================
  // Test Tasks
  //==========================================================
  
  task check_color;
    input [10:0] x, y;
    input [3:0] exp_r, exp_g, exp_b;
    input [200*8:1] test_name;
    begin
      test_num = test_num + 1;
      curr_x = x;
      curr_y = y;
      #2;  // Wait for combinational logic
      
      if ((draw_r == exp_r) && (draw_g == exp_g) && (draw_b == exp_b)) begin
        $display("[PASS] Test %0d: %0s", test_num, test_name);
        pass_count = pass_count + 1;
      end else begin
        $display("[FAIL] Test %0d: %0s", test_num, test_name);
        $display("       At pixel (%0d,%0d): Expected RGB(%h,%h,%h), Got RGB(%h,%h,%h)",
                 x, y, exp_r, exp_g, exp_b, draw_r, draw_g, draw_b);
        fail_count = fail_count + 1;
      end
    end
  endtask
  
  task set_bullet;
    input [10:0] x, y;
    input active;
    begin
      bullet_x = x;
      bullet_y = y;
      bullet_active = active;
      #1;
    end
  endtask
  
  task set_ship;
    input [10:0] x, y;
    begin
      ship_x = x;
      ship_y = y;
      #1;
    end
  endtask
  
  //==========================================================
  // Main Test Sequence
  //==========================================================
  initial begin
    $display("\n========================================");
    $display("Rendering Debug Testbench");
    $display("Testing drawcon bullet rendering");
    $display("========================================\n");
    
    // Initialize
    rst = 0;
    curr_x = 0;
    curr_y = 0;
    ship_x = 500;  // Ship far away from test area
    ship_y = 500;
    bullet_x = 0;
    bullet_y = 0;
    bullet_active = 0;
    
    #20;
    rst = 1;
    #20;
    
    //========================================
    // TEST GROUP 1: Background Only
    //========================================
    $display("\n--- Group 1: Background (No Ship, No Bullet) ---");
    
    set_ship(11'd500, 11'd500);  // Far away
    set_bullet(11'd0, 11'd0, 1'b0);  // Inactive
    
    check_color(11'd5, 11'd100, 4'hF, 4'hF, 4'hF, "Border pixel - WHITE");
    check_color(11'd100, 11'd100, 4'h0, 4'h0, 4'h0, "Interior pixel - BLACK");
    check_color(11'd1435, 11'd500, 4'hF, 4'hF, 4'hF, "Right border - WHITE");
    
    //========================================
    // TEST GROUP 2: Bullet Alone (No Ship Overlap)
    //========================================
    $display("\n--- Group 2: Bullet Alone (Active, No Ship) ---");
    
    set_ship(11'd500, 11'd500);  // Ship far away
    set_bullet(11'd200, 11'd300, 1'b1);  // Active bullet at (200,300)
    
    $display("  Bullet config: pos=(%0d,%0d), size=50x50, active=%b",
             bullet_x, bullet_y, bullet_active);
    $display("  Should cover pixels [200-249, 300-349]");
    
    check_color(11'd200, 11'd300, 4'hF, 4'h0, 4'h0, "Bullet top-left corner - RED");
    check_color(11'd225, 11'd325, 4'hF, 4'h0, 4'h0, "Bullet center - RED");
    check_color(11'd249, 11'd349, 4'hF, 4'h0, 4'h0, "Bullet bottom-right corner - RED");
    
    check_color(11'd199, 11'd300, 4'h0, 4'h0, 4'h0, "Just left of bullet - BLACK");
    check_color(11'd250, 11'd300, 4'h0, 4'h0, 4'h0, "Just right of bullet - BLACK");
    check_color(11'd200, 11'd299, 4'h0, 4'h0, 4'h0, "Just above bullet - BLACK");
    check_color(11'd200, 11'd350, 4'h0, 4'h0, 4'h0, "Just below bullet - BLACK");
    
    //========================================
    // TEST GROUP 3: Inactive Bullet (Should Not Show)
    //========================================
    $display("\n--- Group 3: Inactive Bullet (Should Be Invisible) ---");
    
    set_bullet(11'd200, 11'd300, 1'b0);  // Same position but INACTIVE
    
    check_color(11'd200, 11'd300, 4'h0, 4'h0, 4'h0, "Inactive bullet position - BLACK");
    check_color(11'd225, 11'd325, 4'h0, 4'h0, 4'h0, "Inactive bullet center - BLACK");
    
    //========================================
    // TEST GROUP 4: Ship Alone (No Bullet)
    //========================================
    $display("\n--- Group 4: Ship Alone (No Bullet) ---");
    
    set_ship(11'd400, 11'd400);  // Ship at (400,400)
    set_bullet(11'd0, 11'd0, 1'b0);  // No bullet
    
    $display("  Ship config: pos=(%0d,%0d), size=100x100", ship_x, ship_y);
    $display("  Should cover pixels [400-499, 400-499]");
    
    check_color(11'd400, 11'd400, 4'h0, 4'h0, 4'hF, "Ship top-left - BLUE");
    check_color(11'd450, 11'd450, 4'h0, 4'h0, 4'hF, "Ship center - BLUE");
    check_color(11'd499, 11'd499, 4'h0, 4'h0, 4'hF, "Ship bottom-right - BLUE");
    
    check_color(11'd399, 11'd400, 4'h0, 4'h0, 4'h0, "Just left of ship - BLACK");
    check_color(11'd500, 11'd400, 4'h0, 4'h0, 4'h0, "Just right of ship - BLACK");
    
    //========================================
    // TEST GROUP 5: Priority - Bullet Over Ship
    //========================================
    $display("\n--- Group 5: Priority Layering (Bullet OVER Ship) ---");
    
    set_ship(11'd200, 11'd200);  // Ship at (200,200), covers [200-299, 200-299]
    set_bullet(11'd220, 11'd220, 1'b1);  // Bullet at (220,220), covers [220-269, 220-269]
    
    $display("  Ship: [200-299, 200-299]");
    $display("  Bullet: [220-269, 220-269]");
    $display("  Overlap region: [220-269, 220-269] - should be RED (bullet priority)");
    
    check_color(11'd210, 11'd210, 4'h0, 4'h0, 4'hF, "Ship only region - BLUE");
    check_color(11'd220, 11'd220, 4'hF, 4'h0, 4'h0, "Overlap - RED (bullet priority)");
    check_color(11'd240, 11'd240, 4'hF, 4'h0, 4'h0, "Overlap center - RED");
    check_color(11'd269, 11'd269, 4'hF, 4'h0, 4'h0, "Overlap edge - RED");
    check_color(11'd280, 11'd280, 4'h0, 4'h0, 4'hF, "Ship only region 2 - BLUE");
    
    //========================================
    // TEST GROUP 6: Edge Cases
    //========================================
    $display("\n--- Group 6: Edge Cases ---");
    
    // Bullet at screen edge
    set_ship(11'd500, 11'd500);
    set_bullet(11'd10, 11'd10, 1'b1);  // Near top-left corner
    
    check_color(11'd10, 11'd10, 4'hF, 4'h0, 4'h0, "Bullet at screen edge - RED");
    check_color(11'd59, 11'd59, 4'hF, 4'h0, 4'h0, "Bullet edge pixel - RED");
    
    // Bullet partially off-screen
    set_bullet(11'd1420, 11'd850, 1'b1);  // Near bottom-right
    
    check_color(11'd1420, 11'd850, 4'hF, 4'h0, 4'h0, "Bullet near screen edge - RED");
    
    //========================================
    // TEST GROUP 7: Internal Signal Check
    //========================================
    $display("\n--- Group 7: Internal Signal Verification ---");
    
    set_ship(11'd600, 11'd600);  // Ship away from test
    set_bullet(11'd100, 11'd100, 1'b1);
    
    // Check if bullet detection works
    curr_x = 11'd125;
    curr_y = 11'd125;
    #2;
    
    $display("  Pixel (%0d,%0d) - Inside bullet region", curr_x, curr_y);
    $display("  bullet_active = %b", bullet_active);
    $display("  Bullet bounds: [%0d-%0d, %0d-%0d]", 
             bullet_x, bullet_x+50-1, bullet_y, bullet_y+50-1);
    $display("  Condition checks:");
    $display("    bullet_active = %b", bullet_active);
    $display("    curr_x >= bullet_x: %0d >= %0d = %b", curr_x, bullet_x, curr_x >= bullet_x);
    $display("    curr_x < bullet_x+50: %0d < %0d = %b", curr_x, bullet_x+50, curr_x < bullet_x+50);
    $display("    curr_y >= bullet_y: %0d >= %0d = %b", curr_y, bullet_y, curr_y >= bullet_y);
    $display("    curr_y < bullet_y+50: %0d < %0d = %b", curr_y, bullet_y+50, curr_y < bullet_y+50);
    $display("  Output: RGB(%h,%h,%h) - Expected RED (F,0,0)", draw_r, draw_g, draw_b);
    
    if ((draw_r == 4'hF) && (draw_g == 4'h0) && (draw_b == 4'h0)) begin
      $display("  [OK] Bullet rendering works correctly!");
      test_num = test_num + 1;
      pass_count = pass_count + 1;
    end else begin
      $display("  [ERROR] Bullet rendering BROKEN!");
      test_num = test_num + 1;
      fail_count = fail_count + 1;
    end
    
    //========================================
    // Test Summary
    //========================================
    $display("\n========================================");
    $display("Rendering Test Summary");
    $display("========================================");
    $display("Total Tests: %0d", test_num);
    $display("Passed:      %0d", pass_count);
    $display("Failed:      %0d", fail_count);
    
    if (fail_count == 0) begin
      $display("\n*** ALL RENDERING TESTS PASSED ***");
      $display("Bullet rendering logic is CORRECT.");
    end else begin
      $display("\n*** %0d RENDERING TESTS FAILED ***", fail_count);
      $display("Issue with bullet detection or priority layering.");
    end
    
    $display("========================================\n");
    $finish;
  end
  
  // Timeout
  initial begin
    #10000;
    $display("\n[ERROR] Testbench timeout!");
    $finish;
  end

endmodule
