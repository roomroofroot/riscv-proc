module maindec(
  input logic [6:0] op,
  output logic [1:0] ResultSrc,
  output logic MemWrite,
  output logic Branch, ALUSrc,
  output logic RegWrite, Jump,
  output logic [1:0] ImmSrc,
  output logic [1:0] ALUOp
);
  logic [10:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump} = controls;

  always @ (*)
    case(op)
      7'b0000011: controls = 11'b1_00_1_0_01_0_00_0; // lw
      7'b0100011: controls = 11'b0_01_1_1_00_0_00_0; // sw
      7'b0110011: controls = 11'b1_xx_0_0_00_0_10_0; // R-type
      7'b1100011: controls = 11'b0_10_0_0_00_1_01_0; // beq
      7'b0010011: controls = 11'b1_00_1_0_00_0_10_0; // I-type ALU
      7'b1101111: controls = 11'b1_11_0_0_10_0_00_1; // jal
      7'b0000000: controls = 11'b0_00_0_0_00_0_00_0; // reset/nop
      default: controls = 11'bx_xx_x_x_xx_x_xx_x; // ???
    endcase
endmodule


module aludec(
  input logic opb5,
  input logic [2:0] funct3,
  input logic [6:0] funct7,
  input logic [1:0] ALUOp,
  output logic [3:0] ALUControl
);
  always @ (*)
    case(ALUOp)
      2'b00: ALUControl = 4'b0000; // addition
      2'b01: ALUControl = 4'b0001; // subtraction

      default: case(funct3) // R-type or I-type ALU

        3'b000: case({funct7, opb5})
          8'b0100000_1: ALUControl = 4'b0001; // sub
          8'b0000001_1: ALUControl = 4'b1000; // mul
          default: ALUControl = 4'b0000;      // add, addi
        endcase

        3'b001: case({funct7, opb5})
          8'b0000001_1: ALUControl = 4'b1001; // mulh
          default: ALUControl = 4'b0110;      // sll, slli
        endcase

        3'b010: ALUControl = 4'b0101;         // slt, slti

        3'b011: case(funct7)
          7'b1000000: ALUControl = 4'b1100;   // acc8
          7'b1000001: ALUControl = 4'b1101;   // acc16
          7'b1000010: ALUControl = 4'b1110;   // add8
          7'b1000011: ALUControl = 4'b1111;   // add16
          7'b1100000: ALUControl = 4'b1010;   // mul8
          7'b1100001: ALUControl = 4'b1011;   // mul16
          default: ALUControl = 4'bxxxx;
        endcase

        3'b100: ALUControl = 4'b0100;         // xor, xori
        3'b101: ALUControl = 4'b0111;         // srl, srli
        3'b110: ALUControl = 4'b0011;         // or, ori
        3'b111: ALUControl = 4'b0010;         // and, andi
        default: ALUControl = 4'bxxxx;        // ???

      endcase
    endcase
endmodule


module alu(
  input  logic [31:0] a, b,
  input  logic [3:0] alucontrol,
  output logic [31:0] result,
  output logic zero
);
  logic [31:0] condinvb, sum;
  logic sub, v;

  logic c1, c2, acc;
  logic [31:0] ans;
  logic l1, l2, mulh;
  logic [31:0] m;

  assign sub = ({alucontrol[3], alucontrol[1:0]} == 3'b001);
  assign condinvb = sub ? ~b : b; // for subtraction or slt
  assign sum = a + condinvb + sub;
  assign v = (~(sub^a[31]^b[31]) & (a[31]^sum[31]));

  assign c1 = ({alucontrol[3:2],alucontrol[0]} == 3'b110);
  assign c2 = (alucontrol[3:2] == 2'b11);
  assign acc = (alucontrol[3:1] == 3'b110);

  carry_adder c_add(a, b, c1, c2, acc, ans);

  assign l1 = (alucontrol[3:1] == 3'b101);
  assign l2 = (alucontrol[0] == 1'b0);
  assign mulh = (alucontrol[3:0] == 4'b1001);

  multiplier mul(a, b, l1, l2, mulh, m);

  always @ (*)
    case (alucontrol)
      4'b0000: result = ans;          // addition
      4'b0001: result = sum;          // subtraction
      4'b0010: result = a & b;        // and
      4'b0011: result = a | b;        // or
      4'b0100: result = a ^ b;        // xor
      4'b0101: result = sum[31]^v;    // slt
      4'b0110: result = a << b[4:0];  // sll
      4'b0111: result = a >> b[4:0];  // srl

      // extended operations
      4'b1000: result = m;            // mul
      4'b1001: result = m;            // mulh

      // SIMD operations
      4'b1010: result = m;            // mul8
      4'b1011: result = m;            // mul16
      4'b1100: result = ans;          // acc8
      4'b1101: result = ans;          // acc16
      4'b1110: result = ans;          // add8
      4'b1111: result = ans;          // add16

      default: result = 0;
    endcase

  assign zero = (result == 32'b0);
endmodule


module carry_adder(
  input logic [31:0] a, b,
  input logic c1, c2, acc,
  output logic [31:0] y
);
  logic [8:0] x0, x1, x2, x3;
  logic c8, c16, c24; // carry bits

  always @ (*) begin
    x0 = a[7:0] + b[7:0];
    c8 = ~c1 & x0[8];
    x1 = a[15:8] + b[15:8] + c8;
    c16 = ~c2 & x1[8];
    x2 = a[23:16] + b[23:16] + c16;
    c24 = ~c1 & x2[8];
    x3 = a[31:24] + b[31:24] + c24;

    if (acc & c1) y = x3[7:0] + x2[7:0] + x1[7:0] + x0[7:0];
    else if (acc) y = {x3, x2[7:0]} + {x1, x0[7:0]};
    else y = {x3[7:0], x2[7:0], x1[7:0], x0[7:0]};
  end
endmodule


module multiplier(
  input logic [31:0] a, b,
  input logic l1, l2, mulh,
  output logic [31:0] y
);
  logic [7:0] x0, x1, x2, x3;
  logic [15:0] z0, z1;
  logic [63:0] res;

  always @ (*)
    if (l1) begin
      x0 = a[7:0] * b[7:0];
      x1 = a[15:8] * b[15:8];
      x2 = a[23:16] * b[23:16];
      x3 = a[31:24] * b[31:24];
      y = {x3, x2, x1, x0};
    end
    else if (l2) begin
      z0 = a[15:0] * b[15:0];
      z1 = a[31:16] * b[31:16];
      y = {z1, z0};
    end
    else begin
      res = a*b;
      if (mulh) y = res[63:32];
      else y = res[31:0];
    end
endmodule


module adder(
  input [31:0] a, b,
  output [31:0] y
);
  assign y = a+b;
endmodule

module extend(
  input logic [31:7] instr,
  input logic [1:0] immsrc,
  output logic [31:0] immext
);
  always @ (*)
    case(immsrc)
             // I-type
      2'b00: immext = {{20{instr[31]}}, instr[31:20]};
             // S-type (stores)
      2'b01: immext = {{20{instr[31]}}, instr[31:25], instr[11:7]};
             // B-type (branches)
      2'b10: immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
             // J-type (jal)
      2'b11: immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      default: immext = 32'bx; // undefined
    endcase
endmodule

module flopr #(parameter WIDTH = 8) (
  input logic clk, reset,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else q <= d;
endmodule

module flopenr #(parameter WIDTH = 8) (
  input logic clk, reset, en,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  always_ff @(posedge clk, posedge reset)
    if (reset)  q <= 0;
    else if (en) q <= d;
endmodule

module floprc #(parameter WIDTH = 8) (
  input logic clk, reset, clear,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  always_ff @(posedge clk, posedge reset)
    if (reset) q <= 0;
    else
      if (clear) q <= 0;
      else q <= d;
endmodule

module flopenrc #(parameter WIDTH = 8) (
  input logic clk, reset, clear, en,
  input logic [WIDTH-1:0] d,
  output logic [WIDTH-1:0] q
);
  always_ff @ (posedge clk, posedge reset)
    if (reset) q <= 0;
    else if (en)
      if (clear) q <= 0;
      else q <= d;
endmodule

module mux2 #(parameter WIDTH = 8) (
  input logic [WIDTH-1:0] d0, d1,
  input logic s,
  output logic [WIDTH-1:0] y
);
  assign y = s ? d1 : d0;
endmodule

module mux3 #(parameter WIDTH = 8) (
  input logic [WIDTH-1:0] d0, d1, d2,
  input logic [1:0] s,
  output logic [WIDTH-1:0] y
);
  assign y = s[1] ? d2 : (s[0] ? d1 : d0);
endmodule

module mux4 #(parameter WIDTH = 8) (
  input logic [WIDTH-1:0] d0, d1, d2, d3,
  input logic [1:0] s,
  output logic [WIDTH-1:0] y
);
  assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule

module regfile(
  input logic clk,
  input logic we3,
  input logic [4:0] a1, a2, a3,
  input logic [31:0] wd3,
  output logic [31:0] rd1, rd2
);
  logic [31:0] rf[31:0];

  always_ff @(negedge clk)
    if (we3) rf[a3] <= wd3;

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule
