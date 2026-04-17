
class riscv_monitor extends uvm_monitor;

  `uvm_component_utils(riscv_monitor)

  uvm_analysis_port #(riscv_out_txn) m_port;

  virtual riscv_if inf;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_port = new("m_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "trans", inf))
      `uvm_fatal("CFG", "riscv_monitor: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    riscv_out_txn txn;
    forever begin
      @(posedge inf.MONITOR.clk);

      txn = riscv_out_txn::type_id::create("txn");

      txn.instr      = inf.MONITOR.instr;
      txn.pc         = inf.MONITOR.pc;
      txn.regWrite   = inf.MONITOR.regWrite;
      txn.rd         = inf.MONITOR.rd;
      txn.reg_wr_dat = inf.MONITOR.reg_wr_dat;
      txn.mem_rd_en  = inf.MONITOR.mem_rd_en;
      txn.mem_wr_en  = inf.MONITOR.mem_wr_en;
      txn.m_addr     = inf.MONITOR.m_addr;
      // select the relevant data word
      txn.m_dat      = inf.MONITOR.mem_wr_en ? inf.MONITOR.m_wr_dat
                                              : inf.MONITOR.m_rd_dat;

      m_port.write(txn);
    end
  endtask

endclass : riscv_monitor
