module testbench();

  logic clk;
  logic reset;
  logic [31:0] WriteData, DataAdr;
  logic MemWrite;

  // instantiate device to be tested
  top dut(clk, reset, WriteData, DataAdr, MemWrite);

  // initialize test
  initial
    begin
      $dumpfile ("tb.vcd");
      $dumpvars (0, testbench);
      reset <= 1; # 12; reset <= 0;
      #10000;
      $finish;
  end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
  end

endmodule
