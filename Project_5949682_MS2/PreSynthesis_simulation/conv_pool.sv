`timescale 1ns/1ps
module conv_pool (
    input  logic        clk,
    input  logic        rst,                // synchronous, ACTIVE-HIGH

    // image block & kernels
    input  logic [127:0] image_4x4,
    input  logic  [71:0] conv_kernel_0,
    input  logic  [71:0] conv_kernel_1,
    input  logic  [71:0] conv_kernel_2,
    input  logic [1:0]   shift,              // extra ÷1/2/4/8

    // convolution + pool outputs
    output logic [7:0]  y_0,
    output logic [7:0]  y_1,
    output logic [7:0]  y_2,

    // handshake to external memories
    output logic        input_re,
    output logic [15:0] input_addr,
    output logic        output_we_0,
    output logic [15:0] output_addr_0,
    output logic        output_we_1,
    output logic [15:0] output_addr_1,
    output logic        output_we_2,
    output logic [15:0] output_addr_2
);

// number of 4×4 blocks in 512×512 image
localparam int MAX_BLKS = 512*512/4; // 65536

//------------------------------------------------------------------------------
// Stage 0: Generate one-cycle requests
//------------------------------------------------------------------------------
reg [16:0] block_counter;
reg        req_valid;
reg [15:0] req_address;
always_ff @(posedge clk) begin
    if (rst) begin
        block_counter <= 17'd0;
        req_valid     <= 1'b0;
        req_address   <= 16'd0;
    end else if (block_counter < MAX_BLKS) begin
        req_valid     <= 1'b1;
        req_address   <= block_counter[15:0];
        block_counter <= block_counter + 17'd1;
    end else begin
        req_valid <= 1'b0;
    end
end
assign input_re   = req_valid;
assign input_addr = req_address;

//------------------------------------------------------------------------------
// Stage 0.5: Align request with memory return
//------------------------------------------------------------------------------
reg        req_valid_q;
reg [15:0] req_address_q;
always_ff @(posedge clk) begin
    if (rst) begin
        req_valid_q   <= 1'b0;
        req_address_q <= 16'd0;
    end else begin
        req_valid_q   <= req_valid;
        req_address_q <= req_address;
        if (req_valid)
            $display("Stage0.5: Time=%0t req_valid_q=%b req_address_q=%0d", $time, req_valid_q, req_address_q);
    end
end

//------------------------------------------------------------------------------
// Stage 1: Latch tile and aligned address
//------------------------------------------------------------------------------
reg        lat_valid;
reg [15:0] lat_address;
reg [127:0] lat_tile;
always_ff @(posedge clk) begin
    if (rst) begin
        lat_valid   <= 1'b0;
        lat_address <= 16'd0;
        lat_tile    <= 128'd0;
    end else begin
        lat_valid   <= req_valid_q;
        lat_address <= req_address_q;
        lat_tile    <= image_4x4;
        if (req_valid_q)
            $display("Stage1: Time=%0t lat_valid=%b lat_address=%0d lat_tile=%h", $time, lat_valid, lat_address, lat_tile);
    end
end

//------------------------------------------------------------------------------
// Stage 2: Convolution compute for 4 windows per kernel
//------------------------------------------------------------------------------
reg        conv_valid;
reg [15:0] conv_address;
logic [7:0] c0_00, c0_01, c0_10, c0_11;
logic [7:0] c1_00, c1_01, c1_10, c1_11;
logic [7:0] c2_00, c2_01, c2_10, c2_11;
always_ff @(posedge clk) begin
    if (rst) begin
        conv_valid <= 1'b0;
    end else begin
        conv_valid   <= lat_valid;
        conv_address <= lat_address;
        if (lat_valid) begin
            // Kernel 0
            c0_00 <= conv_single(lat_tile, conv_kernel_0, shift, 2'd0, 2'd0);
            c0_01 <= conv_single(lat_tile, conv_kernel_0, shift, 2'd0, 2'd1);
            c0_10 <= conv_single(lat_tile, conv_kernel_0, shift, 2'd1, 2'd0);
            c0_11 <= conv_single(lat_tile, conv_kernel_0, shift, 2'd1, 2'd1);
            // Kernel 1
            c1_00 <= conv_single(lat_tile, conv_kernel_1, shift, 2'd0, 2'd0);
            c1_01 <= conv_single(lat_tile, conv_kernel_1, shift, 2'd0, 2'd1);
            c1_10 <= conv_single(lat_tile, conv_kernel_1, shift, 2'd1, 2'd0);
            c1_11 <= conv_single(lat_tile, conv_kernel_1, shift, 2'd1, 2'd1);
            // Kernel 2
            c2_00 <= conv_single(lat_tile, conv_kernel_2, shift, 2'd0, 2'd0);
            c2_01 <= conv_single(lat_tile, conv_kernel_2, shift, 2'd0, 2'd1);
            c2_10 <= conv_single(lat_tile, conv_kernel_2, shift, 2'd1, 2'd0);
            c2_11 <= conv_single(lat_tile, conv_kernel_2, shift, 2'd1, 2'd1);
            $display("Stage2: Time=%0t conv_valid=%b conv_address=%0d k0=(%0h,%0h,%0h,%0h)", $time, conv_valid, conv_address, c0_00, c0_01, c0_10, c0_11);
        end
    end
end

//------------------------------------------------------------------------------
// Stage 3: Max-pooling compute for each kernel
//------------------------------------------------------------------------------
reg        pool_valid;
reg [15:0] pool_address;
reg [7:0]  pool_y0, pool_y1, pool_y2;
always_ff @(posedge clk) begin
    if (rst) begin
        pool_valid <= 1'b0;
    end else begin
        pool_valid   <= conv_valid;
        pool_address <= conv_address;
        if (conv_valid) begin
            pool_y0 <= max4(c0_00, c0_01, c0_10, c0_11);
            pool_y1 <= max4(c1_00, c1_01, c1_10, c1_11);
            pool_y2 <= max4(c2_00, c2_01, c2_10, c2_11);
            $display("Stage3: Time=%0t pool_valid=%b pool_address=%0d pool_y=(%0h,%0h,%0h)", $time, pool_valid, pool_address, pool_y0, pool_y1, pool_y2);
        end
    end
end

//------------------------------------------------------------------------------
// Stage 4: Drive outputs and final display
//------------------------------------------------------------------------------
assign y_0       = pool_y0;
assign y_1       = pool_y1;
assign y_2       = pool_y2;
assign output_we_0 = pool_valid;
assign output_we_1 = pool_valid;
assign output_we_2 = pool_valid;
assign output_addr_0 = pool_address;
assign output_addr_1 = pool_address;
assign output_addr_2 = pool_address;
always_ff @(posedge clk) begin
    if (!rst && pool_valid)
        $display("Stage4: Time=%0t output_we=%b output_addr=%0d y=(%0h,%0h,%0h)", $time, pool_valid, pool_address, y_0, y_1, y_2);
end

//------------------------------------------------------------------------------
// Function: conv_single (3×3 convolution + shift + clamp)
//------------------------------------------------------------------------------
function automatic logic [7:0] conv_single(
    input logic [127:0] img,
    input logic [71:0]  ker,
    input logic [1:0]   sh,
    input logic [1:0]   rOff,
    input logic [1:0]   cOff
);
    logic signed [31:0] sum;
    logic signed [16:0] prod;
    integer i, j, total_shift;
    logic signed [31:0] shifted;
    begin
        sum = 0;
        for (i = 0; i < 3; i = i + 1) begin
            for (j = 0; j < 3; j = j + 1) begin
                logic [7:0] pix = img[((i+rOff)*4 + (j+cOff))*8 +: 8];
                prod = $signed({1'b0, pix}) * $signed(kc(ker, i, j));
                sum += prod;
            end
        end
        total_shift = sh + 3;
        shifted = sum >>> total_shift;
        if (shifted < 0) shifted = 0;
        else if (shifted > 255) shifted = 255;
        conv_single = shifted[7:0];
    end
endfunction

//------------------------------------------------------------------------------
// Function: max4 (2×2 max-pool)
//------------------------------------------------------------------------------
function logic [7:0] max4(
    input logic [7:0] a, b, c, d
);
    logic [7:0] m1;
    begin
        m1 = (a > b) ? a : b;
        max4 = (c > d) ? ((c > m1) ? c : m1) : ((d > m1) ? d : m1);
    end
endfunction

//------------------------------------------------------------------------------
// Function: kc (unpack 3×3 kernel coefficient)
//------------------------------------------------------------------------------
function signed [7:0] kc(
    input logic [71:0] ker,
    input logic [1:0]  r,
    input logic [1:0]  c
);
    kc = ker[((r*3 + c) << 3) +: 8];
endfunction

endmodule

