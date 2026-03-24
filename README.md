# Project Specification: "Event Horizon: Asteroid Defense"

## 1. Game Description
A 2D space survival shooter built for the Nexys 4DDR FPGA. The player pilots a central spacecraft, defending against an onslaught of asteroids that vary in size and speed. The game features an "Object Pool" architecture to handle the dynamic splitting and spawning of asteroids, rigid-body elastic collisions, and a hardware-accelerated physics engine. 

**Easter Egg (The Gravity Anomaly):** Flipping a specific switch triggers a "Black Hole" mode, altering the ALU datapath to apply radial gravity to all asteroids, forcing them into a central singularity before a supernova reset.

## 2. Features & Hardware Integration
This design maximizes the grading rubric for "Extra features" and "Creative design ideas".

* **Visuals (Sprites & BRAM):** Asteroids, explosions, and the player ship are stored in Block RAM, featuring multi-frame animations to ensure flawless sprite memory utilization.
* **Movement (Accelerometer):** The player tilts the physical FPGA board to apply thrust vectors to the ship via SPI communication.
* **Aiming & Firing (PS/2 Mouse):** A custom PS/2 controller reads mouse deltas to move a crosshair and register clicks for firing lasers.
* **Difficulty Scaling (Switches):** Hardware switches act as "Overdrive" toggles, dynamically multiplying spawn rates and asteroid velocities to demonstrate variable datapaths.
* **Weapon Heat (LEDs):** The 16 LEDs above the switches act as a thermal capacity bar, filling up as the player shoots and cooling down over time.
* **Mandatory Info Bar:** The top 100 pixels of the VGA display are strictly reserved for the Info Bar. It spans the display width, uses unique group colors, and displays the game name, student IDs, and animated health/score sprites.

---

## 3. System Architecture & Module Breakdown
The project is divided into two distinct domains to facilitate parallel development and modular testing. 

### Domain A: Visuals & Render Pipeline (Person A)
Responsible for VGA timing, memory management, and drawing pixels to the screen.

**Module A1: VGA Sync Generator**
* **Function:** Generates standard 60Hz VGA timing signals.
* **Inputs:** `clk` (100MHz), `rst`
* **Outputs:** `hsync`, `vsync`, `pixel_x` \[9:0\], `pixel_y` \[9:0\], `video_on`
* **Connected To:** Feeds coordinates to Module A3.

**Module A2: BRAM Sprite Controller**
* **Function:** A behavioral wrapper for Xilinx Block RAM containing `.coe` image data.
* **Inputs:** `clk`, `read_addr_a`, `read_addr_b`
* **Outputs:** `color_data_a` \[11:0\], `color_data_b` \[11:0]
* **Connected To:** Feeds color data to Module A3.

**Module A3: Pixel Multiplexer & Info Bar**
* **Function:** Decides what color to output based on the current `pixel_x`/`pixel_y` and object coordinates. Forces the top 100 pixels to be the Info Bar.
* **Inputs:** `pixel_x`, `pixel_y`, `ship_x`, `ship_y`, `asteroid_array`, `score`, `health`
* **Outputs:** `vga_r` \[3:0], `vga_g` \[3:0], `vga_b` \[3:0]
* **Connected To:** Physical VGA pins.

### Domain B: Physics Engine & Logic (Person B)
Responsible for math operations, input handling, and game state.

**Module B1: Hardware Interface (SPI & PS/2)**
* **Function:** Deserializes raw sensor data into usable coordinate deltas.
* **Inputs:** `clk`, `acl_miso`, `ps2_clk`, `ps2_data`
* **Outputs:** `tilt_x`, `tilt_y`, `mouse_x`, `mouse_y`, `mouse_click`
* **Connected To:** Feeds player inputs to Module B2.

**Module B2: Physics ALU & Object Pool (Asteroid Manager)**
* **Function:** Manages the fixed-size array of asteroids. Calculates kinematics for the ship and asteroids using fixed-point binary math. 
* **Inputs:** `clk_frame_tick`, `tilt_x`, `tilt_y`, `switch_gravity`
* **Outputs:** `ship_x`, `ship_y`, `asteroid_array` (positions, sizes, active states)
* **Connected To:** Feeds coordinates to Module B3 and Module A3.

**Module B3: Collision Detection & Game State**
* **Function:** Checks for AABB coordinate overlaps between bullets, asteroids, and the ship. Updates score and heat mechanics.
* **Inputs:** `clk`, `mouse_click`, `ship_x`, `ship_y`, `asteroid_array`
* **Outputs:** `hit_flags` (feeds back to B2 to trigger splits/explosions), `score`, `health`, `led_out` \[15:0], `seven_seg_out`
* **Connected To:** Feeds data to Physical Pins and Module A3.

---

## 4. Methodology & Implementation Workflow
To align with modern verification techniques and secure the highest testing marks, the development cycle relies on Test-Driven Development (TDD).

1. **Local Development (Fedora OS):** All Verilog modules are written using standard editors and version-controlled via Git. 
2. **Self-Checking Testbenches:** Before integration, complex datapaths (like the Physics ALU) are simulated using `iverilog`. SystemVerilog testbenches mathematically verify outputs against expected results, logging `[PASS]` or `[FAIL]`.
3. **Behavioral Modeling:** Xilinx proprietary IP (e.g., Block RAM, Clock Wizards) are abstracted behind Verilog wrappers to allow for fast, local Linux simulation without Vivado overhead.
4. **Final Deployment (Windows/Vivado):** Verified Verilog is pulled from Git onto the Vivado build server. Xilinx IPs are linked, and the final `.bit` file is synthesized for the Nexys 4DDR board.

---

## 5. Critical Milestones for >80% (Exceptional Mark)
* **Testing Rigor (5%):** The report must feature more than two well-explained testbenches using waveforms, explicitly linked to modern verification (Self-Checking/TDD).
* **Flawless Sprites (10%):** Animations (explosions, ship damage) must function without visual bugs, utilizing available memory.
* **Complex Interactions (10%):** The Object Pool must successfully spawn, split, and bounce multiple asteroids simultaneously without frame drops or coordinate glitches.
* **The 10-Minute Limit:** The final video submission must not exceed 10 minutes to avoid a 5-mark penalty per extra minute. The switch-based difficulty override will be used to demonstrate dynamic gameplay scaling swiftly.