`timescale 1ns/1ps

module tboom_freelist_tb;

  localparam int REG_PHYS_ADDR_WIDTH = 6;
  localparam int NUM_PHYS_REGISTERS  = 64;

  logic clk;
  logic rst_n;

  logic checkpoint;
  logic flush;

  logic i0_req_valid;
  logic i1_req_valid;

  logic i0_commit_valid;
  logic [REG_PHYS_ADDR_WIDTH-1:0] i0_commit_pdst_old;

  logic i1_commit_valid;
  logic [REG_PHYS_ADDR_WIDTH-1:0] i1_commit_pdst_old;

  logic i0_pdst_valid;
  logic i1_pdst_valid;

  logic [REG_PHYS_ADDR_WIDTH-1:0] i0_pdst;
  logic [REG_PHYS_ADDR_WIDTH-1:0] i1_pdst;

  logic freelist_empty;
  logic freelist_one_remaining;

  // DUT
  tboom_freelist #(
    .REG_PHYS_ADDR_WIDTH(REG_PHYS_ADDR_WIDTH),
    .NUM_PHYS_REGISTERS(NUM_PHYS_REGISTERS)
  ) dut (
    .*
  );

  // Clock
  always #5 clk = ~clk;

  // Simple reference model
  int unsigned free_head;
  int unsigned checkpoint_head;

  task tb_check(input bit cond, input string msg);
    if (!cond) begin
      $display("FAIL: %s", msg);
      $fatal;
    end
  endtask

  task clear_inputs;
    checkpoint         = 0;
    flush              = 0;
    i0_req_valid       = 0;
    i1_req_valid       = 0;
    i0_commit_valid    = 0;
    i1_commit_valid    = 0;
    i0_commit_pdst_old = '0;
    i1_commit_pdst_old = '0;
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    clear_inputs();

    // Architectural regs assumed p0–p31
    free_head = 32;

    @(posedge clk);
    @(posedge clk);
    rst_n = 1;

    // --------------------------------------
    // Dual allocation
    // --------------------------------------
    i0_req_valid = 1;
    i1_req_valid = 1;
    @(posedge clk);

    tb_check(i0_pdst_valid, "i0 allocation valid");
    tb_check(i1_pdst_valid, "i1 allocation valid");
    tb_check(i0_pdst == free_head, "i0 pdst correct");
    tb_check(i1_pdst == free_head + 1, "i1 pdst correct");

    free_head += 2;
    clear_inputs();

    // --------------------------------------
    // Take checkpoint
    // --------------------------------------
    checkpoint = 1;
    checkpoint_head = free_head;
    @(posedge clk);
    clear_inputs();

    // --------------------------------------
    // Speculative allocations
    // --------------------------------------
    i0_req_valid = 1;
    i1_req_valid = 1;
    @(posedge clk);

    tb_check(i0_pdst == free_head, "spec i0 pdst");
    tb_check(i1_pdst == free_head + 1, "spec i1 pdst");

    free_head += 2;
    clear_inputs();

    // --------------------------------------
    // Flush (rollback speculative)
    // --------------------------------------
    flush = 1;
    free_head = checkpoint_head;
    @(posedge clk);
    clear_inputs();

    // --------------------------------------
    // Re-allocate after flush
    // --------------------------------------
    i0_req_valid = 1;
    i1_req_valid = 1;
    @(posedge clk);

    tb_check(i0_pdst == free_head, "post-flush i0 pdst");
    tb_check(i1_pdst == free_head + 1, "post-flush i1 pdst");

    free_head += 2;
    clear_inputs();

    // --------------------------------------
    // Commit frees
    // --------------------------------------
    i0_commit_valid    = 1;
    i0_commit_pdst_old = 6'd5;
    i1_commit_valid    = 1;
    i1_commit_pdst_old = 6'd6;
    @(posedge clk);
    clear_inputs();

    // --------------------------------------
    // Drain freelist to one remaining
    // --------------------------------------
    while (!freelist_one_remaining) begin
      i0_req_valid = 1;
      @(posedge clk);
      clear_inputs();
    end

    tb_check(freelist_one_remaining, "one remaining asserted");

    // --------------------------------------
    // Final allocation
    // --------------------------------------
    i0_req_valid = 1;
    @(posedge clk);
    clear_inputs();

    tb_check(freelist_empty, "freelist empty");

    $display("ALL FREELIST TESTS PASSED");
    $finish;
  end

  initial begin
    $dumpfile("freelist.vcd");
    $dumpvars(0, tboom_freelist_tb);
  end

endmodule
