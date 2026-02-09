`timescale 1ns/1ps

module tboom_freelist_buffer #(
    parameter int unsigned DATA_WIDTH = 6, //6 bits to address physical addresses
    parameter int unsigned MEMORY_WIDTH = 64,
    parameter int unsigned CHECKPOINT_DEPTH = 8,
    localparam int unsigned FREELIST_LAYER = 0

)(
    input logic [DATA_WIDTH - 1:0] i0_data_in,
    input logic i0_read_enable,
    input logic i0_write_enable,

    input logic [DATA_WIDTH - 1:0] i1_data_in,
    input logic i1_read_enable,
    input logic i1_write_enable,

    input logic clk,
    input logic rst_n,

    input logic checkpoint, //when high on posedge clock, saves the read_pointers[FREELIST_LAYER] of the last stable state
    input logic restore, //when high, stores the last checkpoint, acts as flush.
    input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] checkpoint_restore_pos, //the index to which a checkpoint is to be made/restored. 0 = first checkpoint layer

    output logic [DATA_WIDTH - 1:0] i0_data_out,
    output logic [DATA_WIDTH - 1:0] i1_data_out,

    output logic full,

    output logic one_remaining,//one pdst remains, so instruction pairs that rely on two available pdst cannot proceed
    output logic empty,

    output logic invalid_read,invalid_write //Debug Signal. Illegal read/write was attempted
);
    localparam int POINTER_WIDTH = $clog2(MEMORY_WIDTH);
    logic [DATA_WIDTH - 1: 0] memory_arrays[CHECKPOINT_DEPTH + 1] [MEMORY_WIDTH - 1:0] ;
    
    logic [POINTER_WIDTH:0] read_pointers [CHECKPOINT_DEPTH + 1];
    logic [POINTER_WIDTH:0] write_pointers [CHECKPOINT_DEPTH + 1];
    logic [POINTER_WIDTH:0] write_pointers_next [CHECKPOINT_DEPTH + 1];

        
    always_ff @(posedge clk) begin
        

        if(!rst_n) begin //Reset signal is low
            for (int layer_counter = 0; layer_counter < CHECKPOINT_DEPTH + 1; layer_counter++) begin
                for(int memory_counter = 0; memory_counter < MEMORY_WIDTH; memory_counter++) begin
                
                    memory_arrays[layer_counter][memory_counter] = memory_counter[POINTER_WIDTH-1:0] + (POINTER_WIDTH)'(32); //Reset the data
                end
                read_pointers[layer_counter] <= 0;
                write_pointers[layer_counter] <= 32;
            end

            full <= 1'b0;
            one_remaining <= 1'b0;
            empty <= 1'b0;

            invalid_write <= 1'b0;
        end else if (restore) begin //Reset signal is low
            memory_arrays[FREELIST_LAYER] <= memory_arrays[checkpoint_restore_pos + 1];
                read_pointers[FREELIST_LAYER] <= read_pointers[checkpoint_restore_pos + 1];
                write_pointers[FREELIST_LAYER] <= write_pointers[checkpoint_restore_pos + 1];
                write_pointers_next[FREELIST_LAYER] <= write_pointers_next[checkpoint_restore_pos + 1];
        end else begin
            if(checkpoint) begin
                memory_arrays[checkpoint_restore_pos + 1] <= memory_arrays[FREELIST_LAYER];
                read_pointers[checkpoint_restore_pos + 1] <= read_pointers[FREELIST_LAYER];
                write_pointers[checkpoint_restore_pos + 1] <= write_pointers[FREELIST_LAYER];
                write_pointers_next[checkpoint_restore_pos + 1] <= write_pointers_next[FREELIST_LAYER];
            end
        //Reading -----------------------------------------------------------------------------------------
            //If there is more than one entry remaining, and two physical registers are requested -> grant both
            if(i0_read_enable && i1_read_enable && !one_remaining && !empty) begin 
                read_pointers[FREELIST_LAYER] <= read_pointers[FREELIST_LAYER] + 2;//read pointer increments by two

                one_remaining <= (read_pointers[FREELIST_LAYER] + 2 == write_pointers[FREELIST_LAYER] - 1);//If the current position after update is one less than the write pointer, then there is only one entry left in the list.
                empty <= (read_pointers[FREELIST_LAYER] + 2 == write_pointers[FREELIST_LAYER]); //If the current position after update is the write pointer, than the buffer will be empty


                full <= 1'b0;//after reading, there is no possible way the fifo couple be full
            end

            //If there is only one entry remaining and i0 is a real instruction and i1 is a bubble
            else if(i0_read_enable && !i1_read_enable && !empty) begin

                read_pointers[FREELIST_LAYER] <= read_pointers[FREELIST_LAYER] + 1;

                one_remaining <= (read_pointers[FREELIST_LAYER] + 1 == write_pointers[FREELIST_LAYER] - 1);//If the current position after update is one less than the write pointer, then there is only one entry left in the list.
                empty <= (read_pointers[FREELIST_LAYER] + 1 == write_pointers[FREELIST_LAYER]); //If the current position after update is the write pointer, than the buffer will be empty
            end

            //If there is only one entry remaining and i1 is a real instruction and i0 is a bubble
            else if(!i0_read_enable && i1_read_enable && !empty) begin
                //i1_data_out <= memory_arrays[FREELIST_LAYER][read_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]];

                read_pointers[FREELIST_LAYER] <= read_pointers[FREELIST_LAYER] + 1;

                one_remaining <= (read_pointers[FREELIST_LAYER] + 1 == write_pointers[FREELIST_LAYER] - 1);//If the current position after update is one less than the write pointer, then there is only one entry left in the list.
                empty <= (read_pointers[FREELIST_LAYER] + 1 == write_pointers[FREELIST_LAYER]); //If the current position after update is the write pointer, than the buffer will be empty
            end

        //Writing --------------------------------------------------------------------------------------------
            //Due to the spec, it is impossible for the freelist buffer to be full.
            if(i0_write_enable && i1_write_enable && !full) begin //If a write operation is signaled and queue is not full...
                memory_arrays[FREELIST_LAYER][write_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]] <= i0_data_in ;
                memory_arrays[FREELIST_LAYER][write_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0] + 1] <= i1_data_in ;

                write_pointers[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 2;
                write_pointers_next[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 2;
                full <= (write_pointers_next[FREELIST_LAYER] [POINTER_WIDTH - 1:0] == read_pointers[FREELIST_LAYER][POINTER_WIDTH - 1:0]) && (write_pointers_next[FREELIST_LAYER][POINTER_WIDTH] != read_pointers[FREELIST_LAYER][POINTER_WIDTH]);
                empty <= 1'b0;
            end
            else if(i0_write_enable && !full) begin //If a write operation is signaled and queue is not full...
              memory_arrays[FREELIST_LAYER][write_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]] <= i0_data_in ;

                write_pointers[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 1;
                write_pointers_next[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 1;

                full <= (write_pointers_next[FREELIST_LAYER] [POINTER_WIDTH - 1:0] == read_pointers[FREELIST_LAYER][POINTER_WIDTH - 1:0]) && (write_pointers_next[FREELIST_LAYER][POINTER_WIDTH] != read_pointers[FREELIST_LAYER][POINTER_WIDTH]);
                empty <= 1'b0;
            end
            else if(i1_write_enable && !full) begin //If a write operation is signaled and queue is not full...
              memory_arrays[FREELIST_LAYER][write_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]] <= i1_data_in ;

                write_pointers[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 1;
                write_pointers_next[FREELIST_LAYER] <= write_pointers[FREELIST_LAYER] + 1;

                full <= (write_pointers_next[FREELIST_LAYER] [POINTER_WIDTH - 1:0] == read_pointers[FREELIST_LAYER][POINTER_WIDTH - 1:0]) && (write_pointers_next[FREELIST_LAYER][POINTER_WIDTH] != read_pointers[FREELIST_LAYER][POINTER_WIDTH]);
                empty <= 1'b0;
            end
            if(full) begin
                invalid_write <= 1'b1;
            end
        end
    end

    always_comb begin
    // default vlues
    i0_data_out  = '0;
    i1_data_out  = '0;
    invalid_read = 1'b0;

    // Combinational reads use current read pointer
    if (!empty) begin
        if (i0_read_enable && i1_read_enable) begin
            i0_data_out = memory_arrays[FREELIST_LAYER][read_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]];
            i1_data_out = memory_arrays[FREELIST_LAYER][read_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0] + 1];
        end
        else if (i0_read_enable && !i1_read_enable) begin
            i0_data_out = memory_arrays[FREELIST_LAYER][read_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]];
        end
        else if (!i0_read_enable && i1_read_enable) begin
            i1_data_out = memory_arrays[FREELIST_LAYER][read_pointers[FREELIST_LAYER][POINTER_WIDTH-1:0]];
        end
    end

    // Illegal read detection
    if ((i0_read_enable || i1_read_enable) && empty) begin
        invalid_read = 1'b1;
    end
end

endmodule