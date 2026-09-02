---------------------------------------------------------------------------------------------
-- Copyright 2025 Hananya Ribo 
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
---------------------------------------------------------------------------------------------
library IEEE;
use ieee.std_logic_1164.all;
USE work.cond_compilation_package.all;


package aux_package is

	component RV32I_CORE is
		generic( 
			WORD_GRANULARITY 	: boolean 	:= G_WORD_GRANULARITY;
	    MODELSIM 					: integer 	:= G_MODELSIM;
			DATA_BUS_WIDTH 		: integer 	:= 32;
			ITCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			DTCM_ADDR_WIDTH 	: integer 	:= G_ADDRWIDTH;
			PC_WIDTH 					: integer 	:= 10;
			MA_WIDTH 					: integer 	:= 10;
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
			BPADDR_i					:IN		STD_LOGIC_VECTOR(7 DOWNTO 0);
			STCNT_o						:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			FHCNT_o						:OUT	STD_LOGIC_VECTOR(7 DOWNTO 0);
			st_trigger_o			:OUT	STD_LOGIC
		);
	end component;
---------------------------------------------------------  
	component control is
		PORT( 
		--Inputs
		instruction_i 		: IN 	STD_LOGIC_VECTOR(31 DOWNTO 0);
		
		--Outputs
		RegDst_ctrl_o 		: OUT 	STD_LOGIC;
		ALUSrc_ctrl_o 		: OUT 	STD_LOGIC;
		MemtoReg_ctrl_o 	: OUT 	STD_LOGIC;
		RegWrite_ctrl_o 	: OUT 	STD_LOGIC;
		MemRead_ctrl_o 		: OUT 	STD_LOGIC;
		MemWrite_ctrl_o	 	: OUT 	STD_LOGIC;
		Branch_ctrl_o 		: OUT 	STD_LOGIC;
		Jal_ctrl_o 				: OUT 	STD_LOGIC;
		Jalr_ctrl_o 			: OUT 	STD_LOGIC;
		UpperIm_ctrl_o		: OUT 	STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_o	 		: OUT 	STD_LOGIC_VECTOR(4 DOWNTO 0);
		MUL_OP_ctrl_o		: OUT 	STD_LOGIC_VECTOR(6 DOWNTO 0);
		wbsrc_ctrl_o		: OUT 	STD_LOGIC
	);
	end component;
---------------------------------------------------------	
	component dmemory is
		generic(
			DATA_BUS_WIDTH 	: integer := 32;
			DTCM_ADDR_WIDTH : integer := 8;
			WORDS_NUM 			: integer := 256
		);
		PORT(	
			--Inputs
			clk_i						: IN 	STD_LOGIC;
			rst_i						: IN 	STD_LOGIC;
			Jalr_ctrl_i			: IN 	STD_LOGIC;
			Branch_or_jal_i	: IN 	STD_LOGIC;
			dtcm_addr_i 		: IN 	STD_LOGIC_VECTOR(DTCM_ADDR_WIDTH-1 DOWNTO 0);
			dtcm_data_wr_i 	: IN 	STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MemRead_ctrl_i  : IN 	STD_LOGIC;
			MemWrite_ctrl_i : IN 	STD_LOGIC;
			P0_i      			: IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P1_i      			: IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P2_i      			: IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P3_i      			: IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			MULOP_i    			: IN  STD_LOGIC_VECTOR(6 DOWNTO 0);

			--Outputs
			Flush_o					: OUT STD_LOGIC;
			dtcm_data_rd_o 	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MUL_res_o 			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Execute is
		generic(
			DATA_BUS_WIDTH	: integer := 32;
			PC_WIDTH		: integer := 10
		);
		PORT(
			-- From ID/EX register
			read_data1_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			sign_extend_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			UpperIm_ctrl_i	: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			ALUOp_ctrl_i	: IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ALUSrc_ctrl_i	: IN  STD_LOGIC;
			pc_i			: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			-- Forwarding control
			fwd_ain_i		: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			fwd_bin_i		: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			-- Forwarding data sources
			exmem_alu_res_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			memwb_wdata_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MULOP_i			: IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			-- Outputs
			brTaken_o		: OUT STD_LOGIC;
			alu_res_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			addr_gen_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			fwd_b_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			P0_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P1_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P2_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P3_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Idecode is
		generic(
			PC_WIDTH       : integer := 10;
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			clk_i          : IN  STD_LOGIC;
			rst_i          : IN  STD_LOGIC;
			instruction_i  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			-- WB stage write-back (from WB mux in core)
			wb_wdata_i     : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			wb_rd_i        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			wb_regwrite_i  : IN  STD_LOGIC;
			-- To ID/EX register + hazard units
			read_data1_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			read_data2_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			SignExt_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			rs1_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rs2_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			rd_o           : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
		);
	end component;
---------------------------------------------------------		
	component Ifetch is
		generic(
			WORD_GRANULARITY	: boolean	:= False;
			DATA_BUS_WIDTH		: integer	:= 32;
			PC_WIDTH			: integer	:= 10;
			ITCM_ADDR_WIDTH		: integer	:= 8;
			WORDS_NUM			: integer	:= 256
		);
		PORT(
			-- Clock / reset
			clk_i				: IN  STD_LOGIC;
			rst_i				: IN  STD_LOGIC;
			-- EX-stage feedback
			ex_brtarget_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ex_jalrtgt_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			jalr_sel_i			: IN  STD_LOGIC;
			redirect_active_i	: IN  STD_LOGIC;
			-- Stall control
			pc_write_i			: IN  STD_LOGIC;
			-- IF-stage outputs (combinational; captured by IFID_Reg)
			if_pc_o				: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			if_pc4_o			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			if_instr_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component IFID_Reg is
		generic(
			DATA_BUS_WIDTH	: integer := 32;
			PC_WIDTH		: integer := G_PC_WIDTH
		);
		PORT(
			clk_i			: IN  STD_LOGIC;
			rst_i			: IN  STD_LOGIC;
			flush_i			: IN  STD_LOGIC;
			ifid_write_i	: IN  STD_LOGIC;
			if_pc_i			: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			if_pc4_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			if_instr_i		: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ifid_pc_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ifid_pc4_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ifid_instr_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	COMPONENT PLL IS
		port(
			areset		: IN STD_LOGIC  := '0';
			inclk0		: IN STD_LOGIC  := '0';
			c0     		: OUT STD_LOGIC ;
			locked		: OUT STD_LOGIC 
		);
  END COMPONENT;
---------------------------------------------------------
	component Multiplier_Stage1 is
		generic(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			Ain   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			Bin   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MULOP : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			P0_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P1_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P2_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			P3_o : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component Multiplier_Stage2 is
		generic(
			DATA_BUS_WIDTH : integer := 32
		);
		PORT(
			P0_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P1_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P2_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			P3_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			MULOP     : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			MUL_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component IDEX_Reg is
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := G_PC_WIDTH
		);
		PORT(
			clk_i   : IN STD_LOGIC;
			rst_i   : IN STD_LOGIC;
			stall_i : IN STD_LOGIC;
			flush_i : IN STD_LOGIC;
			ID_pc_i            : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ID_pc_plus4_i      : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			ID_instruction_i   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ID_read_data1_i    : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ID_read_data2_i    : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ID_sign_extend_i   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			ID_rs1_i           : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ID_rs2_i           : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ID_rd_i            : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ID_RegWrite_i      : IN  STD_LOGIC;
			ID_MemtoReg_i      : IN  STD_LOGIC;
			ID_MemRead_i       : IN  STD_LOGIC;
			ID_MemWrite_i      : IN  STD_LOGIC;
			ID_Branch_i        : IN  STD_LOGIC;
			ID_Jal_i           : IN  STD_LOGIC;
			ID_Jalr_i          : IN  STD_LOGIC;
			ID_ALUSrc_i        : IN  STD_LOGIC;
			ID_ALUOp_i         : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			ID_UpperIm_i       : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
			ID_MulOp_i         : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			ID_wbsrc_i         : IN  STD_LOGIC;
			ID_RegDst_i        : IN  STD_LOGIC;
			IDEX_pc_o          : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IDEX_pc_plus4_o    : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			IDEX_instruction_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDEX_read_data1_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDEX_read_data2_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDEX_sign_extend_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			IDEX_rs1_o         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_rs2_o         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_rd_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_RegWrite_o    : OUT STD_LOGIC;
			IDEX_MemtoReg_o    : OUT STD_LOGIC;
			IDEX_MemRead_o     : OUT STD_LOGIC;
			IDEX_MemWrite_o    : OUT STD_LOGIC;
			IDEX_Branch_o      : OUT STD_LOGIC;
			IDEX_Jal_o         : OUT STD_LOGIC;
			IDEX_Jalr_o        : OUT STD_LOGIC;
			IDEX_ALUSrc_o      : OUT STD_LOGIC;
			IDEX_ALUOp_o       : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_UpperIm_o     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			IDEX_MulOp_o       : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			IDEX_wbsrc_o       : OUT STD_LOGIC;
			IDEX_RegDst_o      : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component EXMEM_Reg is
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := G_PC_WIDTH
		);
		PORT(
			clk_i   : IN STD_LOGIC;
			rst_i   : IN STD_LOGIC;
			flush_i : IN STD_LOGIC;
			EX_pc_i            : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EX_pc_plus4_i      : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EX_instruction_i   : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EX_alu_res_i       : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EX_addr_gen_i      : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EX_brTaken_i       : IN  STD_LOGIC;
			EX_read_data2_i    : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EX_P0_i            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			EX_P1_i            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			EX_P2_i            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			EX_P3_i            : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
			EX_rd_i            : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			EX_RegWrite_i      : IN  STD_LOGIC;
			EX_MemtoReg_i      : IN  STD_LOGIC;
			EX_MemRead_i       : IN  STD_LOGIC;
			EX_MemWrite_i      : IN  STD_LOGIC;
			EX_Branch_i        : IN  STD_LOGIC;
			EX_Jal_i           : IN  STD_LOGIC;
			EX_Jalr_i          : IN  STD_LOGIC;
			EX_MulOp_i         : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			EX_wbsrc_i         : IN  STD_LOGIC;
			EX_RegDst_i        : IN  STD_LOGIC;
			EX_pcimm_redirect_ctrl_i : IN  STD_LOGIC;
			EXMEM_pc_o         : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EXMEM_pc_plus4_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EXMEM_instruction_o: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EXMEM_alu_res_o    : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EXMEM_addr_gen_o   : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			EXMEM_brTaken_o    : OUT STD_LOGIC;
			EXMEM_read_data2_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			EXMEM_P0_o         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			EXMEM_P1_o         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			EXMEM_P2_o         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			EXMEM_P3_o         : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
			EXMEM_rd_o         : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			EXMEM_RegWrite_o   : OUT STD_LOGIC;
			EXMEM_MemtoReg_o   : OUT STD_LOGIC;
			EXMEM_MemRead_o    : OUT STD_LOGIC;
			EXMEM_MemWrite_o   : OUT STD_LOGIC;
			EXMEM_Branch_o     : OUT STD_LOGIC;
			EXMEM_Jal_o        : OUT STD_LOGIC;
			EXMEM_Jalr_o       : OUT STD_LOGIC;
			EXMEM_MulOp_o      : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			EXMEM_wbsrc_o      : OUT STD_LOGIC;
			EXMEM_RegDst_o     : OUT STD_LOGIC;
			EXMEM_pcimm_redirect_ctrl_o : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component MEMWB_Reg is
		generic(
			DATA_BUS_WIDTH : integer := 32;
			PC_WIDTH       : integer := G_PC_WIDTH
		);
		PORT(
			clk_i   : IN STD_LOGIC;
			rst_i   : IN STD_LOGIC;
			MEM_pc_i           : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEM_pc_plus4_i     : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEM_instruction_i  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEM_alu_res_i      : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEM_dtcm_data_rd_i : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEM_MUL_res_i      : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEM_rd_i           : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			MEM_RegDst_i       : IN  STD_LOGIC;
			MEM_RegWrite_i     : IN  STD_LOGIC;
			MEM_MemtoReg_i     : IN  STD_LOGIC;
			MEM_MulOp_i        : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			MEM_wbsrc_i        : IN  STD_LOGIC;
			MEMWB_pc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEMWB_pc_plus4_o     : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			MEMWB_instruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMWB_alu_res_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMWB_dtcm_data_rd_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMWB_MUL_res_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
			MEMWB_rd_o           : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
			MEMWB_RegDst_o       : OUT STD_LOGIC;
			MEMWB_RegWrite_o     : OUT STD_LOGIC;
			MEMWB_MemtoReg_o     : OUT STD_LOGIC;
			MEMWB_MulOp_o        : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
			MEMWB_wbsrc_o        : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component ForwardingUnit is
		PORT(
			IDEX_rs1       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_rs2       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			EXMEM_rd       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			EXMEM_RegWrite : IN  STD_LOGIC;
			MEMWB_rd       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			MEMWB_RegWrite : IN  STD_LOGIC;
			Forward_Ain    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
			Forward_Bin    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
		);
	end component;
---------------------------------------------------------
	component StallConditionUnit is
		PORT(
			IFID_instruction_i : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
			IDEX_rd_i          : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
			IDEX_MemRead_i     : IN  STD_LOGIC;
			IDEX_MulOp_i       : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);
			stall_o            : OUT STD_LOGIC;
			PCwrite_o          : OUT STD_LOGIC;
			IFID_write_o       : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------
	component IPC_unit is
		GENERIC (
			PC_WIDTH      : integer := 10;
			CNT_WIDTH     : integer := 8;
			BPADDR_WIDTH  : integer := 8
		);
		PORT(
			clk_i        : IN  STD_LOGIC;
			rst_i        : IN  STD_LOGIC;
			stall_i      : IN  STD_LOGIC;
			flush_i      : IN  STD_LOGIC;
			if_pc_i      : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
			BPADDR_i     : IN  STD_LOGIC_VECTOR(BPADDR_WIDTH-1 DOWNTO 0);
			STCNT_o      : OUT STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);
			FHCNT_o      : OUT STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);
			st_trigger_o : OUT STD_LOGIC
		);
	end component;
---------------------------------------------------------

end aux_package;


