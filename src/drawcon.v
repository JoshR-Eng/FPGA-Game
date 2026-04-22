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


module drawcon #(
      // Ship config
    parameter SHIP_WIDTH    = 100,
    parameter SHIP_HEIGHT   = 100,
      // Screen
    parameter SCREEN_Y_MIN  = 11'd100,
      // Asteroids
    parameter MAX_ASTEROIDS = 16,
    parameter ASTR_SMALL    = 12,
    parameter ASTR_MEDIUM   = 24,
    parameter ASTR_LARGE    = 48,
      // Other Sprites
    parameter TITLE_W       = 360,
    parameter TITLE_H       = 180,
    parameter GAMEOVER_W    = 300,
    parameter GAMEOVER_H    = 200
    )(
    input clk, rst,
    input on_bullet, on_cursor, on_asteroid,
    input blink,
    input [1:0]  game_state,
    input [10:0] curr_x, curr_y,
    input [10:0] ship_x, ship_y,
    input [175:0] astr_x_packed,
    input [175:0] astr_y_packed,
    input [15:0]  astr_active_packed,
    input [31:0]  astr_size_packed,
    input [1:0]   health,
    input [15:0]  score,
    output [3:0]  draw_r, draw_g, draw_b
    );
    

// ==========================================================
// --- Internal Wiring
// ==========================================================    

reg [3:0] blk_r = 0, blk_g = 0, blk_b = 0;  // Initialize at power-up
reg [3:0] bg_r=4'h0, bg_g=4'h0, bg_b=4'h0;

// Object Detection
wire ship_on;
wire on_gamebar;

// Draw Multiplexer
reg [3:0] mux_r;
reg [3:0] mux_g;
reg [3:0] mux_b;

// Asteroid
wire [10:0] astr_x      [0:15];
wire [10:0] astr_y      [0:15];
wire        astr_active [0:15];
wire [1:0]  astr_size   [0:15];
reg  [1:0]  hit_astr_size;
reg  [10:0] hit_astr_lx, hit_astr_ly;
reg         astr_draw_hit;

// Loop counters
integer a, i;

// --- BRAM wires
// Ship
reg  [13:0] ship_addr;
wire [12:0] ship_pixel; // 13-bit: bit[12]=transparent, [11:8]=R, [7:4]=G, [3:0]=B
// Asteroids (one address bus, muxed; separate output per ROM)
reg  [13:0] astr_addr;
wire [12:0] astr_lg_pixel;
wire [12:0] astr_md_pixel;
wire [12:0] astr_sm_pixel;
// Title
reg  [16:0] title_addr;
wire [12:0] title_pixel;
// Game Over
reg  [16:0] gameover_addr;
wire [12:0] gameover_pixel;
// Infobar
reg  [16:0] infobar_addr;
wire [12:0] infobar_pixel;
// Heart
reg  [11:0] heart_addr;
wire [12:0] heart_pixel;

// Delay registers (1 cycle per BRAM read latency)
reg ship_on_d;
reg astr_draw_hit_d;
reg [1:0]  hit_astr_size_d;
reg title_on_d;
reg gameover_on_d;
reg infobar_on_d;
reg [2:0] heart_on_d;           // one bit per heart (3 hearts)

// ==========================================================
// --- Determine if current pixel is over an item
// ==========================================================

// --- SHIP -------------------------------------------------
assign ship_on = (curr_x >= ship_x) && ( curr_x < (ship_x + SHIP_WIDTH)) &&
                 (curr_y >= ship_y) && ( curr_y < (ship_y + SHIP_HEIGHT));


// --- TITLE ------------------------------------------------
localparam TITLE_X    = (1440 - 360) / 2;   // = 540
localparam TITLE_Y    = 100 + (800 - 180)/2; // = 410 (centred in game area)

wire title_on    = (game_state == 2'd0) &&
                   (curr_x >= TITLE_X)    && (curr_x < TITLE_X + TITLE_W) &&
                   (curr_y >= TITLE_Y)    && (curr_y < TITLE_Y + TITLE_H);


// --- GAME OVER --------------------------------------------
localparam GAMEOVER_X = (1440 - 300) / 2;   // = 570
localparam GAMEOVER_Y = 100 + (800 - 200)/2; // = 400
wire gameover_on = (game_state == 2'd2) &&
                   (curr_x >= GAMEOVER_X) && (curr_x < GAMEOVER_X + GAMEOVER_W) &&
                   (curr_y >= GAMEOVER_Y) && (curr_y < GAMEOVER_Y + GAMEOVER_H);

// --- INFO BAR ---------------------------------------------
wire infobar_on  = (curr_y < 11'd100) && (curr_x < 11'd1024);
assign on_gamebar = (curr_y < SCREEN_Y_MIN);  // strictly less than


// --- HEARTS -----------------------------------------------
// Heart positions: right zone of info bar (x = 1024–1439, y = 0–99)
// Space 3 hearts evenly across 416px — centres at x=1090, 1230, 1370
localparam HEART_Y0 = 25;   // top of heart within bar
wire heart_on_0 = (curr_x >= 1050) && (curr_x < 1100) &&
                  (curr_y >= HEART_Y0) && (curr_y < HEART_Y0 + 50);
wire heart_on_1 = (curr_x >= 1115) && (curr_x < 1165) &&
                  (curr_y >= HEART_Y0) && (curr_y < HEART_Y0 + 50);
wire heart_on_2 = (curr_x >= 1180) && (curr_x < 1230) &&
                  (curr_y >= HEART_Y0) && (curr_y < HEART_Y0 + 50);
wire any_heart_on = heart_on_0 | heart_on_1 | heart_on_2;



// ==========================================================
// --- Asteroid Hit detection & Size Evaluator 
// ==========================================================

// --- Asteroid hit detection (combinatorial — runs before clock edge)
// Determine which asteroid the current pixel falls on, and its local coords
always @* begin
    astr_draw_hit  = 1'b0;
    hit_astr_size  = 2'd0;
    hit_astr_lx    = 11'd0;
    hit_astr_ly    = 11'd0;
    for (a = 0; a < 16; a = a+1) begin
        if (astr_active[a] && !astr_draw_hit) begin
            case (astr_size[a])
                2'd0: begin  // Small: 24x24
                    if (curr_x >= astr_x[a] - ASTR_SMALL  && 
                        curr_x <  astr_x[a] + ASTR_SMALL  &&
                        curr_y >= astr_y[a] - ASTR_SMALL  && 
                        curr_y <  astr_y[a] + ASTR_SMALL  ) begin
                        astr_draw_hit = 1'b1; 
                        hit_astr_size = astr_size[a];
                        hit_astr_lx   = curr_x - (astr_x[a] - ASTR_SMALL);
                        hit_astr_ly   = curr_y - (astr_y[a] - ASTR_SMALL);
                    end
                end
                2'd1: begin  // Medium: 48x48
                    if (curr_x >= astr_x[a] - ASTR_MEDIUM && 
                        curr_x <  astr_x[a] + ASTR_MEDIUM &&
                        curr_y >= astr_y[a] - ASTR_MEDIUM && 
                        curr_y <  astr_y[a] + ASTR_MEDIUM ) begin
                        astr_draw_hit = 1'b1; 
                        hit_astr_size = astr_size[a];
                        hit_astr_lx   = curr_x - (astr_x[a] - ASTR_MEDIUM);
                        hit_astr_ly   = curr_y - (astr_y[a] - ASTR_MEDIUM);
                    end
                end
                2'd2: begin  // Large: 96x96
                    if (curr_x >= astr_x[a] - ASTR_LARGE  && 
                        curr_x <  astr_x[a] + ASTR_LARGE  &&
                        curr_y >= astr_y[a] - ASTR_LARGE  && 
                        curr_y <  astr_y[a] + ASTR_LARGE  ) begin
                        astr_draw_hit = 1'b1; 
                        hit_astr_size = astr_size[a];
                        hit_astr_lx   = curr_x - (astr_x[a] - ASTR_LARGE);
                        hit_astr_ly   = curr_y - (astr_y[a] - ASTR_LARGE);
                    end
                end
                default: ;
            endcase
        end
    end
end

// Select which asteroid ROM pixel to use (based on delayed size)
wire [12:0] astr_pixel_sel = (hit_astr_size_d == 2'd2) ? astr_lg_pixel :
                             (hit_astr_size_d == 2'd1) ? astr_md_pixel :
                                                          astr_sm_pixel;


// ==========================================================
// --- Draw Priority Multiplexer
// ==========================================================

always @* begin
    // Layer 0: Background
    mux_r = 4'h0; mux_g = 4'h0; mux_b = 4'h1;

    // Layer 1: Asteroids
    if (astr_draw_hit_d && !astr_pixel_sel[12]) begin
        mux_r = astr_pixel_sel[11:8];
        mux_g = astr_pixel_sel[7:4];
        mux_b = astr_pixel_sel[3:0];
    end

    // Layer 2: Bullets (geometric — keep as-is)
    if (on_bullet) begin
        mux_r = 4'hF; mux_g = 4'hF; mux_b = 4'h0;
    end

    // Layer 3: Ship
    if (ship_on_d && !ship_pixel[12] && !blink) begin
        mux_r = ship_pixel[11:8];
        mux_g = ship_pixel[7:4];
        mux_b = ship_pixel[3:0];
    end

    // Layer 4: Crosshair (geometric — keep as-is)
    if (on_cursor) begin
        mux_r = 4'hF; mux_g = 4'hF; mux_b = 4'hF;
    end

    // Layer 5: Info bar background (solid colour — drawn first, overlaid by BRAM)
    if (on_gamebar) begin
        mux_r = 4'h0; mux_g = 4'h0; mux_b = 4'h0;  // black bar
    end

    // Layer 6: Infobar BRAM overlay (non-transparent pixels only)
    if (infobar_on_d && !infobar_pixel[12]) begin
        mux_r = infobar_pixel[11:8];
        mux_g = infobar_pixel[7:4];
        mux_b = infobar_pixel[3:0];
    end

    // Layer 7: Hearts (hide heart if player has lost that life)
    // heart_on_d[0]=left heart, heart_on_d[2]=right heart
    // health=3 → all 3 shown, health=2 -> rightmost hidden, etc.
    if (heart_on_d[0] && (health >= 2'd1) && !heart_pixel[12]) begin
        mux_r = heart_pixel[11:8]; mux_g = heart_pixel[7:4]; mux_b = heart_pixel[3:0];
    end
    if (heart_on_d[1] && (health >= 2'd2) && !heart_pixel[12]) begin
        mux_r = heart_pixel[11:8]; mux_g = heart_pixel[7:4]; mux_b = heart_pixel[3:0];
    end
    if (heart_on_d[2] && (health == 2'd3) && !heart_pixel[12]) begin
        mux_r = heart_pixel[11:8]; mux_g = heart_pixel[7:4]; mux_b = heart_pixel[3:0];
    end

    // Layer 8: Title overlay (IDLE state only, transparency gated)
    if (title_on_d && !title_pixel[12]) begin
        mux_r = title_pixel[11:8];
        mux_g = title_pixel[7:4];
        mux_b = title_pixel[3:0];
    end

    // Layer 9: Game Over overlay (GAME_OVER state only, transparency gated)
    if (gameover_on_d && !gameover_pixel[12]) begin
        mux_r = gameover_pixel[11:8];
        mux_g = gameover_pixel[7:4];
        mux_b = gameover_pixel[3:0];
    end
end


// Final continous assignment to the output ports
assign draw_r = mux_r;
assign draw_g = mux_g;
assign draw_b = mux_b;


// ==========================================================
// --- BRAM Address Calculation (The Math Way)
// ==========================================================
wire [10:0] local_ship_x = curr_x - ship_x;
wire [10:0] local_ship_y = curr_y - ship_y;

// --- Registered address calculation (clocked)
always @(posedge clk) begin
    // 1-cycle latency delays
    ship_on_d        <= ship_on;
    astr_draw_hit_d  <= astr_draw_hit;
    hit_astr_size_d  <= hit_astr_size;
    title_on_d       <= title_on;
    gameover_on_d    <= gameover_on;
    infobar_on_d     <= infobar_on;
    heart_on_d       <= {heart_on_2, heart_on_1, heart_on_0};

    // Ship address
    if (ship_on)
        ship_addr <= (local_ship_y * SHIP_WIDTH) + local_ship_x;
    else
        ship_addr <= 14'd0;

    // Asteroid address (all 3 ROMs read same addr; mux selects output)
    if (astr_draw_hit) begin
        case (hit_astr_size)
            2'd0: astr_addr <= (hit_astr_ly * 24)  + hit_astr_lx;
            2'd1: astr_addr <= (hit_astr_ly * 48)  + hit_astr_lx;
            2'd2: astr_addr <= (hit_astr_ly * 96)  + hit_astr_lx;
            default: astr_addr <= 14'd0;
        endcase
    end else
        astr_addr <= 14'd0;

    // Title address
    if (title_on)
        title_addr <= ((curr_y - TITLE_Y) * TITLE_W) + (curr_x - TITLE_X);
    else
        title_addr <= 17'd0;

    // Game Over address
    if (gameover_on)
        gameover_addr <= ((curr_y - GAMEOVER_Y) * GAMEOVER_W) + (curr_x - GAMEOVER_X);
    else
        gameover_addr <= 17'd0;

    // Infobar address
    if (infobar_on)
        infobar_addr <= (curr_y * 11'd1024) + curr_x;
    else
        infobar_addr <= 17'd0;

    // Heart address (all 3 hearts share the same 50×50 ROM)
    if (heart_on_0)
        heart_addr <= ((curr_y - HEART_Y0) * 50) + (curr_x - 1050);
    else if (heart_on_1)
        heart_addr <= ((curr_y - HEART_Y0) * 50) + (curr_x - 1115);
    else if (heart_on_2)
        heart_addr <= ((curr_y - HEART_Y0) * 50) + (curr_x - 1180);
    else
        heart_addr <= 12'd0;
end



// ==========================================================
// --- Block Memory Assignment 
// ==========================================================

blk_mem_gen_0 title_sprite   (.clka(clk), 
                              .addra(title_addr),    .douta(title_pixel));
blk_mem_gen_1 ship_sprite    (.clka(clk), 
                              .addra(ship_addr),     .douta(ship_pixel));
blk_mem_gen_2 astr_lg_sprite (.clka(clk), 
                              .addra(astr_addr),     .douta(astr_lg_pixel));
blk_mem_gen_3 astr_md_sprite (.clka(clk), 
                              .addra(astr_addr),     .douta(astr_md_pixel));
blk_mem_gen_4 astr_sm_sprite (.clka(clk), 
                              .addra(astr_addr),     .douta(astr_sm_pixel));
blk_mem_gen_5 gameover_sprite(.clka(clk), 
                              .addra(gameover_addr), .douta(gameover_pixel));
blk_mem_gen_6 infobar_sprite (.clka(clk), 
                              .addra(infobar_addr),  .douta(infobar_pixel));
blk_mem_gen_7 heart_sprite   (.clka(clk), 
                              .addra(heart_addr),    .douta(heart_pixel));



//==========================================================
// --- Unflatten Arrays 
//==========================================================

// --- Asteroid Arrays
genvar j;
generate
  for (j=0; j<MAX_ASTEROIDS; j=j+1) begin : unflatten_asteroids
    assign astr_x[j]      = astr_x_packed[(j*11)+10 -: 11] ;
    assign astr_y[j]      = astr_y_packed[(j*11)+10 -: 11] ;
    assign astr_active[j] = astr_active_packed[j] ;
    assign astr_size[j]   = astr_size_packed[(j*2)+1 -: 2];
  end
endgenerate



endmodule
