`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mouse_tb
// Description: Self-checking testbench for PS/2 mouse interface
// Tests:
//   - PS/2 packet transmission (44-bit frame)
//   - Parity bit validation
//   - X/Y position extraction
//   - X/Y sign bit handling
//   - Button state detection (left, right, middle)
//   - Multiple packet sequences
//////////////////////////////////////////////////////////////////////////////////

module mouse_tb;

    // Testbench signals
    reg         clk;
    reg         rst;
    reg         mouse_data;
    reg         mouse_clk;
    
    wire [7:0]  x_pos;
    wire [7:0]  y_pos;
    wire        x_sign;
    wire        y_sign;
    wire        left_btn;
    wire        right_btn;
    wire        middle_btn;
    
    // Test control
    integer     test_count;
    integer     pass_count;
    integer     fail_count;
    
    // Instantiate the Unit Under Test
    mouse uut (
        .clk(clk),
        .rst(rst),
        .mouse_data(mouse_data),
        .mouse_clk(mouse_clk),
        .x_pos(x_pos),
        .y_pos(y_pos),
        .x_sign(x_sign),
        .y_sign(y_sign),
        .left_btn(left_btn),
        .right_btn(right_btn),
        .middle_btn(middle_btn)
    );
    
    // Clock generation (100 MHz system clock)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end
    
    // PS/2 Clock generation (separate from system clock)
    initial begin
        mouse_clk = 1;
    end
    
    // Task: Generate PS/2 clock pulse
    task ps2_clock_pulse;
        begin
            #100 mouse_clk = 0;  // PS/2 clock typically 10-16.7 kHz
            #100 mouse_clk = 1;
        end
    endtask
    
    // Task: Send a single 11-bit PS/2 packet (start + 8 data + parity + stop)
    task send_ps2_packet;
        input [7:0] data;
        reg parity_bit;
        integer i;
        begin
            // Calculate odd parity
            parity_bit = ~^data;
            
            // Start bit (0)
            mouse_data = 0;
            ps2_clock_pulse();
            
            // Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                mouse_data = data[i];
                ps2_clock_pulse();
            end
            
            // Parity bit
            mouse_data = parity_bit;
            ps2_clock_pulse();
            
            // Stop bit (1)
            mouse_data = 1;
            ps2_clock_pulse();
        end
    endtask
    
    // Task: Send complete mouse movement packet (4 packets of 11 bits = 44 bits)
    // Packet format:
    //   Byte 1: [Y_overflow, X_overflow, Y_sign, X_sign, 1, Middle_btn, Right_btn, Left_btn]
    //   Byte 2: X movement (0-255)
    //   Byte 3: Y movement (0-255)
    //   Byte 4: Z movement (scroll wheel) - usually 0x00
    task send_mouse_packet;
        input        l_btn, r_btn, m_btn;
        input        x_sgn, y_sgn;
        input [7:0]  x_mov, y_mov;
        reg [7:0]    byte1;
        begin
            // Construct status byte (Byte 1)
            byte1 = {2'b00, y_sgn, x_sgn, 1'b1, m_btn, r_btn, l_btn};
            
            $display("[TIME=%0t] Sending packet: L=%b R=%b M=%b X_sign=%b Y_sign=%b X=%d Y=%d", 
                     $time, l_btn, r_btn, m_btn, x_sgn, y_sgn, x_mov, y_mov);
            
            // Send 4 packets
            send_ps2_packet(byte1);      // Status byte
            send_ps2_packet(x_mov);      // X movement
            send_ps2_packet(y_mov);      // Y movement
            send_ps2_packet(8'h00);      // Z movement (wheel)
            
            // Wait for processing
            #2000;
        end
    endtask
    
    // Task: Check output values
    task check_output;
        input [7:0]  exp_x, exp_y;
        input        exp_x_sign, exp_y_sign;
        input        exp_left, exp_right, exp_middle;
        input [200*8:1] test_name;
        begin
            test_count = test_count + 1;
            
            if (x_pos === exp_x && y_pos === exp_y && 
                x_sign === exp_x_sign && y_sign === exp_y_sign &&
                left_btn === exp_left && right_btn === exp_right && 
                middle_btn === exp_middle) begin
                $display("[PASS] Test %0d: %0s", test_count, test_name);
                $display("       Expected: X=%d Y=%d X_sign=%b Y_sign=%b L=%b R=%b M=%b",
                         exp_x, exp_y, exp_x_sign, exp_y_sign, exp_left, exp_right, exp_middle);
                $display("       Got:      X=%d Y=%d X_sign=%b Y_sign=%b L=%b R=%b M=%b",
                         x_pos, y_pos, x_sign, y_sign, left_btn, right_btn, middle_btn);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %0d: %0s", test_count, test_name);
                $display("       Expected: X=%d Y=%d X_sign=%b Y_sign=%b L=%b R=%b M=%b",
                         exp_x, exp_y, exp_x_sign, exp_y_sign, exp_left, exp_right, exp_middle);
                $display("       Got:      X=%d Y=%d X_sign=%b Y_sign=%b L=%b R=%b M=%b",
                         x_pos, y_pos, x_sign, y_sign, left_btn, right_btn, middle_btn);
                fail_count = fail_count + 1;
            end
            $display("");
        end
    endtask
    
    // Main test sequence
    initial begin
        // Initialize signals
        rst = 1;
        mouse_data = 1;
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        $display("========================================");
        $display("  PS/2 Mouse Interface Testbench");
        $display("========================================");
        $display("");
        
        // Hold reset
        #200;
        rst = 0;
        #100;
        
        // Test 1: Basic movement - positive X, positive Y, no buttons
        $display("--- Test 1: Positive X/Y movement, no buttons ---");
        send_mouse_packet(0, 0, 0, 0, 0, 8'd10, 8'd20);
        check_output(8'd10, 8'd20, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 
                     "Positive X/Y movement");
        
        // Test 2: Negative X movement (sign bit set)
        $display("--- Test 2: Negative X movement ---");
        send_mouse_packet(0, 0, 0, 1, 0, 8'd5, 8'd15);
        check_output(8'd5, 8'd15, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0,
                     "Negative X movement");
        
        // Test 3: Negative Y movement (sign bit set)
        $display("--- Test 3: Negative Y movement ---");
        send_mouse_packet(0, 0, 0, 0, 1, 8'd25, 8'd30);
        check_output(8'd25, 8'd30, 1'b0, 1'b1, 1'b0, 1'b0, 1'b0,
                     "Negative Y movement");
        
        // Test 4: Left button click
        $display("--- Test 4: Left button click ---");
        send_mouse_packet(1, 0, 0, 0, 0, 8'd0, 8'd0);
        check_output(8'd0, 8'd0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
                     "Left button click");
        
        // Test 5: Right button click
        $display("--- Test 5: Right button click ---");
        send_mouse_packet(0, 1, 0, 0, 0, 8'd0, 8'd0);
        check_output(8'd0, 8'd0, 1'b0, 1'b0, 1'b0, 1'b1, 1'b0,
                     "Right button click");
        
        // Test 6: Middle button click
        $display("--- Test 6: Middle button click ---");
        send_mouse_packet(0, 0, 1, 0, 0, 8'd0, 8'd0);
        check_output(8'd0, 8'd0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1,
                     "Middle button click");
        
        // Test 7: Multiple buttons + movement
        $display("--- Test 7: Multiple buttons with movement ---");
        send_mouse_packet(1, 1, 0, 1, 1, 8'd50, 8'd100);
        check_output(8'd50, 8'd100, 1'b1, 1'b1, 1'b1, 1'b1, 1'b0,
                     "Dual button + negative movement");
        
        // Test 8: Maximum values
        $display("--- Test 8: Maximum X/Y values ---");
        send_mouse_packet(0, 0, 0, 0, 0, 8'd255, 8'd255);
        check_output(8'd255, 8'd255, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                     "Maximum X/Y values");
        
        // Test 9: Sequential packets (simulate continuous mouse movement)
        $display("--- Test 9: Sequential packet transmission ---");
        send_mouse_packet(0, 0, 0, 0, 0, 8'd1, 8'd1);
        check_output(8'd1, 8'd1, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                     "Sequential packet 1");
        
        send_mouse_packet(0, 0, 0, 0, 0, 8'd2, 8'd2);
        check_output(8'd2, 8'd2, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                     "Sequential packet 2");
        
        // Final summary
        $display("========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Passed:      %0d", pass_count);
        $display("Failed:      %0d", fail_count);
        $display("========================================");
        
        if (fail_count == 0) begin
            $display("[SUCCESS] All tests passed!");
        end else begin
            $display("[FAILURE] Some tests failed. Review output above.");
        end
        
        $display("");
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #120000000;  // Increased timeout for sequential tests
        $display("[ERROR] Testbench timeout!");
        $finish;
    end
    
    // Waveform dump for GTKWave
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, mouse_tb);
    end

endmodule
