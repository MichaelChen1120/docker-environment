#include <iostream>
#include "VCounter.h"
#include "verilated_vcd_c.h"


int main() {
    Verilated::traceEverOn(true);
    VerilatedVcdC* fp = new VerilatedVcdC();

    auto dut = new VCounter;
    dut->trace(fp, 0);
    fp->open("wave.vcd");

    int clk = 0;
    const int maxclk = 10;

    dut->rst = 1;
    dut->max = 9;
    dut->clk = 1; dut->eval(); fp->dump(clk++);

    dut->rst = 0;
    while (clk < maxclk << 1) {
        // falling edge
        dut->clk = 0; dut->eval(); fp->dump(clk++);

        // rising edge
        dut->clk = 1; dut->eval(); fp->dump(clk++);
        std::cout << "count: " << dut->out << std::endl;
    }

    fp->close();
    dut->final();
    delete dut;
    return 0;
}
