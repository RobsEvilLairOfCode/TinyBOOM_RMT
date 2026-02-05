//This file is a LLM generated version of the tb/rmt/tboom_rename_unit_tb.sv written in C++. It uses the same tests. I have commented on each function

#include "Vtboom_rename_unit.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include "tboom_rmt_ref_model.h"

#include <cstdint>
#include <functional>
#include <iostream>

//Cycle clock and advance simulation time (Also writes to vcd waveform file)
static void tick(Vtboom_rename_unit* dut, VerilatedVcdC* tfp) {
    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(Verilated::time());
    Verilated::timeInc(1);

    dut->clk = 1;
    dut->eval();  // sequential logic
    dut->eval();  // settle combinational fan-out
    if (tfp) tfp->dump(Verilated::time());
    Verilated::timeInc(1);
}

//Clears freelist inputs
static void clear_commits(Vtboom_rename_unit* dut) {
    dut->i0_commit_valid = 0;
    dut->i0_commit_pdst_old = 0;
    dut->i1_commit_valid = 0;
    dut->i1_commit_pdst_old = 0;
}

//Clears RMT instruction 0 inputs
static void clear_i0(Vtboom_rename_unit* dut) {
    dut->i0_valid = 0;
    dut->i0_rd_valid = 0;
    dut->i0_rs1_valid = 0;
    dut->i0_rs2_valid = 0;
    dut->i0_arch_rs1 = 0;
    dut->i0_arch_rs2 = 0;
    dut->i0_arch_rd = 0;
}

//Clears RMT instruction 1 inputs
static void clear_i1(Vtboom_rename_unit* dut) {
    dut->i1_valid = 0;
    dut->i1_rd_valid = 0;
    dut->i1_rs1_valid = 0;
    dut->i1_rs2_valid = 0;
    dut->i1_arch_rs1 = 0;
    dut->i1_arch_rs2 = 0;
    dut->i1_arch_rd = 0;
}

//Calls above helper functions and also clears checkpoint/restore and ensures clock is low
static void initialize_inputs(Vtboom_rename_unit* dut) {
    clear_commits(dut);
    clear_i0(dut);
    clear_i1(dut);
    dut->checkpoint = 0;
    dut->restore = 0;
    dut->checkpoint_restore_pos = 0;
    dut->clk = 0;
}

//
static void start_cycle(Vtboom_rename_unit* dut) {
    dut->checkpoint = 0;
    dut->restore = 0;
    dut->checkpoint_restore_pos = 0;
    clear_commits(dut);
}

//Creates a checkpoint on the cycle
static void assert_checkpoint(Vtboom_rename_unit* dut, uint32_t pos) {
    dut->checkpoint = 1;
    dut->restore = 0;
    dut->checkpoint_restore_pos = pos;
}

//Restores a checkpoint on the cycle
static void assert_restore(Vtboom_rename_unit* dut, uint32_t pos) {
    dut->checkpoint = 0;
    dut->restore = 1;
    dut->checkpoint_restore_pos = pos;
}

static void set_i0(Vtboom_rename_unit* dut,
                   bool valid,
                   bool rd_valid,
                   bool rs1_valid,
                   bool rs2_valid,
                   uint32_t arch_rs1,
                   uint32_t arch_rs2,
                   uint32_t arch_rd) {
    dut->i0_valid = valid;
    dut->i0_rd_valid = rd_valid;
    dut->i0_rs1_valid = rs1_valid;
    dut->i0_rs2_valid = rs2_valid;
    dut->i0_arch_rs1 = arch_rs1;
    dut->i0_arch_rs2 = arch_rs2;
    dut->i0_arch_rd = arch_rd;
}

static void set_i1(Vtboom_rename_unit* dut,
                   bool valid,
                   bool rd_valid,
                   bool rs1_valid,
                   bool rs2_valid,
                   uint32_t arch_rs1,
                   uint32_t arch_rs2,
                   uint32_t arch_rd) {
    dut->i1_valid = valid;
    dut->i1_rd_valid = rd_valid;
    dut->i1_rs1_valid = rs1_valid;
    dut->i1_rs2_valid = rs2_valid;
    dut->i1_arch_rs1 = arch_rs1;
    dut->i1_arch_rs2 = arch_rs2;
    dut->i1_arch_rd = arch_rd;
}

static void set_i0_valid(Vtboom_rename_unit* dut,
                         uint32_t arch_rs1,
                         uint32_t arch_rs2,
                         uint32_t arch_rd) {
    set_i0(dut, true, true, true, true, arch_rs1, arch_rs2, arch_rd);
}

static void set_i1_valid(Vtboom_rename_unit* dut,
                         uint32_t arch_rs1,
                         uint32_t arch_rs2,
                         uint32_t arch_rd) {
    set_i1(dut, true, true, true, true, arch_rs1, arch_rs2, arch_rd);
}

// ----------------------------------------------------------------------------- 
// Scoreboard comparison
// ----------------------------------------------------------------------------- 
static bool compare_with_model(Vtboom_rename_unit* dut,
                               tboom_rmt_ref_model& model,
                               int cycle,
                               const char* label) {
    std::cout << "-------------------------------- Cycle " << cycle;
    if (label) {
        std::cout << " [" << label << "]";
    }
    std::cout << " --------------------------------" << std::endl;

    std::cout << "DUT Outputs:" << std::endl;
    std::cout << "  stall = " << +dut->stall << std::endl;
    std::cout << "  i0_phys_rd = " << +dut->i0_phys_rd << std::endl;
    std::cout << "  i0_phys_rs1 = " << +dut->i0_phys_rs1 << std::endl;
    std::cout << "  i0_phys_rs2 = " << +dut->i0_phys_rs2 << std::endl;
    std::cout << "  i0_phys_stale = " << +dut->i0_phys_stale << std::endl;
    std::cout << "  i1_phys_rd = " << +dut->i1_phys_rd << std::endl;
    std::cout << "  i1_phys_rs1 = " << +dut->i1_phys_rs1 << std::endl;
    std::cout << "  i1_phys_rs2 = " << +dut->i1_phys_rs2 << std::endl;
    std::cout << "  i1_phys_stale = " << +dut->i1_phys_stale << std::endl;

    // Handle control-side effects in the reference model before rename work
    if (dut->restore) {
        model.restore(dut->checkpoint_restore_pos);
    }
    if (dut->checkpoint) {
        model.checkpoint(dut->checkpoint_restore_pos);
    }
    if (dut->i0_commit_valid && dut->i0_commit_pdst_old != 0) {
        model.freelist_write(dut->i0_commit_pdst_old);
    }
    if (dut->i1_commit_valid && dut->i1_commit_pdst_old != 0) {
        model.freelist_write(dut->i1_commit_pdst_old);
    }

    tboom_arch_instruction_input i0{};
    tboom_arch_instruction_input i1{};

    i0.valid = dut->i0_valid;
    i0.rd_valid = dut->i0_rd_valid;
    i0.rs1_valid = dut->i0_rs1_valid;
    i0.rs2_valid = dut->i0_rs2_valid;
    i0.arch_rs1 = dut->i0_arch_rs1;
    i0.arch_rs2 = dut->i0_arch_rs2;
    i0.arch_rd = dut->i0_arch_rd;

    i1.valid = dut->i1_valid;
    i1.rd_valid = dut->i1_rd_valid;
    i1.rs1_valid = dut->i1_rs1_valid;
    i1.rs2_valid = dut->i1_rs2_valid;
    i1.arch_rs1 = dut->i1_arch_rs1;
    i1.arch_rs2 = dut->i1_arch_rs2;
    i1.arch_rd = dut->i1_arch_rd;

    tboom_arch_instruction_output ref = model.tboom_rmt_write_instruction(i0, i1);

    std::cout << "Reference Outputs:" << std::endl;
    std::cout << "  stall = " << ref.stall << std::endl;
    std::cout << "  i0_phys_rd = " << ref.i0_phys_rd << std::endl;
    std::cout << "  i0_phys_rs1 = " << ref.i0_phys_rs1 << std::endl;
    std::cout << "  i0_phys_rs2 = " << ref.i0_phys_rs2 << std::endl;
    std::cout << "  i0_phys_stale = " << ref.i0_phys_stale << std::endl;
    std::cout << "  i1_phys_rd = " << ref.i1_phys_rd << std::endl;
    std::cout << "  i1_phys_rs1 = " << ref.i1_phys_rs1 << std::endl;
    std::cout << "  i1_phys_rs2 = " << ref.i1_phys_rs2 << std::endl;
    std::cout << "  i1_phys_stale = " << ref.i1_phys_stale << std::endl;

    // Match rename_map_table gating on invalid sources
    if (!i0.rs1_valid) ref.i0_phys_rs1 = 0;
    if (!i0.rs2_valid) ref.i0_phys_rs2 = 0;
    if (!i1.rs1_valid) ref.i1_phys_rs1 = 0;
    if (!i1.rs2_valid) ref.i1_phys_rs2 = 0;

    if (!(i0.valid && i0.rd_valid)) ref.i0_phys_stale = 0;
    if (!(i1.valid && i1.rd_valid)) ref.i1_phys_stale = 0;

    bool mismatch = false;
    mismatch |= (dut->stall != static_cast<uint32_t>(ref.stall));
    mismatch |= (dut->i0_phys_rd != static_cast<uint32_t>(ref.i0_phys_rd));
    mismatch |= (dut->i0_phys_rs1 != static_cast<uint32_t>(ref.i0_phys_rs1));
    mismatch |= (dut->i0_phys_rs2 != static_cast<uint32_t>(ref.i0_phys_rs2));
    if (i0.valid && i0.rd_valid) {
        mismatch |= (dut->i0_phys_stale != static_cast<uint32_t>(ref.i0_phys_stale));
    }
    mismatch |= (dut->i1_phys_rd != static_cast<uint32_t>(ref.i1_phys_rd));
    mismatch |= (dut->i1_phys_rs1 != static_cast<uint32_t>(ref.i1_phys_rs1));
    mismatch |= (dut->i1_phys_rs2 != static_cast<uint32_t>(ref.i1_phys_rs2));
    if (i1.valid && i1.rd_valid) {
        mismatch |= (dut->i1_phys_stale != static_cast<uint32_t>(ref.i1_phys_stale));
    }

    if (mismatch) {
        std::cout << "** MISMATCH DETECTED **" << std::endl;
    }

    return mismatch;
}

static bool step_and_check(Vtboom_rename_unit* dut,
                           VerilatedVcdC* tfp,
                           tboom_rmt_ref_model& model,
                           int& cycle,
                           const char* label) {
    tick(dut, tfp);
    bool mismatch = compare_with_model(dut, model, cycle, label);
    ++cycle;
    return mismatch;
}

static void run_reset(Vtboom_rename_unit* dut,
                      VerilatedVcdC* tfp,
                      tboom_rmt_ref_model& model,
                      int& cycle,
                      int& mismatches) {
    initialize_inputs(dut);

    dut->rst_n = 0;
    tick(dut, tfp);
    tick(dut, tfp);

    model = tboom_rmt_ref_model(32, 64);
    cycle = 0;

    dut->rst_n = 1;
    start_cycle(dut);
    clear_i0(dut);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "reset_release")) {
        ++mismatches;
    }
}

// ----------------------------------------------------------------------------- 
// Individual tests
// ----------------------------------------------------------------------------- 
using TestFunc = void(*)(Vtboom_rename_unit*, VerilatedVcdC*, tboom_rmt_ref_model&, int&, int&);

static void test_simple_read(Vtboom_rename_unit* dut,
                             VerilatedVcdC* tfp,
                             tboom_rmt_ref_model& model,
                             int& cycle,
                             int& mismatches) {
    start_cycle(dut);
    clear_i0(dut);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "simple_read:idle")) ++mismatches;

    start_cycle(dut);
    set_i0_valid(dut, 1, 2, 3);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "simple_read:issue_i0")) ++mismatches;

    start_cycle(dut);
    clear_i0(dut);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "simple_read:drain")) ++mismatches;
}

static void test_independant_write(Vtboom_rename_unit* dut,
                            VerilatedVcdC* tfp,
                            tboom_rmt_ref_model& model,
                            int& cycle,
                            int& mismatches) {
    start_cycle(dut);
    set_i0_valid(dut, 1, 2, 3);
    set_i1_valid(dut, 4, 5, 6);
    if (step_and_check(dut, tfp, model, cycle, "independant_write:rename_pair")) ++mismatches;

    start_cycle(dut);
    clear_i0(dut);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "independant_write:idle")) ++mismatches;
}

static void test_waw(Vtboom_rename_unit* dut,
                     VerilatedVcdC* tfp,
                     tboom_rmt_ref_model& model,
                     int& cycle,
                     int& mismatches) {
    start_cycle(dut);
    set_i0_valid(dut, 1, 2, 3);
    set_i1_valid(dut, 5, 4, 3);
    if (step_and_check(dut, tfp, model, cycle, "waw:same_rd")) ++mismatches;
}

static void test_war(Vtboom_rename_unit* dut,
                     VerilatedVcdC* tfp,
                     tboom_rmt_ref_model& model,
                     int& cycle,
                     int& mismatches) {
    start_cycle(dut);
    set_i0_valid(dut, 3, 2, 1);
    set_i1_valid(dut, 5, 4, 3);
    if (step_and_check(dut, tfp, model, cycle, "war:write_after_read")) ++mismatches;
}

static void test_raw(Vtboom_rename_unit* dut,
                     VerilatedVcdC* tfp,
                     tboom_rmt_ref_model& model,
                     int& cycle,
                     int& mismatches) {
    start_cycle(dut);
    set_i0_valid(dut, 1, 2, 3);
    set_i1_valid(dut, 3, 4, 5);
    if (step_and_check(dut, tfp, model, cycle, "raw:forwarding")) ++mismatches;
}

static void test_no_rd(Vtboom_rename_unit* dut,
                       VerilatedVcdC* tfp,
                       tboom_rmt_ref_model& model,
                       int& cycle,
                       int& mismatches) {
    start_cycle(dut);
    set_i0(dut, true, false, true, true, 1, 2, 30);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "no_rd:i0_dest_invalid")) ++mismatches;
}

static void test_no_rs(Vtboom_rename_unit* dut,
                       VerilatedVcdC* tfp,
                       tboom_rmt_ref_model& model,
                       int& cycle,
                       int& mismatches) {
    start_cycle(dut);
    set_i0(dut, true, true, false, false, 6, 7, 3);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "no_rs:rs_invalid")) ++mismatches;

    start_cycle(dut);
    set_i0(dut, true, true, true, false, 1, 2, 3);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "no_rs:rs2_invalid")) ++mismatches;
}

static void test_bubble(Vtboom_rename_unit* dut,
                        VerilatedVcdC* tfp,
                        tboom_rmt_ref_model& model,
                        int& cycle,
                        int& mismatches) {
    start_cycle(dut);
    clear_i0(dut);
    set_i1_valid(dut, 1, 2, 3);
    if (step_and_check(dut, tfp, model, cycle, "bubble:i1_only")) ++mismatches;

    start_cycle(dut);
    set_i0_valid(dut, 3, 4, 5);
    set_i1_valid(dut, 6, 7, 8);
    if (step_and_check(dut, tfp, model, cycle, "bubble:pair_after_i1")) ++mismatches;
}

static void test_checkpoint_restore(Vtboom_rename_unit* dut,VerilatedVcdC* tfp,tboom_rmt_ref_model& model,int& cycle,int& mismatches) {
    start_cycle(dut);
    set_i0_valid(dut, 1, 2, 3);
    set_i1_valid(dut, 4, 5, 6);
    assert_checkpoint(dut, 0);
    if (step_and_check(dut, tfp, model, cycle, "checkpoint:save")) ++mismatches;

    start_cycle(dut);
    assert_checkpoint(dut, 0);//create a checkpoint before changing 9
    set_i0_valid(dut, 7, 8, 9); //9 becomes 34
    set_i1_valid(dut, 10, 11, 12);
    if (step_and_check(dut, tfp, model, cycle, "checkpoint:overwrite")) ++mismatches;

    start_cycle(dut);
    set_i0_valid(dut, 9, 13, 14); //show that 9 is 34
    set_i1_valid(dut, 15, 16, 17); 
    if (step_and_check(dut, tfp, model, cycle, "restore:apply")) ++mismatches;

    start_cycle(dut);
    assert_restore(dut,0);//restore the checkpoint
    clear_i0(dut);
    clear_i1(dut);
    if (step_and_check(dut, tfp, model, cycle, "restore:verify")) ++mismatches;

    start_cycle(dut);
    set_i0_valid(dut, 9, 13, 14); //show that 9 is unchanged (9)
    set_i1_valid(dut, 15, 16, 17); 
    if (step_and_check(dut, tfp, model, cycle, "restore:verify")) ++mismatches;
}

static void test_zero_reg(Vtboom_rename_unit* dut, VerilatedVcdC* tfp,tboom_rmt_ref_model& model,int& cycle, int& mismatches) {
    start_cycle(dut);
    set_i0(dut, true, true, true, true, 1, 2, 0);
    set_i1(dut, true, false, true, true, 3, 4, 0);
    if (step_and_check(dut, tfp, model, cycle, "zero_reg:first_use")) ++mismatches;

    start_cycle(dut);
    set_i0(dut, true, true, true, true, 5, 6, 0);
    set_i1(dut, true, false, true, true, 7, 8, 0);
    if (step_and_check(dut, tfp, model, cycle, "zero_reg:second_use")) ++mismatches;
}

// ----------------------------------------------------------------------------- 
// Test harness plumbing
// ----------------------------------------------------------------------------- 
static int run_test(const char* name,
                    Vtboom_rename_unit* dut,
                    VerilatedVcdC* tfp,
                    TestFunc func) {
    std::cout << std::endl << "==== " << name << " ====" << std::endl;

    tboom_rmt_ref_model model(32, 64);
    int cycle = 0;
    int mismatches = 0;

    run_reset(dut, tfp, model, cycle, mismatches);
    func(dut, tfp, model, cycle, mismatches);

    std::cout << "==== " << name << " complete (" << mismatches << " mismatches) ====" << std::endl;
    return mismatches;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vtboom_rename_unit* dut = new Vtboom_rename_unit;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("rename.vcd");

    const struct {
        const char* name;
        TestFunc func;
    } tests[] = {
        {"reset_idle_and_simple_read", test_simple_read},
        {"independant_write", test_independant_write},
        {"write_after_write", test_waw},
        {"write_after_read", test_war},
        {"read_after_write", test_raw},
        {"no_rd_destination", test_no_rd},
        {"no_rs_operands", test_no_rs},
        {"bubble_flow", test_bubble},
        {"checkpoint_restore", test_checkpoint_restore},
        {"zero_register_guard", test_zero_reg},
    };

    int total_mismatches = 0;
    for (const auto& t : tests) {
        total_mismatches += run_test(t.name, dut, tfp, t.func);
    }

    if (total_mismatches == 0) {
        std::cout << std::endl << "All C++ self-checks passed." << std::endl;
    } else {
        std::cout << std::endl << "Self-checks completed with " << total_mismatches
                  << " mismatching cycle(s)." << std::endl;
    }

    tick(dut,tfp);
    tfp->close();
    delete tfp;
    delete dut;

    return (total_mismatches == 0);
}
