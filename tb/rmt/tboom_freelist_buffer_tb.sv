`timescale 1ns/1ps

module tboom_freelist_buffer_tb;

  localparam int DATA_WIDTH   = 32;
  localparam int MEMORY_WIDTH = 8;

  logic [DATA_WIDTH-1:0] i0_data_in;
  logic                  i0_read_enable;
  logic                  i0_write_enable;

  logic [DATA_WIDTH-1:0] i1_data_in;
  logic                  i1_read_enable;
  logic                  i1_write_enable;

  logic clk;
  logic rst_n;

  logic checkpoint;
  logic restore;

  logic [DATA_WIDTH-1:0] i0_data_out;
  logic [DATA_WIDTH-1:0] i1_data_out;

  logic full;
  logic one_remaining;
  logic empty;
  logic invalid_read;
  logic invalid_write;

  tboom_freelist_buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .MEMORY_WIDTH(MEMORY_WIDTH)
  ) dut (
    .*   // safe here since names match
  );

  // clock
  always #5 clk = ~clk;

  // reference FIFO model
  logic [DATA_WIDTH-1:0] ref_mem [0:MEMORY_WIDTH-1];
  int head, tail, count;
  int checkpoint_head;

  task tb_check(input bit cond, input string msg);
    if (!cond) begin
      $display("FAIL: %s", msg);
      $fatal;
    end
  endtask

  task clear_ctrl;
    i0_read_enable  = 0;
    i1_read_enable  = 0;
    i0_write_enable = 0;
    i1_write_enable = 0;
    i0_data_in      = '0;
    i1_data_in      = '0;
    checkpoint      = 0;
    restore         = 0;
  endtask

  initial begin
    clk = 0;
    rst_n = 0;
    clear_ctrl();

    head = 0;
    tail = 0;
    count = 0;

    @(posedge clk);
    rst_n = 1;

    // -------------------------------
    // Fill freelist (dual writes)
    // -------------------------------
    repeat (MEMORY_WIDTH/2) begin
      i0_write_enable = 1;
      i1_write_enable = 1;
      i0_data_in = count + 100;
      i1_data_in = count + 101;

      ref_mem[tail] = i0_data_in; tail++; count++;
      ref_mem[tail] = i1_data_in; tail++; count++;

      @(posedge clk);
      clear_ctrl();
    end

    tb_check(full, "full after filling");

    // -------------------------------
    // Take checkpoint
    // -------------------------------
    checkpoint = 1;
    checkpoint_head = head;
    @(posedge clk);
    clear_ctrl();

    // -------------------------------
    // Consume two entries
    // -------------------------------
    i0_read_enable = 1;
    i1_read_enable = 1;
    @(posedge clk);

    tb_check(i0_data_out == ref_mem[head], "read after checkpoint i0");
    head++; count--;
    tb_check(i1_data_out == ref_mem[head], "read after checkpoint i1");
    head++; count--;

    clear_ctrl();

    // -------------------------------
    // Restore (flush)
    // -------------------------------
    restore = 1;
    head = checkpoint_head;
    count += 2;
    @(posedge clk);
    clear_ctrl();

    // -------------------------------
    // Read again — should match pre-flush
    // -------------------------------
    i0_read_enable = 1;
    i1_read_enable = 1;
    @(posedge clk);

    tb_check(i0_data_out == ref_mem[head], "restore i0 matches");
    head++; count--;
    tb_check(i1_data_out == ref_mem[head], "restore i1 matches");
    head++; count--;

    clear_ctrl();

    // -------------------------------
    // Drain to one remaining
    // -------------------------------
    while (count > 1) begin
      i0_read_enable = 1;
      @(posedge clk);
      head++; count--;
      clear_ctrl();
    end

    tb_check(one_remaining, "one remaining flag");

    // -------------------------------
    // Illegal dual read
    // -------------------------------
    i0_read_enable = 1;
    i1_read_enable = 1;
    @(posedge clk);

    tb_check(invalid_read, "invalid dual read");
    clear_ctrl();

    // -------------------------------
    // Final read
    // -------------------------------
    i0_read_enable = 1;
    @(posedge clk);
    count--;

    tb_check(empty, "empty at end");

    $display("ALL TESTS PASSED");
    $finish;
  end

  initial begin
    $dumpfile("the_waveform.vcd");
    $dumpvars(0,tboom_freelist_buffer_tb);
  end

endmodule
