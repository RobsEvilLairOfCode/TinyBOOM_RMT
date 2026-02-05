#include "Vtboom_freelist_buffer_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Vtboom_freelist_buffer_tb* tb = new Vtboom_freelist_buffer_tb;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    tb->trace(tfp, 99);
    tfp->open("wave.vcd");

    while(!Verilated::gotFinish()){
        tb->eval();
        Verilated::timeInc(1);
    }

    tfp->close();
    delete tb;
    delete tfp;
    return 0;
}

