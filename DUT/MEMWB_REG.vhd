--============================================================================
-- Copyright 2026
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- MEM/WB Pipeline Register
-- No flush or stall here — always propagates MEM_*_i normally.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.all;

ENTITY MEMWB_Reg IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH		: integer := G_PC_WIDTH
	);
	PORT(
		clk_i	: IN STD_LOGIC;
		rst_i	: IN STD_LOGIC;

		-- Inputs (from DMEMORY + Multiplier Stage 2)
		MEM_pc_i			: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_pc_plus4_i		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEM_instruction_i	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_alu_res_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_dtcm_data_rd_i	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_MUL_res_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEM_rd_i			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		MEM_RegDst_i		: IN STD_LOGIC;
		MEM_RegWrite_i		: IN STD_LOGIC;
		MEM_MemtoReg_i		: IN STD_LOGIC;
		MEM_MulOp_i			: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		MEM_wbsrc_i			: IN STD_LOGIC;

		-- Outputs (to WRITEBACK)
		MEMWB_pc_o			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEMWB_pc_plus4_o	: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		MEMWB_instruction_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMWB_alu_res_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMWB_dtcm_data_rd_o: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMWB_MUL_res_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		MEMWB_rd_o			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		MEMWB_RegDst_o		: OUT STD_LOGIC;
		MEMWB_RegWrite_o	: OUT STD_LOGIC;
		MEMWB_MemtoReg_o	: OUT STD_LOGIC;
		MEMWB_MulOp_o		: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		MEMWB_wbsrc_o		: OUT STD_LOGIC
	);
END MEMWB_Reg;

ARCHITECTURE behavior OF MEMWB_Reg IS
BEGIN
	PROCESS(clk_i, rst_i)
	BEGIN
	    IF rst_i = '1' THEN
	        MEMWB_pc_o           <= (OTHERS => '0');
	        MEMWB_pc_plus4_o     <= (OTHERS => '0');
	        MEMWB_instruction_o  <= (OTHERS => '0');
	        MEMWB_alu_res_o      <= (OTHERS => '0');
	        MEMWB_dtcm_data_rd_o <= (OTHERS => '0');
	        MEMWB_MUL_res_o      <= (OTHERS => '0');
	        MEMWB_rd_o           <= (OTHERS => '0');
	        MEMWB_RegDst_o       <= '0';
	        MEMWB_RegWrite_o     <= '0';
	        MEMWB_MemtoReg_o     <= '0';
	        MEMWB_MulOp_o        <= (OTHERS => '0');
	        MEMWB_wbsrc_o        <= '0';

	    ELSIF rising_edge(clk_i) THEN
	        MEMWB_pc_o           <= MEM_pc_i;
	        MEMWB_pc_plus4_o     <= MEM_pc_plus4_i;
	        MEMWB_instruction_o  <= MEM_instruction_i;
	        MEMWB_alu_res_o      <= MEM_alu_res_i;
	        MEMWB_dtcm_data_rd_o <= MEM_dtcm_data_rd_i;
	        MEMWB_MUL_res_o      <= MEM_MUL_res_i;
	        MEMWB_rd_o           <= MEM_rd_i;
	        MEMWB_RegDst_o       <= MEM_RegDst_i;
	        MEMWB_RegWrite_o     <= MEM_RegWrite_i;
	        MEMWB_MemtoReg_o     <= MEM_MemtoReg_i;
	        MEMWB_MulOp_o        <= MEM_MulOp_i;
	        MEMWB_wbsrc_o        <= MEM_wbsrc_i;
	    END IF;
	END PROCESS;
END behavior;
