# Asteroid Collision — FPGA Game on Nexys A7-100T

![Platform](https://img.shields.io/badge/Platform-Nexys%20A7--100T-blue)
![Device](https://img.shields.io/badge/FPGA-Artix--7%20XC7A100T-brightgreen)
![Language](https://img.shields.io/badge/HDL-Verilog--2001-orange)
![Tool](https://img.shields.io/badge/Tool-Vivado%202024-red)
![Clock](https://img.shields.io/badge/Clock-106%20MHz-yellow)

A fully custom RTL implementation of an Asteroids-style top-down shooter, synthesised on the Xilinx Artix-7 FPGA. Every component — from the VGA timing generator and SPI accelerometer driver to the parallel collision engine and priority-multiplexed renderer — is hand-written in Verilog with no soft-processor or IP cores for game logic.

---

## Contents

- [Game Overview](#game-overview)
- [Technical Highlights](#technical-highlights)
- [System Architecture](#system-architecture)
- [Module Reference](#module-reference)
- [Implementation Details](#implementation-details)
  - [VGA Timing & Pixel Clock](#vga-timing--pixel-clock)
  - [Rendering Pipeline](#rendering-pipeline)
  - [Accelerometer-Driven Ship](#accelerometer-driven-ship)
  - [Bullet Direction Normalisation](#bullet-direction-normalisation)
  - [LFSR-Based Asteroid Spawning](#lfsr-based-asteroid-spawning)
  - [Parallel Collision Detection](#parallel-collision-detection)
  - [Game State FSM](#game-state-fsm)
  - [Gun Heat Mechanic](#gun-heat-mechanic)
  - [Switch-Mapped Features & Nightmare Mode](#switch-mapped-features--nightmare-mode)
  - [Inter-Module Bus Strategy](#inter-module-bus-strategy)
- [Verification](#verification)
- [Repository Structure](#repository-structure)
- [Build & Synthesis](#build--synthesis)
- [Hardware Requirements](#hardware-requirements)
- [Known Limitations & Future Work](#known-limitations--future-work)
- [References](#references)

---

## Game Overview

**Asteroid Collision** is a 2D space shooter rendered over VGA at **1440×900 @ 60 Hz**. The player's ship is steered by physically tilting the board (ADXL362 3-axis accelerometer via SPI) and aims with an independent crosshair controlled via push buttons. Asteroids spawn pseudorandomly from screen edges and the player must destroy as many as possible before losing all three lives.

| Feature | Detail |
|---|---|
| Display | 1440 × 900 px @ 60 Hz VGA |
| Ship control | ADXL362 accelerometer (SPI) — tilt to move |
| Aiming | Independent crosshair, push-button controlled |
| Projectiles | Up to 16 simultaneous bullets |
| Asteroids | Up to 16 simultaneous, 3 sizes (24×24, 48×48, 96×96 px) |
| Lives | 3 with 120-frame invincibility window per hit |
| Score display | 8-digit seven-segment (binary → BCD → 7-seg) |
| Heat display | 16 on-board LEDs as a left-filling bargraph |
| Sprites | 8 Block RAMs (ship, 3× asteroid sizes, hearts, infobar, title, game-over) |
| Creative features | 4 difficulty tiers, speed boost, shield, rapid fire, Nightmare Mode easter egg |

---

## Technical Highlights

These are the engineering decisions worth understanding:

- **Single-clock domain, frame-gated architecture** — all game logic runs at 106 MHz but advances state exactly once per frame via a `frame_tick` clock-enable, eliminating screen tearing by design.
- **Shift-based vector normalisation** — bullet direction is computed without a hardware divider using a priority-encoded arithmetic right-shift over 8 breakpoints, mapped to a two-stage pipeline across clock boundaries.
- **176-bit flat-packed inter-module buses** — Verilog-2001's lack of multi-dimensional ports is solved by packing all 16-slot object arrays into flat `[175:0]` buses at module boundaries and unpacking locally with `generate` loops.
- **Maximal-length 16-bit LFSR** — pseudo-random asteroid spawn uses the polynomial \(x^{16} + x^{14} + x^{13} + x^{11} + 1\), guaranteeing a period of 65,535 frames. A single LFSR state is bit-sliced across position, size, velocity, and edge selection simultaneously.
- **256 parallel AABB comparators** — all 16 × 16 bullet–asteroid overlap tests evaluate combinatorially within a single clock cycle; no iterative loop or sequencer required.
- **13-bit BRAM pixel format with transparency** — bit 12 acts as a per-pixel transparency flag, allowing the priority-mux renderer to correctly layer sprites without a dedicated colour-key comparison.
- **Hardware-efficient power-ups** — speed boost uses a single left-shift instead of a multiplier; shield is a combinatorial mask on the health decrement; rapid fire shifts the heat cooldown rate; all synthesise to pure LUT logic.

---

## System Architecture

The design is organised into four functional clusters, all synchronous on a single 106 MHz `pixclk` domain derived from the on-board 100 MHz oscillator via `clk_wiz_0`:

```
┌─────────────────────────────────────────────────────────────────┐
│                         GAME TOP (game_top.v)                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Accelerometer                          │   │
│  │   iclk ──► accSPI ──► accOutput ──► acl_data[14:0]      │   │
│  └──────────────────────────────────────────────────────────┘   │
│  pixclk ─────────────────────────────────────────────────────►  │
│                                                                  │
│  ┌─── GAME LOGIC (frame_tick gated) ───────────────────────┐    │
│  │  gameState.v ◄──────────────────── ship_hit             │    │
│  │       │ game_state / new_game       collisions.v        │    │
│  │       ▼                              ▲   ▲              │    │
│  │  scoreDisplay ──► 7-seg         bul_packed  astr_packed │    │
│  │  heatDisplay  ──► LED[15:0]          │       │          │    │
│  └──────────────────────────────────────│───────│──────────┘    │
│                            Position &   │       │               │
│                            States ▼     │       │               │
│  ┌─── GAME OBJECTS (frame_tick gated) ──┴───────┴────────────┐  │
│  │  shipMovement ──► crosshairMovement ──► bulletManager     │  │
│  │                                         asteroidManager   │  │
│  └────────────────────────────────────────────────────────────┘  │
│                            Position & States ▼                   │
│  ┌─── DRAWCON ──────────────────────────────────────────────┐   │
│  │  Priority-mux renderer (10 layers, BRAM + geometric)     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                            draw_r/g/b ▼                          │
│  ┌─── VGA (vga.v) ──────────────────────────────────────────┐   │
│  │  hcount/vcount ──► hsync, vsync, pix_r/g/b, frame_tick   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

The `frame_tick` signal — a single-cycle pulse generated at `hcount=0, vcount=930` (start of vertical blanking) — gates all physics and FSM updates. This means every game entity advances by exactly one step per 16.74 ms frame, decoupled from the pixel-clock rendering path.

---

## Module Reference

| Module | Cluster | Function | Key Outputs |
|---|---|---|---|
| `game_top.v` | Top | Wiring hub, localparams, feature decode | All inter-module connections |
| `vga.v` | Platform | Sync generator, counter wrap | `hsync`, `vsync`, `curr_x/y`, `frame_tick` |
| `clk_wiz_0` | Platform | PLL: 100 MHz → 106 MHz | `pixclk` |
| `iclk.v` | Accel | SPI clock divider | `spi_clk` |
| `accSPI.v` | Accel | Full-duplex SPI master (ADXL362) | `acl_data[14:0]` |
| `accOutput.v` | Accel | Data deserialiser | `acl_x/y/z` |
| `shipMovement.v` | Objects | Tilt → velocity → clamped position | `ship_x/y` |
| `crosshairMovement.v` | Objects | Button-driven cursor | `cursor_x/y` |
| `bulletManager.v` | Objects | 16-slot bullet pool, fire pipeline, heat | `bul_*_packed[175:0]`, `gun_heat` |
| `asteroidManager.v` | Objects | 16-slot asteroid pool, LFSR spawn | `astr_*_packed[175:0]` |
| `collisions.v` | Logic | 256+16 parallel AABB comparators | `bul_hit[15:0]`, `astr_hit[15:0]`, `ship_hit` |
| `gameState.v` | Logic | 3-state Moore FSM, health, score, blink | `game_state`, `new_game`, `health`, `blink` |
| `scoreDisplay.v` | Logic | Binary → BCD → 7-seg multiplexer | `a_to_g`, `an[7:0]` |
| `heatDisplay.v` | Logic | Heat → LED bargraph | `led[15:0]` |
| `drawcon.v` | Render | 10-layer priority-mux compositor | `draw_r/g/b` |

---

## Implementation Details

### VGA Timing & Pixel Clock

The display target is 1440×900 @ 60 Hz. The required pixel clock is derived from the total raster dimensions including blanking:

\[f_\text{pixel} = H_\text{total} \times V_\text{total} \times f_\text{refresh} = 1904 \times 932 \times 60 \approx 106.6\,\text{MHz}\]

`vga.v` implements two free-running counters: `hcount` (0–1903) and `vcount` (0–931). The sync pulses are asserted at the correct count boundaries:

```verilog
// hsync: active-low, 152 clocks wide
assign hsync = ~(hcount < 12'd152);

// vsync: active-low, 3 lines wide
assign vsync = ~(vcount < 10'd3);

// Single-cycle frame_tick at start of blanking
assign frame_tick = (hcount == 0) && (vcount == 10'd930);
```

The `display_region` flag gates pixel output to zero outside the 1440×900 active window, protecting the blanking intervals from rogue pixel data.

---

### Rendering Pipeline

`drawcon.v` is a purely combinatorial priority multiplexer with **10 strict layers**. Higher layers overwrite lower layers; each BRAM sprite carries a 13-bit pixel format where **bit 12 is a per-pixel transparency flag**, allowing seamless sprite overlap without a colour-key check.

| Priority | Content | Method | Notes |
|---|---|---|---|
| 0 | Background | Constant | `RGB = 12'h001` (deep blue) |
| 0.5 | Stars (64) | Hardcoded coords | XOR phase stagger for twinkle |
| 1 | Asteroids | BRAM (3 shared-address ROMs) | Transparent pixels skip to layer below |
| 2 | Bullets | Geometric rect | Yellow `12'hFF0` |
| 3 | Ship | BRAM sprite | Suppressed during `blink` |
| 4 | Crosshair | Geometric cross | White `12'hFFF` |
| 5 | Infobar background | Constant fill | Yellow `12'hDC4`, `curr_y < 100` |
| 6 | Infobar graphic | 1024×100 BRAM | Non-transparent pixels only |
| 7 | Hearts (×3) | 50×50 BRAM | Right-to-left depletion |
| 8 | Title screen | BRAM | `IDLE` state only |
| 9 | Game Over screen | BRAM | `GAME_OVER` state only |

All BRAM reads carry **1-cycle latency**. The detection signals (`_on`) are registered to `_on_d` delay flip-flops so address computation and BRAM output arrive in the same clock cycle at the mux input.

---

### Accelerometer-Driven Ship

`accSPI.v` implements a full-duplex SPI master that continuously reads the ADXL362's output registers, packing the result into a 15-bit bus (`acl_data[14:0]`) with 5 bits per axis.

A hardware-level axis swap compensates for the sensor's physical orientation on the Nexys A7 PCB: `acl_x` drives screen-Y velocity and `acl_y` drives screen-X velocity.

The `tilt_to_vel()` function converts raw two's-complement axis data to a signed pixel velocity:
1. Decompose to sign + magnitude
2. Apply a 2-LSB deadzone (suppresses mechanical noise on a desk)
3. Map magnitude 2–15 → velocity 0–4 px/frame

Position is hard-clamped to effective screen bounds accounting for the 100×100 px sprite footprint, preventing partial off-screen rendering.

---

### Bullet Direction Normalisation

Exact vector normalisation requires a hardware divider — expensive in LUTs and on the critical path. Instead, `bulletManager.v` uses a **priority-encoded arithmetic right-shift** to approximate normalisation:

1. Compute `raw_dx = cursor_x - ship_centre_x`, `raw_dy = cursor_y - ship_centre_y`
2. Find the dominant axis (larger absolute value)
3. Encode the dominant magnitude into a shift amount `shift_n` across 8 breakpoints:
   - `dominant > 64` → `shift_n = 3` (÷8)
   - `dominant > 32` → `shift_n = 2` (÷4)
   - `dominant > 16` → `shift_n = 1` (÷2)
   - else → `shift_n = 0`
4. Apply `scaled_dx = raw_dx >>> shift_n`, `scaled_dy = raw_dy >>> shift_n`
5. Result: velocity in range `[-7, +7]` on each axis

To break the combinatorial path across clock boundaries, `dominant` and `shift_n` are registered into `dominant_reg` and `shift_n_reg`, making the direction computation a clean 2-cycle pipeline.

```verilog
// Stage 1: register the dominant axis and shift amount
always @(posedge pixclk) begin
    dominant_reg <= dominant;
    shift_n_reg  <= shift_n;
end

// Stage 2: apply shift (arithmetic >>> preserves sign)
assign scaled_dx = $signed(raw_dx) >>> shift_n_reg;
assign scaled_dy = $signed(raw_dy) >>> shift_n_reg;
```

---

### LFSR-Based Asteroid Spawning

Asteroid spawn events use a 16-bit Fibonacci LFSR with a mathematically selected maximal-length tap polynomial:

\[b[n] = b[n-16] \oplus b[n-14] \oplus b[n-13] \oplus b[n-11]\]

This corresponds to the primitive polynomial \(x^{16} + x^{14} + x^{13} + x^{11} + 1\), guaranteeing a sequence period of \(2^{16} - 1 = 65{,}535\) frames (~18 minutes at 60 Hz) before any spawn pattern repeats.

A single LFSR state is bit-sliced across all spawn parameters simultaneously:

| Bits | Parameter |
|---|---|
| `[15:6]` | Spawn X or Y coordinate (scaled to screen bounds) |
| `[5:4]` | Asteroid size index (SMALL / MEDIUM / LARGE) |
| `[3:2]` | Orthogonal drift velocity (−1 to +2 px/frame) |
| `[1:0]` | Starting screen edge (top / bottom / left / right) |

The spawn interval is controlled by a countdown timer, configurable from 180 frames (easy) to 30 frames (overdrive) via hardware switches.

---

### Parallel Collision Detection

`collisions.v` evaluates all object interactions combinatorially within a single clock cycle using **axis-aligned bounding box (AABB)** overlap tests:

\[\text{hit}(A, B) \iff |x_A - x_B| < r_A + r_B \;\wedge\; |y_A - y_B| < r_A + r_B\]

The implementation unfolds all comparisons in parallel:
- **256 bullet–asteroid comparators** (16 bullets × 16 asteroids)
- **16 ship–asteroid comparators**

No loop or sequencer is required — all 272 comparisons resolve in a single combinatorial pass, producing `bul_hit[15:0]`, `astr_hit[15:0]`, and `ship_hit` simultaneously.

Half-sizes are pre-registered one cycle ahead to avoid a long combinatorial path from the size-decode into the subtractor chain.

Score attribution uses an edge-detect mask to correctly distinguish destroyed asteroids (those that were active, became inactive, *and* had their `astr_hit` flag asserted) from asteroids that simply drifted off-screen:

```verilog
astr_destroyed = astr_active_prev & ~astr_active_packed & astr_hit;
```

---

### Game State FSM

`gameState.v` implements a three-state Moore machine:

```
         start_pending
IDLE ─────────────────────► PLAYING
  ▲                              │
  │   start_pending         health == 0
  └──────────────── GAME_OVER ◄──┘
```

The `new_game` signal is a **one-cycle pulse** generated on the GAME_OVER → IDLE transition. It resets all object managers and positional vectors across the entire design without requiring a board-level hard reset — every module samples `new_game` on the next `frame_tick`.

A 60-frame grace period on entering `PLAYING` prevents immediate ship collisions during spawn.

---

### Gun Heat Mechanic

The gun heat register `gun_heat_reg` implements a thermal model for the firing rate limiter:

| Event | Effect |
|---|---|
| Fire bullet | `gun_heat += 48` |
| Gun blocked | `gun_heat >= 200` (overheat threshold) |
| Cool per frame | `gun_heat -= 1` (nominal) |
| Rapid fire mode | `gun_heat -= 3` per frame |
| Overheat feedback | All 16 LEDs blink at ~3.75 Hz |

`heatDisplay.v` maps the heat register to the 16 LEDs as a left-filling bargraph, dividing the 0–200 range into 8 equal steps of 25 LSB per LED pair. The blink is driven by `blink_counter[3]`, toggling every 8 frame ticks.

---

### Switch-Mapped Features & Nightmare Mode

Five gameplay modifiers are decoded from `sw[7:0]` as direct combinatorial select lines — no registers required:

| Feature | Switch | Hardware Implementation |
|---|---|---|
| Difficulty | `{sw[7], sw[4]}` | Spawn interval mux: 180 / 120 / 60 / 30 frames |
| Speed Boost | `sw[1]` | `velocity << 1` — single left shift, zero LUT overhead vs. multiplier |
| Shield | `sw[3]` | Combinatorial mask on health decrement |
| Rapid Fire | `sw[5]` | Cooldown rate select: ×1 nominal → ×3 |
| **Nightmare Mode** | `sw[5] & sw[3] & sw[1] & ~sw[2]` | Overrides all above |

**Nightmare Mode** is triggered when a player attempts to activate all three power-ups simultaneously. A combinatorial override fires: the shield is forcibly suppressed, the spawn interval locks to maximum difficulty (30 frames), and the LEDs blink continuously regardless of gun heat state.

```verilog
assign nightmare_en = sw[5] & sw[3] & sw[1] & ~sw[2];
```

---

### Inter-Module Bus Strategy

Verilog-2001 does not support multi-dimensional port declarations. To pass arrays of 16 object states between modules, all per-object fields are **flattened into wide packed buses** at the module boundary and unpacked locally via `generate`:

```verilog
// Packing in bulletManager.v
genvar j;
generate
    for (j = 0; j < 16; j = j + 1) begin
        assign bul_x_packed[j*11 +: 11] = bul_x[j];
        assign bul_y_packed[j*11 +: 11] = bul_y[j];
    end
endgenerate

// Unpacking in collisions.v
generate
    for (j = 0; j < 16; j = j + 1) begin
        assign bul_x_int[j] = bul_x_packed[j*11 +: 11];
        assign bul_y_int[j] = bul_y_packed[j*11 +: 11];
    end
endgenerate
```

This produces six 176-bit buses per object type (`x`, `y`, `vx`, `vy`, `active`, `size`), keeping all inter-module connections to synthesisable static widths.

---

## Verification

Three self-checking testbenches were written in Verilog and simulated with Icarus Verilog / GTKWave. Each testbench uses internal accumulators to compare expected vs. actual outputs, printing automated `[PASS]`/`[FAIL]` metrics at completion.

### Testbench 1 — VGA Controller (`vga_tb.v`)

Targets the counter wrap boundaries directly rather than simulating a full 16.74 ms frame. Verifies:
- `hsync` asserts for exactly 152 clocks
- `frame_tick` fires as a single cycle at `vcount=930`
- `curr_x/y` are zero outside the active window

### Testbench 2 — Collision Detector (`collision_tb.v`)

Covers four corner-case scenarios. **18 tests, 18 PASS, 0 FAIL:**

| Test | Description |
|---|---|
| T1 | Direct hit: bullet exactly on asteroid centre |
| T2 | Near miss: 1 pixel outside AABB boundary |
| T3 | Dynamic radius scaling: LARGE hit / SMALL miss / MEDIUM boundary miss |
| T4 | Ship collision: active overlap, near miss, and inactive asteroid (flag = 0) |

### Testbench 3 — Game State FSM (`gameState_tb.v`)

Exercises all reachable state transitions (`IDLE → PLAYING → GAME_OVER → IDLE`) and verifies:
- `new_game` fires as a single-cycle pulse on re-entry to `IDLE`
- `invis_timer` loads 120 on `ship_hit` and counts down correctly
- `blink` (derived from `invis_timer[3]`) toggles every 8 frames
- Subsequent `ship_hit` assertions during the invincibility window do not decrement `health`

---

## Repository Structure

```
FPGA-Game/
├── src/
│   ├── game_top.v              # Top-level wiring hub & feature decode
│   ├── vga.v                   # VGA sync generator
│   ├── drawcon.v               # 10-layer priority-mux renderer
│   ├── gameState.v             # 3-state Moore FSM
│   ├── collisions.v            # 272 parallel AABB comparators
│   ├── bulletManager.v         # 16-slot bullet pool & fire pipeline
│   ├── asteroidManager.v       # 16-slot asteroid pool & LFSR spawner
│   ├── shipMovement.v          # Accelerometer → velocity → position
│   ├── crosshairMovement.v     # Button-driven crosshair
│   ├── scoreDisplay.v          # Binary → BCD → 7-segment multiplexer
│   ├── heatDisplay.v           # Heat register → LED bargraph
│   ├── Mouse/                  # PS/2 mouse driver (stubbed, future work)
│   └── Accelerometer/
│       ├── iclk.v              # SPI clock divider
│       ├── accSPI.v            # Full-duplex SPI master (ADXL362)
│       └── accOutput.v         # Data deserialiser
├── sprites/                    # Python/utility scripts for BRAM .coe generation
├── testbench/
│   ├── vga_tb.v
│   ├── collision_tb.v
│   └── gameState_tb.v
├── constraints/
│   └── Nexys-A7-100T.xdc       # Pin assignments & timing constraints
└── README.md
```

---

## Build & Synthesis

### Prerequisites

- **Xilinx Vivado** 2020.x or later (WebPACK licence sufficient)
- Nexys A7-100T board with USB cable and VGA monitor

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/JoshR-ENG/FPGA-Game.git
   cd FPGA-Game
   ```

2. **Open Vivado and create a project**
   - Part: `xc7a100tcsg324-1`
   - Add all `src/*.v` files and subdirectories as sources
   - Add `constraints/Nexys-A7-100T.xdc` as a constraint file

3. **Add Block RAM IP**
   - All BRAM sprite ROMs are initialised from `.coe` files in `sprites/`
   - Regenerate IP if Vivado version differs from the project default

4. **Run synthesis and implementation**
   ```
   Flow → Run Synthesis
   Flow → Run Implementation
   Flow → Generate Bitstream
   ```

5. **Program the board**
   ```
   Open Hardware Manager → Program Device → Select .bit file
   ```

### Simulation (Icarus Verilog)

```bash
# Example: simulate the collision testbench
cd testbench
iverilog -o sim_collision collision_tb.v ../src/collisions.v
vvp sim_collision
# Expected output: 18 PASS, 0 FAIL
```

---

## Hardware Requirements

| Component | Specification |
|---|---|
| FPGA Board | Nexys A7-100T (Artix-7 XC7A100T) |
| Display | VGA monitor supporting 1440×900 @ 60 Hz |
| Interface | VGA Pmod adapter (supplied by university lab, or Digilent Pmod VGA) |
| Accelerometer | On-board ADXL362 (no additional hardware required) |
| Power | USB (5V) via Micro-USB or external 5V barrel jack |

---

## Known Limitations & Future Work

### Current Limitations

- **Button-based aiming** — the PS/2 mouse driver exists in `src/Mouse/` but is currently stubbed; the crosshair defaults to discrete push-button movement.
- **AABB imprecision on circular sprites** — corner regions of the bounding box extend visibly beyond the asteroid sprite, occasionally producing unfair-looking collisions.
- **Shift-normalisation speed variance** — bullets fired at shallow angles travel marginally faster than diagonal shots due to the power-of-2 approximation.
- **No cross-domain synchronisation** — the SPI domain and game-logic domain share a single clock; a formal 2-FF CDC synchroniser would be more robust.

### Future Work

| Enhancement | Approach |
|---|---|
| Circular collision masks | \(x^2 + y^2 < r^2\) using Artix-7 DSP48 blocks — no impact on LUT fabric |
| PS/2 mouse aiming | Activate the existing driver with proper CDC FIFO on the data path |
| Asteroid splitting | Spawn 2× medium on large destruction, 2× small on medium |
| Persistent high scores | BRAM with `INIT` attributes or SPI flash across power cycles |
| Hardware-in-the-loop testing | UART scoreboard streaming collision events to host PC for on-hardware regression |

---

## References

1. Digilent, Inc. *VGA Display Controller*. Available: https://digilent.com/reference/learn/programmable-logic/tutorials/vga-display-congroller/start
2. Analog Devices. *ADXL362 Datasheet: Micropower 3-Axis Digital Output MEMS Accelerometer*. Available: https://www.analog.com/media/en/technical-documentation/data-sheets/adxl362.pdf
3. Texas Instruments. *What's an LFSR?* Application Report SCTA036A, 1996. Available: https://www.ti.com/lit/an/scta036a/scta036a.pdf

---

*University of Warwick — ES3B2 Digital Systems Design — 2025/26*
