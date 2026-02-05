#pragma once
#include <stdio.h>
#include <vector>
#include <cassert>
#include <deque>

struct tboom_arch_instruction_input{
    bool valid;
    bool rd_valid;
    bool rs1_valid;
    bool rs2_valid;

    int arch_rd;
    int arch_rs1;
    int arch_rs2;
};

struct tboom_arch_instruction_output{
    bool stall;

    int i0_phys_rd;
    int i0_phys_rs1;
    int i0_phys_rs2;
    int i0_phys_stale;

    int i1_phys_rd;
    int i1_phys_rs1;
    int i1_phys_rs2;
    int i1_phys_stale;
};



class tboom_rmt_ref_model {
public:
    // Constructor
    tboom_rmt_ref_model(int num_arch, int num_phys);

    // -------------------
    // Freelist operations
    // -------------------
    bool freelist_is_empty();
    bool freelist_is_one_remaining();
    bool freelist_is_full();
    void freelist_write(int input);  // Does not enforce full
    int freelist_read();             // Does not enforce empty

    // -------------------
    // RMT operations
    // -------------------
    int tboom_rmt_read(int arch_reg) const;
    void tboom_rmt_write(int arch_reg, int phys_reg);

    // Rename instruction interface
    tboom_arch_instruction_output tboom_rmt_write_instruction(
        tboom_arch_instruction_input i0,
        tboom_arch_instruction_input i1
    );

    // -------------------
    // Checkpoint / restore
    // -------------------
    void checkpoint(int checkpoint);
    void restore(int checkpoint);

private:
    int rmt_max_size = 32;
    int freelist_max_size = 64;
    static constexpr int MAX_CHECKPOINTS = 8;
    std::vector<int> map;
    std::deque<int> freelist;
    std::vector<int> map_cp[MAX_CHECKPOINTS];
    std::deque<int>  freelist_cp[MAX_CHECKPOINTS];
    
};
