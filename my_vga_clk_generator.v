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
`timescale 1ns / 1ps
`include "my_vga_clk_generator.vh"
/* todo: reset */
module my_vga_clk_generator #( `MY_VGA_DEFAULT_PARAMS ) (
           input pclk,
           output out_hsync,
           output out_vsync,
           output out_blank,
           output reg [10:0] out_hcnt, /* 0..2043 */
           output reg [10:0] out_vcnt, /* 0..2043 */
           input reset_n
       );

`MY_VGA_DECLS

    /*
     *
     *         +
     *         |
     *         | VACTIVE
     *         |
     *         |       HACTIVE            HFP    HSLEN    HBP
     *         ------------------------++-----++-------+------+
     *         |
     *         |
     *         |
     *         |
     *         |
     *         +
     *         | VFP
     *         +
     *         +
     *         |
     *         | VSLEN
     *         |
     *         +
     *         +
     *         |
     *         | HBP
     *         |
     *         +
     *
     */

    /* verilator lint_off UNUSED */
    wire locked;

assign out_vsync = ((out_vcnt >= (VACTIVE + VFP -1)) && (out_vcnt < (VACTIVE + VFP + VSLEN))) ^ ~VPOL;
assign out_hsync = ((out_hcnt >= (HACTIVE + HFP -1)) && (out_hcnt < (HACTIVE + HFP + HSLEN))) ^ ~HPOL;
assign out_blank = (out_hcnt >= HACTIVE) || (out_vcnt >= VACTIVE);

wire hcycle = out_hcnt == (HTOTAL -1) || ~reset_n;
wire vcycle = out_vcnt == (VTOTAL -1) || ~reset_n;

always @(posedge pclk) out_hcnt <= hcycle ? 0 : out_hcnt + 1;

always @(posedge pclk) begin
    if (hcycle) out_vcnt <= vcycle ? 0 : out_vcnt + 1;
end

endmodule
