
interface riscv_if(input clk, input reset);

  // ---- driven by DUT (primary outputs) ----
  logic        trap;
  logic [31:0] pc;
  logic [31:0] instr;

  // ---- observation signals (assigned in testbench top via hierarchical ref) ----
  logic        regWrite;
  logic [4:0]  rd;
  logic [31:0] reg_wr_dat;

  logic        mem_rd_en;
  logic        mem_wr_en;
  logic [31:0] m_addr;
  logic [31:0] m_rd_dat;
  logic [31:0] m_wr_dat;

  // ---- clocking blocks ----
  clocking driver_cb @(posedge clk);
    output instr;
    input  trap;
    input  pc;
  endclocking

  clocking monitor_cb @(posedge clk);
    input instr;
    input pc;
    input trap;
    input regWrite;
    input rd;
    input reg_wr_dat;
    input mem_rd_en;
    input mem_wr_en;
    input m_addr;
    input m_rd_dat;
    input m_wr_dat;
  endclocking

  modport DRIVER  (clocking driver_cb,  input clk, reset);
  modport MONITOR (clocking monitor_cb, input clk, reset);

endinterface : riscv_if
