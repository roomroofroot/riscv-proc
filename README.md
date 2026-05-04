# riscv-proc

SystemVerilog implementations of single-cycle and pipelined RV32I processors.  

Follows the single-cycle design and pipeline architecture outlined in the RISC-V edition of  
[Digital Design and Computer Architecture](https://pages.hmc.edu/harris/ddca/) _by David and Sarah Harris_.

Along with this, a minimal SIMD implementation has been provided.

## Files
`single/core.sv` is a slightly modified single-cycle implementation from the book  
`pipeline/core.sv` is a modified rework of the pipelined processor from [another project](https://github.com/princeofyozgat/riscv)  
`common.sv` contains modules common to single/, pipeline/  
`csimd.sv` modifies common.sv to reuse components and support SIMD

## Tools and Usage
I am using `iverilog` and `gtkwave` to compile and test.  
To test either the single-cycle or pipelined processors -  
- modify test.hex (or change mem.sv to read another .hex file)
- use `iverilog` to compile the testbench, run this within `pipeline/` or `single/`  
```sh
iverilog -g2012 core.sv ../common.sv mem.sv tb.sv -o risc_sim
vvp risc_sim
gtkwave tb.vcd
```

## Supported Instructions
Most RV32I Base Integer instr., except unsigned instr. and few I-type, B-type, U-type instr.   
Also supports `mul` and `mulh` instr. from the RV32M Multiply Extension.  

To use SIMD instr., use `csimd.sv` in place of `common.sv`  

## TODO
- [ ] Proper documentation
- [ ] Test SIMD instr.
- [ ] Basic branch prediction
- [ ] Support for RISC-V [BitManip](https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html) extension (for use with SIMD)
- [ ] Make SIMD instr. compatible with RISC-V [Packed](https://www.jhauser.us/RISCV/ext-P/) extension

## References
- [Digital Design and Computer Architecture: RISC-V Edition](https://pages.hmc.edu/harris/ddca/)  
- [RISC-V Pipelined implementation](https://github.com/princeofyozgat/riscv)
- [RISC-V Reference Card](https://github.com/jameslzhu/riscv-card/releases/download/latest/riscv-card.pdf)
- [RISC-V "M" Extension](https://docs.riscv.org/reference/isa/unpriv/m-st-ext.html)
