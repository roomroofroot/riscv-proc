module top(
  input logic clk, reset,
  output logic [31:0] WriteData_m, DataAdr_m,
  output logic MemWrite_m
);
  logic [31:0] PC_f, Instr_f, ReadData_m;

  // instantiate processor and memories
  riscv riscv(clk, reset, PC_f, Instr_f, MemWrite_m,
              DataAdr_m, WriteData_m, ReadData_m);
  imem imem(PC_f, Instr_f);
  dmem dmem(clk, MemWrite_m, DataAdr_m, WriteData_m, ReadData_m);
endmodule


module riscv(
  input logic clk, reset,
  output logic [31:0] PC_f,
  input logic [31:0] Instr_f,
  output logic MemWrite_m,
  output logic [31:0] ALUResult_m, WriteData_m,
  input logic [31:0] ReadData_m
);

  logic [6:0] op_d;
  logic [2:0] f3_d, f3_e;
  logic [6:0] f7_d;
  logic [1:0] ImmSrc_d;
  logic Zero_e, PCSrc_e;
  logic [3:0] ALUControl_e;
  logic ALUSrc_e, ResultSrcb0_e, RegWrite_m;
  logic [1:0] ResultSrc_w;
  logic RegWrite_w;
  logic [1:0] forward_ae, forward_be;
  logic stall_f, stall_d, flush_d, flush_e;
  logic [4:0] rs1_d, rs2_d, rs1_e, rs2_e, rd_e, rd_m, rd_w;
  
  controller c(clk, reset, op_d, f3_d, f7_d, ImmSrc_d, flush_e, Zero_e, PCSrc_e,
               ALUControl_e, ALUSrc_e, ResultSrcb0_e, MemWrite_m, RegWrite_m,
               RegWrite_w, ResultSrc_w);
  datapath dp(clk, reset, stall_f, PC_f, Instr_f, op_d, f3_d, f7_d, stall_d,
              flush_d, ImmSrc_d, flush_e, forward_ae, forward_be, PCSrc_e,
              ALUControl_e, ALUSrc_e, Zero_e, f3_e, MemWrite_m, WriteData_m,
              ALUResult_m, ReadData_m, RegWrite_w, ResultSrc_w,
              rs1_d, rs2_d, rs1_e, rs2_e, rd_e, rd_m, rd_w);

  hazard hu(rs1_d, rs2_d, rs1_e, rs2_e, rd_e, rd_m, rd_w,
            PCSrc_e, ResultSrcb0_e, RegWrite_m, RegWrite_w,
            forward_ae, forward_be, stall_f, stall_d, flush_d, flush_e);

endmodule


module controller(
  input logic clk, reset,
  input logic [6:0] op_d,
  input logic [2:0] f3_d,
  input logic [6:0] f7_d,
  output logic [1:0] ImmSrc_d,
  input logic flush_e, Zero_e,
  output logic PCSrc_e,
  output logic [3:0] ALUControl_e,
  output logic ALUSrc_e,
  output logic ResultSrcb0_e,
  output logic MemWrite_m, RegWrite_m,
  output logic RegWrite_w,
  output logic [1:0] ResultSrc_w
);

  logic RegWrite_d, RegWrite_e;
  logic [1:0] ResultSrc_d, ResultSrc_e, ResultSrc_m;
  logic MemWrite_d, MemWrite_e;
  logic Jump_d, Jump_e, Branch_d, Branch_e;
  logic [1:0] ALUOp_d;
  logic [3:0] ALUControl_d;
  logic ALUSrc_d;

  maindec md(op_d, ResultSrc_d, MemWrite_d, Branch_d, ALUSrc_d, RegWrite_d,
             Jump_d, ImmSrc_d, ALUOp_d);
  aludec ad(op_d[5], f3_d, f7_d, ALUOp_d, ALUControl_d);

  floprc #(11) controlreg_e(clk, reset, flush_e,
                            {RegWrite_d, ResultSrc_d, MemWrite_d, Jump_d, Branch_d, ALUControl_d, ALUSrc_d},
                            {RegWrite_e, ResultSrc_e, MemWrite_e, Jump_e, Branch_e, ALUControl_e, ALUSrc_e});

  assign PCSrc_e = Branch_e & Zero_e | Jump_e;
  assign ResultSrcb0_e = ResultSrc_e[0];

  flopr #(4) controlreg_m(clk, reset,
                          {RegWrite_e, ResultSrc_e, MemWrite_e},
                          {RegWrite_m, ResultSrc_m, MemWrite_m});
  flopr #(3) controlreg_w(clk, reset,
                          {RegWrite_m, ResultSrc_m},
                          {RegWrite_w, ResultSrc_w});

endmodule


module datapath(
  input logic clk, reset,
// IF
  input logic stall_f,
  output logic [31:0] PC_f,
  input logic [31:0] Instr_f,
// ID
  output logic [6:0] op_d,
  output logic [2:0] f3_d,
  output logic [6:0] f7_d,
  input logic stall_d, flush_d,
  input logic [1:0] ImmSrc_d,
// EX
  input logic flush_e,
  input logic [1:0] forward_ae, forward_be,
  input logic PCSrc_e,
  input logic [3:0] ALUControl_e,
  input logic ALUSrc_e,
  output logic Zero_e,
  output logic [2:0] f3_e,
// MEM
  input logic MemWrite_m,
  output logic [31:0] WriteData_m, ALUResult_m,
  input logic [31:0] ReadData_m,
// WB
  input logic RegWrite_w,
  input logic [1:0] ResultSrc_w,
// Hazard
  output logic [4:0] rs1_d, rs2_d, rs1_e, rs2_e,
  output logic [4:0] rd_e, rd_m, rd_w
);

// IF
  logic [31:0] PCPlus4_f, PCNext_f;
// ID
  logic [31:0] Instr_d, PC_d, PCPlus4_d;
  logic [31:0] rd1_d, rd2_d;
  logic [31:0] ImmExt_d;
  logic [4:0] rd_d;
// EX
  logic [31:0] rd1_e, rd2_e, PC_e, ImmExt_e;
  logic [31:0] SrcA_e, SrcB_e;
  logic [31:0] ALUResult_e, WriteData_e;
  logic [31:0] PCPlus4_e, PCTarget_e;
// MEM
  logic [31:0] PCPlus4_m, PCTarget_m;
// WB
  logic [31:0] ALUResult_w, ReadData_w;
  logic [31:0] PCPlus4_w, PCTarget_w, Result_w;

// IF
  mux2 #(32) pcmux(PCPlus4_f, PCTarget_e, PCSrc_e, PCNext_f);
  flopenr #(32) pcreg(clk, reset, ~stall_f, PCNext_f, PC_f);
  adder pcadd(PC_f, 32'd4, PCPlus4_f);

// ID
  flopenrc #(96) reg_d(clk, reset, flush_d, ~stall_d,
                       {Instr_f, PC_f, PCPlus4_f},
                       {Instr_d, PC_d, PCPlus4_d});
  assign op_d = Instr_d[6:0];
  assign f3_d = Instr_d[14:12];
  assign f7_d = Instr_d[31:25];
  assign rs1_d = Instr_d[19:15];
  assign rs2_d = Instr_d[24:20];
  assign rd_d = Instr_d[11:7];

  regfile rf(clk, RegWrite_w, rs1_d, rs2_d, rd_w, Result_w, rd1_d, rd2_d);
  extend ext(Instr_d[31:7], ImmSrc_d, ImmExt_d);

  floprc #(178) reg_e(clk, reset, flush_e,
                      {rd1_d, rd2_d, PC_d, rs1_d, rs2_d, rd_d, ImmExt_d, PCPlus4_d, f3_d},
                      {rd1_e, rd2_e, PC_e, rs1_e, rs2_e, rd_e, ImmExt_e, PCPlus4_e, f3_e});

  mux3 #(32) famux_e(rd1_e, Result_w, ALUResult_m, forward_ae, SrcA_e);
  mux3 #(32) fbmux_e(rd2_e, Result_w, ALUResult_m, forward_be, WriteData_e);
  mux2 #(32) srcbmux(WriteData_e, ImmExt_e, ALUSrc_e, SrcB_e);
  alu alu(SrcA_e, SrcB_e, ALUControl_e, ALUResult_e, Zero_e);
  adder branchadd(ImmExt_e, PC_e, PCTarget_e);

  flopr #(133) reg_m(clk, reset,
                     {ALUResult_e, WriteData_e, rd_e, PCTarget_e, PCPlus4_e},
                     {ALUResult_m, WriteData_m, rd_m, PCTarget_m, PCPlus4_m});
  flopr #(133) reg_w(clk, reset,
                     {ALUResult_m, ReadData_m, rd_m, PCTarget_m, PCPlus4_m},
                     {ALUResult_w, ReadData_w, rd_w, PCTarget_w, PCPlus4_w});
  mux4 #(32) resmux(ALUResult_w, ReadData_w, PCPlus4_w, PCTarget_w, ResultSrc_w, Result_w);

endmodule


module hazard(
  input logic [4:0] rs1_d, rs2_d, rs1_e, rs2_e, rd_e, rd_m, rd_w,
  input logic PCSrc_e, ResultSrcb0_e,
  input logic RegWrite_m, RegWrite_w,
  output logic [1:0] forward_ae, forward_be,
  output logic stall_f, stall_d, flush_d, flush_e
);

  logic lwstall_d;

  always @ (*) begin
    forward_ae = 2'b00;
    forward_be = 2'b00;
    if (rs1_e != 5'b0)
      if ((rs1_e == rd_m) & RegWrite_m) forward_ae = 2'b10;
      else if ((rs1_e == rd_w) & RegWrite_w) forward_ae = 2'b01;
    if (rs2_e != 5'b0)
      if ((rs2_e == rd_m) & RegWrite_m) forward_be = 2'b10;
      else if ((rs2_e == rd_w) & RegWrite_w) forward_be = 2'b01;
  end

  assign lwstall_d = ResultSrcb0_e & (rd_e != 0) & ((rs1_d == rd_e) | (rs2_d == rd_e));
  assign stall_d = lwstall_d;
  assign stall_f = lwstall_d;
  assign flush_d = PCSrc_e;
  assign flush_e = lwstall_d | PCSrc_e;

endmodule
