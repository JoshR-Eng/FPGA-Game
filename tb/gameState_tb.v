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
parameter PERIOD        = 10;           // ns per clock
parameter FRAME_CYCLES  = 1904 * 932;   // cycles per frame
parameter NUM_FRAMES    = 3;           

//==========================================================
// --- Clock Generation
//==========================================================

// --- 100 MHz Clock
initial clk   = 0;
always #5 clk = ~clk;



//==========================================================
// --- Tests
//==========================================================



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
      @(posedge clk);
      frame_tick = 1'b1;
      @(posedge clk);
      frame_tick = 1'b0;
      @(posedge clk);  // settle 1
      @(posedge clk);  // settle 2
    end
  end
endtask

// Pulse start_trigger for exactly 1 clock cycle
task pulse_start;
  begin
    @(posedge clk);
    start_trigger = 1'b1;
    @(posedge clk);
    start_trigger = 1'b0;
  end
endtask

// Convenience pass/fail assertion
task check;
  input [127:0] label;
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
