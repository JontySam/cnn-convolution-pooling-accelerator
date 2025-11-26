`timescale 1ps/1ps

module tb_conv_pool;
  //--------------------------------------------------------------
  // Parameters
  //--------------------------------------------------------------
  localparam CLK_PERIOD   = 550;            // 125 MHz
  localparam RUN_TIME_PS  = 550*(65_536+6);    // long enough for 65 536 blocks
  localparam MAX_BLKS     = 512*512/4;   // 65 536

  //--------------------------------------------------------------
  // Memories
  //--------------------------------------------------------------
  logic [127:0] image    [0:MAX_BLKS-1];
  logic  [71:0] filter_0, filter_1, filter_2;
  logic   [7:0] golden0 [0:MAX_BLKS-1];
  logic   [7:0] golden1 [0:MAX_BLKS-1];
  logic   [7:0] golden2 [0:MAX_BLKS-1];
  logic   [7:0] res0    [0:MAX_BLKS-1];
  logic   [7:0] res1    [0:MAX_BLKS-1];
  logic   [7:0] res2    [0:MAX_BLKS-1];

  //--------------------------------------------------------------
  // DUT signals
  //--------------------------------------------------------------
  logic         clk;
  logic         rst_n;
  logic [127:0] dut_image;
  logic  [71:0] dut_kernel_0, dut_kernel_1, dut_kernel_2;
  logic   [1:0] dut_shift;
  logic         dut_input_re;
  logic  [15:0] dut_input_addr;
  logic         dut_we0, dut_we1, dut_we2;
  logic  [15:0] dut_addr0, dut_addr1, dut_addr2;
  logic   [7:0] dut_y0, dut_y1, dut_y2;

  //--------------------------------------------------------------
  // DUT instance
  //--------------------------------------------------------------
  conv_pool dut (
    .clk           (clk),
    .rst           (~rst_n),         // active-HIGH rst in RTL
    .image_4x4     (dut_image),
    .conv_kernel_0 (dut_kernel_0),
    .conv_kernel_1 (dut_kernel_1),
    .conv_kernel_2 (dut_kernel_2),
    .shift         (dut_shift),
    .input_re      (dut_input_re),
    .input_addr    (dut_input_addr),
    .output_we_0   (dut_we0),
    .output_addr_0 (dut_addr0),
    .output_we_1   (dut_we1),
    .output_addr_1 (dut_addr1),
    .output_we_2   (dut_we2),
    .output_addr_2 (dut_addr2),
    .y_0           (dut_y0),
    .y_1           (dut_y1),
    .y_2           (dut_y2)
  );

  //--------------------------------------------------------------
  // Clock generation
  //--------------------------------------------------------------
  initial clk = 0;
  always #(CLK_PERIOD/2) clk = ~clk;

  //--------------------------------------------------------------
  // Reset task
  //--------------------------------------------------------------
  task apply_reset();
    begin
      rst_n = 0;
      repeat (2) @(posedge clk);
      rst_n = 1;
    end
  endtask

  //--------------------------------------------------------------
  // Load files task
  //--------------------------------------------------------------
  task load_files();
    integer fd, i;
    begin
      fd = $fopen("image.txt","r");
      for (i = 0; i < MAX_BLKS; i++) $fscanf(fd, "%h\n", image[i]);
      $fclose(fd);
      fd = $fopen("filter_0.txt","r"); $fscanf(fd, "%b\n", filter_0); $fclose(fd);
      fd = $fopen("filter_1.txt","r"); $fscanf(fd, "%b\n", filter_1); $fclose(fd);
      fd = $fopen("filter_2.txt","r"); $fscanf(fd, "%b\n", filter_2); $fclose(fd);
      fd = $fopen("golden_0.txt","r");
      for (i = 0; i < MAX_BLKS; i++) $fscanf(fd, "%h\n", golden0[i]);
      $fclose(fd);
      fd = $fopen("golden_1.txt","r");
      for (i = 0; i < MAX_BLKS; i++) $fscanf(fd, "%h\n", golden1[i]);
      $fclose(fd);
      fd = $fopen("golden_2.txt","r");
      for (i = 0; i < MAX_BLKS; i++) $fscanf(fd, "%h\n", golden2[i]);
      $fclose(fd);
    end
  endtask

  //--------------------------------------------------------------
  // Drive memory and kernels
  //--------------------------------------------------------------
  always @(posedge clk) begin
    if (dut_input_re)
      dut_image <= image[dut_input_addr];
    dut_kernel_0 <= filter_0;
    dut_kernel_1 <= filter_1;
    dut_kernel_2 <= filter_2;
    dut_shift    <= 2'b00;
  end

  //--------------------------------------------------------------
  // Capture results
  //--------------------------------------------------------------
  initial begin
    for (int i = 0; i < MAX_BLKS; i++) begin
      res0[i] = 0; res1[i] = 0; res2[i] = 0;
    end
  end
  always @(posedge clk) begin
    if (dut_we0) res0[dut_addr0] <= dut_y0;
    if (dut_we1) res1[dut_addr1] <= dut_y1;
    if (dut_we2) res2[dut_addr2] <= dut_y2;
  end

  //--------------------------------------------------------------
  // Compare, print, and dump task
  //--------------------------------------------------------------
  task compare_and_dump();
    integer fd_res0, fd_cmp0, fd_cmp1, fd_cmp2, i;
    begin
      // Dump result for kernel0
      fd_res0 = $fopen("res0.txt","w");
      for (i = 0; i < MAX_BLKS; i++) $fwrite(fd_res0, "%h\n", res0[i]);
      $fclose(fd_res0);

      // Compare and write comparisons for each kernel
      fd_cmp0 = $fopen("compare_0.txt","w");
      fd_cmp1 = $fopen("compare_1.txt","w");
      fd_cmp2 = $fopen("compare_2.txt","w");
      for (i = 0; i < MAX_BLKS; i++) begin
        // Console print
        $display("Kernel0 Block %0d: res=%h, exp=%h", i, res0[i], golden0[i]);
        $display("Kernel1 Block %0d: res=%h, exp=%h", i, res1[i], golden1[i]);
        $display("Kernel2 Block %0d: res=%h, exp=%h", i, res2[i], golden2[i]);
        // File write
        $fwrite(fd_cmp0, "Block %0d: res=%h, exp=%h\n", i, res0[i], golden0[i]);
        $fwrite(fd_cmp1, "Block %0d: res=%h, exp=%h\n", i, res1[i], golden1[i]);
        $fwrite(fd_cmp2, "Block %0d: res=%h, exp=%h\n", i, res2[i], golden2[i]);
        // Check mismatches
        if (res0[i] !== golden0[i]) begin
          $display("FAILED kernel0 at block %0d", i);
          $finish;
        end
        if (res1[i] !== golden1[i]) begin
          $display("FAILED kernel1 at block %0d", i);
          $finish;
        end
        if (res2[i] !== golden2[i]) begin
          $display("FAILED kernel2 at block %0d", i);
          $finish;
        end
      end
      $fclose(fd_cmp0);
      $fclose(fd_cmp1);
      $fclose(fd_cmp2);
      $display("All blocks passed for all kernels!");
    end
  endtask



  //--------------------------------------------------------------
  // VCD dump
  //--------------------------------------------------------------
  initial begin
    $dumpfile("tb_conv_pool.vcd");
    $dumpvars(0, tb_conv_pool);
  end

  //--------------------------------------------------------------
  // Main stimulus
  //--------------------------------------------------------------
  initial begin
    load_files();
    apply_reset();
    #RUN_TIME_PS;
    compare_and_dump();
    $finish;
  end

endmodule

