`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.03.2026 11:40:27
// Design Name: 
// Module Name: AccelerometerData
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


module accOutput(
    input CLK100MHZ,            // nexys a7 clock
    input ACL_MISO,             // master in
    output ACL_MOSI,            // master out
    output ACL_SCLK,            // spi sclk
    output ACL_CSN,             // spi ~chip select
    //output [14:0] LED,          // X = LED[14:10], Y = LED[9:5], Z = LED[4:0]
    output [14:0] acl_data
    );
 wire w_4MHz;
    wire [14:0] w_acl_data;
        
    iclk clock_generation(
        .CLK100MHZ(CLK100MHZ),
        .clk_4MHz(w_4MHz)
    );
    
    AccSPI master(
        .iclk(w_4MHz),
        .miso(ACL_MISO),
        .sclk(ACL_SCLK),
        .mosi(ACL_MOSI),
        .cs(ACL_CSN),
        .acl_data(w_acl_data)
    );
    
    //assign LED[14:10] = acl_data[14:10];    // 5 bits of x data
    //assign LED[9:5]   = acl_data[9:5];     // 5 bits of y data
    //assign LED[4:0]   = acl_data[4:0];      // 5 bits of z data
    assign acl_data = w_acl_data;
endmodule
