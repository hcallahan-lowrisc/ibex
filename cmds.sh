# /home/harrycallahan/projects/ibex/examples/simple_system/README.md

fusesoc --cores-root=. run --target=sim --setup --build lowrisc:ibex:ibex_simple_system --RV32E=0 --RV32M=ibex_pkg::RV32MFast
make -C examples/sw/simple_system/hello_test
./build/lowrisc_ibex_ibex_simple_system_0/sim-verilator/Vibex_simple_system [-t] --meminit=ram,./examples/sw/simple_system/hello_test/hello_test.elf
