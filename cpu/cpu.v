module cpu(
  input clk,
  input sys_clk,
  input rst,
  // Switch and Keys
  input [9:0] SW,
  input [3:0] KEY,
  // VGA and PS2 Keyboard
  input  [31:0] io_addr,
  input         io_wren,
  input  [31:0] io_wdata,
  output [31:0] io_rdata,
  output [31:0] io_rgba,
  // LEDR and 7-SEG
  output [9:0] LEDR,
  output reg [23:0] SEG
);

  // Program counter and instruction
  wire [31:0] pc_vaddr;
  wire [31:0] pc_paddr;
  wire [31:0] seq_pc;
  wire [31:0] instr;
  wire [31:0] instr_sign_ex;

  // Signals
  wire        signal_mem_wren;
  wire        signal_reg_wren;
  wire        signal_jal_wren;
  wire        signal_reg_dmux_sel;
  wire        signal_reg_rmux_sel;
  wire        signal_reg_is_upper;
  wire        signal_alu_imux_sel;
  wire  [3:0] signal_alu_op;
  wire  [2:0] signal_pc_control;

  // Registers
  wire  [4:0] reg_waddr;
  wire  [4:0] reg_raddr0;
  wire  [4:0] reg_raddr1;
  wire [31:0] reg_rdata0;
  wire [31:0] reg_rdata1;
  wire [31:0] reg_wdata;
  wire [31:0] reg_ledctr;

  // ALU
  wire [31:0] alu_src;
  wire [31:0] alu_dest;
  wire  [4:0] alu_shamt;
  wire        alu_eflags_of;
  wire        alu_eflags_zf;

  // Data Memory
  wire [31:0] mem_paddr;
  wire [31:0] mem_rdata;
  
  //-------------------------------------
  // DEBUG OUTPUT
  //-------------------------------------
  reg [15:0] DEBUG_SEG;
  reg [31:0] DEBUG_SEG_32;
  wire [31:0] REG_DEBUG_OUT;
  assign LEDR = KEY[2] ? reg_ledctr[9:0] : 
  {
    signal_mem_wren, signal_reg_wren,
	  signal_reg_dmux_sel, signal_reg_rmux_sel,
	  signal_alu_imux_sel, signal_alu_op[3:0], (signal_pc_control != 0)
  };
  always @ (*) begin
    if (SW == 0) begin
	    SEG = pc_vaddr[23:0];
    end else begin
	    if (SW[9]) begin
		    DEBUG_SEG_32 = reg_rdata0;
	    end else if (SW[8]) begin
	      DEBUG_SEG_32 = alu_src;
	    end else if (SW[7]) begin
	      DEBUG_SEG_32 = alu_dest;
	    end else if (SW[6]) begin
	      DEBUG_SEG_32 = reg_wdata;
	    end else if (SW[5]) begin
	      DEBUG_SEG_32 = mem_rdata;
	    end else begin
		    DEBUG_SEG_32 = REG_DEBUG_OUT;
      end
 
      if (~KEY[2]) begin
  	    DEBUG_SEG = DEBUG_SEG_32[31:16];
 	    end else begin
	      DEBUG_SEG = DEBUG_SEG_32[15:0];
	    end
      SEG = {DEBUG_SEG, pc_vaddr[7:0]};
	  end
  end

  //-------------------------------------
  // Instantiations
  //-------------------------------------
  program_counter mPC(
    .clk(clk),
    .rst(rst),
    .pc_control(signal_pc_control),
    .jmp_addr(instr[25:0]),
    .branch_offset(instr[15:0]),
    .reg_addr(reg_rdata0),
    .pc(pc_vaddr),
	 .seq_pc(seq_pc)
  );

  // Instruction starts from 0x400000 to fit MARS.
  assign pc_paddr = pc_vaddr - 32'h400000;
  instr_memory mINSTRMEM(
    .addr(pc_paddr),
    .instr(instr)
  );

  sign_ex mSIEX(
    .in(instr[15:0]),
    .out(instr_sign_ex)
  );

  decoder mDECODER(
    .instr(instr),
    .alu_zf(alu_eflags_zf),
    .mem_wren(signal_mem_wren),
    .reg_wren(signal_reg_wren),
	 .jal_wren(signal_jal_wren),
    .reg_dmux_sel(signal_reg_dmux_sel),
    .reg_rmux_sel(signal_reg_rmux_sel),
    .reg_is_upper(signal_reg_is_upper),
    .alu_imux_sel(signal_alu_imux_sel),
    .alu_op(signal_alu_op),
    .pc_control(signal_pc_control)
  );

  assign reg_raddr0 = instr[25:21];
  assign reg_raddr1 = instr[20:16];

  // if R-mux signal is valid, use rd register;
  // otherwise, use rt register.
  mux21 #(.DATA_WIDTH(5)) mRegMUX(
    .in0(reg_raddr1),
    .in1(instr[15:11]),
    .sel(signal_reg_rmux_sel),
    .out(reg_waddr)
  );
  
  // if D-mux signal is valid, load result from ALU to register;
  // otherwise, load mem_rdata read from memory.
  mux21 mMEMMUX(
    .in0(mem_rdata),
	  .in1(alu_dest),
	  .sel(signal_reg_dmux_sel),
	  .out(reg_wdata)
  );
  
  // if I-mux signal is valid, use the sign extended immediate from instruction;
  // otherwise, use rt register for second operand.
  mux21 mIMMMUX(
    .in0(reg_rdata1),
	  .in1(instr_sign_ex),
	  .sel(signal_alu_imux_sel),
	  .out(alu_src)
  );
  
  // read/write from registers.
  register_file mREG(
    .clk(clk),
    .raddr0(reg_raddr0),
    .rdata0(reg_rdata0),
    .raddr1(reg_raddr1),
    .rdata1(reg_rdata1),
    .waddr(reg_waddr),
    .wdata(reg_wdata),
    .wren(signal_reg_wren),
    .is_upper(signal_reg_is_upper),
	 .jal_wren(signal_jal_wren),
	 .jal_data(seq_pc),
    .DEBUG_ADDR(SW[4:0]),
    .DEBUG_OUT(REG_DEBUG_OUT),
	 .IO_RGBA_OUT(io_rgba),
    .LEDR_OUT(reg_ledctr)
  );
  
  // ALU module
  assign alu_shamt = instr[10:6];
  alu mALU(
    .op(signal_alu_op),
    .rs(reg_rdata0),
    .rt(alu_src),
    .sa(alu_shamt),
    .rd(alu_dest),
    .zf(alu_eflags_zf),
    .of(alu_eflags_of)
  );
  
  // All data address begins from 0x10000000 to fit MARS.
  // A port is used for CPU;
  // B port is used for I/O.
  assign mem_paddr = alu_dest - 32'h10000000;
  data_memory mMEM(
    .address_a({2'b00, mem_paddr[31:2]}),
	 .address_b({2'b00, io_addr[31:2]}),
	 .clock_a(sys_clk),
	 .clock_b(sys_clk),
	 .data_a(reg_rdata1),    // Save Rt register
	 .data_b(io_wdata),
	 .wren_a(signal_mem_wren),
	 .wren_b(io_wren),
	 .q_a(mem_rdata),
	 .q_b(io_rdata),
  );
endmodule
