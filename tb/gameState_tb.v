`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 21.04.2026 16:15:29
// Design Name: 
// Module Name: gameState_tb.v 
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


module gameState_tb();

//==========================================================
// --- Signals & Parameters
//==========================================================

// --- Inputs ( = reg)
reg        clk;
reg        rst;
reg        frame_tick;
reg        start_trigger;
reg        ship_hit;
reg [15:0] astr_hit;
reg [15:0] astr_active_packed;
reg        shield_en;

// --- Outputs ( = wire)
wire [1:0]  health;
wire [15:0] score;
wire        blink;
wire        game_active;
wire [1:0]  game_state;
wire        new_game;

// --- Test Tracking
integer test_pass;
integer test_fail;

// --- Parameters
localparam IDLE      = 2'd0;
localparam PLAYING   = 2'd1;
localparam GAME_OVER = 2'd2;
localparam INVIS_FRAMES = 120;


//==========================================================
// --- Clock Generation
//==========================================================

// --- 100 MHz Clock
initial clk   = 0;
always #5 clk = ~clk;



//==========================================================
// --- Tests
//==========================================================

initial begin
  $dumpfile("waves.vcd");
  $dumpvars(1, gameState_tb);

  // --- Initialise
  test_pass     = 0;
  test_fail     = 0;
  rst           = 1'b0;
  clear_inputs();

  // Apply reset then release
  @(posedge clk); @(posedge clk);
  rst = 1'b1;
  @(posedge clk); @(posedge clk);


  // --------------------------------------------------------
  // TEST 1: IDLE -> PLAYING transition
  //
  //  Objective:
  //    Confirm the FSM starts in IDLE and transitions to 
  //    PLAYING exactly one frame_tick after a start_trigger
  //    pulse. game_active must gate correctly.
  //
  //  Expectation:
  //    start_trigger sets start_pending=1 in the clocked
  //    always block. The transition fires on the next
  //    frame_tick when start_pending is seen.
  // -------------------------------------------------------- 
  $display("\n--- TEST 1: IDLE -> PLAYING ---");

  // Verify initial state is IDLE before any stimulus
  check("T1: initial state == IDLE",      game_state  == IDLE);
  check("T1: game_active == 0 in IDLE",   game_active == 1'b0);

  // Pulse start_trigger, then fire one frame_tick to commit transition
  pulse_start();
  send_frame_ticks(1);

  check("T1: state == PLAYING after start", game_state  == PLAYING);
  check("T1: game_active == 1 in PLAYING",  game_active == 1'b1);
  check("T1: health == 3 on entry",         health      == 2'd3);
  check("T1: score  == 0 on entry",         score       == 16'd0);




  // --------------------------------------------------------
  // TEST 2: Asteroid destroyed += score by 1 
  //
  //  Objective:
  //    Confirm the FSM starts in IDLE and transitions to 
  //    PLAYING exactly one frame_tick after a start_trigger
  //    pulse. game_active must gate correctly.
  //
  //  Expectation:
  //    Initially assert astr_active and astr_hit
  //    in the next clock cycle the astroid should
  //    be deactivated, astr_destroyed asserted and 
  //    score +=1
  // -------------------------------------------------------- 
  $display("\n--- TEST 2: Score increments by exactly 1 ---");

  // Tick N: asteroid active, hit flag raised
  astr_active_packed = 16'b0000_0000_0000_0001;  // asteroid 0 active
  astr_hit           = 16'b0000_0000_0000_0001;  // asteroid 0 hit
  send_frame_ticks(1);

  // Score must still be 0 — deactivation hasn't happened yet
  check("T2: score == 0 after tick N (not yet deactivated)", score == 16'd0);

  // Tick N+1: deactivate asteroid, keep hit flag asserted
  astr_active_packed = 16'b0000_0000_0000_0000;  // asteroid 0 now inactive
  astr_hit           = 16'b0000_0000_0000_0001;  // hit flag still high
  send_frame_ticks(1);

  check("T2: score == 1 after deactivation tick",  score == 16'd1);

  // Tick N+2: clear hit flag — score must NOT increment again
  astr_active_packed = 16'b0;
  astr_hit           = 16'b0;
  send_frame_ticks(1);

  check("T2: score still == 1 after hit flag cleared", score == 16'd1);

  // Restore clean state
  clear_inputs();
  send_frame_ticks(100); // drain 60-frame startup grace period

  // --------------------------------------------------------
  // TEST 3: Ship hit with invincibility
  //
  //  Objective:
  //    Confirm health decrements on first ship_hit, then
  //    the invincibility window (120 frames) blocks further
  //    health loss. After the timer ends, the next hit
  //    lowers health again.
  //
  //  Expected:
  //    invis_timer starts at INVIS_FRAMES (120) on a hit.
  //    Decrements by 1 each frame_tick.
  //    ship_hit only causes damage when invis_timer == 0.
  // --------------------------------------------------------
  $display("\n--- TEST 3: Ship hit + invincibility ---");

  // First hit, health 3 -> 2
  ship_hit = 1'b1;
  send_frame_ticks(1);
  check("T3: health == 2 after first hit",    health == 2'd2);

  // Immediately hit again 
  //  invis_timer is now 120, must be ignored
  send_frame_ticks(1);
  check("T3: health still 2 during invincibility", health == 2'd2);

  // Check blink is active during invincibility
  ship_hit = 1'b0;
  send_frame_ticks(105);  // run timer down to ~15
  check("T3: blink == 1 near end of invis window", blink == 1'b1);

  // Wait for full timer expiry (120 frames total from hit)
  send_frame_ticks(15);   // complete the remaining frames
  check("T3: blink == 0 after invis expires", blink == 1'b0);

  // Hit again after timer end, health 2->1 
  ship_hit = 1'b1;
  send_frame_ticks(1);
  check("T3: health == 1 after second hit post-expiry", health == 2'd1);

  ship_hit = 1'b0;
  // Drain invis timer again before Test 4
  send_frame_ticks(INVIS_FRAMES);
  clear_inputs();


  // --------------------------------------------------------
  // TEST 4: PLAYING -> GAME_OVER via health drain
  //
  //  Objective:
  //    Drain health to 0 across three hits (with invis gaps)
  //    and confirm the FSM transitions to GAME_OVER.
  //    Also confirm game_active deasserts.
  //
  //  Note: health is already 1 entering this test.
  // --------------------------------------------------------
  $display("\n--- TEST 4: PLAYING -> GAME_OVER ---");

  // One more hit: health 1 -> 0 -> GAME_OVER
  ship_hit = 1'b1;
  send_frame_ticks(1);
  ship_hit = 1'b0;
  send_frame_ticks(1);

  check("T4: health == 0",                   health      == 2'd0);
  check("T4: state  == GAME_OVER",           game_state  == GAME_OVER);
  check("T4: game_active == 0 in GAME_OVER", game_active == 1'b0);


  // --------------------------------------------------------
  // TEST 5: new_game pulse and GAME_OVER -> IDLE
  //
  //  Objective:
  //    Confirm new_game is a single-cycle pulse that fires
  //    exactly on the GAME_OVER -> IDLE transition.
  //    Confirm health and score reset on new_game.
  //
  //  Expected:
  //    new_game = (game_state == IDLE) && (game_state_prev != IDLE)
  //    It is combinatorial from two registered signals, so it
  //    goes high in the same cycle the state reaches IDLE.
  // --------------------------------------------------------
  $display("\n--- TEST 5: new_game pulse + GAME_OVER -> IDLE ---");

  // Trigger transition out of GAME_OVER
  pulse_start();
  send_frame_ticks(1);

  check("T5: state == IDLE after start in GAME_OVER", game_state == IDLE);

  // new_game should be high for exactly 1 cycle on transition.
  check("T5: new_game == 0 after transition settled", new_game == 1'b0);

  // Verify state machine reset values
  check("T5: health restored to 3", health == 2'd3);
  check("T5: score  restored to 0", score  == 16'd0);

  // Fire another frame_tick - new_game must NOT fire again
  send_frame_ticks(1);
  check("T5: new_game == 0 on second tick in IDLE", new_game == 1'b0);



  // --------------------------------------------------------
  //                      SUMMARY
  // --------------------------------------------------------
  $display("\n--- gameState_tb COMPLETE ---");
  $display("\t%0d PASS", test_pass);
  $display("\t%0d FAIL", test_fail);
  $finish;
end


//==========================================================
// --- QOL Tasks 
//==========================================================

// Reset all inputs to safe defaults
task clear_inputs;
  begin
    ship_hit          = 1'b0;
    astr_hit          = 16'b0;
    astr_active_packed= 16'b0;
    start_trigger     = 1'b0;
    shield_en         = 1'b0;
    frame_tick        = 1'b0;
  end
endtask

// Fire exactly N frame_tick pulses
// Each tick: assert for 1 cycle, deassert, wait 2 settle cycles
task send_frame_ticks;
  input [31:0] n;
  integer i;
  begin
    for (i = 0; i < n; i = i + 1) begin
      @(negedge clk); frame_tick = 1'b1;
      @(posedge clk);
      @(negedge clk); frame_tick = 1'b0;
    end
  end
endtask

// Pulse start_trigger for exactly 1 clock cycle
task pulse_start;
  begin
    start_trigger = 1'b1;
    @(posedge clk);
    start_trigger = 1'b0;
  end
endtask

// Convenience pass/fail assertion
task check;
  input [511:0] label;
  input         condition;
  begin
    if (condition) begin
      $display("[PASS] %s", label);
      test_pass = test_pass + 1;
    end else begin
      $display("[FAIL] %s", label);
      test_fail = test_fail + 1;
    end
  end
endtask


//==========================================================
// --- Instantiate Module being Tested
//==========================================================
gameState uut (
  .clk               (clk),
  .rst               (rst),
  .frame_tick        (frame_tick),
  .start_trigger     (start_trigger),
  .ship_hit          (ship_hit),
  .astr_hit          (astr_hit),
  .astr_active_packed(astr_active_packed),
  .health            (health),
  .score             (score),
  .blink             (blink),
  .game_active       (game_active),
  .game_state        (game_state),
  .new_game          (new_game),
  .shield_en         (shield_en)
);

endmodule
