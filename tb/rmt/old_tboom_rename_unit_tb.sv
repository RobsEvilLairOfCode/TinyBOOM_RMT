`timescale 1ns/1ps

module old_tboom_rename_unit_tb;

    // -----------------------------
    // Parameters
    // -----------------------------
    localparam int REG_ARCH_ADDR_WIDTH = 5;
    localparam int REG_PHYS_ADDR_WIDTH = 6;
    localparam int MEMORY_WIDTH        = 32;
    localparam int CHECKPOINT_DEPTH    = 8;

    // -----------------------------
    // Clock / Reset
    // -----------------------------
    logic clk;
    logic rst_n;

    always #5 clk = ~clk;

    // -----------------------------
    // DUT inputs
    // -----------------------------
    logic checkpoint;
    logic restore;
    logic [$clog2(CHECKPOINT_DEPTH)-1:0] checkpoint_restore_pos;

    logic i0_valid;
    logic i0_rd_valid;
    logic i0_rs1_valid;
    logic i0_rs2_valid;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i0_arch_rs1;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i0_arch_rs2;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i0_arch_rd;

    logic i1_valid;
    logic i1_rd_valid;
    logic i1_rs1_valid;
    logic i1_rs2_valid;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i1_arch_rs1;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i1_arch_rs2;
    logic [REG_ARCH_ADDR_WIDTH-1:0] i1_arch_rd;

    logic i0_commit_valid;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_commit_pdst_old;

    logic i1_commit_valid;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_commit_pdst_old;

    // -----------------------------
    // DUT outputs
    // -----------------------------
    logic stall;

    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_phys_rd;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_phys_rs1;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_phys_rs2;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_phys_stale;

    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_phys_rd;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_phys_rs1;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_phys_rs2;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_phys_stale;


    // -----------------------------
    // DUT
    // -----------------------------

    logic [REG_PHYS_ADDR_WIDTH-1:0] arch_map [0:(1<<REG_ARCH_ADDR_WIDTH)-1];



    tboom_rename_unit #(
        .REG_ARCH_ADDR_WIDTH(REG_ARCH_ADDR_WIDTH),
        .REG_PHYS_ADDR_WIDTH(REG_PHYS_ADDR_WIDTH),
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

        .i0_commit_valid(i0_commit_valid),
        .i0_commit_pdst_old(i0_commit_pdst_old),

        .i1_commit_valid(i1_commit_valid),
        .i1_commit_pdst_old(i1_commit_pdst_old),

        .stall(stall),

        .i0_phys_rd(i0_phys_rd),
        .i0_phys_rs1(i0_phys_rs1),
        .i0_phys_rs2(i0_phys_rs2),
        .i0_phys_stale(i0_phys_stale),

        .i1_phys_rd(i1_phys_rd),
        .i1_phys_rs1(i1_phys_rs1),
        .i1_phys_rs2(i1_phys_rs2),
        .i1_phys_stale(i1_phys_stale)
    );

    // -----------------------------
    // Test sequence
    // -----------------------------
    initial begin
        clk = 0;
        rst_n = 0;

        checkpoint = 0;
        restore = 0;
        checkpoint_restore_pos = '0;

        i0_valid = 0;
        i1_valid = 0;
        i0_rd_valid = 0;
        i1_rd_valid = 0;
        i0_rs1_valid = 0;
        i0_rs2_valid = 0;
        i1_rs1_valid = 0;
        i1_rs2_valid = 0;

        i0_arch_rs1 = '0;
        i0_arch_rs2 = '0;
        i0_arch_rd  = '0;
        i1_arch_rs1 = '0;
        i1_arch_rs2 = '0;
        i1_arch_rd  = '0;

        i0_commit_valid = 0;
        i1_commit_valid = 0;
        i0_commit_pdst_old = '0;
        i1_commit_pdst_old = '0;

        // -----------------------------
        // Reset
        // -----------------------------
        repeat (5) @(posedge clk);
        rst_n = 1;

        $warning("=== RESET RELEASED ===");

        // -----------------------------
        // Test 1: Single instruction rename
        // -----------------------------
        @(posedge clk);
        i0_valid      = 1;
        i0_rd_valid   = 1;
        i0_rs1_valid  = 1;
        i0_rs2_valid  = 0;
        i0_arch_rs1   = 5'd1;
        i0_arch_rd    = 5'd2;

        @(posedge clk);
        i0_valid = 0;

        // -----------------------------
        // Test 2: Dual issue, RAW hazard
        // i1 reads i0 destination
        // -----------------------------
        @(posedge clk);
        i0_valid     = 1;
        i0_rd_valid  = 1;
        i0_arch_rd   = 5'd3;

        i1_valid     = 1;
        i1_rs1_valid = 1;
        i1_arch_rs1  = 5'd3; // RAW on i0

        @(posedge clk);
        i0_valid = 0;
        i1_valid = 0;

        // -----------------------------
        // Test 3: Commit frees registers
        // -----------------------------
        @(posedge clk);
        i0_commit_valid = 1;
        i0_commit_pdst_old = i0_phys_stale;

        @(posedge clk);
        i0_commit_valid = 0;

        // -----------------------------
        // End simulation
        // -----------------------------
        repeat (10) @(posedge clk);
        $warning("=== TEST COMPLETE ===");
        $finish;
    end




// -------------------------------------------------
// Basic invariants
// -------------------------------------------------
always @(posedge clk) begin
    #1;
    if (rst_n) begin
        // Physical register 0 must never be allocated
        if (i0_phys_rd == '0 && i0_valid && i0_rd_valid && !stall)
            $warning(
            "[TB] BAD RENAME I0: arch_rd=%0d phys_rd=%0d | valid=%0b rd_valid=%0b stall=%0b",
            i0_arch_rd,
            i0_phys_rd,
            i0_valid,
            i0_rd_valid,
            stall
            );


        if (i1_phys_rd == '0 && i1_valid && i1_rd_valid && !stall)
            $warning(
            "[TB] BAD RENAME I1: arch_rd=%0d phys_rd=%0d | valid=%0b rd_valid=%0b stall=%0b",
            i1_arch_rd,
            i1_phys_rd,
            i1_valid,
            i1_rd_valid,
            stall
            );

        // Stall must block rename side-effects
        if (stall) begin
            assert (i0_phys_rd == '0)
                else $error("[TB] i0_phys_rd changed during stall");

            assert (i1_phys_rd == '0)
                else $error("[TB] i1_phys_rd changed during stall");
        end
    end
end



// -------------------------------------------------
// RAW hazard check: i1 must see i0 destination
// -------------------------------------------------
always @(posedge clk) begin
    #1;
    if (rst_n && !stall) begin
        if (i0_valid && i0_rd_valid && i1_valid) begin
            // rs1 RAW
            if (i1_rs1_valid && (i1_arch_rs1 == i0_arch_rd)) begin
                assert (i1_phys_rs1 == i0_phys_rd)
                    else $warning("[TB][RAW] i1 rs1 did not bypass i0 rd");
            end

            // rs2 RAW
            if (i1_rs2_valid && (i1_arch_rs2 == i0_arch_rd)) begin
                assert (i1_phys_rs2 == i0_phys_rd)
                    else $warning("[TB][RAW] i1 rs2 did not bypass i0 rd");
            end
        end
    end
end

always @(posedge clk) begin
    #1;
    if (rst_n && !stall) begin
        if (i0_valid && i0_rs1_valid) begin
            assert (i0_phys_rs1 == arch_map[i0_arch_rs1])
                else $warning("[TB][MAP] i0 rs1 mismatch");
                
        end

        if (i1_valid && i1_rs1_valid) begin
            assert (i1_phys_rs1 == arch_map[i1_arch_rs1] ||
                    i1_phys_rs1 == i0_phys_rd) // allow RAW bypass
                else $warning("[TB][MAP] i1 rs1 mismatch");
                
        end
    end
end

always @(posedge clk) begin
    #1;
    if (rst_n) begin
        if (i0_commit_valid) begin
            assert (i0_commit_pdst_old != '0)
                else $warning("[TB][COMMIT] i0 committed phys reg 0");
        end

        if (i1_commit_valid) begin
            assert (i1_commit_pdst_old != '0)
                else $warning("[TB][COMMIT] i1 committed phys reg 0");
        end
    end
end


integer i;
always @(posedge clk) begin
    if (!rst_n) begin
        for (i = 0; i < (1<<REG_ARCH_ADDR_WIDTH); i++)
            arch_map[i] <= '0;
    end
end

always @(posedge clk) begin
    if (rst_n && !stall) begin
        if (i0_valid && i0_rd_valid)
            arch_map[i0_arch_rd] <= i0_phys_rd;

        if (i1_valid && i1_rd_valid)
            arch_map[i1_arch_rd] <= i1_phys_rd;
    end
end



initial begin
    $dumpfile("the_waveform.vcd");
    $dumpvars(0, tboom_rename_unit_tb);
  end


endmodule
