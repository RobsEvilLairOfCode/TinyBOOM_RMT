`timescale 1ns/1ps

module tboom_rename_map_table#(
    parameter int REG_ARCH_ADDR_WIDTH = 5,
    parameter int REG_PHYS_ADDR_WIDTH = 6,
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
    input logic write0_enable, //write a new physical register 
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] write0_pos, //Arch REG
    input logic [REG_PHYS_ADDR_WIDTH - 1:0] write0_phys_reg,//physical REG paired with ARCH reg

    input logic write1_enable,
    input logic [REG_ARCH_ADDR_WIDTH - 1:0] write1_pos,
    input logic [REG_PHYS_ADDR_WIDTH - 1 :0] write1_phys_reg,

    output logic i0_freelist_request,//if i0 has a valid rd, 
    output logic i1_freelist_request,

    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_stale,
    
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs1,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs2,
    output logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_stale
);
    logic write0_enable_buffer,write1_enable_buffer;

    logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs1_buffer;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_rs2_buffer;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i0_phys_stale_buffer;
    
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs1_buffer;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_rs2_buffer;
    logic [REG_PHYS_ADDR_WIDTH - 1:0] i1_phys_stale_buffer;

 tboom_rename_map_table_buffer rename_map_buffer(
    .clk(clk),
    .rst_n(rst_n),
    .checkpoint(checkpoint),
    .restore(restore),
    .checkpoint_restore_pos(checkpoint_restore_pos),
    .i0_arch_rs1(i0_arch_rs1),
    .i0_arch_rs2(i0_arch_rs2),
    .i0_arch_rd(i0_arch_rd),
    .i1_arch_rs1(i1_arch_rs1),
    .i1_arch_rs2(i1_arch_rs2),
    .i1_arch_rd(i1_arch_rd),
    .write0_enable(write0_enable_buffer),
    .write0_pos(write0_pos),
    .write0_phys_reg(write0_phys_reg),
    .write1_enable(write1_enable_buffer),
    .write1_pos(write1_pos),
    .write1_phys_reg(write1_phys_reg),
    .i0_phys_rs1(i0_phys_rs1_buffer),
    .i0_phys_rs2(i0_phys_rs2_buffer),
    .i0_phys_stale(i0_phys_stale_buffer),
    .i1_phys_rs1(i1_phys_rs1_buffer),
    .i1_phys_rs2(i1_phys_rs2_buffer),
    .i1_phys_stale(i1_phys_stale_buffer)
 );

always_comb begin
    //if rs1/rs2 is invalid, output 0 instead
    i0_phys_rs1 = (i0_rs1_valid) ? i0_phys_rs1_buffer : '0 ;
    i0_phys_rs2 = (i0_rs2_valid) ? i0_phys_rs2_buffer : '0 ;

    i1_phys_rs1 = (i1_rs1_valid) ? i1_phys_rs1_buffer : '0 ;
    i1_phys_rs2 = (i1_rs2_valid) ? i1_phys_rs2_buffer : '0 ;

    //The stale will be updated no matter what, but when rd is invalid is technicaly a DONT CARE
    i0_phys_stale = i0_phys_stale_buffer;
    i1_phys_stale = i1_phys_stale_buffer;

    //No RMT update should take place when write enable or iX_rd_valid is low
    //stalls are check in the top rename module
    write0_enable_buffer = write0_enable && i0_rd_valid && i0_valid && !(i0_arch_rd == '0) && !restore;
    write1_enable_buffer = write1_enable && i1_rd_valid && i1_valid && !(i1_arch_rd == '0) && !restore;

    //send a request for a free physical register if the instruction has a valid destination register
    i0_freelist_request = i0_rd_valid && i0_valid && !(i0_arch_rd == '0);
    i1_freelist_request = i1_rd_valid && i1_valid && !(i1_arch_rd == '0);
end

endmodule