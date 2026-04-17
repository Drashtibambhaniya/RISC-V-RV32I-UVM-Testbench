class riscv_driver extends uvm_driver #(riscv_in_txn);

  `uvm_component_utils(riscv_driver)

  virtual riscv_if vi;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual riscv_if)::get(this, "", "trans", vi))
      `uvm_fatal("CFG", "riscv_driver: virtual interface not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    riscv_in_txn req;
    // hold instr low until reset is asserted
    vi.DRIVER.instr <= 32'h0;
    forever begin
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  task drive(input riscv_in_txn req);
    @(posedge vi.DRIVER.clk);
    vi.DRIVER.instr <= req.instr;
    if (vi.trap)
      `uvm_info("DRIVER", "TRAP asserted (EBREAK/ECALL)", UVM_MEDIUM)
  endtask

endclass : riscv_driver
