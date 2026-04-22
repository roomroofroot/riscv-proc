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

        3'b000: case(funct7)
          7'b0100000: ALUControl = 4'b0001; // sub
          7'b0000001: ALUControl = 4'b1000; // mul
          default: ALUControl = 4'b0000;    // add, addi
        endcase
        3'b001: case(funct7)
          7'b0000001: ALUControl = 4'b1001; // mulh
          default: ALUControl = 4'b0110;    // sll
        endcase
        3'b010: ALUControl = 4'b0101;       // slt, slti
        3'b100: ALUControl = 4'b0100;       // xor, xori
        3'b101: ALUControl = 4'b0111;       // srl
        3'b110: ALUControl = 4'b0011;       // or, ori
        3'b111: ALUControl = 4'b0010;       // and, andi
        default: ALUControl = 4'bxxxx;      // ???

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
  logic [63:0] m;
  logic [31:0] mlo, mhi;

  assign sub = ({alucontrol[3], alucontrol[1:0]} == 3'b001);
  assign condinvb = sub ? ~b : b; // for subtraction or slt
  assign sum = a + condinvb + sub;
  assign v = (~(sub^a[31]^b[31]) & (a[31]^sum[31]));

  assign m = a*b;
  assign mlo = m[31:0];
  assign mhi = m[63:32];

  always @ (*)
    case (alucontrol)
      4'b0000: result = sum;          // addition
      4'b0001: result = sum;          // subtraction
      4'b0010: result = a & b;        // and
      4'b0011: result = a | b;        // or
      4'b0100: result = a ^ b;        // xor
      4'b0101: result = sum[31]^v;    // slt
      4'b0110: result = a << b[4:0];  // sll
      4'b0111: result = a >> b[4:0];  // srl

      // extended operations
      4'b1000: result = mlo;          // mul
      4'b1001: result = mhi;          // mulh

      default: result = 0;
  endcase

  assign zero = (result == 32'b0);
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
