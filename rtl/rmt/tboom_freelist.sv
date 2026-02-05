`timescale 1ns/1ps

module tboom_freelist#(
    parameter int REG_PHYS_ADDR_WIDTH = 6, //number of bits needed to access all physical registers 
    parameter int NUM_PHYS_REGISTERS = 64,
    parameter int CHECKPOINT_DEPTH = 8
)(
    input logic clk,
    input logic rst_n,//Active Low Reset

    input logic checkpoint, // make a checkpoint in the buffer
    input logic restore, //Forces RMT to restore mappings for in-flight instructions if a mispredict occurs. Undoes speculative allocation
    input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] checkpoint_restore_pos, //the index to which a checkpoint is to be made/restored

    input logic i0_req_valid, //asserted during rename if an instruction needs a physical destination regiser (not LOAD, STOR, etc.). Driven by Rename/Decode logic

    input logic i0_commit_valid,//asserted during commit/retirement when isntruction that had a destination registers have commited and are architecturally visible. Driven by ReOrdering Buffer/Commit logic
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_commit_pdst_old,//The previous physical register that represented the architectural destination.

    input logic i1_req_valid,

    input logic i1_commit_valid,
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_commit_pdst_old,

    output logic i0_pdst_valid, //Did the allocation succeed? (When would the allocation not succeed?)
    output logic i1_pdst_valid,

    output logic [REG_PHYS_ADDR_WIDTH-1:0] i0_pdst, //The new physical address that goes to the RMT
    output logic [REG_PHYS_ADDR_WIDTH-1:0] i1_pdst,

    output logic freelist_empty, //The freelist is empty and the cpu should stall if high
    output logic freelist_one_remaining //The freelist only has one physical register remaining and the cpu should send a pair with a bubble or one instruction that needs a reg destination if high
);
    //Freelist Overview
    //Hand out one new physical register when the RMT requests it
    //Indicate that the CPU should stall if the freelist is empty

    //Accept old physical registers from commited/retired instructions

    //Undo speculative allocations during flush
    //Restore freelist state to the last commited checkpoint
    parameter int BITS_IN_WORD = 32;

    //Buffer_signals
    logic [REG_PHYS_ADDR_WIDTH-1:0] i0_freelist_buffer_data_in, i0_freelist_buffer_data_out, i1_freelist_buffer_data_in, i1_freelist_buffer_data_out;
    logic i0_freelist_buffer_read_enable,i0_freelist_buffer_write_enable, i1_freelist_buffer_read_enable,i1_freelist_buffer_write_enable;
    logic freelist_buffer_full, freelist_buffer_one_remaining, freelist_buffer_empty;

    //A buffer that is able to hold all physical registers
    tboom_freelist_buffer #(.DATA_WIDTH(REG_PHYS_ADDR_WIDTH),.MEMORY_WIDTH(NUM_PHYS_REGISTERS)) freelist_buffer(
        .i0_data_in(i0_freelist_buffer_data_in),
        .i0_read_enable(i0_freelist_buffer_read_enable),
        .i0_write_enable(i0_freelist_buffer_write_enable),
        .i1_data_in(i1_freelist_buffer_data_in),
        .i1_read_enable(i1_freelist_buffer_read_enable),
        .i1_write_enable(i1_freelist_buffer_write_enable),
        .clk(clk),
        .rst_n(rst_n),
        .checkpoint(checkpoint),//no extra logic is needed as a checkpoint logic is not determined by freelist
        .restore(restore),
        .checkpoint_restore_pos(checkpoint_restore_pos),
        .i0_data_out(i0_freelist_buffer_data_out),
        .i1_data_out(i1_freelist_buffer_data_out),
        .full(freelist_buffer_full),
        .one_remaining(freelist_one_remaining),
        .empty(freelist_empty),
        .invalid_read(),
        .invalid_write()
    );

    always_comb begin //trigger on either the positive edge of the clock or the negitive edge of the clock
        i0_pdst_valid = 1'b0;
        i1_pdst_valid = 1'b0;
        i0_pdst = '0;
        i1_pdst = '0;
        i0_freelist_buffer_read_enable = 1'b0;
        i1_freelist_buffer_read_enable = 1'b0;
        i0_freelist_buffer_write_enable = 1'b0;
        i1_freelist_buffer_write_enable = 1'b0;
        i0_freelist_buffer_data_in = '0;
        i1_freelist_buffer_data_in = '0;
        
        //If request from RMT for a new physical register for older instruction
        if(i0_req_valid && i1_req_valid) begin//if both requests are valid
            if(freelist_empty || freelist_one_remaining) begin //if there are not enough physical registers for the pair...
                i0_pdst_valid = 1'b0;
                i1_pdst_valid = 1'b0;
            end else begin //If there are enough instructions
                i0_freelist_buffer_read_enable = 1'b1;//enable read
                i0_pdst = i0_freelist_buffer_data_out;//write data to the pdst

                i1_freelist_buffer_read_enable = 1'b1;//enable read
                i1_pdst = i1_freelist_buffer_data_out;//write data to the pdst
            
                i0_pdst_valid = 1'b1;
                i1_pdst_valid = 1'b1;
            end
        end else if(i0_req_valid && !i1_req_valid) begin//if only instr 0 request is valid
            if(freelist_empty) begin //if there are not enough physical registers for the pair...
                i0_pdst_valid = 1'b0;
                i1_pdst_valid = 1'b0;
            end else begin //If there are enough instructions
                i0_freelist_buffer_read_enable = 1'b1;//enable read
                i0_pdst = i0_freelist_buffer_data_out;//write data to the pdst

                i1_freelist_buffer_read_enable = 1'b0;//disable read

                i0_pdst_valid = 1'b1;
                i1_pdst_valid = 1'b0;
            end
        end else if(!i0_req_valid && i1_req_valid) begin//if only instr 1 request is valid
            if(freelist_empty) begin //if there are not enough physical registers for the pair...
                i0_pdst_valid = 1'b0;
                i1_pdst_valid = 1'b0;
            end else begin //If there are enough instructions
                i0_freelist_buffer_read_enable = 1'b0;//enable read

                i1_freelist_buffer_read_enable = 1'b1;//disable read
                i1_pdst = i1_freelist_buffer_data_out;//write data to the pdst

                i0_pdst_valid = 1'b0;
                i1_pdst_valid = 1'b1;
            end
        end

        //Incoming retired Phys registers
        if(i0_commit_valid) begin
            i0_freelist_buffer_write_enable = 1'b1;
            i0_freelist_buffer_data_in = i1_commit_pdst_old;
        end
        if(i1_commit_valid) begin
            i1_freelist_buffer_write_enable = 1'b1;
            i1_freelist_buffer_data_in = i1_commit_pdst_old;
        end
    end
endmodule