
class riscv_scoreboard extends uvm_subscriber #(riscv_out_txn);

  `uvm_component_utils(riscv_scoreboard)

  uvm_analysis_imp #(riscv_out_txn, riscv_scoreboard) sc_port;

  // reference model state
  reg [31:0] stack[31:0];   // register file  (stack[0] always 0)
  reg [31:0] mem[(2**25)-1:0];
  reg [31:0] csr[4095:0];

  // pending-check state
  reg        bflag   = 0;
  reg        m_flag  = 0;
  reg [31:0] next_pc_exp;
  reg [31:0] m_addr_exp, m_dat_exp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    sc_port = new("sc_port", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    stack[0] = 32'b0;
  endfunction


  // ------------------------------------------------------------------
  //  Main write callback — called by monitor every clock
  // ------------------------------------------------------------------
  function void write(input riscv_out_txn t);

    if (!t.regWrite && !t.mem_rd_en && !t.mem_wr_en &&
        t.instr == 32'h0) return;   // idle cycle, nothing to check

    stack[0] = 32'b0;   // x0 is hardwired zero

    // ---- 1. PC check (deferred from previous branch/jump) ----
    if (bflag) begin
      if (t.pc === next_pc_exp)
        `uvm_info("SB_PC", $sformatf("PC PASS  exp=%h obs=%h", next_pc_exp, t.pc), UVM_MEDIUM)
      else
        `uvm_error("SB_PC", $sformatf("PC FAIL  exp=%h obs=%h", next_pc_exp, t.pc))
      bflag = 0;
    end

    // ---- 2. Memory check (deferred from previous load/store) ----
    if (m_flag) begin
      check_mem(t);
      m_flag = 0;
    end

    // ---- 3. Reference model — decode and update ----
    decode_and_update(t);

    // ---- 4. Register writeback check ----
    if (t.regWrite && t.rd != 5'b0) begin
      if (t.reg_wr_dat === stack[t.rd])
        `uvm_info("SB_REG", $sformatf("REG x%0d PASS  exp=%h obs=%h",
                  t.rd, stack[t.rd], t.reg_wr_dat), UVM_MEDIUM)
      else
        `uvm_error("SB_REG", $sformatf("REG x%0d FAIL  exp=%h obs=%h",
                   t.rd, stack[t.rd], t.reg_wr_dat))
    end

  endfunction


  // ------------------------------------------------------------------
  //  Memory check helper
  // ------------------------------------------------------------------
  function void check_mem(input riscv_out_txn t);
    if ((t.m_dat === m_dat_exp) && (t.m_addr === m_addr_exp))
      `uvm_info("SB_MEM", $sformatf("MEM PASS  addr=%h dat=%h", m_addr_exp, m_dat_exp), UVM_MEDIUM)
    else
      `uvm_error("SB_MEM", $sformatf("MEM FAIL  exp_addr=%h exp_dat=%h  obs_addr=%h obs_dat=%h",
                 m_addr_exp, m_dat_exp, t.m_addr, t.m_dat))
  endfunction


  // ------------------------------------------------------------------
  //  Reference model decode — updates stack[], sets deferred flags
  // ------------------------------------------------------------------
  function void decode_and_update(input riscv_out_txn t);
    reg [31:0] op1, op2, se_imm;

    case (t.instr[6:0])

      7'b0110111: begin   // LUI
        stack[t.instr[11:7]] = {t.instr[31:12], 12'b0};
      end

      7'b0010111: begin   // AUIPC
        stack[t.instr[11:7]] = {t.instr[31:12], 12'b0} + t.pc;
      end

      7'b1101111: begin   // JAL
        stack[t.instr[11:7]] = t.pc + 32'd4;
        next_pc_exp = t.pc + $signed({{12{t.instr[31]}}, t.instr[19:12],
                                       t.instr[20], t.instr[30:21], 1'b0});
        bflag = 1;
      end

      7'b1100111: begin   // JALR
        next_pc_exp = ($signed({{21{t.instr[31]}}, t.instr[30:20]}) +
                       $signed(stack[t.instr[19:15]])) & 32'hfffffffe;
        stack[t.instr[11:7]] = t.pc + 32'd4;
        bflag = 1;
      end

      7'b1100011: begin   // BRANCH
        op1   = stack[t.instr[19:15]];
        op2   = stack[t.instr[24:20]];
        se_imm = $signed({{20{t.instr[31]}}, t.instr[7],
                           t.instr[30:25], t.instr[11:8], 1'b0});
        case (t.instr[14:12])
          3'b000: next_pc_exp = (op1 == op2)                          ? se_imm + t.pc : t.pc + 4; // BEQ
          3'b001: next_pc_exp = (op1 != op2)                          ? se_imm + t.pc : t.pc + 4; // BNE
          3'b100: next_pc_exp = ($signed(op1) <  $signed(op2))        ? se_imm + t.pc : t.pc + 4; // BLT
          3'b101: next_pc_exp = ($signed(op1) >= $signed(op2))        ? se_imm + t.pc : t.pc + 4; // BGE  (was >)
          3'b110: next_pc_exp = (op1 <  op2)                          ? se_imm + t.pc : t.pc + 4; // BLTU
          3'b111: next_pc_exp = (op1 >= op2)                          ? se_imm + t.pc : t.pc + 4; // BGEU (was >)
          default: next_pc_exp = t.pc + 4;
        endcase
        bflag = 1;
      end

      7'b0000011: begin   // LOAD
        m_addr_exp = t.instr[14] ?
                     (stack[t.instr[19:15]] + {{21{t.instr[31]}}, t.instr[30:20]}) << 2 :
                     ($signed(stack[t.instr[19:15]]) + $signed({{21{t.instr[31]}}, t.instr[30:20]})) << 2;
        case (t.instr[14:12])
          3'b000, 3'b100: begin
            stack[t.instr[11:7]] = mem[m_addr_exp] & 32'h0000_00ff;
          end
          3'b001, 3'b101: begin
            stack[t.instr[11:7]] = mem[m_addr_exp] & 32'h0000_ffff;
          end
          3'b010: begin
            stack[t.instr[11:7]] = mem[m_addr_exp];
          end
          default: stack[t.instr[11:7]] = 32'b0;
        endcase
        if (t.instr[11:7] == 5'b0) stack[t.instr[11:7]] = 32'b0;
        m_dat_exp = stack[t.instr[11:7]];
        m_flag = 1;
      end

      7'b0100011: begin   // STORE
        m_addr_exp = (stack[t.instr[19:15]] +
                      {{21{t.instr[31]}}, t.instr[30:25], t.instr[11:7]}) << 2;
        case (t.instr[14:12])
          3'b000: m_dat_exp = stack[t.instr[24:20]] & 32'h0000_00ff;
          3'b001: m_dat_exp = stack[t.instr[24:20]] & 32'h0000_ffff;
          3'b010: m_dat_exp = stack[t.instr[24:20]];
          default: m_dat_exp = 32'b0;
        endcase
        mem[m_addr_exp] = m_dat_exp;
        m_flag = 1;
      end

      7'b0010011: begin   // I-type ALU
        case (t.instr[14:12])
          3'b000: stack[t.instr[11:7]] = $signed(stack[t.instr[19:15]]) +
                                          $signed({{21{t.instr[31]}}, t.instr[30:20]});
          3'b010: stack[t.instr[11:7]] = ($signed(stack[t.instr[19:15]]) <
                                           $signed({{21{t.instr[31]}}, t.instr[30:20]})) ? 1 : 0;
          3'b011: stack[t.instr[11:7]] = (stack[t.instr[19:15]] <
                                           {{21{t.instr[31]}}, t.instr[30:20]}) ? 1 : 0;
          3'b100: stack[t.instr[11:7]] = stack[t.instr[19:15]] ^
                                          {{21{t.instr[31]}}, t.instr[30:20]};
          3'b110: stack[t.instr[11:7]] = stack[t.instr[19:15]] |
                                          {{21{t.instr[31]}}, t.instr[30:20]};
          3'b111: stack[t.instr[11:7]] = stack[t.instr[19:15]] &
                                          {{21{t.instr[31]}}, t.instr[30:20]};
          3'b001: stack[t.instr[11:7]] = stack[t.instr[19:15]] << t.instr[24:20];
          3'b101: begin
            stack[t.instr[11:7]] = stack[t.instr[19:15]] >> t.instr[24:20];
            if (t.instr[30]) stack[t.instr[11:7]][31] = stack[t.instr[19:15]][31]; // SRAI
          end
          default: stack[t.instr[11:7]] = 32'b0;
        endcase
        if (t.instr[11:7] == 5'b0) stack[t.instr[11:7]] = 32'b0;
      end

      7'b0110011: begin   // R-type ALU
        case (t.instr[14:12])
          3'b000: stack[t.instr[11:7]] = t.instr[30] ?
                  $signed(stack[t.instr[19:15]]) - $signed(stack[t.instr[24:20]]) :
                  $signed(stack[t.instr[19:15]]) + $signed(stack[t.instr[24:20]]);
          3'b010: stack[t.instr[11:7]] = ($signed(stack[t.instr[19:15]]) <
                                           $signed(stack[t.instr[24:20]])) ? 1 : 0;
          3'b011: stack[t.instr[11:7]] = (stack[t.instr[19:15]] <
                                           stack[t.instr[24:20]]) ? 1 : 0;
          3'b100: stack[t.instr[11:7]] = stack[t.instr[19:15]] ^ stack[t.instr[24:20]];
          3'b110: stack[t.instr[11:7]] = stack[t.instr[19:15]] | stack[t.instr[24:20]];
          3'b111: stack[t.instr[11:7]] = stack[t.instr[19:15]] & stack[t.instr[24:20]];
          3'b001: stack[t.instr[11:7]] = stack[t.instr[19:15]] << stack[t.instr[24:20]][4:0];
          3'b101: begin
            stack[t.instr[11:7]] = stack[t.instr[19:15]] >> stack[t.instr[24:20]][4:0];
            if (t.instr[30]) stack[t.instr[11:7]][31] = stack[t.instr[19:15]][31]; // SRA
          end
          default: stack[t.instr[11:7]] = 32'b0;
        endcase
        if (t.instr[11:7] == 5'b0) stack[t.instr[11:7]] = 32'b0;
      end

      7'b1110011: begin   // CSR / ECALL / EBREAK
        case (t.instr[14:12])
          3'b000: csr[12'h341] = t.pc;   // ECALL/EBREAK — save PC to mepc
          3'b001: begin   // CSRRW
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = stack[t.instr[19:15]];
          end
          3'b010: begin   // CSRRS
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = stack[t.instr[19:15]] | csr[t.instr[31:20]];
          end
          3'b011: begin   // CSRRC
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = ~stack[t.instr[19:15]] & csr[t.instr[31:20]];
          end
          3'b101: begin   // CSRRWI
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = {27'b0, t.instr[19:15]};
          end
          3'b110: begin   // CSRRSI
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = {27'b0, t.instr[19:15]} | csr[t.instr[31:20]];
          end
          3'b111: begin   // CSRRCI
            if (t.instr[11:7] != 5'b0) stack[t.instr[11:7]] = csr[t.instr[31:20]];
            csr[t.instr[31:20]] = ~{27'b0, t.instr[19:15]} & csr[t.instr[31:20]];
          end
          default: ;
        endcase
      end

      default: ; // FENCE etc — no state update needed

    endcase
  endfunction

endclass : riscv_scoreboard
