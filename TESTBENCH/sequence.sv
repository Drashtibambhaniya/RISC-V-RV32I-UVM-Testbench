
class riscv_sequence extends uvm_sequence #(riscv_in_txn);

  `uvm_object_utils(riscv_sequence)

  riscv_in_txn trans;
  reg [4:0]  i;

  function new(string name = "riscv_sequence");
    super.new(name);
  endfunction

  task body();

    // ---- Step 1: load all 32 registers with known values via ADDI x[i], x0, i ----
    i = 0;
    repeat (32) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.instr = {12'b0, 5'b0, 3'b000, i, 7'b0010011};  // ADDI rd=i, rs1=x0, imm=0
      ++i;
      start_item(trans); finish_item(trans);
    end

    // ---- Step 2: U-type (LUI, AUIPC) ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b0110111, 7'b0010111}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 3: R-type ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b0110011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 4: I-type ALU ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b0010011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 5: STORE ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b0100011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 6: LOAD ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b0000011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 7: BRANCH ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b1100011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 8: JUMP ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b1100111, 7'b1101111}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 9: CSR ----
    repeat (20) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.randomize with { instr[6:0] inside {7'b1110011}; };
      start_item(trans); finish_item(trans);
    end

    // ---- Step 10: re-read all regs (ADDI x[i], x[i], 0) to verify final state ----
    i = 0;
    repeat (32) begin
      trans = riscv_in_txn::type_id::create("trans");
      trans.instr = {12'b0, i, 3'b000, i, 7'b0010011};  // ADDI rd=i, rs1=i, imm=0
      ++i;
      start_item(trans); finish_item(trans);
    end

  endtask

endclass : riscv_sequence
