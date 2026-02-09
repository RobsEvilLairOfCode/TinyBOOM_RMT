module tboom_rename_map_table_buffer #(
    parameter int unsigned REG_ARCH_ADDR_WIDTH = 5,
    parameter int unsigned REG_PHYS_ADDR_WIDTH = 6,
    parameter int unsigned MEMORY_WIDTH = 32,
    parameter int unsigned CHECKPOINT_DEPTH = 8,
    localparam int unsigned RMT_LAYER = 0
)(

    input logic clk,
    input logic rst_n,

    input logic checkpoint, //when high on posedge clock, saves the read_pointer of the last stable state
    input logic restore, //when high, stores the last checkpoint, acts as flush.
    input logic [$clog2(CHECKPOINT_DEPTH) - 1:0] checkpoint_restore_pos, //the index to which a checkpoint is to be made/restored

    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rs1,//input arch register for Register Select 1
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rs2,//input arch register for Register Select 2
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i0_arch_rd, //input arch register for Register Destination

    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rs1,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rs2,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] i1_arch_rd,

//writing
    input logic write0_enable, //write a new physical register 
    input logic [REG_ARCH_ADDR_WIDTH - 1 :0] write0_pos, //Arch REG
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] write0_phys_reg,//physical REG paired with ARCH reg

    input logic write1_enable,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] write1_pos,
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] write1_phys_reg,

    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_stale,
    
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_stale
);
    //logic [REG_ARCH_ADDR_WIDTH - 1: 0] memory_counter;
    //int layer_counter;

    logic [REG_PHYS_ADDR_WIDTH - 1: 0] arch_array [CHECKPOINT_DEPTH + 1][MEMORY_WIDTH];


    always_ff @(posedge clk) begin
        if(!rst_n) begin
            for(int memory_counter = 0; memory_counter < MEMORY_WIDTH; memory_counter++) begin
                for(int layer_counter = 0; layer_counter < CHECKPOINT_DEPTH + 1; layer_counter++) begin
                   arch_array[layer_counter][memory_counter] = memory_counter[REG_PHYS_ADDR_WIDTH-1:0]; //Reset the data to zero  
                end
            end

            i0_phys_rs1 <= '0;
            i0_phys_rs2 <= '0;
            i0_phys_stale <= '0;

            i1_phys_rs1 <= '0;
            i1_phys_rs2 <= '0;
            i1_phys_stale <= '0;

            
        end else if (restore) begin
            for (int r = 0; r < MEMORY_WIDTH; r++) begin
                    arch_array[RMT_LAYER][r] <= arch_array[checkpoint_restore_pos + 1][r];
            end
        end else begin
            //Restore
            if(checkpoint) begin
                for (int r = 0; r < MEMORY_WIDTH; r++) begin
                    arch_array[checkpoint_restore_pos + 1][r] <= arch_array[RMT_LAYER][r];
                end
            end

            //Read
            i0_phys_rs1 <= arch_array[RMT_LAYER][i0_arch_rs1];
            i0_phys_rs2 <= arch_array[RMT_LAYER][i0_arch_rs2];
            i0_phys_stale <= arch_array[RMT_LAYER][i0_arch_rd];
            i1_phys_rs1 <= arch_array[RMT_LAYER][i1_arch_rs1];
            i1_phys_rs2 <= arch_array[RMT_LAYER][i1_arch_rs2];
            i1_phys_stale <= arch_array[RMT_LAYER][i1_arch_rd];

            //Write
            if(write0_enable) begin
                arch_array[RMT_LAYER][write0_pos] <= write0_phys_reg;
            end
            //write 0 and 1 should not write to the same place (w0 has priority)
            if(write1_enable && !(write0_enable && (write0_pos == write1_pos))) begin
                arch_array[RMT_LAYER][write1_pos] <= write1_phys_reg;
            end
        end
    end
endmodule