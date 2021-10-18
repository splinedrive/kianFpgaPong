/*
 *  kianFpgaPong
 *
 *  copyright (c) 2021 hirosh dabui <hirosh@dabui.de>
 *
 *  permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  the software is provided "as is" and the author disclaims all warranties
 *  with regard to this software including all implied warranties of
 *  merchantability and fitness. in no event shall the author be liable for
 *  any special, direct, indirect, or consequential damages or any damages
 *  whatsoever resulting from loss of use, data or profits, whether in an
 *  action of contract, negligence or other tortious action, arising out of
 *  or in connection with the use or performance of this software.
 *
 */
`default_nettype none
`timescale 1ns/1ps

module top(
           input  wire clk25,

           input wire A0,
           input wire B0,
           input wire SW0,
           input wire start_game,

           input wire A1,
           input wire B1,
           input wire SW1,

           output reg led,

           output wire la,
           output wire ra,

           output wire r,
           output wire g,
           output wire b,

           output wire ck,

           output wire hs,
           output wire de,

           output wire int_,
           output wire vs
       );

localparam FPGA_FREQUENCY = 25_000_000;

reg [5:0] reset_cnt = 0;
wire resetn = &reset_cnt;
always @(posedge clk) begin
    reset_cnt <= reset_cnt + {4'b0, !resetn};
end

// for porting use pll to have 25 MHz
//wire clk = clk12;
wire clk = clk25;
wire locked;
//pll pll_i(clk25, clk, locked);
//pll pll_i(clk12, clk);

wire [10:0] hcnt;
wire [10:0] vcnt;
wire hcycle;
wire vcycle;
wire hsync;
wire vsync;
wire blank;

assign ck = clk;
assign de = ~blank;
assign hs = hsync;
assign vs = vsync;

////////////////
localparam SWIDTH  = 640;
localparam SHEIGHT = 480;
my_vga_clk_generator #(
                         .VPOL( 1 ),
                         .HPOL( 1 ),
                         .FRAME_RATE( 85 ),

                         .HACTIVE( SWIDTH ),
                         .HFP( 16 ),
                         .HSLEN( 96 ),
                         .HBP( 48 ),

                         .VACTIVE( SHEIGHT ),
                         .VFP( 10 ),
                         .VSLEN( 2 ),
                         .VBP( 33 )

                     ) my_vga_clk_generator_i(
                         .pclk(clk),
                         .out_hcnt(hcnt),
                         .out_vcnt(vcnt),
                         .out_hsync(hsync),
                         .out_vsync(vsync),
                         .out_blank(blank),
                         .reset_n(resetn)
                     );


wire autopilot_paddle0 = SW0;
wire autopilot_paddle1 = SW1;

////////////////
/* got from https://www.fpga4fun.com/QuadratureDecoder.html */
reg [2:0] a_reg0 = 0;
reg [2:0] b_reg0 = 0;

always @(posedge clk) a_reg0 <= {a_reg0[1:0], A0};
always @(posedge clk) b_reg0 <= {b_reg0[1:0], B0};

always @(posedge clk) led <= led ^ (rotation_detected0 | rotation_direction1);
wire rotation_detected0  = a_reg0[1] ^ a_reg0[2] ^ b_reg0[1] ^ b_reg0[2];
wire rotation_direction0 = a_reg0[1] ^ b_reg0[2];
reg [10:0] paddle_y0 = SHEIGHT/2 - 4;

////////////////
always @(posedge clk) begin
    if (rotation_detected0) begin
        if (!rotation_direction0) begin
            if (paddle_y0 <= (SHEIGHT-PADDLE_HEIGHT-PADDLE_SPEED))
                paddle_y0 <= paddle_y0 + PADDLE_SPEED;
        end else begin
            if (paddle_y0 >= PADDLE_HEIGHT+1+PADDLE_SPEED) begin
                paddle_y0 <= paddle_y0 - PADDLE_SPEED;
            end
        end
    end

    if (autopilot_paddle0) begin
        if ((paddle_y0 -PADDLE_HEIGHT) < ball_y)  begin
            if (paddle_y0 <= (SHEIGHT-PADDLE_HEIGHT-PADDLE_SPEED))
                paddle_y0 <= paddle_y0 + 1;
        end else begin
            if (paddle_y0 >= PADDLE_HEIGHT+1+PADDLE_SPEED) begin
                paddle_y0 <= paddle_y0 - 1;
            end
        end
    end

end

wire paddle_gfx0 = (vcnt >= paddle_y0-PADDLE_HEIGHT ) && vcnt <= (paddle_y0 + PADDLE_HEIGHT) && ((hcnt >= (SWIDTH-PADDLE_OFFSET)) && (hcnt < (SWIDTH -PADDLE_OFFSET + PADDLE_WIDTH)) ) ;

//// paddle 2
reg [2:0] a_reg1 = 0;
reg [2:0] b_reg1 = 0;

always @(posedge clk) a_reg1 <= {a_reg1[1:0], A1};
always @(posedge clk) b_reg1 <= {b_reg1[1:0], B1};

wire rotation_detected1  = a_reg1[1] ^ a_reg1[2] ^ b_reg1[1] ^ b_reg1[2];
wire rotation_direction1 = a_reg1[1] ^ b_reg1[2];
reg [10:0] paddle_y1 = SHEIGHT/2 - PADDLE_WIDTH;

////////////////
always @(posedge clk) begin
    if (rotation_detected1) begin
        if (!rotation_direction1) begin
            if (paddle_y1 <= (SHEIGHT-PADDLE_HEIGHT-PADDLE_SPEED))
                paddle_y1 <= paddle_y1 + PADDLE_SPEED;
        end else begin
            if (paddle_y1 >= PADDLE_HEIGHT+1+PADDLE_SPEED) begin
                paddle_y1 <= paddle_y1 - PADDLE_SPEED;
            end
        end
    end

    if (autopilot_paddle1) begin
        if ((paddle_y1 -PADDLE_HEIGHT) < ball_y)  begin
            if (paddle_y1 <= (SHEIGHT-PADDLE_HEIGHT-PADDLE_SPEED))
                paddle_y1 <= paddle_y1 + 1;
        end else begin
            if (paddle_y1 >= PADDLE_HEIGHT+1+PADDLE_SPEED) begin
                paddle_y1 <= paddle_y1 - 1;
            end
        end
    end

end

wire paddle_gfx1 = (vcnt >= paddle_y1-PADDLE_HEIGHT ) && vcnt <= (paddle_y1 + PADDLE_HEIGHT) && (hcnt >= (PADDLE_OFFSET) && hcnt < (PADDLE_OFFSET+PADDLE_WIDTH));

/////////////////
localparam BALL_SPEED_X  = 2;
localparam BALL_SPEED_Y  = 1;
localparam BALL_SIZE     = 8;

reg [10:0] ball_x       = SWIDTH>>1;
reg [10:0] ball_y       = (SHEIGHT>>1)-(BALL_SIZE>>1);
reg [10:0] ball_delta_x = BALL_SPEED_X;
reg [10:0] ball_delta_y = BALL_SPEED_Y;


wire [10:0] xdiff = hcnt - ball_x;
wire [10:0] ydiff = vcnt - ball_y;
localparam PADDLE_OFFSET = 128;
localparam PADDLE_HEIGHT = 25;
localparam PADDLE_SPEED  = 8;
localparam PADDLE_WIDTH  = 6;
wire ball_gfx = (xdiff < BALL_SIZE) && (ydiff < BALL_SIZE);

reg vsync_reg = 0;
reg [1:0] cnt = 0;

wire next_frame = vsync_reg ^ vsync;

wire bounced_x = paddle_col0 | paddle_col1 | ball_left_right_col;// | strip_col;
wire bounced_y = ball_top_bottom_col;
always @(posedge clk) begin
    vsync_reg <= vsync;

    if (next_frame) begin
        if (bounced_x) begin
            ball_delta_x <= -ball_delta_x;
        end
        if (bounced_y) begin
            ball_delta_y <= -ball_delta_y;
        end

        if (ball_left_right_col) begin
            if ( ~ball_delta_x[10] ) begin
                score0_bcd <= (score0_bcd == 9) ? 0 : score0_bcd + 1;
                score1_bcd <= (score0_bcd == 9) ? 0 : score1_bcd;
            end else begin
                score1_bcd <= (score1_bcd == 9) ? 0 : score1_bcd + 1;
                score0_bcd <= (score1_bcd == 9) ? 0 : score0_bcd;
            end
        end

        if (!start_game) begin
            score0_bcd <= 0;
            score1_bcd <= 0;
        end

        ball_x <= ball_x + (bounced_x ? -ball_delta_x : ball_delta_x);
        ball_y <= ball_y + (bounced_y ? -ball_delta_y : ball_delta_y);
    end

end

// collision logic
reg paddle_col0           = 0;
reg paddle_col1           = 0;
reg strip_col             = 0;
reg ball_top_bottom_col   = 0;
reg ball_left_right_col   = 0;

always @(posedge clk) begin
    if (next_frame) begin
        paddle_col0 <= 0;
        paddle_col1 <= 0;
        ball_top_bottom_col <= 0;
        ball_left_right_col <= 0;
        strip_col           <= 0;
    end else begin
        if (paddle_gfx0 & ball_gfx) paddle_col0 <= 1'b1;
        if (paddle_gfx1 & ball_gfx) paddle_col1 <= 1'b1;
        if (strip_gfx & ball_gfx)   strip_col <= 1'b1;

        if ((ball_y >= (SHEIGHT - BALL_SIZE))) ball_top_bottom_col <= 1;
        if ((ball_x >= (SWIDTH  - BALL_SIZE))) ball_left_right_col <= 1;
    end
end


wire strip_gfx = hcnt == ((SWIDTH>>1)-1) && !vcnt[4];


//////////////////////

wire [3:0] digit = hcnt < (SWIDTH>>1) ? score0_bcd : score1_bcd;


//////////////////////

wire [3:0] digit = hcnt < (SWIDTH>>1) ? score0_bcd : score1_bcd;

localparam SCORE0_X        = 'h10*13;
localparam SCORE0_Y        = 'h10*2;
localparam SCORE0_SCALE_X  = 3;
localparam SCORE0_SCALE_Y  = 5;
localparam SCORE0_HEIGHT   = 5;
localparam SCORE0_WIDTH    = 5;

reg [3:0]   score0_bcd   = 0;
wire [10:0] score0_xdiff = hcnt - SCORE0_X;
wire [10:0] score0_ydiff = vcnt - SCORE0_Y;
wire [2 :0] y_offset     = (score0_ydiff >> SCORE0_SCALE_Y);
wire score0_shown        = (score0_xdiff < (SCORE0_WIDTH << SCORE0_SCALE_X) ) && (score0_ydiff < (SCORE0_HEIGHT << SCORE0_SCALE_Y));
wire score0_gfx          = score0_shown ? digit_bits[ (score0_xdiff >> SCORE0_SCALE_X) & 'd15 ] : 1'b0;

//////////////////////
localparam SCORE1_X        = 'h10*25;
localparam SCORE1_Y        = 'h10*2;
localparam SCORE1_SCALE_X  = 3;
localparam SCORE1_SCALE_Y  = 5;
localparam SCORE1_HEIGHT   = 5;
localparam SCORE1_WIDTH    = 5;
reg [3:0]   score1_bcd   = 0;
wire [10:0] score1_xdiff = hcnt - SCORE1_X;
wire [10:0] score1_ydiff = vcnt - SCORE1_Y;
wire [2 :0] y_offset     = (score1_ydiff >> SCORE1_SCALE_Y);
wire score1_shown        = (score1_xdiff < (SCORE1_WIDTH << SCORE1_SCALE_X) ) && (score1_ydiff < (SCORE1_HEIGHT << SCORE1_SCALE_Y));
wire score1_gfx          = score1_shown ? digit_bits[ (score1_xdiff >> SCORE1_SCALE_X) & 'd15 ] : 1'b0;

//////////////////////

assign {r,g,b, int_} = ~blank ? {{3{paddle_gfx0 | paddle_gfx1 |
                                    ball_gfx    | strip_gfx | score0_gfx | score1_gfx}}, 1'b0} : 4'b0;


//////////////////////////////////
reg [17:0] colision_cnt = ~0;
wire audio_disable = &colision_cnt;
reg ball_top_bottom_col_reg = 0;
reg ball_left_right_col_reg = 0;
always @(posedge clk) begin
    if (paddle_col0 || paddle_col1 || ball_top_bottom_col || ball_left_right_col) begin
        ball_top_bottom_col_reg <= ball_top_bottom_col;
        ball_left_right_col_reg <= ball_left_right_col;
        colision_cnt <= 0;
    end else begin
        colision_cnt <= colision_cnt + {4'b0, !audio_disable};
    end
end

assign la = speaker & !audio_disable;
assign ra = speaker & !audio_disable;
parameter ball_left_right_tone     = (FPGA_FREQUENCY/125/2) -1;
parameter ball_top_bottom_tone     = (FPGA_FREQUENCY/245/2) -1;
parameter paddle_tone              = (FPGA_FREQUENCY/490/2) -1;

reg [$clog2(ball_left_right_tone) -1:0] counter;
always @(posedge clk) begin

    if(counter==0) counter <= ball_top_bottom_col_reg ? ball_top_bottom_tone : (ball_left_right_col_reg
                ? ball_left_right_tone : paddle_tone); else counter <= counter-1;

end

reg speaker;
always @(posedge clk) if(counter==0) speaker <= ~speaker;

//////////////////////////

// rom 10x5x5
reg  [4:0] digit_bit_array[0:9][0:4];

function [4:0] reverse;
    input [4:0] d;
    integer i;
    begin
        for (i = 0; i < 5; i++)
            reverse[i] = d[4-i];
    end
endfunction


wire [4:0] digit_bits = reverse(digit_bit_array[digit][y_offset]);

// got from https://8bitworkshop.com/ the bitmap for digits
initial begin
    digit_bit_array[0][0] = 5'b11111;
    digit_bit_array[0][1] = 5'b10001;
    digit_bit_array[0][2] = 5'b10001;
    digit_bit_array[0][3] = 5'b10001;
    digit_bit_array[0][4] = 5'b11111;

    digit_bit_array[1][0] = 5'b01100;
    digit_bit_array[1][1] = 5'b00100;
    digit_bit_array[1][2] = 5'b00100;
    digit_bit_array[1][3] = 5'b00100;
    digit_bit_array[1][4] = 5'b11111;

    digit_bit_array[2][0] = 5'b11111;
    digit_bit_array[2][1] = 5'b00001;
    digit_bit_array[2][2] = 5'b11111;
    digit_bit_array[2][3] = 5'b10000;
    digit_bit_array[2][4] = 5'b11111;

    digit_bit_array[3][0] = 5'b11111;
    digit_bit_array[3][1] = 5'b00001;
    digit_bit_array[3][2] = 5'b11111;
    digit_bit_array[3][3] = 5'b00001;
    digit_bit_array[3][4] = 5'b11111;

    digit_bit_array[4][0] = 5'b10001;
    digit_bit_array[4][1] = 5'b10001;
    digit_bit_array[4][2] = 5'b11111;
    digit_bit_array[4][3] = 5'b00001;
    digit_bit_array[4][4] = 5'b00001;

    digit_bit_array[5][0] = 5'b11111;
    digit_bit_array[5][1] = 5'b10000;
    digit_bit_array[5][2] = 5'b11111;
    digit_bit_array[5][3] = 5'b00001;
    digit_bit_array[5][4] = 5'b11111;

    digit_bit_array[6][0] = 5'b11111;
    digit_bit_array[6][1] = 5'b10000;
    digit_bit_array[6][2] = 5'b11111;
    digit_bit_array[6][3] = 5'b10001;
    digit_bit_array[6][4] = 5'b11111;

    digit_bit_array[7][0] = 5'b11111;
    digit_bit_array[7][1] = 5'b00001;
    digit_bit_array[7][2] = 5'b00001;
    digit_bit_array[7][3] = 5'b00001;
    digit_bit_array[7][4] = 5'b00001;

    digit_bit_array[8][0] = 5'b11111;
    digit_bit_array[8][1] = 5'b10001;
    digit_bit_array[8][2] = 5'b11111;
    digit_bit_array[8][3] = 5'b10001;
    digit_bit_array[8][4] = 5'b11111;

    digit_bit_array[9][0] = 5'b11111;
    digit_bit_array[9][1] = 5'b10001;
    digit_bit_array[9][2] = 5'b11111;
    digit_bit_array[9][3] = 5'b00001;
    digit_bit_array[9][4] = 5'b11111;
end


endmodule
