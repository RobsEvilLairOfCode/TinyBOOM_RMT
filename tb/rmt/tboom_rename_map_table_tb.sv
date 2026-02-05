`timescale 1ns/1ps

module tboom_rename_map_table_tb;

  // Parameters
  parameter int unsigned DATA_WIDTH       = 5;
  parameter int unsigned MEMORY_WIDTH     = 32;
  parameter int unsigned CHECKPOINT_DEPTH = 8;

  // Clock / Reset
  logic clk;
  logic rst_n;

  // Inputs
  logic checkpoint;
  logic restore;
  logic [$clog2(CHECKPOINT_DEPTH)-1:0] checkpoint_restore_pos;

  logic i0_valid, i0_rd_valid, i0_rs1_valid, i0_rs2_valid;
  logic [DATA_WIDTH-1:0] i0_arch_rs1, i0_arch_rs2, i0_arch_rd;

  logic i1_valid, i1_rd_valid, i1_rs1_valid, i1_rs2_valid;
  logic [DATA_WIDTH-1:0] i1_arch_rs1, i1_arch_rs2, i1_arch_rd;

  logic write0_enable;
  logic [MEMORY_WIDTH-1:0] write0_pos;
  logic [DATA_WIDTH-1:0] write0_phys_reg;

  logic write1_enable;
  logic [MEMORY_WIDTH-1:0] write1_pos;
  logic [DATA_WIDTH-1:0] write1_phys_reg;

  // Outputs
  logic i0_freelist_request;
  logic i1_freelist_request;

  logic [DATA_WIDTH-1:0] i0_phys_rs1, i0_phys_rs2, i0_phys_stale;
  logic [DATA_WIDTH-1:0] i1_phys_rs1, i1_phys_rs2, i1_phys_stale;

  // Clock generator
  always #5 clk = ~clk;

  // DUT instantiation
  tboom_rename_map_table #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEMORY_WIDTH(MEMORY_WIDTH),
    .CHECKPOINT_DEPTH(CHECKPOINT_DEPTH)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .checkpoint(checkpoint),
    .restore(restore),
    .checkpoint_restore_pos(checkpoint_restore_pos),

    .i0_valid(i0_valid),
    .i0_rd_valid(i0_rd_valid),
    .i0_rs1_valid(i0_rs1_valid),
    .i0_rs2_valid(i0_rs2_valid),
    .i0_arch_rs1(i0_arch_rs1),
    .i0_arch_rs2(i0_arch_rs2),
    .i0_arch_rd(i0_arch_rd),

    .i1_valid(i1_valid),
    .i1_rd_valid(i1_rd_valid),
    .i1_rs1_valid(i1_rs1_valid),
    .i1_rs2_valid(i1_rs2_valid),
    .i1_arch_rs1(i1_arch_rs1),
    .i1_arch_rs2(i1_arch_rs2),
    .i1_arch_rd(i1_arch_rd),

    .write0_enable(write0_enable),
    .write0_pos(write0_pos),
    .write0_phys_reg(write0_phys_reg),

    .write1_enable(write1_enable),
    .write1_pos(write1_pos),
    .write1_phys_reg(write1_phys_reg),

    .i0_freelist_request(i0_freelist_request),
    .i1_freelist_request(i1_freelist_request),

    .i0_phys_rs1(i0_phys_rs1),
    .i0_phys_rs2(i0_phys_rs2),
    .i0_phys_stale(i0_phys_stale),

    .i1_phys_rs1(i1_phys_rs1),
    .i1_phys_rs2(i1_phys_rs2),
    .i1_phys_stale(i1_phys_stale)
  );

  // Test sequence
  initial begin
    // Init
    clk = 0;
    rst_n = 0;

    checkpoint = 0;
    restore = 0;
    checkpoint_restore_pos = 0;

    i0_valid = 0;
    i1_valid = 0;

    write0_enable = 0;
    write1_enable = 0;

    // Reset
    repeat (2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);

    // ----------------------------
    // TEST 1: Basic mapping read
    // ----------------------------
    i0_valid     = 1;
    i0_rs1_valid = 1;
    i0_rs2_valid = 1;
    i0_rd_valid =  1;
    i0_arch_rs1  = 5'd1;
    i0_arch_rs2  = 5'd2;
    i0_arch_rd  = 5'd3;

    i1_valid     = 1;
    i1_rs1_valid = 1;
    i1_rs2_valid = 1;
    i1_rd_valid = 1;
    i1_arch_rs1  = 5'd4;
    i1_arch_rs2  = 5'd5;
    i1_arch_rd  = 5'd6;

    // default mapping should return arch index (assuming initialized)
    @(posedge clk);
    $display("i0_phys_rs1=%0d i0_phys_rs2=%0d", i0_phys_rs1, i0_phys_rs2);
    $display("i1_phys_rs1=%0d i1_phys_rs2=%0d", i1_phys_rs1, i1_phys_rs2);

    // ----------------------------
    // TEST 2: Write updates
    // ----------------------------
    write0_enable = 1;
    write0_pos    = 5'd1;
    write0_phys_reg = 5'd31;

    write1_enable = 1;
    write1_pos    = 5'd2;
    write1_phys_reg = 5'd30;

    @(posedge clk);
    write0_enable = 0;
    write1_enable = 0;

    // Check mapping after write
    @(posedge clk);
    i0_arch_rs1 = 5'd1;
    i0_arch_rs2 = 5'd2;
    @(posedge clk);
    if (i0_phys_rs1 !== 5'd31 || i0_phys_rs2 !== 5'd30)
      $fatal("Write update failed!");

    // ----------------------------
    // TEST 3: Bubble behavior
    // ----------------------------
    i0_valid = 0;
    i1_valid = 0;

    @(posedge clk);
    if (i0_freelist_request !== 0 || i1_freelist_request !== 0)
      $fatal("Bubble should not request freelist!");

    // ----------------------------
    // TEST 4: Checkpoint + restore
    // ----------------------------
    checkpoint = 1;
    checkpoint_restore_pos = 3;
    @(posedge clk);
    checkpoint = 0;

    // change mapping after checkpoint
    write0_enable = 1;
    write0_pos    = 5'd1;
    write0_phys_reg = 5'd15;
    @(posedge clk);
    write0_enable = 0;

    // restore
    restore = 1;
    checkpoint_restore_pos = 3;
    @(posedge clk);
    restore = 0;

    // verify mapping restored
    i0_valid = 1;
    i0_rs1_valid = 1;
    i0_arch_rs1 = 5'd1;
    @(posedge clk);

    if (i0_phys_rs1 !== 5'd31)
      $fatal("Checkpoint restore failed!");

    $display("All tests passed.");
    $finish;
  end

  initial begin
    $dumpfile("the_waveform.vcd");
    $dumpvars(0,tboom_rename_map_table_tb);
  end

endmodule
