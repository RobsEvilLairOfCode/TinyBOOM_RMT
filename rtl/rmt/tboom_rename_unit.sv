`timescale 1ns/1ps

module tboom_rename_unit#(
    parameter int unsigned REG_ARCH_ADDR_WIDTH = 5,
    parameter int unsigned REG_PHYS_ADDR_WIDTH = 6,
    parameter int unsigned MEMORY_WIDTH = 32,
    parameter int unsigned CHECKPOINT_DEPTH = 8
)(
    input logic clk,
    input logic rst_n,

    input logic checkpoint, //when high on posedge clock, saves the read_pointer of the last stable state
    input logic restore, //when high, stores the last checkpoint, acts as flush.
    input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] checkpoint_restore_pos, //the index to which a checkpoint is to be made/restored

    input logic i0_valid, //i0 is not a bubble
    input logic i0_rd_valid,//whether or not i0 has an rd
    input logic i0_rs1_valid, //Is the rs1 valid? (Does the instruction actually require and rs1)
    input logic i0_rs2_valid, //Is the rs2 valid? (Does the instruction actually require and rs1)
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rs1,//input arch register for Register Select 1
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rs2,//input arch register for Register Select 2
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rd, //input arch register for Register Destination

    input logic i1_valid,
    input logic i1_rd_valid,
    input logic i1_rs1_valid,
    input logic i1_rs2_valid,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rd,

//writing
    input logic i0_commit_valid,//asserted during commit/retirement when isntruction that had a destination registers have commited and are architecturally visible. Driven by ReOrdering Buffer/Commit logic
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_commit_pdst_old,//The previous physical register that represented the architectural destination.

    input logic i1_commit_valid,//asserted during commit/retirement when isntruction that had a destination registers have commited and are architecturally visible. Driven by ReOrdering Buffer/Commit logic
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_commit_pdst_old,//The previous physical register that represented the architectural destination.

    //output

    //TODO: Rename to stall_freelist later
    output logic stall, //no phys registers for renaming

    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rd,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_stale,
    
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rd,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_stale
);
    logic i0_rmt_freelist_request,i1_rmt_freelist_request;
    logic i0_pdst_valid; //Did the allocation succeed? (When would the allocation not succeed?)
    logic i1_pdst_valid;

    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_freelist_pdst; //The new physical address that goes to the RMT
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_freelist_pdst;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_rmt_rs1;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_rmt_rs1;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_rmt_rs2;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_rmt_rs2;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_rmt_stale;
    logic [REG_PHYS_ADDR_WIDTH-1:0] i1_rmt_stale;

    logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rd_speculative;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rd_speculative;

    logic freelist_empty; //The freelist is empty and the cpu should stall if high
    logic freelist_one_remaining;

    logic write0_enable; //write a new physical register 
    logic [REG_ARCH_ADDR_WIDTH - 1:0] write0_pos; //Arch REG
    logic [REG_PHYS_ADDR_WIDTH - 1:0] write0_phys_reg;//physical REG paired with ARCH reg

    logic write1_enable;
    logic [REG_ARCH_ADDR_WIDTH - 1:0] write1_pos;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] write1_phys_reg;

tboom_rename_map_table rename_map_table(
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

    .i0_freelist_request(i0_rmt_freelist_request), //connects to freelist
    .i1_freelist_request(i1_rmt_freelist_request),

    .i0_phys_rs1(i0_rmt_rs1),
    .i0_phys_rs2(i0_rmt_rs2),
    .i0_phys_stale(i0_rmt_stale),

    .i1_phys_rs1(i1_rmt_rs1), //go to muxes
    .i1_phys_rs2(i1_rmt_rs2),
    .i1_phys_stale(i1_rmt_stale)
  );

    tboom_freelist freelist(
    .clk(clk),
    .rst_n(rst_n),

    .checkpoint(checkpoint),
    .restore(restore),
    .checkpoint_restore_pos(checkpoint_restore_pos),

    .i0_req_valid(i0_rmt_freelist_request),
    .i0_commit_valid(i0_commit_valid),
    .i0_commit_pdst_old(i0_commit_pdst_old),

    .i1_req_valid(i1_rmt_freelist_request),
    .i1_commit_valid(i1_commit_valid),
    .i1_commit_pdst_old(i1_commit_pdst_old),

    .i0_pdst_valid(i0_pdst_valid),
    .i1_pdst_valid(i1_pdst_valid),

    .i0_pdst(i0_freelist_pdst),
    .i1_pdst(i1_freelist_pdst),

    .freelist_empty(freelist_empty),
    .freelist_one_remaining(freelist_one_remaining)
  );

//hold the speculative rd for one cycle
  tboom_delay_buffer #(.WIDTH(REG_PHYS_ADDR_WIDTH)) i0_delay(.clk(clk),.rst_n(rst_n),.d(i0_phys_rd_speculative),.q(i0_phys_rd));
    tboom_delay_buffer #(.WIDTH(REG_PHYS_ADDR_WIDTH)) i1_delay(.clk(clk),.rst_n(rst_n),.d(i1_phys_rd_speculative),.q(i1_phys_rd));

always_comb begin

        i0_phys_rs1   = i0_rmt_rs1;
        i0_phys_rs2   = i0_rmt_rs2;
        i0_phys_stale = i0_rmt_stale;
        i0_phys_rd_speculative = 0;

        i1_phys_rs1   = i1_rmt_rs1;
        i1_phys_rs2   = i1_rmt_rs2;
        i1_phys_stale = i1_rmt_stale;
        i1_phys_rd_speculative = 0;

        write0_enable = 1'b0;
        write1_enable = 1'b0;
        write0_pos = '0;
        write1_pos = '0;
        write0_phys_reg = '0;
        write1_phys_reg = '0;

    //stall if the freelist is empty or there is one entry remaining when two instruction pdsts are requested
    stall = freelist_empty || (freelist_one_remaining && i0_rmt_freelist_request && i1_rmt_freelist_request);

        //If i0 has a destination requested from the freelist and the freelist destination retrieved is not 0...
        if (i0_rmt_freelist_request && i0_pdst_valid) begin
            //i0 destiantion becomes the freelist retrieval for i0
            i0_phys_rd_speculative = i0_freelist_pdst;
        end

        if (i1_rmt_freelist_request && i1_pdst_valid) begin
            i1_phys_rd_speculative = i1_freelist_pdst;
        end

        // If the i0 destination is not zero (encased if statements depend on valid destination)
        if (i0_valid && i0_rd_valid && i0_phys_rd != '0) begin
            //If the destination from the freelist is the same as the i1 rsx...
            if (i1_valid && i1_rs1_valid && i0_arch_rd == i1_arch_rs1)
                //replace with updated mapping
                i1_phys_rs1 = i0_phys_rd;

            if (i1_valid && i1_rs2_valid && i0_arch_rd == i1_arch_rs2)
                i1_phys_rs2 = i0_phys_rd;
            //This is particularly for a WAW sitation
            if (i1_valid && i0_arch_rd == i1_arch_rd)
                i1_phys_stale = i0_phys_rd;
        end

        //Do not write to the RMT when the freelist signals to stall
        //(Other logic an checks handled inside RMT)
        if(!stall) begin
            write0_enable = 1'b1;
            write0_pos = i0_arch_rd;
            write0_phys_reg = i0_phys_rd_speculative;
        end

        if(!stall) begin
            write1_enable = 1'b1;
            write1_pos = i1_arch_rd;
            write1_phys_reg = i1_phys_rd_speculative;
        end
end

endmodule