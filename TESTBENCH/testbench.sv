
`include "design.sv"
`include "interface.sv"
`include "seq_item.sv"
`include "sequence.sv"
`include "sequencer.sv"
`include "driver.sv"
`include "monitor.sv"
`include "agent.sv"
`include "subscriber.sv"
`include "scoreboard.sv"
`include "env.sv"
`include "test.sv"

module top();

  bit clk;
  bit reset;

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
    clk   = 0;
    reset = 0;
    #20 reset = 1;
  end

  always #2 clk = ~clk;

  riscv_if riscv_if0 (.clk(clk), .reset(reset));

  riscv_wrapper dut (
    .clk   (riscv_if0.clk),
    .reset (riscv_if0.reset),
    .trap  (riscv_if0.trap),
    .pc    (riscv_if0.pc),
    .instr (riscv_if0.instr)
  );

  // ------------------------------------------------------------------
  //  Observation connections — hierarchical references are ONLY here,
  //  in the testbench top. RTL never sees these names.
  // ------------------------------------------------------------------
  assign riscv_if0.regWrite    = dut.core.regWrite_l3;
  assign riscv_if0.rd          = dut.core.rd_l3;
  assign riscv_if0.reg_wr_dat  = dut.core.reg_wr_dat;

  assign riscv_if0.mem_rd_en   = dut.core.MemRead_l2;
  assign riscv_if0.mem_wr_en   = dut.core.MemWrite_l2;
  assign riscv_if0.m_addr      = dut.core.m_addr;
  assign riscv_if0.m_rd_dat    = dut.mem.m_rd_dat;
  assign riscv_if0.m_wr_dat    = dut.core.m_wr_dat;

  // ------------------------------------------------------------------
  //  UVM kickoff
  // ------------------------------------------------------------------
  initial begin
    uvm_config_db #(virtual riscv_if)::set(uvm_root::get(), "*", "trans", riscv_if0);
    run_test("riscv_test");
  end

endmodule
