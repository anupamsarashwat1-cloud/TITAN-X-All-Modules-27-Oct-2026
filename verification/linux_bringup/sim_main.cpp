#include <verilated.h>
#include "Vtitan_x_top.h"
#include "Vtitan_x_top___024root.h"
#include <iostream>
#include <memory>
#include <string>
#include <sys/time.h>
#include <sys/resource.h>
#include <cstdlib>

enum UartState { UART_IDLE, UART_START, UART_DATA, UART_STOP };

int main(int argc, char** argv) {
    // Elevate stack size limit to 256MB to avoid segfaults on large simulation structures
    struct rlimit rl;
    if (getrlimit(RLIMIT_STACK, &rl) == 0) {
        rl.rlim_cur = 256 * 1024 * 1024;
        setrlimit(RLIMIT_STACK, &rl);
    }

    Verilated::commandArgs(argc, argv);
    
    uint64_t max_cycles = 100000;
    for (int i = 1; i < argc; i++) {
        if (std::string(argv[i]) == "--cycles" && i + 1 < argc) {
            max_cycles = std::stoull(argv[i + 1]);
        }
    }

    auto top = std::make_unique<Vtitan_x_top>();
    
    top->clk = 0;
    top->rst_n = 0;
    
    uint64_t ticks = 0;
    UartState uart_state = UART_IDLE;
    uint32_t uart_cnt = 0;
    uint8_t uart_byte = 0;
    int uart_bit_idx = 0;
    const uint32_t BIT_CYCLES = 868;

    std::cout << "====================================================\n";
    std::cout << " SMVDU TITAN-X SoC — Verilator OS Simulation Harness\n";
    std::cout << " Max Cycles: " << max_cycles << "\n";
    std::cout << " UART0 Output Console Stream:\n";
    std::cout << "====================================================\n" << std::endl;
    
    while (!Verilated::gotFinish()) {
        if (ticks < 20) {
            top->rst_n = 0;
        } else {
            top->rst_n = 1;
        }
        
        top->clk = !top->clk;
        top->eval();
        
        if (top->clk) {
            int tx_bit = (top->uart_tx & 1);
            switch (uart_state) {
                case UART_IDLE:
                    if (tx_bit == 0) {
                        uart_state = UART_START;
                        uart_cnt = BIT_CYCLES + (BIT_CYCLES / 2);
                        uart_byte = 0;
                        uart_bit_idx = 0;
                    }
                    break;
                case UART_START:
                case UART_DATA:
                    if (--uart_cnt == 0) {
                        uart_byte |= (tx_bit << uart_bit_idx);
                        uart_bit_idx++;
                        if (uart_bit_idx == 8) {
                            std::cout << (char)uart_byte << std::flush;
                            uart_state = UART_STOP;
                            uart_cnt = BIT_CYCLES;
                        } else {
                            uart_cnt = BIT_CYCLES;
                        }
                    }
                    break;
                case UART_STOP:
                    if (--uart_cnt == 0) {
                        uart_state = UART_IDLE;
                    }
                    break;
            }
        }

        ticks++;
        
        if (ticks % 200000 == 0) {
            std::cerr << "[SIM INFO] " << (ticks / 2) << " cycles elapsed...\n" << std::flush;
        }

        if ((ticks / 2) >= max_cycles) {
            std::cout << "\n[SIM INFO] Reached max cycle limit (" << max_cycles << "). Stopping simulation.\n";
            break;
        }
    }
    
    std::cout << "\n====================================================\n";
    std::cout << " Simulation finished at cycle " << (ticks / 2) << ".\n";
    std::cout << "====================================================\n" << std::endl;
    top->final();
    
    return 0;
}
