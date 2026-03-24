`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.03.2026 12:21:21
// Design Name: 
// Module Name: PlayerMovement
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


module PlayerMovement(
    input clk,
    input rst,
    input [14:0] acl_data,
    output [10:0] playerpos_x,
    output [10:0] playerpos_y 
    );
    
wire [14:0]w_acl_data;

reg [10:0] r_playerpos_x;
reg [10:0] r_playerpos_y;

wire x_sign;
wire y_sign;

wire [3:0] x_data;
wire [3:0] y_data;

assign x_sign = acl_data[14];
assign y_sign = acl_data[9];
 
assign x_data = acl_data[13:10];
assign y_data = acl_data[8:5];

assign playerpos_x = r_playerpos_x;
assign playerpos_y = r_playerpos_y;

// Accelerometer is at 90 degrees to the board orientation so the accelerometer x and y are swapped.
always@(posedge clk) begin
    if (rst) begin
    r_playerpos_x <= 11'd10;
    r_playerpos_y <= 11'd10;
    end
    else begin
    
    if (x_sign == 1'b1) begin // up
        if (r_playerpos_y > 11'd10) begin
            if ((x_data > 4'd2) & (x_data < 4'd6)) begin
            r_playerpos_y <= r_playerpos_y - 1;
            end 
            if ((x_data > 4'd6) & (x_data < 4'd10)) begin
            r_playerpos_y <= r_playerpos_y - 2;
            end 
            if ((x_data > 4'd10) & (x_data < 4'd14)) begin
            r_playerpos_y <= r_playerpos_y - 3;
            end
            if (x_data > 4'd14) begin
            r_playerpos_y <= r_playerpos_y - 4;
            end  
        end
    end
    if (y_sign == 1'b0) begin // left
        if (r_playerpos_x > 11'd10) begin
            if ((y_data > 4'd2) & (y_data < 4'd6)) begin
            r_playerpos_x <= r_playerpos_x - 1;
            end 
            if ((y_data > 4'd6) & (y_data < 4'd10)) begin
            r_playerpos_x <= r_playerpos_x - 2;
            end 
            if ((y_data > 4'd10) & (y_data < 4'd14)) begin
            r_playerpos_x <= r_playerpos_x - 3;
            end
            if (y_data > 4'd14) begin
            r_playerpos_x <= r_playerpos_x - 4;
            end  
        end
    end
    if (y_sign == 1'b1) begin// right
        if (r_playerpos_x < 11'd1429) begin
            if ((y_data > 4'd2) & (y_data < 4'd6)) begin
            r_playerpos_x <= r_playerpos_x + 1;
            end 
            if ((y_data > 4'd6) & (y_data < 4'd10)) begin
            r_playerpos_x <= r_playerpos_x + 2;
            end 
            if ((y_data > 4'd10) & (y_data < 4'd14)) begin
            r_playerpos_x <= r_playerpos_x + 3;
            end
            if (y_data > 4'd14) begin
            r_playerpos_x <= r_playerpos_x + 4;
            end  
        end
    end
    if(x_sign == 1'b0) begin //down
        if (r_playerpos_y < 11'd889) begin
            if ((x_data > 4'd2) & (x_data < 4'd6)) begin
            r_playerpos_y <= r_playerpos_y + 1;
            end 
            if ((x_data > 4'd6) & (x_data < 4'd10)) begin
            r_playerpos_y <= r_playerpos_y + 2;
            end 
            if ((x_data > 4'd10) & (x_data < 4'd14)) begin
            r_playerpos_y <= r_playerpos_y + 3;
            end
            if (x_data > 4'd14) begin
            r_playerpos_y <= r_playerpos_y + 4;
            end  
        end
    end
 end
 end
endmodule

