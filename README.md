# riscv-proc

Implementing single-cycle, pipelined variants of an RV32 processor in SystemVerilog.  

Follows the single-cycle design and pipeline architecture outlined in the RISC-V edition of  
[Digital Design and Computer Architecture](https://pages.hmc.edu/harris/ddca/) _by David and Sarah Harris_.

Along with this, a minimal SIMD implementation has been provided.

## Files
`single/core.sv` - slightly modified single-cycle implementation from the book  
`pipeline/core.sv` - pipelined implementation, modified version of [another project](https://github.com/princeofyozgat/riscv)  
`common.sv` - modules common to `single/`, `pipeline/`  
`csimd.sv` - `common.sv`, but with SIMD support while reusing components

## Tools and Usage
I've used `iverilog` and `gtkwave` to compile and test  
To test, modify `test.hex` (or change `mem.sv` to read another hexfile)  
Run the following within `single/` or `pipeline/`
```sh
iverilog -g2012 core.sv ../csimd.sv mem.sv tb.sv -o risc_sim
vvp risc_sim
gtkwave tb.vcd
```
**Note**: `single/tb.sv` uses the default testbench provided in H&H, if needed swap out with `pipeline/tb.sv`

## Supported Instructions
- Most RV32I Base Integer instr., except unsigned, U-type, and a few I-type and B-type
- `mul` and `mulh` from the RV32M Multiply Extension  
**Note**: these instr. execute in 1 cycle, like in some digital signal processors (not realistic for general processors).
- Basic SIMD unsigned instr. (to use SIMD, use `csimd.sv` in place of `common.sv`)  
Refer to `csimd.sv` for instruction encoding details  
**Note**: SIMD instructions reuse encodings of unsigned R-type, considering they aren't implemented yet. (see TODO)  

## TODO
- [ ] Basic branch prediction
- [ ] Compatibility with RISC-V [Packed](https://www.jhauser.us/RISCV/ext-P/) extension (SIMD)
- [ ] Support for RISC-V [BitManip](https://docs.riscv.org/reference/isa/unpriv/b-st-ext.html) extension (for use with SIMD)

## References
- [Digital Design and Computer Architecture: RISC-V Edition](https://pages.hmc.edu/harris/ddca/)  
- [RISC-V Docs](https://docs.riscv.org/reference/isa/unpriv/unpriv-index.html)
- [RISC-V Pipelined implementation](https://github.com/princeofyozgat/riscv)
- [RISC-V Reference Card](https://github.com/jameslzhu/riscv-card/releases/download/latest/riscv-card.pdf)
