# RMT + Freelist for TinyBOOM Project

## The subproject is part of a greater personal project named TinyBOOM, which is a 32-bit Out of Order RISC RV32I+M Processor based on Berkley's BOOM.

 **A Rename Map Table (RMT)** is a table that holds the maps of architectural registers to physical registers, and is integral for out of order CPU architecture. instead of each register used in an instruction begin used literally which introduces many write after write (WAW) and write after read (WAR) hazards, the RMT maps each architectural register (essentially written in assembly code), and assigns it to the most convenient physical register, evading all WAW and WAW hazards as long as physical registers are available in the freelist

 The **freelist** is a FIFO buffer that holds the available physical registers and, on request from the RMT when an instruction needs a new physical address, pops a known free physical register to be used in the physical respresentation of a given architectural instruction. The freelist recieves new physical registers when instructions are retired futher down the pipeline.

## Features

* Two-wide RMT
* Two-wide freelist
* Checkpoint/Restore

## Tools

* Verilator 5.043
* GTKWave

## How to Run

This respository includes SystemVerilog and C++ testbenches, the latter of which includes a software model of the RMT and Freelist for self-checking functionality.
Both the *tb/rmt* and *tb_c/rmt* folder include shell scripts that can be executed to automatically compile and run the complete testbenches. Waveforms will be outputed will you can view. 

## References

[Boom Documentation](https://docs.boom-core.org/en/latest/)

Copyright © 2026 Robert Freeman

All rights reserved.

This project is open-source and shared for educational and portfolio demonstration purposes.

You are welcome to reference the design for learning, but please do not reproduce, redistribute, or commercialize this work without permission.  
