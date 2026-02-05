#include "tboom_rmt_ref_model.h"

tboom_rmt_ref_model::tboom_rmt_ref_model(int num_arch, int num_phys) : map(num_arch, 0) {
    rmt_max_size = num_arch;
    freelist_max_size = num_phys;
    for (int i = 0; i < rmt_max_size; i++)
        map[i] = i;

    for (int i = 0; i < num_phys/2; i++)
        freelist.push_back(i + 32);
}

//Freelist

bool tboom_rmt_ref_model::freelist_is_empty(){
    return freelist.empty();
}

bool tboom_rmt_ref_model::freelist_is_one_remaining(){
    return freelist.size() == 1;
}

bool tboom_rmt_ref_model::freelist_is_full(){
    return freelist.size() == freelist_max_size;
}

void tboom_rmt_ref_model::freelist_write(int input){
    if(!tboom_rmt_ref_model::freelist_is_full()){
        freelist.push_back(input);
    }else{
        printf("WARNING: tried to write to freelist when it is full\n");
    }
}

//Does not enforce empty Use freelist_is_empty
int tboom_rmt_ref_model::freelist_read(){
    int ret = freelist.front();
    freelist.pop_front();
    printf("INFO: Freelist Returning %d\n",ret);
    return ret;
}

//RMT

int tboom_rmt_ref_model::tboom_rmt_read(int arch_reg) const {
    if(arch_reg >= rmt_max_size){
        printf("WARNING: RMT request too large! Requested %d\n",arch_reg);
    }
    return map[arch_reg];
}

void tboom_rmt_ref_model::tboom_rmt_write(int arch_reg, int phys_reg) {
    if(arch_reg != 0){
        map[arch_reg] = phys_reg;
    }else{
        printf("WARNING: prevented overwrite of arch 0 in RMT\n");
    }
}

tboom_arch_instruction_output tboom_rmt_ref_model::tboom_rmt_write_instruction(tboom_arch_instruction_input i0, tboom_arch_instruction_input i1){
    tboom_arch_instruction_output output;
    
    //defaults
    output.i0_phys_rd = 0;
    output.i1_phys_rd = 0;
    output.stall = false;

    output.i0_phys_rs1 = tboom_rmt_ref_model::tboom_rmt_read(i0.arch_rs1);
    output.i0_phys_rs2 = tboom_rmt_ref_model::tboom_rmt_read(i0.arch_rs2);
    output.i0_phys_stale = tboom_rmt_ref_model::tboom_rmt_read(i0.arch_rd);

    output.i1_phys_rs1 = tboom_rmt_ref_model::tboom_rmt_read(i1.arch_rs1);
    output.i1_phys_rs2 = tboom_rmt_ref_model::tboom_rmt_read(i1.arch_rs2);
    output.i1_phys_stale = tboom_rmt_ref_model::tboom_rmt_read(i1.arch_rd);


    if(((i0.rd_valid || i1.rd_valid) && tboom_rmt_ref_model::freelist_is_empty())||//at least one instruction needs pdst and freelist is empty
       ((i0.rd_valid && i1.rd_valid) && tboom_rmt_ref_model::freelist_is_one_remaining())){ //two instructions need pdst and freelist only has one
        output.stall = true;
        printf("WARNING: Stall occurred, Freelist empty = %d, Freelist one left = %d\n",tboom_rmt_ref_model::freelist_is_empty(),tboom_rmt_ref_model::freelist_is_one_remaining());
        return output;
    }
    
    //stalled operations do not proceed past this point

    //in order to retrieve from the freelist, i0 must be valid and the destination must be valid and not zero
    
    printf("INFO: i0.valid = %d , i0.rd_valid = %d, (i0.arch_rd != 0) = %d\n",i0.valid,i0.rd_valid,(i0.arch_rd != 0));
    if(i0.valid && i0.rd_valid && (i0.arch_rd != 0)){
       output.i0_phys_rd = tboom_rmt_ref_model::freelist_read();
    }else if(!i0.valid){
        printf("WARNING: Input i0 is not valid, cannot pop from freelist\n");
    }else if(!i0.rd_valid){
        printf("WARNING: Input i0 destination is not valid, cannot pop from freelist\n");
    }else if(i0.arch_rd == 0){
        printf("WARNING: Input i0 destination is 0 but instruction destination is marked valid, cannot pop from freelist\n");
    }else if(tboom_rmt_ref_model::freelist_is_empty()){
        printf("WARNING: Input i0 freelist empty, cannot pop from freelist\n");
    }else{
        printf("WARNING: Input i0 unknown issue, cannot pop from freelist\n");
    }

    //in order to retrieve from the freelist, i1 must be valid and the destination must be valid and not zero
    if(i1.valid && i1.rd_valid && (i1.arch_rd != 0)){
        output.i1_phys_rd = tboom_rmt_ref_model::freelist_read();
    }else if(!i1.valid){
        printf("WARNING: Input i1 is not valid, cannot pop from freelist\n");
    }else if(!i1.rd_valid){
        printf("WARNING: Input i1 destination is not valid, cannot pop from freelist\n");
    }else if(i1.arch_rd == 0){
        printf("WARNING: Input i1 destination is 0 but instruction destination is marked valid, cannot pop from freelist\n");
    }else if(tboom_rmt_ref_model::freelist_is_empty()){
        printf("WARNING: Input i1 freelist empty, cannot pop from freelist\n");
    }else{
        printf("WARNING: Input i1 unknown issue, cannot pop from freelist\n");
    }
    
    //RS1, RS2, Stale


    //forwarding

    //The for forwarding a valid, non-zero i0_phys_rd is requried
    if(i0.valid && i0.rd_valid && output.i0_phys_rd != 0){
        //rs1
        if(i1.valid && i1.rs1_valid && i0.arch_rd == i1.arch_rs1)
            output.i1_phys_rs1 = output.i0_phys_rd;

        //rs2
        if(i1.valid && i1.rs2_valid && i0.arch_rd == i1.arch_rs2)
            output.i1_phys_rs2 = output.i0_phys_rd;

        //stale
        //Note i1.rd_valid is not checked because even if it was false the output would be a "dont care" anyways
        if(i1.valid && i0.arch_rd == i1.arch_rd)
            output.i1_phys_stale = output.i0_phys_rd;
    }

    //Update RMT Mapping
    if(output.i0_phys_rd != 0){
       tboom_rmt_ref_model::tboom_rmt_write(i0.arch_rd,output.i0_phys_rd);
    }
    if(output.i1_phys_rd != 0){
        tboom_rmt_ref_model::tboom_rmt_write(i1.arch_rd,output.i1_phys_rd);
    }

    return output;
}

//Both
void tboom_rmt_ref_model::checkpoint(int checkpoint){
    map_cp[checkpoint] = map;
    freelist_cp[checkpoint] = freelist;
}

//NOTE: If calling restore, do not call any other function for the clock cycle, especially tboom_rmt_write_instruction
void tboom_rmt_ref_model::restore(int checkpoint){
    map = map_cp[checkpoint];
    freelist = freelist_cp[checkpoint];
}
