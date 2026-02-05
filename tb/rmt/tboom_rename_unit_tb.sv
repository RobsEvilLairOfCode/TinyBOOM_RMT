`timescale 1ns/1ps

module tboom_rename_unit_tb;

    // Parameters
    localparam int REG_ARCH_ADDR_WIDTH = 5;
    localparam int REG_PHYS_ADDR_WIDTH = 6;
    localparam int MEMORY_WIDTH        = 32; //32 positions in the Freelist Buffer
    localparam int CHECKPOINT_DEPTH    = 8;
    localparam logic TRUE = 1;
    localparam logic FALSE = 0;

    // -----------------------------
    // Clock / Reset
    // -----------------------------
    logic clk;
    logic rst_n;

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

    initial begin
        test_checkpoint();
        $finish();
    end
    
    //Test 1
    task test_reset_initalize();
        initialize();
        reset();

        cycle_clock();
    endtask

    //Test 2
    task test_simple_read();
        initialize();
        reset();

        set_i0_valid(1,2,3);
        cycle_clock();
    endtask

    //Test 3
    task test_independent_write();
        initialize();
        reset();

        set_i0_valid(1,2,3);
        set_i1_valid(4,5,6);
        cycle_clock();
    endtask

    //Test 4
    task test_WAW();
        initialize();
        reset();

        set_i0_valid(1,2,3);
        set_i1_valid(5,4,3);
        cycle_clock();
    endtask

    //Test 5
    task test_WAR();
        initialize();
        reset();

        set_i0_valid(3,2,1);
        set_i1_valid(5,4,3);
        cycle_clock();
    endtask

    //Test 6
    task test_RAW();
        initialize();
        reset();

        set_i0_valid(1,2,3);
        set_i1_valid(3,4,5);
        cycle_clock();
    endtask

    //Test 7
    task test_no_RD();
        initialize();
        reset();

        set_i0(TRUE,FALSE,TRUE,TRUE,1,2,30);//30 is some random incorrect number
        cycle_clock();
    endtask

    //Test 8
    task test_no_RS1_RS2();
        initialize();
        reset();

        set_i0(TRUE,TRUE,FALSE,FALSE,6,7,3);//only 3 is valid
        cycle_clock();
        set_i0(TRUE,TRUE,TRUE,FALSE,1,2,3);//only 3 is valid
        cycle_clock();
    endtask

    //Test 9
    task test_bubble();
        initialize();
        reset();

        set_i1_valid(1,2,3);
        cycle_clock();
        set_i0_valid(3,4,5);
        set_i1_valid(6,7,8);
        cycle_clock();
    endtask

    //Test 10/11
    task test_checkpoint();
        initialize();
        reset();
        set_i0_valid(1,2,3);
        set_i1_valid(4,5,6);
        cycle_clock();
        checkpoint_make(0);//checkpoint and save the last clock cycle (After 3->32 and 6->33  but before 9->34)
        set_i0_valid(7,8,9);//9 is overwritten to be 34
        set_i1_valid(10,11,12);
        cycle_clock();
        checkpoint_deassert();
        set_i0_valid(9,13,14);//show that 9 is 34
        set_i1_valid(15,16,17);
        cycle_clock();//Nothing can happen on a cycle that restores
        checkpoint_restore(0);
        cycle_clock();
        checkpoint_deassert();
        set_i0_valid(9,13,14);//show that 9 is 9, 34 was not used
        set_i1_valid(15,16,17);
        cycle_clock();
        cycle_clock();
    endtask

    task test_zero_reg();
        initialize();
        reset();
        //register zero should never be renamed
        set_i0(TRUE,TRUE,TRUE,TRUE,1,2,0); //where rd_valid is true
        set_i1(TRUE,FALSE,TRUE,TRUE,3,4,0);//where rd_valid is false
        cycle_clock();
        set_i0(TRUE,TRUE,TRUE,TRUE,5,6,0); //where rd_valid is true
        set_i1(TRUE,FALSE,TRUE,TRUE,7,8,0);//where rd_valid is false
        cycle_clock();
    endtask

    // Test: Multiple nested checkpoints and restores
    task test_multiple_checkpoints();
        logic [REG_PHYS_ADDR_WIDTH-1:0] pdst_cp0_i0;
        logic [REG_PHYS_ADDR_WIDTH-1:0] pdst_cp1_i0;
        logic [REG_PHYS_ADDR_WIDTH-1:0] pdst_cp2_i0;

        $display("==== TEST: MULTIPLE CHECKPOINTS ====");

        initialize();
        reset();

        // -----------------------------
        // Cycle 1: First allocation
        // -----------------------------
        set_i0_valid(1, 2, 3);   // rd = 3
        clear_i1();
        cycle_clock();

        pdst_cp0_i0 = i0_phys_rd;

        // Take checkpoint 0
        checkpoint_make(0);
        cycle_clock();
        checkpoint_deassert();

        $display("Checkpoint 0 taken: rd3 -> phys %0d", pdst_cp0_i0);

        // -----------------------------
        // Cycle 2: Second allocation
        // -----------------------------
        set_i0_valid(4, 5, 6);   // rd = 6
        clear_i1();
        cycle_clock();

        pdst_cp1_i0 = i0_phys_rd;

        // Take checkpoint 1
        checkpoint_make(1);
        cycle_clock();
        checkpoint_deassert();

        // -----------------------------
        // Cycle 3: Third allocation
        // -----------------------------
        set_i0_valid(7, 8, 9);   // rd = 9
        clear_i1();
        cycle_clock();

        pdst_cp2_i0 = i0_phys_rd;

        // Take checkpoint 2
        checkpoint_make(2);
        cycle_clock();
        checkpoint_deassert();

        // -----------------------------
        // Cycle 4: Speculative allocation
        // -----------------------------
        set_i0_valid(10, 11, 12); // rd = 12
        clear_i1();
        cycle_clock();

        // -----------------------------
        // Restore checkpoint 1
        // -----------------------------
        checkpoint_restore(1);
        cycle_clock();
        checkpoint_deassert();

        // Re-allocate rd = 9 (should match CP2 allocation again)
        set_i0_valid(7, 8, 9);
        clear_i1();
        cycle_clock();

        // -----------------------------
        // Restore checkpoint 0
        // -----------------------------
        checkpoint_restore(0);
        cycle_clock();
        checkpoint_deassert();

        // Re-allocate rd = 6 (should match CP1 allocation)
        set_i0_valid(4, 5, 6);
        clear_i1();
        cycle_clock();
    endtask


    task initialize();
        clk = 0;
        rst_n = 1;

        checkpoint = '0;
        restore = '0;
        checkpoint_restore_pos = '0;

        i0_valid = '0;
        i0_rd_valid = '0;
        i0_rs1_valid = '0;
        i0_rs2_valid = '0;
        i0_arch_rs1 = '0;
        i0_arch_rs2 = '0;
        i0_arch_rd = '0;

        i1_valid = '0;
        i1_rd_valid = '0;
        i1_rs1_valid = '0;
        i1_rs2_valid = '0;
        i1_arch_rs1 = '0;
        i1_arch_rs2 = '0;
        i1_arch_rd = '0;

        i0_commit_valid = '0;
        i0_commit_pdst_old = '0;

        i1_commit_valid = '0;
        i1_commit_pdst_old = '0;
    endtask

    task cycle_clock();
        #5;
        clk = 0;
        #5;
        clk = 1;

        $display(
        "[i0] valid=%0b rd_v=%0b rs1_v=%0b rs2_v=%0b | rs1=%0d rs2=%0d rd=%0d",
        i0_valid,
        i0_rd_valid,
        i0_rs1_valid,
        i0_rs2_valid,
        i0_phys_rs1,
        i0_phys_rs2,
        i0_phys_rd
        );
        $display(
        "[i1] valid=%0b rd_v=%0b rs1_v=%0b rs2_v=%0b | rs1=%0d rs2=%0d rd=%0d",
        i1_valid,
        i1_rd_valid,
        i1_rs1_valid,
        i1_rs2_valid,
        i1_phys_rs1,
        i1_phys_rs2,
        i1_phys_rd
        );
        $display("\n");
    endtask
    
    task reset();
        rst_n = 0;
        cycle_clock();
        cycle_clock();
        rst_n = 1;
        cycle_clock();
    endtask

    //instructions
    task set_i0(
    input logic        valid,
    input logic        rd_valid,
    input logic        rs1_valid,
    input logic        rs2_valid,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rd
    );
        i0_valid      = valid;
        i0_rd_valid   = rd_valid;
        i0_rs1_valid  = rs1_valid;
        i0_rs2_valid  = rs2_valid;
        i0_arch_rs1   = arch_rs1;
        i0_arch_rs2   = arch_rs2;
        i0_arch_rd    = arch_rd;
    endtask

    task set_i0_valid(
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rd
    );
        set_i0(TRUE,TRUE,TRUE,TRUE,arch_rs1,arch_rs2,arch_rd);
    endtask

    task set_i1(
    input logic        valid,
    input logic        rd_valid,
    input logic        rs1_valid,
    input logic        rs2_valid,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rd
    );
        i1_valid      = valid;
        i1_rd_valid   = rd_valid;
        i1_rs1_valid  = rs1_valid;
        i1_rs2_valid  = rs2_valid;
        i1_arch_rs1   = arch_rs1;
        i1_arch_rs2   = arch_rs2;
        i1_arch_rd    = arch_rd;
    endtask

    task set_i1_valid(
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH-1:0] arch_rd
    );
        set_i1(TRUE,TRUE,TRUE,TRUE,arch_rs1,arch_rs2,arch_rd);
    endtask

    task clear_i0();
        set_i0(FALSE,FALSE,FALSE,FALSE,'0,'0,'0);
    endtask

    task clear_i1();
        set_i1(FALSE,FALSE,FALSE,FALSE,'0,'0,'0);
    endtask

    task commit_i0_pdst(input logic [REG_PHYS_ADDR_WIDTH - 1:0] pdst_old);
        i0_commit_valid = '1;
        i0_commit_pdst_old = pdst_old;
    endtask 

    task commit_i1_pdst(input logic [REG_PHYS_ADDR_WIDTH - 1:0] pdst_old);
        i1_commit_valid = '1;
        i1_commit_pdst_old = pdst_old;
    endtask

    task decommit_i0_pdst();
        i0_commit_valid = '0;
        i0_commit_pdst_old = '0;
    endtask

    task decommit_i1_pdst();
        i1_commit_valid = '0;
        i1_commit_pdst_old = '0;
    endtask

    task checkpoint_make(
        input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] checkpoint_pos
    );
        checkpoint = '1;
        restore = '0;
        checkpoint_restore_pos = checkpoint_pos;
    endtask

    task checkpoint_restore(
        input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] restore_pos
    );
        checkpoint = '0;
        restore = '1;
        checkpoint_restore_pos = restore_pos;
    endtask

    task checkpoint_deassert();
        checkpoint = '0;
        restore = '0;
        checkpoint_restore_pos = '0;
    endtask

    initial begin
    $dumpfile("the_waveform.vcd");
    $dumpvars(0, tboom_rename_unit_tb);
    end

endmodule
