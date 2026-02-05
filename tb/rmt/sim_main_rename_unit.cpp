#include "Vtboom_rename_unit_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);
    Vtboom_rename_unit_tb* tb = new Vtboom_rename_unit_tb;

    while(!Verilated::gotFinish()){
        tb->eval();
        Verilated::timeInc(1);
    }

    delete tb;
    return 0;
}

