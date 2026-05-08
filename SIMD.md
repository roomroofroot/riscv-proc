# SIMD Details
Currently implements `acc8`, `acc16`, `add8`, `add16`, `mul8`, `mul16`

## Encoding details
R-type unsigned encodings are reused for these instructions.

| Instruction | funct3 | funct7 |
|---|---|---|
| `acc8` | 011 | 1000000 | 
| `acc16` | 011 | 1000001 | 
| `add8` | 011 | 1000010 | 
| `add16` | 011 | 1000011 | 
| `mul8` | 011 | 1100000 | 
| `mul16` | 011 | 1100001 |

## Implementation details
- `add`, `add8`, `add16`, `acc8`, `acc16` use the `carry_adder` module, which has 4 separate byte-adders instead of a single 32-bit adder.
2 bits `c1`, `c2` are passed to this module to decide whether to carry forward at each byte interval.
`acc8` and `acc16` (accumulate functions) can reuse these byte-adders as well.
- `mul`, `mulh`, `mul8`, `mul16` use the `multiplier` module, which is not yet synthesizable. These execute in 1 cycle (suitable for DSP-grade multipliers)

Refer to `csimd.sv` for more details
