module riscv_wrapper(
	input clk,
	input reset,
	output trap,
  	output [31:0] pc,
  	input [31:0] instr
);
  
  wire [31:0]csr_wr_data, csr_rd_data, m_addr, m_rd_dat, m_wr_dat;
  wire [11:0]csr_rd_addr, csr_wr_addr;
  
  riscv_core core(
    		.clk(clk),.reset(reset),
                 
    		.pc(pc),.instr_in(instr),
     
    		.trap(trap),
                        
            .csr_rd(csr_rd),
    		.csr_wr(csr_wr),
            .csr_rd_addr(csr_rd_addr),
    		.csr_wr_addr(csr_wr_addr),
            .csr_wr_data(csr_wr_data),
            .csr_rd_data(csr_rd_data),
            
            .MemRead_l2(rd_en),
    		.MemWrite_l2(wr_en),
            .m_addr(m_addr),
            .m_wr_dat(m_wr_dat),
            .m_rd_dat(m_rd_dat)
           );

/* IM ins_mem(.clk(clk),
            .reset(reset),
            .pc(pc),
            .instr(instr_in)
           );
*/
  
cs_reg csre(.clk(clk),
            .reset(reset),       
            .csr_rd(csr_rd),
    		.csr_wr(csr_wr),
            .rd_addr(csr_rd_addr),
            .rd_dat(csr_rd_data),
            .wr_addr(csr_wr_addr),
            .wr_dat(csr_wr_data)
           );
  
data_memory mem(.clk(clk),
             .reset(reset),
             .m_addr(m_addr),
             .m_wr_dat(m_wr_dat),
             .rd_en(rd_en),
             .wr_en(wr_en),
             .m_rd_dat(m_rd_dat)
            );
  
  
/*  
  always @(pc) begin
  $display("PC          = %d  ",pc);
  $display("Reset       = %d  ",reset);
  $display("Instruction = 0x%h  ",instr);
  $display("ALU output  = %d  ",m_addr); 
//  if (MemWrite) $display("Data 0x%h written to address %d",m_wr_dat, m_addr);
    $display("---------------------------------------------------------------");
end
  */
/*  always @(pc) begin
    $display("PC = %h : instr = %h", pc, instr);
  end*/
  endmodule

module control_unit(
  	input [31:0]instr,
  	input reset,
  	input [2:0]funct,
    output invert,
  	output [1:0]im_sel,
    output jump,
    output branch,
    output Alusrc1,
    output Alusrc2,
    output regWrite,
    output MemRead,
    output MemWrite,
    output jal,
    output csr,
    output [1:0]wr_sel,
    output [2:0]ALUop,
    output fence
); 
  
  wire [6:0]opcode;
assign opcode = instr[6:0];
wire rv = opcode[1] & opcode[0];
wire j_type = opcode[6] & opcode[5] & ~opcode[4] & opcode[2] & rv;
wire b_type = opcode[6] & opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] & rv;     // b_type + sub
wire u_type = ~opcode[6] & opcode[4] & ~opcode[3] & opcode[2] & rv;
wire load_type = ~opcode[6] & ~opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] & rv;
wire s_type = ~opcode[6] & opcode[5] & ~opcode[4] & ~opcode[3] & ~opcode[2] & rv;
wire r_type = ~opcode[6] & opcode[5] & opcode[4] & ~opcode[3] & ~opcode[2] & rv;
wire i_type = ~opcode[6] & ~opcode[5] & opcode[4] & ~opcode[3] & ~opcode[2] & rv;
wire csr_type = opcode[6] & opcode[5] & opcode[4] & ~opcode[3] & ~opcode[2] & rv;

assign fence =  ~opcode[6] & ~opcode[5] & ~opcode[4] & opcode[3] & opcode[2] & rv;

assign invert = ((instr[31:25] == 7'b0100000) & (((funct == 3'b101)&(i_type | r_type)) | (r_type&(funct == 3'b000)))) | (MemRead & (funct[2:1]==2'b10)) ? 1 : 0 ;   


assign jump = reset ? j_type : 0 ;
assign branch = reset ? b_type : 0;
assign Alusrc1 = reset ? u_type : 0;
assign Alusrc2 = reset ? ~(b_type | r_type) : 0;
assign regWrite = reset ? ~(s_type | b_type | fence) : 0;
assign MemRead = reset ? load_type : 0;
assign MemWrite = reset ? s_type : 0;
assign jal = reset ? j_type & opcode[3] : 0;
assign csr = reset ? csr_type : 0;
assign im_sel[0] = reset ? i_type | u_type | j_type | load_type : 0;
assign im_sel[1] = reset ? u_type | s_type : 0;
assign wr_sel[0] = reset ? j_type | load_type | s_type : 0;
assign wr_sel[1] = reset ? csr_type | j_type | (u_type&opcode[5]) : 0;
assign ALUop[2] = reset ? ~(u_type | j_type | b_type | load_type | s_type ) & (((i_type | r_type) & funct[2]) | csr_type): 0;
assign ALUop[1] = reset ? ~(u_type | j_type | s_type) & (((i_type | r_type) & funct[1]) | (csr_type & funct[1]) | (b_type & funct[2])  | (load_type & (funct[2:1]==2'b10))): 0;
assign ALUop[0] = reset ? ~(u_type | j_type | s_type) & (((i_type | r_type) & funct[0]) | (csr_type & funct[0]) | (b_type & funct[1])  | (load_type & (funct[2:1]==2'b10))): 0;

endmodule // control_unit


//`include "reg.sv"
//`include "control_unit.sv"
//`include "sign_extend.sv"
//`include "EX.sv"
//`include "pc_control.sv"

module riscv_core#(
				parameter XLEN = 32,
				IRQ = 0)(
  input clk,
  input reset,
  
  output reg [31:0]pc,
  input [31:0]instr_in,
  
  output reg trap,
/*
  // PLIC
  input EIP,
  input [31:0]irq_handler,
  output IRQ_complete,
*/
  
  // CSR
  output csr_rd,
  output reg csr_wr, 
  output reg [11:0]csr_rd_addr,
  output reg [11:0]csr_wr_addr,
  output reg [31:0] csr_wr_data,
  input [31:0]csr_rd_data,
  
  
  // DATA MEMORY
  output reg MemRead_l2,
  output reg MemWrite_l2,
  output reg [31:0]m_addr,
  output reg [31:0]m_wr_dat,
  input [31:0]m_rd_dat
  
);
  
  
/////////////////////////////////////////////////////////////
//	IF
/////////////////////////////////////////////////////////////

reg [31:0]  instr, pc_l1;
reg reset_l1; 
  
  always@(posedge clk) begin
    instr <= reset ? instr_in : 32'h0;
    pc_l1 <= pc; 
    reset_l1 <= reset;
//    $display("DUT : pc = %h, instr = %h", pc_l1, instr);
  end
   
/////////////////////////////////////////////////////////////
//	ID & EX & pc_control
/////////////////////////////////////////////////////////////
 
  
  

 wire [1:0] im_sel, wr_sel;
 wire [2:0] ALUop, funct;
 control_unit  debug(.reset(reset_l1),
                     .instr(instr),
                     .jump(jump),
                     .im_sel(im_sel),
                     .branch(branch),
                     .Alusrc1(Alusrc1),
                     .Alusrc2(Alusrc2),
                     .MemRead(MemRead),
                     .MemWrite(MemWrite),
                     .ALUop(ALUop),
                     .regWrite(regWrite),
                     .jal(jal),
                     .csr(csr_rd),
                     .wr_sel(wr_sel),
                     .funct(funct),
                     .invert(invert),
                     .fence(fence)
                    );
  
  
  
wire [31:0] rd1, rd2;
wire [4:0] rs1, rs2;
reg [31:0] reg_wr_dat;
reg [4:0] rd_l3; 
reg regWrite_l3;
  assign rs1 = instr[19:15];
  assign rs2 = instr[24:20];
registers regfetch (.clk(clk),		.reset(reset_l1),
                    .rs1(rs1),		.rs2(rs2),
                    .rd1(rd1),				.rd2(rd2),
                    .rd(rd_l3),
                    .reg_wr_dat(reg_wr_dat),
                    .regWrite(regWrite_l3)
                    );
  
  
wire [31:0]se_I_imm, se_S_imm, se_U_imm, se_J_imm, se_B_imm, se_csr_imm; 
sign_extend_I se_I(.se_I_in(instr[31:20]),
                   .opcode(instr[6:0]),
                   .funct(funct),
                   .se_I_imm(se_I_imm));

sign_extend_S se_S(.se_S_in1(instr[31:25]),
                   .se_S_in2(instr[11:7]),
                   .se_S_imm(se_S_imm));

sign_extend_U se_U(.se_U_in(instr[31:12]),
                   .se_U_imm(se_U_imm));

sign_extend_J se_J(.se_J_in(instr[31:12]),
                   .se_J_imm(se_J_imm));

sign_extend_B se_B(.se_B_in1(instr[31:25]),
                   .se_B_in2(instr[11:7]),
                   .se_B_imm(se_B_imm));
  
sign_extend_csr se_csr(.se_csr_in(instr[19:15]),
                       .se_csr_imm(se_csr_imm));
  
  
wire [31:0] IF_out1;
reg [31:0]Imm;
  
always_comb begin
  case (im_sel)
  2'b00: Imm = csr_rd_data;
  2'b01: Imm = se_I_imm;
  2'b10: Imm = se_S_imm;
  2'b11: Imm = se_U_imm;
endcase 
end

wire [31:0] alu_in1, alu_in2, Imm_pc, Imm_jalr;

assign IF_out1 = (csr_rd & instr[14]) ? se_csr_imm : (rs1 == rd_l3 ? reg_wr_dat : rd1);  
assign funct = instr[14:12];
 
assign alu_in1 = Alusrc1 ? pc_l1 : ((csr_rd & (funct[1:0]== 2'b11)) ? ~IF_out1 : IF_out1);
assign alu_in2 = Alusrc2 ? Imm : (rs2 == rd_l3 ? reg_wr_dat : rd2);
  
assign Imm_pc = jal ? se_J_imm : se_B_imm;
   
assign csr_wr_addr = instr[31:20];
assign csr_rd_addr = instr[31:20];   

  wire [31:0]alu_out, next_pc, pc_in0;
ALU compute (.reset(reset_l1),
               .alu_in1(alu_in1), 
               .alu_in2(alu_in2),
               .ALUop(ALUop),
               .invert(invert),
               .zero(zero),
               .less_than(less_than),
               .alu_out(alu_out));


  assign Imm_jalr = (jump & ~jal) ? {alu_out[31:1],1'b0} : 32'h0;
  
pc_control hw(.reset(reset_l1), 
                .pc(pc_l1),
                .Imm_pc(Imm_pc),
                .funct(funct),
                .jal(jal),
                .zero(zero),
                .less_than(less_than),
              	.branch(branch),
                .jump(jump),
                .Imm_jalr(Imm_jalr),
              	.pc_in0(pc_in0),
                .next_pc(next_pc));

  
  reg [31:0] Imm_l2, pc_in0_l2;
  reg [4:0] rd_l2;
  reg [2:0] ALUop_l2, funct_l2;
  reg [1:0] wr_sel_l2;
  reg reset_l2, regWrite_l2;  
   
  
  always @ (posedge clk) begin
    
    reset_l2 <= reset_l1; 
    trap <= (instr == 32'h00100073) | ((instr == 32'h0) & reset_l1) ? 1 : 0;
    pc_in0_l2 <= pc_in0;
    
    
    pc <= reset_l1 ? next_pc : 32'h0;
    
    
    csr_wr <= csr_rd;
  	csr_wr_data <= csr_wr ? (funct[1] ? alu_out : alu_in1): 32'b0;
    
    rd_l2 <= instr[11:7];
    regWrite_l2 <= regWrite;
    
    funct_l2 <= funct;
    wr_sel_l2 <= wr_sel;
    Imm_l2 <= Imm;
    
    m_addr <= alu_out;
    MemWrite_l2 <= MemWrite;
    MemRead_l2 <= MemRead;
    
    if (reset_l1) begin
      if (MemWrite) begin  
        case (funct[1:0])
              2'b00: m_wr_dat <= rd2 & 32'h000000ff;
              2'b01: m_wr_dat <= rd2 & 32'h0000ffff;
              2'b10: m_wr_dat <= rd2;
              2'b11: m_wr_dat <= rd2;
        endcase
      end  else m_wr_dat <= 32'h0;
    end 
    else m_wr_dat <= 32'h0;
    
  end
/////////////////////////////////////////////////////////////
//	DM
/////////////////////////////////////////////////////////////
  
always @ (posedge clk) begin
    regWrite_l3 <= regWrite_l2;
    rd_l3 <= rd_l2;

   	if (reset_l2) begin
      case (wr_sel_l2)
        2'b00: reg_wr_dat <= m_addr;
        2'b01: if (MemRead_l2) begin
          		case (funct_l2[1:0])
                  2'b00: reg_wr_dat <= m_rd_dat & 32'h000000ff;
                  2'b01: reg_wr_dat <= m_rd_dat & 32'h0000ffff;
                  2'b10: reg_wr_dat <= m_rd_dat;
                endcase
              end 
        2'b10: reg_wr_dat <= Imm_l2; 
        2'b11: reg_wr_dat <= pc_in0_l2; 
      endcase 
    end
  	else reg_wr_dat <= 32'h0;
  
     

    
  
end 

  
/////////////////////////////////////////////////////////////
//	WB
/////////////////////////////////////////////////////////////

  
  
endmodule
/////////////////////////////////////////////////////////////

module cs_reg(
    input clk,
  	input reset,
  	input csr_rd,
  	input csr_wr,
  	input [11:0]rd_addr,
  	input [11:0]wr_addr,
  	output reg [31:0]rd_dat,
	input [31:0]wr_dat

);

  reg [31:0]csrm[4095:0];


  
  always_comb begin
    rd_dat =  (csr_rd & reset) ? csrm[rd_addr] : 32'h0;
  end

  
  always @(posedge clk) begin
    if (csr_wr & reset)       csrm[wr_addr] <= wr_dat;
  end
 
 
endmodule
module data_memory(
	input clk,
  	input reset,
	input [31:0]m_addr,
    input [31:0]m_wr_dat,
    input rd_en,
    input wr_en,
    output reg [31:0]m_rd_dat
	);


  reg [31:0]mem[(2**30) - 1:0];
  
  initial begin
    mem[49152] = 32'h0;
    mem[49168] = 32'h0;
    mem[49184] = 32'h0;
    mem[49200] = 32'h0;
    mem[49216] = 32'h0;
    mem[49232] = 32'h0;
    mem[49248] = 32'h0;
    mem[49264] = 32'h0;
    mem[49280] = 32'h0;
  end
 
  always @(posedge clk) begin
    m_rd_dat <= (rd_en & reset) ? mem[m_addr << 2] : 32'h0;
    if  (wr_en & reset) begin
      	mem[m_addr << 2] <= m_wr_dat;
//        $display("%h",m_wr_dat);
    end

    
  end

endmodule
module ALU(
  	input reset,
	input [31:0]alu_in1,
	input [31:0]alu_in2,
	input [2:0]ALUop,
	input invert,
	output reg [31:0] alu_out,
	output reg zero,
	output reg less_than
	);


reg [32:0]alu_res;
   
wire [31:0]alu2, temp;


always_comb begin
  if (reset) begin    
      case (ALUop)
        3'b000: alu_res = $signed(alu_in1) + $signed(alu2);		// add
        3'b001: alu_res = alu_in1 << alu_in2[4:0];				// Shift left
        3'b010: alu_res = $signed(alu_in1) - $signed(alu2);		// set if less
        3'b011: alu_res = alu_in1 - alu2;						// set if less Unsigned
        3'b100: alu_res = alu_in1 ^ alu_in2;					// XOR
        3'b101: begin alu_res = alu_in1 >> alu_in2[4:0];		// Shift right
                  if (invert ) alu_res[31] = alu_in1[31];
                end
        3'b110: alu_res = alu_in1 | alu_in2;					// OR
        3'b111: alu_res = alu_in1 & alu_in2;					// AND
         default: alu_res = 33'h00000000;  						// default
      endcase  
 
      if (ALUop[2:1] === 2'b01) begin
        less_than = (alu_res[32] === 1) ? 1 : 0;
        alu_out = less_than;
      end else begin 
        alu_out = alu_res[31:0];
        less_than = 1'b0;
      end 
    zero = (alu_res == 33'b0) ? 1 : 0;
  end
  else begin
    alu_out = 32'b0;
    less_than = 0;
    zero = 0;
  end
end
  
  
  assign alu2 = invert ? (~alu_in2 + 32'b1): alu_in2;

endmodule


module pc_control(
  	input reset,
	input [31:0]pc,
  	input [31:0]Imm_pc,
	input [2:0]funct,
    input jal,
	input zero,
	input less_than,
	input branch,
	input jump,
  	input [31:0]Imm_jalr,
  	output reg [31:0]pc_in0,
  	output reg [31:0]next_pc
	);
  

reg [31:0] pc_in1;
reg b_type, pc_sel;

  always_comb begin
    case ({funct[2],funct[0]})
        2'b00: b_type = zero;
        2'b01: b_type = ~zero;
        2'b10: b_type = less_than;
        2'b11: b_type = ~ (less_than | zero);
    endcase 
    pc_sel = (jump) | (branch & b_type);
  	pc_in0 = reset ? pc + 32'd4 : 32'h0;
  	pc_in1 = (jump & ~jal) ? Imm_jalr : (pc + $signed(Imm_pc));
  	next_pc = reset ? (pc_sel ? pc_in1 : pc_in0) : 32'h0;
end  
    
endmodule 

module registers(
  	input clk,
  	input reset,
	input [4:0] rs1,
	input [4:0] rs2,
  	input [4:0] rd,
	input [31:0] reg_wr_dat,
	input regWrite,
	output reg [31:0] rd1,
	output reg [31:0] rd2
	);
 
  reg [31:0] registry [31:1], test;
  
  initial begin
    for (int i = 1; i<32; ++i)
      registry[i] = 32'h0;
  end
  
  always_comb begin
  	rd1 =  (reset & (rs1!=5'b0)) ? registry[rs1] : 32'h0;
  	rd2 =  (reset & (rs2!=5'b0)) ? registry[rs2] : 32'h0;
  end
  
  
  always@ (posedge clk) begin    
    if(reset & regWrite & (rd!=5'b0)) begin      registry[rd] <= reg_wr_dat;
      test <= reg_wr_dat;
    end
  end
  
  
endmodule // registers
module sign_extend_csr(
	input [4:0]se_csr_in,
  	output [31:0]se_csr_imm
	);
  assign se_csr_imm = {27'b0,se_csr_in};

endmodule


module sign_extend_I(
  	input [6:0]opcode,
  	input [11:0]se_I_in,
  	input [2:0] funct,
	output [31:0]se_I_imm
	);
  assign se_I_imm = ((funct[1:0] == 2'b01) & (opcode == 7'b0010011)) ? {27'b0,se_I_in[4:0]} : {{21{se_I_in[11]}},se_I_in[10:0]};
endmodule


module sign_extend_S(
	input [6:0]se_S_in1,
	input [4:0]se_S_in2,
	output [31:0]se_S_imm
	);
  assign se_S_imm = {{21{se_S_in1[6]}},se_S_in1[5:0],se_S_in2};
endmodule



module sign_extend_U(
	input [19:0]se_U_in,
	output [31:0]se_U_imm
	);
  assign se_U_imm = {se_U_in,12'b0};
endmodule



module sign_extend_J(
	input [19:0]se_J_in,
	output [31:0]se_J_imm
	);
  assign se_J_imm = {{12{se_J_in[19]}},se_J_in[7:0],se_J_in[8],se_J_in[18:9],1'b0};
endmodule



// Sign extend of B 
module sign_extend_B(
	input [6:0]se_B_in1,
	input [4:0]se_B_in2,
	output [31:0]se_B_imm
	);
  assign se_B_imm = {{20{se_B_in1[6]}},se_B_in2[0],se_B_in1[5:0],se_B_in2[4:1],1'b0};
endmodule



