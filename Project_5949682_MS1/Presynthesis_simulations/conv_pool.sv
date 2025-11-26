//------------------------------------------------------------------------------
// EE 5324  Project 3  Convolution + 2×2 Max-Pooling Engine  (Milestone-1)
// Clean Verilog-2001 RTL  synthesizable and VCS-friendly
//------------------------------------------------------------------------------
`timescale 1ns/1ps
module conv_pool (
    input           clk,
    input           rst,            // synchronous, ACTIVE-HIGH

    // image block & kernels ------------------------------------------------
    input  [127:0]  image_4x4,
    input  [71:0]   conv_kernel_0,
    input  [71:0]   conv_kernel_1,
    input  [71:0]   conv_kernel_2,
    input  [1:0]    shift,          // extra ÷1/2/4/8 requested by test-bench

    // convolution+pool outputs --------------------------------------------
    output [7:0]    y_0,
    output [7:0]    y_1,
    output [7:0]    y_2,

    // handshake to external memories --------------------------------------
    output          input_re,
    output [15:0]   input_addr,

    output          output_we_0,
    output [15:0]   output_addr_0,
    output          output_we_1,
    output [15:0]   output_addr_1,
    output          output_we_2,
    output [15:0]   output_addr_2
);

// number of 4×4 blocks in 512×512 image
localparam int MAX_BLKS = 512*512/4; // 65536 blocks

//------------------------------------------------------------------------------
// Stage-0: Request generation
//------------------------------------------------------------------------------
reg [16:0] blk_cnt_r;
reg        req_vld_r;
reg [15:0] req_addr_r;

always_ff @(posedge clk) begin
    if (rst) begin
        blk_cnt_r  <= 17'd0;
        req_vld_r  <= 1'b0;
        req_addr_r <= 16'd0;
    end else begin
        if (req_vld_r)
            req_vld_r <= 1'b0;
        else if (blk_cnt_r < MAX_BLKS) begin
            req_vld_r  <= 1'b1;
            req_addr_r <= blk_cnt_r[15:0];
            blk_cnt_r  <= blk_cnt_r + 17'd1;
        end
    end
end

assign input_re   = req_vld_r;
assign input_addr = req_addr_r;

//------------------------------------------------------------------------------
// Stage-0.5: Align request with returned data
//------------------------------------------------------------------------------
reg        req_vld_q;
reg [15:0] req_addr_q;
always_ff @(posedge clk) begin
    req_vld_q  <= req_vld_r;
    req_addr_q <= req_addr_r;
end

//------------------------------------------------------------------------------
// Stage-1: Capture 4×4 block
//------------------------------------------------------------------------------
reg        vld_s1;
reg [15:0] addr_s1;
reg [127:0] img_s1;
always_ff @(posedge clk) begin
    if (rst) begin
        vld_s1  <= 1'b0;
        addr_s1 <= 16'd0;
        img_s1  <= 128'd0;
    end else begin
        vld_s1  <= req_vld_q;
        addr_s1 <= req_addr_q;
        img_s1  <= image_4x4;
    end
end

//------------------------------------------------------------------------------
// Helper functions: unpack pixel and kernel coefficient
//------------------------------------------------------------------------------
function [7:0] px;
    input [127:0] img;
    input [1:0]   r, c;
    begin
        px = img[((r*4 + c) << 3) +: 8];
    end
endfunction

function signed [7:0] kc;
    input [71:0] ker;
    input [1:0]  r, c;
    begin
        kc = ker[((r*3 + c) << 3) +: 8];
    end
endfunction

//------------------------------------------------------------------------------
// Stage-2: Convolution + 2×2 max-pool
//------------------------------------------------------------------------------
function [7:0] conv_pool_kernel;
    input [127:0]       img;
    input signed [71:0] ker;
    input [1:0]         sh;
    reg signed [31:0] c0, c1, c2, c3;
    reg signed [23:0] mult;
    integer i, j;
    reg [7:0] u0, u1, u2, u3;
    reg [7:0] m01, m23;
    integer total_shift;
    begin
        c0 = 0; c1 = 0; c2 = 0; c3 = 0;
        for (i = 0; i < 3; i = i+1)
            for (j = 0; j < 3; j = j+1) begin
                mult = $signed({1'd0, px(img, i, j)}) * kc(ker, i, j);
                c0   = c0 + mult;
                mult = $signed({1'd0, px(img, i, j+1)}) * kc(ker, i, j);
                c1   = c1 + mult;
                mult = $signed({1'd0, px(img, i+1, j)}) * kc(ker, i, j);
                c2   = c2 + mult;
                mult = $signed({1'd0, px(img, i+1, j+1)}) * kc(ker, i, j);
                c3   = c3 + mult;
            end
        total_shift = sh + 3;  // remove fractional bits + apply shift
        c0 = c0 >>> total_shift; c1 = c1 >>> total_shift;
        c2 = c2 >>> total_shift; c3 = c3 >>> total_shift;
        c0 = (c0 < 0) ? 0 : (c0 > 255) ? 255 : c0;
        c1 = (c1 < 0) ? 0 : (c1 > 255) ? 255 : c1;
        c2 = (c2 < 0) ? 0 : (c2 > 255) ? 255 : c2;
        c3 = (c3 < 0) ? 0 : (c3 > 255) ? 255 : c3;
        u0 = c0[7:0]; u1 = c1[7:0]; u2 = c2[7:0]; u3 = c3[7:0];
        m01 = (u0 > u1) ? u0 : u1;
        m23 = (u2 > u3) ? u2 : u3;
        conv_pool_kernel = (m01 > m23) ? m01 : m23;
    end
endfunction

reg        vld_s2;
reg [15:0] addr_s2;
reg [7:0]  y0_reg, y1_reg, y2_reg;
always_ff @(posedge clk) begin
    if (rst) begin
        vld_s2  <= 1'b0;
        addr_s2 <= 16'd0;
        y0_reg  <= 8'd0;
        y1_reg  <= 8'd0;
        y2_reg  <= 8'd0;
    end else begin
        vld_s2  <= vld_s1;
        addr_s2 <= addr_s1;
        if (vld_s1) begin
            y0_reg <= conv_pool_kernel(img_s1, conv_kernel_0, shift);
            y1_reg <= conv_pool_kernel(img_s1, conv_kernel_1, shift);
            y2_reg <= conv_pool_kernel(img_s1, conv_kernel_2, shift);
        end
    end
end

//------------------------------------------------------------------------------
// Stage-3: Handshake & outputs
//------------------------------------------------------------------------------
assign y_0          = y0_reg;
assign y_1          = y1_reg;
assign y_2          = y2_reg;

assign output_we_0  = vld_s2;
assign output_we_1  = vld_s2;
assign output_we_2  = vld_s2;

assign output_addr_0 = addr_s2;
assign output_addr_1 = addr_s2;
assign output_addr_2 = addr_s2;

endmodule

