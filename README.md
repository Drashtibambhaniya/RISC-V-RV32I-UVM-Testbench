RISC-V RV32I Functional Verification — UVM Testbench

A layered UVM testbench for functional verification of a pipelined RV32I processor with CSR extension support.

* Design Under Test

The DUT is a pipelined RISC-V processor implementing the RV32I base integer ISA, structured as a wrapper around three sub-modules:

| Sub-module | Description |
|------------|-------------|
| `riscv_core` | 3-stage pipeline — IF, ID/EX, WB |
| `cs_reg` | CSR register file |
| `data_memory` | Word-addressable data memory |

**Instruction set coverage:**

| Category | Instructions |
|----------|-------------|
| U-type | LUI, AUIPC |
| Jump | JAL, JALR |
| Branch | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| Load | LB, LH, LW, LBU, LHU |
| Store | SB, SH, SW |
| I-type ALU | ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI |
| R-type ALU | ADD, SUB, SLT, SLTU, XOR, OR, AND, SLL, SRL, SRA |
| CSR | CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI |
| System | ECALL, EBREAK, FENCE |

---

## Testbench Architecture
┌─────────────────────────────────────────────────┐
│                  riscv_test                     │
│  ┌───────────────────────────────────────────┐  │
│  │               riscv_env                   │  │
│  │  ┌─────────────────────┐  ┌────────────┐  │  │
│  │  │     riscv_agent     │  │ scoreboard │  │  │
│  │  │  ┌───────────────┐  │  └─────▲──────┘  │  │
│  │  │  │   sequencer   │  │        │          │  │
│  │  │  └──────┬────────┘  │  ┌─────┴──────┐  │  │
│  │  │  ┌──────▼────────┐  │  │  coverage  │  │  │
│  │  │  │    driver     │  │  └─────▲──────┘  │  │
│  │  │  └──────┬────────┘  │        │          │  │
│  │  │  ┌──────▼────────┐  │  ┌─────┴──────┐  │  │
│  │  │  │    monitor    ├──┼──►  analysis   │  │  │
│  │  │  └───────────────┘  │  │    port     │  │  │
│  │  └─────────────────────┘  └────────────┘  │  │
│  └───────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │    riscv_if        │  ← clocking blocks
              │  (interface)       │    driver_cb / monitor_cb
              └─────────┬──────────┘
                        │  hierarchical assigns (testbench top only)
              ┌─────────▼──────────┐
              │   riscv_wrapper    │  ← pure RTL, no TB dependencies
              │   (DUT)            │
              └────────────────────┘

## File Structure


├── rtl/
│   └── design.sv          # DUT: riscv_wrapper, riscv_core, ALU, memories, control
│
├── tb/
│   ├── interface.sv        # riscv_if — clocking blocks, observation signals
│   ├── seq_item.sv         # riscv_in_txn + riscv_out_txn
│   ├── sequence.sv         # riscv_sequence — directed + constrained-random stimulus
│   ├── sequencer.sv        # riscv_sequencer
│   ├── driver.sv           # riscv_driver — drives instr via clocking block
│   ├── monitor.sv          # riscv_monitor — samples full out_txn each clock
│   ├── agent.sv            # riscv_agent
│   ├── scoreboard.sv       # riscv_scoreboard — RV32I+CSR reference model
│   ├── subscriber.sv       # riscv_coverage — functional coverage
│   ├── env.sv              # riscv_env
│   ├── test.sv             # riscv_test
│   └── testbench.sv        # top — DUT instantiation + hierarchical assigns
│
└── README.md

## Stimulus Strategy

The test sequence runs in phases to ensure register state is known before dependent instructions execute:

1. **Register initialisation** — ADDI `x[i], x0, 0` for all 32 registers
2. **U-type** — LUI, AUIPC with random immediates
3. **R-type** — all 10 operations with random rs1/rs2
4. **I-type ALU** — all 9 operations with constrained immediates
5. **Store** — SB, SH, SW to randomised addresses
6. **Load** — LB, LH, LW, LBU, LHU from previously stored addresses
7. **Branch** — all 6 conditions, both taken and not-taken paths
8. **Jump** — JAL, JALR with constrained targets
9. **CSR** — CSRRW, CSRRS, CSRRC and immediate variants
10. **Register readback** — ADDI `x[i], x[i], 0` to verify final register state

Constraints in `riscv_in_txn` enforce legal opcode/funct3 combinations for every instruction type.

---

## Scoreboard — Reference Model

The scoreboard maintains a shadow copy of the processor state:

- **Register file** — 32 × 32-bit entries, x0 hardwired to zero
- **Data memory** — mirrors DUT memory, updated on every store
- **CSR file** — tracks all CSR read-modify-write operations

Checks performed on every observed transaction:

| Check | Trigger | Method |
|-------|---------|--------|
| Register writeback | `regWrite` asserted | Compare `reg_wr_dat` vs predicted |
| PC after branch/jump | Next instruction | Deferred `bflag` mechanism |
| Memory address + data | `mem_rd_en` or `mem_wr_en` | Deferred `m_flag` mechanism |

All mismatches reported via `` `uvm_error `` — simulation exits non-zero on any failure.

## Functional Coverage

Covergroup `instructions` in `riscv_coverage`:

| Coverpoint | Description |
|------------|-------------|
| `c_instr` | All 11 opcode bins |
| `c_funct` | funct3 field (0–7) |
| `c_cross` | opcode × funct3 — legal combination coverage |
| `cp_regwrite` | Register writeback toggle |
| `cp_rd` | x0 vs non-zero destination |
| `cp_mem_rd` | Load enable |
| `cp_mem_wr` | Store enable |


## Work in Progress

SVA assertions — PC increment, trap conditions, memory mutual exclusion
Pipeline latency alignment in scoreboard (instruction-to-writeback skew)
Deeper coverage — branch taken/not-taken, immediate edge values, shift corner cases
