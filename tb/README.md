# Testbench Directory

This directory contains testbenches for the Event Horizon game modules.

## Available Testbenches

### mouse_tb.v - PS/2 Mouse Interface Testbench

**Purpose:** Validates the PS/2 mouse interface module functionality

**Features:**
- Self-checking testbench with automatic [PASS]/[FAIL] reporting
- Tests 10 scenarios including:
  - Positive/negative X and Y movement
  - All three mouse buttons (left, right, middle)
  - Sign bit handling
  - Maximum value edge cases (255)
  - Sequential packet transmission
- **All tests pass!** ✓

**How to Run:**
```bash
# From project root directory
iverilog -g2012 -o sim.vvp tb/mouse_tb.v src/mouse.v
vvp sim.vvp
gtkwave waves.vcd  # View waveforms
```

Or use the Makefile (after setting SOURCES):
```bash
# Edit Makefile to set: SOURCES = tb/mouse_tb.v src/mouse.v
make sim
```

**Expected Output:**
```
========================================
  Test Summary
========================================
Total Tests: 10
Passed:      10
Failed:      0
========================================
[SUCCESS] All tests passed!
```

## Bug Fixes Applied

The testbench development revealed and fixed several bugs in `src/mouse.v`:

1. **Variable name mismatch**: Changed `word_m/x/y/w` to `word1/2/3/4` to match usage
2. **Missing middle button**: Added `middle_btn` output assignment
3. **Missing PS/2 clock synchronization**: Added proper clock domain crossing for `mouse_clk`
4. **Incorrect FIFO clearing**: Removed premature FIFO clear that prevented data capture
5. **Bit order reversal**: Added bit reversal for proper LSB-first PS/2 protocol handling

## Creating New Testbenches

When creating testbenches for this project:

1. **Follow TDD Principles:** Make them self-checking with automatic pass/fail reporting
2. **Use $display statements:** Print `[PASS]` or `[FAIL]` for each test case
3. **Generate VCD files:** Include `$dumpfile()` and `$dumpvars()` for waveform viewing
4. **Test edge cases:** Include maximum/minimum values, boundary conditions
5. **Document behavior:** Add comments explaining what each test validates
6. **Add timeout:** Include a timeout watchdog to prevent infinite loops

## Testbench Template

```verilog
`timescale 1ns / 1ps

module my_module_tb;
    // Signals
    reg clk, rst;
    wire [7:0] output_signal;
    
    // Test control
    integer test_count, pass_count, fail_count;
    
    // Instantiate UUT
    my_module uut(.clk(clk), .rst(rst), .out(output_signal));
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Test sequence
    initial begin
        // Initialize
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        // Run tests
        // ... test cases ...
        
        // Report summary
        $display("Tests: %0d, Passed: %0d, Failed: %0d", 
                 test_count, pass_count, fail_count);
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, my_module_tb);
    end
endmodule
```
