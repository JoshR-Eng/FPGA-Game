`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2026 11:33:11
// Design Name: 
// Module Name: mouse
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


module mouse(
    input        clk,              // System Clock (100 MHz)
    input        rst,              // Active-high reset
    input        mouse_data,       // PS/2 Data from mouse
    input        mouse_clk,        // PS/2 Clk from mouse
    
    output [7:0] x_pos,            // X pos [0, +255] 
    output [7:0] y_pos,            // Y pos [0, +255]
    output x_sign, y_sign,         // Sign of the X & Y Position
    output       left_btn,         // Left button state
    output       right_btn,        // Right button state
    output       middle_btn        // Middle button state
    );
    
    // --- Internal registers --------------------------------------
    wire [10:0]  word1, word2, word3, word4;
    wire [7:0]   signal1, signal2, signal3, signal4;
    wire         val;
    
    assign ready = val && ack;
    
    
    // --- Map Signals ---------------------------------------------
    // Note: PS/2 sends LSB first, so we reverse the bits when extracting
    assign x_pos = {signal2[0], signal2[1], signal2[2], signal2[3], signal2[4], signal2[5], signal2[6], signal2[7]};
    assign y_pos = {signal3[0], signal3[1], signal3[2], signal3[3], signal3[4], signal3[5], signal3[6], signal3[7]};
    assign x_sign = signal1[3];  // Bit 4 of status byte
    assign y_sign = signal1[2];  // Bit 5 of status byte
    assign left_btn = signal1[7]; // Bit 0 of status byte
    assign right_btn = signal1[6]; // Bit 1 of status byte
    assign middle_btn = signal1[5]; // Bit 2 of status byte 
    
    
    // --- Signal Processing ---------------------------------------
    reg [43:0]  fifo;
    reg [43:0]  buffer;
    reg [5:0]   counter;
    reg [1:0]   PS2Clk_sync;
    reg         PS2Data;
    reg         ack;
    wire        PS2Clk_negedge;
    
    assign word1 = fifo[33 +: 11];
    assign word2 = fifo[22 +: 11];
    assign word3 = fifo[11 +: 11];
    assign word4 = fifo[0 +: 11];
    
    assign PS2Clk_negedge = (PS2Clk_sync == 2'b10);
    
    initial begin
        fifo <= 44'b0;
        buffer <= 44'b0;
        counter <= 6'b0;
        PS2Clk_sync <= 2'b1;
        ack <= 1'b0;
        PS2Data <= 1'b0;
    end
    
    always @(posedge clk) begin 
        if (rst) begin
            fifo <= 44'b0;
            buffer <= 44'b0;
            counter <= 6'b0;
            ack <= 1'b0;
            PS2Clk_sync <= 2'b11;
            PS2Data <= 1'b0;
        end else begin
            // Synchronize PS/2 clock
            PS2Clk_sync <= {PS2Clk_sync[0], mouse_clk};
            PS2Data <= mouse_data;
            
            if (PS2Clk_negedge) begin
                buffer <= {buffer[42:0], PS2Data};
                counter <= counter + 6'b1;
            end
            
            if (counter == 6'd44) begin
                // Counter == 44 --> Buffer is FULL
                fifo <= buffer;
                buffer <= 44'b0;
                counter <= 6'b0;
                ack <= 1'b1;
            end else begin
                // Counter != 44 --> clear ack flag
                ack <= 1'b0;
            end
        end
    end


    // --- Signal Validation ---------------------------------------
    wire parity1, parity2, parity3, parity4, parity;
    wire start1, start2, start3, start4, start;
    wire stop1, stop2, stop3, stop4, stop;
    wire valid1, valid2, valid3, valid4;

    // Separate packets into segments
    assign {start1, signal1, parity1, stop1} = word1;
    assign {start2, signal2, parity2, stop2} = word2;
    assign {start3, signal3, parity3, stop3} = word3;
    assign {start4, signal4, parity4, stop4} = word4;
    
    // XNOR words together and compare to parity bit
    assign valid1 = ~^signal1 == parity1;
    assign valid2 = ~^signal2 == parity2;
    assign valid3 = ~^signal3 == parity3;
    assign valid4 = ~^signal4 == parity4;
    
    assign parity = valid1 && valid2 && valid3 && valid4;
    assign start = (!start1 && !start2 && !start3 && !start4);
    assign stop = (stop1 && stop2 && stop3 && stop4);
    assign o_valid = (start && stop && parity);

endmodule
