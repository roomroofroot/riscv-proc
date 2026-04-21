module top(
  input logic clk, reset,
  output logic [31:0] WriteData, DataAdr,
  output logic MemWrite
);
  logic [31:0] PC, Instr, ReadData;

  // instantiate processor and memories
  riscvsingle rvsingle(clk, reset, PC, Instr, MemWrite,
                       DataAdr, WriteData, ReadData);
  imem imem(PC, Instr);
  dmem dmem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule


module riscvsingle(
  input logic clk, reset,
  output logic [31:0] PC,
  input logic [31:0] Instr,
  output logic MemWrite,
  output logic [31:0] ALUResult, WriteData,
  input logic [31:0] ReadData
);

  logic ALUSrc, RegWrite, Jump, Zero;
  logic [1:0] ResultSrc, ImmSrc;
  logic [3:0] ALUControl;

  controller c(Instr[6:0], Instr[14:12], Instr[31:25], Zero, ResultSrc,
               MemWrite, PCSrc, ALUSrc, RegWrite, Jump, ImmSrc, ALUControl);
  datapath dp(clk, reset, ResultSrc, PCSrc, ALUSrc, RegWrite, ImmSrc,
              ALUControl, Zero, PC, Instr, ALUResult, WriteData, ReadData);

endmodule


module controller(
  input logic [6:0] op,
  input logic [2:0] funct3,
  input logic [6:0] funct7,
  input logic Zero,
  output logic [1:0] ResultSrc,
  output logic MemWrite,
  output logic PCSrc, ALUSrc,
  output logic RegWrite, Jump,
  output logic [1:0] ImmSrc,
  output logic [3:0] ALUControl
);

  logic [1:0] ALUOp;
  logic Branch;

  maindec md(op, ResultSrc, MemWrite, Branch, ALUSrc, RegWrite, Jump, ImmSrc, ALUOp);
  aludec ad(op[5], funct3, funct7, ALUOp, ALUControl);

  assign PCSrc = Branch & Zero | Jump;

endmodule


module datapath(
  input logic clk, reset,
  input logic [1:0] ResultSrc,
  input logic PCSrc, ALUSrc,
  input logic RegWrite,
  input logic [1:0] ImmSrc,
  input logic [3:0] ALUControl,
  output logic Zero,
  output logic [31:0] PC,
  input logic [31:0] Instr,
  output logic [31:0] ALUResult, WriteData,
  input logic [31:0] ReadData
);

  logic [31:0] PCNext, PCPlus4, PCTarget;
  logic [31:0] ImmExt;
  logic [31:0] SrcA, SrcB;
  logic [31:0] Result;

  // next PC logic
  flopr #(32) pcreg(clk, reset, PCNext, PC);
  adder pcadd4(PC, 32'd4, PCPlus4);
  adder pcaddbranch(PC, ImmExt, PCTarget);
  mux2 #(32) pcmux(PCPlus4, PCTarget, PCSrc, PCNext);

  // register file logic
  regfile rf(clk, RegWrite, Instr[19:15], Instr[24:20],
             Instr[11:7], Result, SrcA, WriteData);
  extend ext(Instr[31:7], ImmSrc, ImmExt);

  // ALU logic
  mux2 #(32) srcbmux(WriteData, ImmExt, ALUSrc, SrcB);
  alu alu(SrcA, SrcB, ALUControl, ALUResult, Zero);
  mux3 #(32) resultmux(ALUResult, ReadData, PCPlus4, ResultSrc, Result);

endmodule
