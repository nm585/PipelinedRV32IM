--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Top Level Structural Model for the 5-Stage Pipelined RISC-V Core
-- (IF -> ID -> EX -> MEM -> WB, with forwarding, a destination-register
--  collision stall check, and branch/JAL resolved in EX while JALR
--  resolves one stage later, in EX/MEM)
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
use ieee.std_logic_unsigned.all;
USE work.cond_compilation_package.all;
USE work.aux_package.all;
USE work.const_package.all;


ENTITY RV32I_CORE IS
	generic(
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
	    MODELSIM 					: integer 	:= G_MODELSIM;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			PC_WIDTH 					: integer 	:= G_PC_WIDTH;
			MA_WIDTH 					: integer 	:= G_MA_WIDTH;
			DATA_WORDS_NUM 		: integer 	:= G_DATA_WORDSNUM;
			CLK_CNT_WIDTH 		: integer 	:= 16
	);
	PORT(
		--Inputs
		rst_i		 					:IN	STD_LOGIC;
		clk_i							:IN	STD_LOGIC;

		--Outputs (used also for Signal-Tap auxiliary pins)
		pc_o							:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		instruction_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		--Per-stage PC/instruction taps (LAB5 page 8, Figure 8 top entity)
		IFpc_o						:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IFinstruction_o		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDpc_o						:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IDinstruction_o		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EXpc_o						:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXinstruction_o		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMpc_o						:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEMinstruction_o	:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		WBpc_o						:OUT	STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		WBinstruction_o		:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		RegWrite_ctrl_o		:OUT 	STD_LOGIC;
		MemWrite_ctrl_o		:OUT 	STD_LOGIC;
		Branch_ctrl_o			:OUT 	STD_LOGIC;

		read_data1_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o 			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		write_data_o			:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		alu_res_o 				:OUT	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		brTaken_o					:OUT 	STD_LOGIC;

		dtcm_addr_o				:OUT 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
		dtcm_data_wr_o		:OUT 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		dtcm_data_rd_o		:OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		mclk_cnt_o				:OUT	STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

		--IPC / breakpoint support (LAB5 task definition, page 8)
		BPADDR_i					:IN		STD_LOGIC_VECTOR(7 DOWNTO 0);	-- breakpoint addr (fed by SW7-SW0)
		STCNT_o						:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);	-- stall counter
		FHCNT_o						:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);	-- flush counter
		st_trigger_o			:OUT	STD_LOGIC											-- Signal-Tap trigger (IFPC == BPADDR_i)
	);
END RV32I_CORE;
--============================================================================
ARCHITECTURE structure OF RV32I_CORE IS

	SIGNAL mclk_w 				: STD_LOGIC;
	SIGNAL mclk_cnt_q			: STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

	-- IFETCH (IF stage) — combinational IF-stage outputs
	SIGNAL if_pc_w				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_pc4_w				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_instr_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	-- IF/ID register outputs (IFID_Reg)
	SIGNAL ifid_pc_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ifid_pc4_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL ifid_instr_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- IDECODE (ID stage, combinational RF read + sign extend)
	SIGNAL read_data1_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL read_data2_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL sign_extend_w 	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL rs1_w				: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rs2_w				: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rd_w					: STD_LOGIC_VECTOR(4 DOWNTO 0);

	-- CONTROL (ID stage, combinational)
	SIGNAL alu_src_w 			: STD_LOGIC;
	SIGNAL branch_w 			: STD_LOGIC;
	SIGNAL Jal_ctrl_w 		: STD_LOGIC;
	SIGNAL Jalr_ctrl_w 		: STD_LOGIC;
	SIGNAL reg_write_w 		: STD_LOGIC;
	SIGNAL mem_write_w 		: STD_LOGIC;
	SIGNAL MemtoReg_w 		: STD_LOGIC;
	SIGNAL mem_read_w 		: STD_LOGIC;
	SIGNAL upper_im_w			: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL alu_op_w 			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL mul_op_w				: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL wbsrc_w				: STD_LOGIC; -- '1' selects ALU result, '0' selects MUL result (inner WB mux)
	SIGNAL regdst_w				: STD_LOGIC;

	-- ID/EX register outputs
	SIGNAL IDEX_pc_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_pc_plus4_w		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_read_data1_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_read_data2_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_sign_extend_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL IDEX_rs1_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL IDEX_rs2_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL IDEX_rd_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL IDEX_RegWrite_w		: STD_LOGIC;
	SIGNAL IDEX_MemtoReg_w		: STD_LOGIC;
	SIGNAL IDEX_MemRead_w		: STD_LOGIC;
	SIGNAL IDEX_MemWrite_w		: STD_LOGIC;
	SIGNAL IDEX_Branch_w		: STD_LOGIC;
	SIGNAL IDEX_Jal_w			: STD_LOGIC;
	SIGNAL IDEX_Jalr_w			: STD_LOGIC;
	SIGNAL IDEX_ALUSrc_w		: STD_LOGIC;
	SIGNAL IDEX_ALUOp_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL IDEX_UpperIm_w		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL IDEX_MulOp_w			: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL IDEX_wbsrc_w			: STD_LOGIC;
	SIGNAL IDEX_RegDst_w		: STD_LOGIC;

	-- EXECUTE outputs (EX stage, combinational)
	SIGNAL brTaken_w 			: STD_LOGIC;
	SIGNAL alu_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL addr_gen_w 		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL fwd_b_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Multiplier Stage 1 outputs (EX) -> EX/MEM register inputs
	SIGNAL EX_P0_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P1_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P2_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EX_P3_w				: STD_LOGIC_VECTOR(15 DOWNTO 0);

	-- EX/MEM register outputs
	SIGNAL EXMEM_pc_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_pc_plus4_w		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_alu_res_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_addr_gen_w		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_brTaken_w		: STD_LOGIC;
	SIGNAL EXMEM_read_data2_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL EXMEM_P0_w			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EXMEM_P1_w			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EXMEM_P2_w			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EXMEM_P3_w			: STD_LOGIC_VECTOR(15 DOWNTO 0);
	SIGNAL EXMEM_rd_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL EXMEM_RegWrite_w		: STD_LOGIC;
	SIGNAL EXMEM_MemtoReg_w		: STD_LOGIC;
	SIGNAL EXMEM_MemRead_w		: STD_LOGIC;
	SIGNAL EXMEM_MemWrite_w		: STD_LOGIC;
	SIGNAL EXMEM_Branch_w		: STD_LOGIC;
	SIGNAL EXMEM_Jal_w			: STD_LOGIC;
	SIGNAL EXMEM_Jalr_w			: STD_LOGIC;
	SIGNAL EXMEM_MulOp_w		: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL EXMEM_wbsrc_w		: STD_LOGIC;
	SIGNAL EXMEM_RegDst_w		: STD_LOGIC;

	-- DMEMORY (MEM stage)
	SIGNAL dtcm_addr_w 		: STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL dtcm_data_rd_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Multiplier Stage 2 output (MEM stage)
	SIGNAL MUL_res_w 			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- MEM/WB register outputs
	SIGNAL MEMWB_pc_w		    : STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_pc_plus4_w		: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_instruction_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_alu_res_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_dtcm_data_rd_w	: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_MUL_res_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL MEMWB_rd_w			: STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL MEMWB_RegDst_w		: STD_LOGIC;
	SIGNAL MEMWB_RegWrite_w		: STD_LOGIC;
	SIGNAL MEMWB_MemtoReg_w		: STD_LOGIC;
	SIGNAL MEMWB_MulOp_w		: STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL MEMWB_wbsrc_w		: STD_LOGIC;

	-- WB mux outputs: inner MUX selects ALU/MUL/MEM, outer MUX adds PC+4 for JAL/JALR
	SIGNAL wb_inner_mux_w		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL wb_wdata_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ID_wdata_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- ForwardingUnit outputs
	SIGNAL Forward_Ain_w		: STD_LOGIC_VECTOR(1 DOWNTO 0);
	SIGNAL Forward_Bin_w		: STD_LOGIC_VECTOR(1 DOWNTO 0);

	-- StallConditionUnit outputs
	SIGNAL PCwrite_w			: STD_LOGIC;
	SIGNAL IF_IDwrite_w			: STD_LOGIC;
	SIGNAL Stall_w				: STD_LOGIC;

	-- Branch/JAL/JALR redirect: JAL/taken-branch resolved combinationally in EX,
	-- JALR resolved one stage later in EX/MEM (see redirect wiring below)
	SIGNAL flush_w			: STD_LOGIC;
	signal EXMEM_pcimm_redirect_ctrl_w	: STD_LOGIC; -- EX/MEM-stage (registered) Jal/taken-branch flag
	signal IDEX_pcimm_redirect_ctrl_w : STD_LOGIC; -- EX-stage (combinational) Jal/taken-branch flag

	-- IPC / breakpoint support unit outputs (LAB5 page 8)
	SIGNAL stcnt_w				: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL fhcnt_w				: STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL st_trigger_w		: STD_LOGIC;
BEGIN

	--=======================================
	-- PLL module connection
	--=======================================
	G0:
	if (MODELSIM = 0) generate
	  MCLK: PLL
		PORT MAP (
			inclk0 	=> clk_i,
			c0 		=> mclk_w
		);
	else generate
		mclk_w <= clk_i;
	end generate;

	--=======================================
	-- Branch/JAL redirect condition: combinational in EX, then registered one
	-- more stage (EX/MEM) so it aligns with JALR's own EX/MEM-stage timing
	--=======================================
	IDEX_pcimm_redirect_ctrl_w <= IDEX_Jal_w OR (IDEX_Branch_w AND brTaken_w);

	-- NOTE: flush_w is now generated inside the MEM-stage module (DMEMORY):
	--   Flush_o <= Branch_or_jal_i OR Jalr_ctrl_i
	-- driven by the EX/MEM-registered redirect flags. See the dmemory port map.

	--===========================================
	-- IFETCH (IF stage: PC, ITCM, redirect muxes)
	--===========================================
	IFE : Ifetch
	generic map(
		WORD_GRANULARITY	=> 	WORD_GRANULARITY,
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH,
		PC_WIDTH					=>	PC_WIDTH,
		ITCM_ADDR_WIDTH		=>	ITCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (
		--Inputs
		clk_i 					=> mclk_w,
		rst_i 					=> rst_i,
		ex_brtarget_i		=> EXMEM_addr_gen_w,
		ex_jalrtgt_i		=> EXMEM_alu_res_w(PC_WIDTH-1 DOWNTO 0),
		jalr_sel_i			=> EXMEM_Jalr_w,
		redirect_active_i	=> EXMEM_pcimm_redirect_ctrl_w,
		pc_write_i			=> PCwrite_w,

		--Outputs (combinational IF stage)
		if_pc_o					=> if_pc_w,
		if_pc4_o				=> if_pc4_w,
		if_instr_o			=> if_instr_w
	);

	--===========================================
	-- IF/ID Pipeline Register (own module)
	--===========================================
	IFIDREG : IFID_Reg
	generic map(
		DATA_BUS_WIDTH => DATA_BUS_WIDTH,
		PC_WIDTH       => PC_WIDTH
	)
	PORT MAP (
		clk_i			=> mclk_w,
		rst_i			=> rst_i,
		flush_i			=> flush_w,
		ifid_write_i	=> IF_IDwrite_w,
		if_pc_i			=> if_pc_w,
		if_pc4_i		=> if_pc4_w,
		if_instr_i		=> if_instr_w,
		ifid_pc_o		=> ifid_pc_w,
		ifid_pc4_o		=> ifid_pc4_w,
		ifid_instr_o	=> ifid_instr_w
	);


	-- RF write-back value: PC+4 for JAL/JALR (RegDst), else the WB mux result.
	ID_wdata_w <= ZEROS_DBUS2PCADDR & MEMWB_pc_plus4_w WHEN MEMWB_RegDst_w = '1' ELSE
	              wb_wdata_w;
	--=======================================
	-- IDECODE (ID stage: RF + sign extend)
	--=======================================
	ID : Idecode
  generic map(
		PC_WIDTH				=>	PC_WIDTH,
		DATA_BUS_WIDTH	=>  DATA_BUS_WIDTH
	)
	PORT MAP (
		--Inputs
		clk_i 					=> mclk_w,
		rst_i 					=> rst_i,
    instruction_i 	=> ifid_instr_w,
		wb_wdata_i			=> ID_wdata_w,
		wb_rd_i					=> MEMWB_rd_w,
		wb_regwrite_i		=> MEMWB_RegWrite_w,

		--Outputs
		read_data1_o 		=> read_data1_w,
        read_data2_o 		=> read_data2_w,
		SignExt_o 			=> sign_extend_w,
		rs1_o						=> rs1_w,
		rs2_o						=> rs2_w,
		rd_o						=> rd_w
	);
	--=======================================
	-- CONTROL (ID stage)
	--=======================================
	CTL:   control
	PORT MAP (
		--Inputs
		instruction_i 		=> ifid_instr_w,

		--Outputs
		RegDst_ctrl_o			=> regdst_w,
		ALUSrc_ctrl_o 		=> alu_src_w,
		MemtoReg_ctrl_o 	=> MemtoReg_w,
		RegWrite_ctrl_o 	=> reg_write_w,
		MemRead_ctrl_o 		=> mem_read_w,
		MemWrite_ctrl_o 	=> mem_write_w,
		Branch_ctrl_o 		=> branch_w,
		Jal_ctrl_o 				=> Jal_ctrl_w,
		Jalr_ctrl_o				=> Jalr_ctrl_w,
		UpperIm_ctrl_o 		=> upper_im_w,
		ALUOp_ctrl_o 			=> alu_op_w,
		MUL_OP_ctrl_o			=> mul_op_w,
		wbsrc_ctrl_o 			=> wbsrc_w
 	);
	--=======================================
	-- ID/EX, EX/MEM, MEM/WB pipeline registers
	--=======================================
	-- ID/EX, EX/MEM, MEM/WB pipeline registers (each in its own file)
	IDEXREG : IDEX_Reg
	generic map(
		DATA_BUS_WIDTH => DATA_BUS_WIDTH,
		PC_WIDTH       => PC_WIDTH
	)
	PORT MAP (
		clk_i             => mclk_w,
		rst_i             => rst_i,
		stall_i           => Stall_w,
		flush_i           => flush_w,
		ID_pc_i           => ifid_pc_w,
		ID_pc_plus4_i     => ifid_pc4_w,
		ID_instruction_i  => ifid_instr_w,
		ID_read_data1_i   => read_data1_w,
		ID_read_data2_i   => read_data2_w,
		ID_sign_extend_i  => sign_extend_w,
		ID_rs1_i          => rs1_w,
		ID_rs2_i          => rs2_w,
		ID_rd_i           => rd_w,
		ID_RegWrite_i     => reg_write_w,
		ID_MemtoReg_i     => MemtoReg_w,
		ID_MemRead_i      => mem_read_w,
		ID_MemWrite_i     => mem_write_w,
		ID_Branch_i       => branch_w,
		ID_Jal_i          => Jal_ctrl_w,
		ID_Jalr_i         => Jalr_ctrl_w,
		ID_ALUSrc_i       => alu_src_w,
		ID_ALUOp_i        => alu_op_w,
		ID_UpperIm_i      => upper_im_w,
		ID_MulOp_i        => mul_op_w,
		ID_wbsrc_i        => wbsrc_w,
		ID_RegDst_i       => regdst_w,
		IDEX_pc_o         => IDEX_pc_w,
		IDEX_pc_plus4_o   => IDEX_pc_plus4_w,
		IDEX_instruction_o=> IDEX_instruction_w,
		IDEX_read_data1_o => IDEX_read_data1_w,
		IDEX_read_data2_o => IDEX_read_data2_w,
		IDEX_sign_extend_o=> IDEX_sign_extend_w,
		IDEX_rs1_o        => IDEX_rs1_w,
		IDEX_rs2_o        => IDEX_rs2_w,
		IDEX_rd_o         => IDEX_rd_w,
		IDEX_RegWrite_o   => IDEX_RegWrite_w,
		IDEX_MemtoReg_o   => IDEX_MemtoReg_w,
		IDEX_MemRead_o    => IDEX_MemRead_w,
		IDEX_MemWrite_o   => IDEX_MemWrite_w,
		IDEX_Branch_o     => IDEX_Branch_w,
		IDEX_Jal_o        => IDEX_Jal_w,
		IDEX_Jalr_o       => IDEX_Jalr_w,
		IDEX_ALUSrc_o     => IDEX_ALUSrc_w,
		IDEX_ALUOp_o      => IDEX_ALUOp_w,
		IDEX_UpperIm_o    => IDEX_UpperIm_w,
		IDEX_MulOp_o      => IDEX_MulOp_w,
		IDEX_wbsrc_o      => IDEX_wbsrc_w,
		IDEX_RegDst_o     => IDEX_RegDst_w
	);

	EXMEMREG : EXMEM_Reg
	generic map(
		DATA_BUS_WIDTH => DATA_BUS_WIDTH,
		PC_WIDTH       => PC_WIDTH
	)
	PORT MAP (
		clk_i             => mclk_w,
		rst_i             => rst_i,
		flush_i           => flush_w,
		EX_pc_i           => IDEX_pc_w,
		EX_pc_plus4_i     => IDEX_pc_plus4_w,
		EX_instruction_i  => IDEX_instruction_w,
		EX_alu_res_i      => alu_res_w,
		EX_addr_gen_i     => addr_gen_w,
		EX_brTaken_i      => brTaken_w,
		EX_read_data2_i   => fwd_b_w,
		EX_P0_i           => EX_P0_w,
		EX_P1_i           => EX_P1_w,
		EX_P2_i           => EX_P2_w,
		EX_P3_i           => EX_P3_w,
		EX_rd_i           => IDEX_rd_w,
		EX_RegWrite_i     => IDEX_RegWrite_w,
		EX_MemtoReg_i     => IDEX_MemtoReg_w,
		EX_MemRead_i      => IDEX_MemRead_w,
		EX_MemWrite_i     => IDEX_MemWrite_w,
		EX_Branch_i       => IDEX_Branch_w,
		EX_Jal_i          => IDEX_Jal_w,
		EX_Jalr_i         => IDEX_Jalr_w,
		EX_MulOp_i        => IDEX_MulOp_w,
		EX_wbsrc_i        => IDEX_wbsrc_w,
		EX_RegDst_i       => IDEX_RegDst_w,
		EX_pcimm_redirect_ctrl_i => IDEX_pcimm_redirect_ctrl_w,
		EXMEM_pc_o        => EXMEM_pc_w,
		EXMEM_pc_plus4_o  => EXMEM_pc_plus4_w,
		EXMEM_instruction_o => EXMEM_instruction_w,
		EXMEM_alu_res_o   => EXMEM_alu_res_w,
		EXMEM_addr_gen_o  => EXMEM_addr_gen_w,
		EXMEM_brTaken_o   => EXMEM_brTaken_w,
		EXMEM_read_data2_o=> EXMEM_read_data2_w,
		EXMEM_P0_o        => EXMEM_P0_w,
		EXMEM_P1_o        => EXMEM_P1_w,
		EXMEM_P2_o        => EXMEM_P2_w,
		EXMEM_P3_o        => EXMEM_P3_w,
		EXMEM_rd_o        => EXMEM_rd_w,
		EXMEM_RegWrite_o  => EXMEM_RegWrite_w,
		EXMEM_MemtoReg_o  => EXMEM_MemtoReg_w,
		EXMEM_MemRead_o   => EXMEM_MemRead_w,
		EXMEM_MemWrite_o  => EXMEM_MemWrite_w,
		EXMEM_Branch_o    => EXMEM_Branch_w,
		EXMEM_Jal_o       => EXMEM_Jal_w,
		EXMEM_Jalr_o      => EXMEM_Jalr_w,
		EXMEM_MulOp_o     => EXMEM_MulOp_w,
		EXMEM_wbsrc_o     => EXMEM_wbsrc_w,
		EXMEM_RegDst_o    => EXMEM_RegDst_w,
		EXMEM_pcimm_redirect_ctrl_o => EXMEM_pcimm_redirect_ctrl_w
	);

	MEMWBREG : MEMWB_Reg
	generic map(
		DATA_BUS_WIDTH => DATA_BUS_WIDTH,
		PC_WIDTH       => PC_WIDTH
	)
	PORT MAP (
		clk_i             => mclk_w,
		rst_i             => rst_i,
		MEM_pc_i          => EXMEM_pc_w,
		MEM_pc_plus4_i    => EXMEM_pc_plus4_w,
		MEM_instruction_i => EXMEM_instruction_w,
		MEM_alu_res_i     => EXMEM_alu_res_w,
		MEM_dtcm_data_rd_i=> dtcm_data_rd_w,
		MEM_MUL_res_i     => MUL_res_w,
		MEM_rd_i          => EXMEM_rd_w,
		MEM_RegDst_i      => EXMEM_RegDst_w,
		MEM_RegWrite_i    => EXMEM_RegWrite_w,
		MEM_MemtoReg_i    => EXMEM_MemtoReg_w,
		MEM_MulOp_i       => EXMEM_MulOp_w,
		MEM_wbsrc_i       => EXMEM_wbsrc_w,
		MEMWB_pc_o          => MEMWB_pc_w,
		MEMWB_pc_plus4_o    => MEMWB_pc_plus4_w,
		MEMWB_instruction_o => MEMWB_instruction_w,
		MEMWB_alu_res_o     => MEMWB_alu_res_w,
		MEMWB_dtcm_data_rd_o=> MEMWB_dtcm_data_rd_w,
		MEMWB_MUL_res_o     => MEMWB_MUL_res_w,
		MEMWB_rd_o          => MEMWB_rd_w,
		MEMWB_RegDst_o      => MEMWB_RegDst_w,
		MEMWB_RegWrite_o    => MEMWB_RegWrite_w,
		MEMWB_MemtoReg_o    => MEMWB_MemtoReg_w,
		MEMWB_MulOp_o       => MEMWB_MulOp_w,
		MEMWB_wbsrc_o       => MEMWB_wbsrc_w
	);

	--=======================================
	-- Forwarding Unit (resolves RAW hazards for the EX-stage instruction)
	--=======================================
	FWD : ForwardingUnit
	PORT MAP (
		IDEX_rs1				=> IDEX_rs1_w,
		IDEX_rs2				=> IDEX_rs2_w,
		EXMEM_rd				=> EXMEM_rd_w,
		EXMEM_RegWrite	=> EXMEM_RegWrite_w,
		MEMWB_rd				=> MEMWB_rd_w,
		MEMWB_RegWrite	=> MEMWB_RegWrite_w,
		Forward_Ain			=> Forward_Ain_w,
		Forward_Bin			=> Forward_Bin_w
	);

	--=======================================
	-- Stall Condition Unit (destination-register collision across
	-- ID/EX, EX/MEM, and MEM/WB)
	--=======================================
	STALLU : StallConditionUnit
	PORT MAP (
		IFID_instruction_i => ifid_instr_w,
		IDEX_rd_i          => IDEX_rd_w,
		IDEX_MemRead_i     => IDEX_MemRead_w,
		IDEX_MulOp_i       => IDEX_MulOp_w,
		stall_o            => Stall_w,
		PCwrite_o          => PCwrite_w,
		IFID_write_o       => IF_IDwrite_w
	);

	--=======================================
	-- EXECUTE (EX stage: ALU + branch-target adder + forwarding muxes)
	--=======================================
	EXE:  Execute
  generic map(
		DATA_BUS_WIDTH 	=> 	DATA_BUS_WIDTH,
		PC_WIDTH 				=>	PC_WIDTH
	)
	PORT MAP (
		--Inputs
		read_data1_i 		=> IDEX_read_data1_w,
        read_data2_i 		=> IDEX_read_data2_w,
		sign_extend_i 	=> IDEX_sign_extend_w,
		UpperIm_ctrl_i 	=> IDEX_UpperIm_w,
		ALUOp_ctrl_i 		=> IDEX_ALUOp_w,
		ALUSrc_ctrl_i 	=> IDEX_ALUSrc_w,
		pc_i						=> IDEX_pc_w,
		fwd_ain_i				=> Forward_Ain_w,
		fwd_bin_i				=> Forward_Bin_w,
		exmem_alu_res_i	=> EXMEM_alu_res_w,
		memwb_wdata_i		=> wb_wdata_w,
		MULOP_i					=> IDEX_MulOp_w,

		--Outputs
		brTaken_o 			=> brTaken_w,
        alu_res_o			=> alu_res_w,
		addr_gen_o 			=> addr_gen_w,
		fwd_b_o				=> fwd_b_w,
		P0_o					=> EX_P0_w,
		P1_o					=> EX_P1_w,
		P2_o					=> EX_P2_w,
		P3_o					=> EX_P3_w
	);
	--=======================================
	-- DTCM module connection (MEM stage, off EX/MEM-registered signals)
	--=======================================
	G1:
	if (WORD_GRANULARITY = True) generate -- i.e. each WORD has a unike address
		dtcm_addr_w	<= EXMEM_alu_res_w(MA_WIDTH-1 DOWNTO 2); -- increment memory address by 4;
	elsif (WORD_GRANULARITY = False) generate -- i.e. each BYTE has a unike address
		dtcm_addr_w	<= EXMEM_alu_res_w(MA_WIDTH-1 DOWNTO 0);
	end generate;

	MEM:  dmemory
	generic map(
		DATA_BUS_WIDTH		=> 	DATA_BUS_WIDTH,
		DTCM_ADDR_WIDTH		=> 	DTCM_ADDR_WIDTH,
		WORDS_NUM					=>	DATA_WORDS_NUM
	)
	PORT MAP (
		--Inputs
		clk_i 						=> mclk_w,
		rst_i 						=> rst_i,
		Jalr_ctrl_i				=> EXMEM_Jalr_w,                 -- EX/MEM JALR flag
		Branch_or_jal_i		=> EXMEM_pcimm_redirect_ctrl_w, -- EX/MEM JAL/taken-branch flag
		dtcm_addr_i 			=> dtcm_addr_w,
		dtcm_data_wr_i 		=> EXMEM_read_data2_w,
		MemRead_ctrl_i 		=> EXMEM_MemRead_w,
		MemWrite_ctrl_i 	=> EXMEM_MemWrite_w,
		P0_i      				=> EXMEM_P0_w,
		P1_i      				=> EXMEM_P1_w,
		P2_i      				=> EXMEM_P2_w,
		P3_i      				=> EXMEM_P3_w,
		MULOP_i    				=> EXMEM_MulOp_w,

		--Outputs
		Flush_o					=> flush_w,                       -- redirect flush, drives IF/ID + ID/EX + EX/MEM
		dtcm_data_rd_o 		=> dtcm_data_rd_w,
		MUL_res_o 				=> MUL_res_w
	);

	--=======================================
	-- Write-Back mux (WB stage): MemtoReg(load) > wbsrc-selected ALU/MUL.
	-- RegDst(jal/jalr) PC+4 override is applied separately in ID_wdata_w below,
	-- not here — wb_wdata_w (this signal) does not carry the JAL/JALR value.
	--=======================================
	-- Inner MUX: ALU / MUL
	wb_inner_mux_w <= MEMWB_alu_res_w WHEN MEMWB_wbsrc_w = '1' ELSE
	                  MEMWB_MUL_res_w;

	-- Outer MUX: Memory (load) / inner MUX output
	wb_wdata_w <= MEMWB_dtcm_data_rd_w WHEN MEMWB_MemtoReg_w = '1' ELSE
	              wb_inner_mux_w;

	--=======================================
	-- MCLK counter register connection
	--=======================================
	process (mclk_w , rst_i)
	begin
		if rst_i = '1' then
			mclk_cnt_q	<=	(others	=> '0');
		elsif rising_edge(mclk_w) then
			mclk_cnt_q	<=	mclk_cnt_q + '1';
		end if;
	end process;

	--=======================================
	-- IPC / breakpoint support unit (LAB5 page 8)
	-- STCNT/FHCNT counters + IFPC==BPADDR Signal-Tap trigger
	--=======================================
	IPC : IPC_unit
	generic map(
		PC_WIDTH      => PC_WIDTH,
		CNT_WIDTH     => 8,
		BPADDR_WIDTH  => 8
	)
	PORT MAP (
		clk_i        => mclk_w,
		rst_i        => rst_i,
		stall_i      => Stall_w,
		flush_i      => flush_w,
		if_pc_i      => if_pc_w,
		BPADDR_i     => BPADDR_i,
		STCNT_o      => stcnt_w,
		FHCNT_o      => fhcnt_w,
		st_trigger_o => st_trigger_w
	);
---------------------------------------------------------------------------------------
-- Copying out important signals only for Verification and FPGA Velidation(Signal-TAP)
---------------------------------------------------------------------------------------
	pc_o							<=	ifid_pc_w;																	-- IFETCH output (IF/ID-stage PC)
  instruction_o 		<= 	ifid_instr_w;															-- IFETCH output (ID-stage instruction)

	--Per-stage PC/instruction taps (LAB5 page 8, Figure 8 top entity)
	IFpc_o						<=	if_pc_w;
	IFinstruction_o		<=	if_instr_w;
	IDpc_o						<=	ifid_pc_w;
	IDinstruction_o		<=	ifid_instr_w;
	EXpc_o						<=	IDEX_pc_w;
	EXinstruction_o		<=	IDEX_instruction_w;
	MEMpc_o						<=	EXMEM_pc_w;
	MEMinstruction_o	<=	EXMEM_instruction_w;
	WBpc_o						<=	MEMWB_pc_w;
	WBinstruction_o		<=	MEMWB_instruction_w;

	RegWrite_ctrl_o 	<= 	reg_write_w;																-- CONTROL output (ID stage)
  MemWrite_ctrl_o 	<= 	mem_write_w;																-- CONTROL output (ID stage)
	Branch_ctrl_o 		<= 	branch_w;																		-- CONTROL output (ID stage)

  read_data1_o 			<= 	read_data1_w;																-- IDECODE output (ID stage)
  read_data2_o 			<= 	read_data2_w;																-- IDECODE output (ID stage)
  write_data_o  		<= 	wb_wdata_w;																	-- WB-stage write-back value
  alu_res_o 				<= 	alu_res_w;																	-- EXECUTE output (EX stage)
  brTaken_o 				<= 	brTaken_w;																	-- EXECUTE output (EX stage)

	dtcm_addr_o 			<= 	dtcm_addr_w;																-- DMEMORY input (MEM stage)
	dtcm_data_wr_o 		<= 	EXMEM_read_data2_w;													-- DMEMORY input (MEM stage)
	dtcm_data_rd_o		<=	dtcm_data_rd_w;															-- DMEMORY output (MEM stage)

	mclk_cnt_o				<=	mclk_cnt_q;																	-- TOP output (CLKCNT_o)

	--IPC / breakpoint Signal-Tap auxiliary pins (LAB5 page 8)
	STCNT_o					<=	stcnt_w;																		-- stall counter
	FHCNT_o					<=	fhcnt_w;																		-- flush counter
	st_trigger_o			<=	st_trigger_w;																-- Signal-Tap trigger (IFPC == BPADDR_i)

---------------------------------------------------------------------------------------

END structure;
