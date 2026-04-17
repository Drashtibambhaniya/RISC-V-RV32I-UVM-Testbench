
// ============================================================
//  riscv_in_txn  — stimulus only (driver sends this)
// ============================================================
class riscv_in_txn extends uvm_sequence_item;

  `uvm_object_utils(riscv_in_txn)

  rand logic [31:0] instr;

  // ---- valid opcode constraint ----
  constraint c_opcode {
    instr[6:0] inside {
      7'b0110111, 7'b0010111, 7'b1101111, 7'b1100111,
      7'b1100011, 7'b0000011, 7'b0100011, 7'b0010011,
      7'b0110011, 7'b0001111, 7'b1110011
    };
  }

  // ---- valid funct3 per opcode ----
  constraint c_funct {
    (instr[6:0] == 7'b1100111) -> (instr[14:12] inside {3'b000});
    (instr[6:0] == 7'b1100011) -> (instr[14:12] inside {3'b000,3'b001,3'b100,3'b101,3'b110,3'b111});
    (instr[6:0] == 7'b0000011) -> (instr[14:12] inside {3'b000,3'b001,3'b010,3'b100,3'b101});
    (instr[6:0] == 7'b0100011) -> (instr[14:12] inside {3'b000,3'b001,3'b010});
    ((instr[6:0] == 7'b0010011) & (instr[13:12] == 2'b01)) ->
                                  (instr[31:25] inside {7'b0000000, 7'b0100000});
    (instr[6:0] == 7'b0110011) -> (instr[31:25] inside {7'b0000000, 7'b0100000});
    (instr[6:0] == 7'b1110011) -> (instr[14:12] inside {3'b000,3'b001,3'b010,3'b011,3'b101,3'b110,3'b111});
    ((instr[6:0] == 7'b1110011) & (instr[14:12] == 3'b000)) ->
                                  (instr[31:7] inside {25'b0000000000000000000000000,
                                                       25'b0000000000010000000000000});
    (instr[6:0] == 7'b0001111) -> (instr[14:12] inside {3'b000,3'b001});
  }

  function new(string name = "riscv_in_txn");
    super.new(name);
  endfunction

  function string convert2string;
    string instr_name;
    case (instr[6:0])
      7'b0110111 : instr_name = "LUI";
      7'b0010111 : instr_name = "AUIPC";
      7'b1101111 : instr_name = "JAL";
      7'b1100111 : instr_name = "JALR";
      7'b1100011 :
        case (instr[14:12])
          3'b000 : instr_name = "BEQ";
          3'b001 : instr_name = "BNE";
          3'b100 : instr_name = "BLT";
          3'b101 : instr_name = "BGE";
          3'b110 : instr_name = "BLTU";
          3'b111 : instr_name = "BGEU";
          default: instr_name = "B?";
        endcase
      7'b0000011 :
        case (instr[14:12])
          3'b000 : instr_name = "LB";
          3'b001 : instr_name = "LH";
          3'b010 : instr_name = "LW";
          3'b100 : instr_name = "LBU";
          3'b101 : instr_name = "LHU";
          default: instr_name = "L?";
        endcase
      7'b0100011 :
        case (instr[14:12])
          3'b000 : instr_name = "SB";
          3'b001 : instr_name = "SH";
          3'b010 : instr_name = "SW";
          default: instr_name = "S?";
        endcase
      7'b0010011 :
        case (instr[14:12])
          3'b000 : instr_name = "ADDI";
          3'b010 : instr_name = "SLTI";
          3'b011 : instr_name = "SLTIU";
          3'b100 : instr_name = "XORI";
          3'b110 : instr_name = "ORI";
          3'b111 : instr_name = "ANDI";
          3'b001 : instr_name = "SLLI";
          3'b101 : instr_name = instr[30] ? "SRAI" : "SRLI";
          default: instr_name = "I?";
        endcase
      7'b0110011 :
        case (instr[14:12])
          3'b000 : instr_name = instr[30] ? "SUB" : "ADD";
          3'b010 : instr_name = "SLT";
          3'b011 : instr_name = "SLTU";
          3'b100 : instr_name = "XOR";
          3'b110 : instr_name = "OR";
          3'b111 : instr_name = "AND";
          3'b001 : instr_name = "SLL";
          3'b101 : instr_name = instr[30] ? "SRA" : "SRL";
          default: instr_name = "R?";
        endcase
      7'b0001111 : instr_name = instr[12] ? "FENCE.I" : "FENCE";
      7'b1110011 :
        case (instr[14:12])
          3'b000 : instr_name = instr[20] ? "EBREAK" : "ECALL";
          3'b001 : instr_name = "CSRRW";
          3'b010 : instr_name = "CSRRS";
          3'b011 : instr_name = "CSRRC";
          3'b101 : instr_name = "CSRRWI";
          3'b110 : instr_name = "CSRRSI";
          3'b111 : instr_name = "CSRRCI";
          default: instr_name = "CSR?";
        endcase
      default : instr_name = "UNKNOWN";
    endcase
    return $sformatf("INSTR=%h  TYPE=%-6s  rd=x%0d", instr, instr_name, instr[11:7]);
  endfunction

endclass : riscv_in_txn


// ============================================================
//  riscv_out_txn  — what the monitor observes from the DUT
// ============================================================
class riscv_out_txn extends uvm_sequence_item;

  `uvm_object_utils(riscv_out_txn)

  // instruction that produced these outputs (for reference model decode)
  logic [31:0] instr;
  logic [31:0] pc;

  // register writeback
  logic        regWrite;
  logic [4:0]  rd;
  logic [31:0] reg_wr_dat;

  // memory access
  logic        mem_rd_en;
  logic        mem_wr_en;
  logic [31:0] m_addr;
  logic [31:0] m_dat;    // m_wr_dat when write, m_rd_dat when read

  function new(string name = "riscv_out_txn");
    super.new(name);
  endfunction

  function string convert2string;
    return $sformatf(
      "PC=%h INSTR=%h | regWrite=%0b rd=x%0d wr_dat=%h | mem_rd=%0b mem_wr=%0b addr=%h dat=%h",
      pc, instr, regWrite, rd, reg_wr_dat, mem_rd_en, mem_wr_en, m_addr, m_dat);
  endfunction

endclass : riscv_out_txn
