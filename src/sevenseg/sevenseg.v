`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: J. Rawlinson 
// 
// Create Date: 02.02.2026 14:31:41
// Design Name: 
// Module Name: seginterface
// Project Name: 
// Target Devices: 
// Tool Versions: Nexys A7-100T 
// Description: This module takes the desired number and it's position
//              to be displayed on the seven-seg and outputs which of
//              the seven segments should be turned on 
// 
// Dependencies: None 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sevenseg(
    input [3:0] num,
    output a, b, c, d, e, f, g
    );
    
    reg [6: 0] output_sevenseg;
    
    assign {a,b,c,d,e,f,g} = output_sevenseg;
    
    always @* begin
        case(num)
            4'h0 : output_sevenseg = 7'b0000001;
            4'h1 : output_sevenseg = 7'b1001111;
            4'h2 : output_sevenseg = 7'b0010010;
            4'h3 : output_sevenseg = 7'b0000110;
            4'h4 : output_sevenseg = 7'b1001100;
            4'h5 : output_sevenseg = 7'b0100100;
            4'h6 : output_sevenseg = 7'b0100000;
            4'h7 : output_sevenseg = 7'b0001111;
            4'h8 : output_sevenseg = 7'b0000000;
            4'h9 : output_sevenseg = 7'b0001100;
            4'ha : output_sevenseg = 7'b0000010;
            4'hb : output_sevenseg = 7'b1100000;
            4'hc : output_sevenseg = 7'b0110001;
            4'hd : output_sevenseg = 7'b1000010;
            4'he : output_sevenseg = 7'b0110000;
            4'hf : output_sevenseg = 7'b0111000;
            default : output_sevenseg = 7'b0000000;
        endcase  
    end
    
endmodule
