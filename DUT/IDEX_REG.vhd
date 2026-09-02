--============================================================================
-- Copyright 2026
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- ID/EX Pipeline Register
-- Stall: insert bubble (zeros) | Flush: insert bubble (zeros)
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.all;

ENTITY IDEX_Reg IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH		: integer := G_PC_WIDTH
	);
	PORT(
		clk_i	: IN STD_LOGIC;
		rst_i	: IN STD_LOGIC;
		stall_i	: IN STD_LOGIC;
		flush_i	: IN STD_LOGIC;

		-- Inputs (from IDECODE + CONTROL)
		ID_pc_i				: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_pc_plus4_i		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ID_instruction_i	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		ID_read_data1_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		ID_read_data2_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		ID_sign_extend_i	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		ID_rs1_i			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		ID_rs2_i			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		ID_rd_i				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		ID_RegWrite_i		: IN STD_LOGIC;
		ID_MemtoReg_i		: IN STD_LOGIC;
		ID_MemRead_i		: IN STD_LOGIC;
		ID_MemWrite_i		: IN STD_LOGIC;
		ID_Branch_i			: IN STD_LOGIC;
		ID_Jal_i			: IN STD_LOGIC;
		ID_Jalr_i			: IN STD_LOGIC;
		ID_ALUSrc_i			: IN STD_LOGIC;
		ID_ALUOp_i			: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		ID_UpperIm_i		: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		ID_MulOp_i			: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		ID_wbsrc_i			: IN STD_LOGIC;
		ID_RegDst_i			: IN STD_LOGIC;

		-- Outputs (to EXECUTE)
		IDEX_pc_o			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IDEX_pc_plus4_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		IDEX_instruction_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDEX_read_data1_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDEX_read_data2_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDEX_sign_extend_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		IDEX_rs1_o			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		IDEX_rs2_o			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		IDEX_rd_o			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		IDEX_RegWrite_o		: OUT STD_LOGIC;
		IDEX_MemtoReg_o		: OUT STD_LOGIC;
		IDEX_MemRead_o		: OUT STD_LOGIC;
		IDEX_MemWrite_o		: OUT STD_LOGIC;
		IDEX_Branch_o		: OUT STD_LOGIC;
		IDEX_Jal_o			: OUT STD_LOGIC;
		IDEX_Jalr_o			: OUT STD_LOGIC;
		IDEX_ALUSrc_o		: OUT STD_LOGIC;
		IDEX_ALUOp_o		: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		IDEX_UpperIm_o		: OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
		IDEX_MulOp_o		: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		IDEX_wbsrc_o		: OUT STD_LOGIC;
		IDEX_RegDst_o		: OUT STD_LOGIC
	);
END IDEX_Reg;

ARCHITECTURE behavior OF IDEX_Reg IS
BEGIN
	PROCESS(clk_i, rst_i)
	BEGIN
	    IF rst_i = '1' THEN
	        IDEX_pc_o          <= (OTHERS => '0');
	        IDEX_pc_plus4_o    <= (OTHERS => '0');
	        IDEX_instruction_o <= (OTHERS => '0');
	        IDEX_read_data1_o  <= (OTHERS => '0');
	        IDEX_read_data2_o  <= (OTHERS => '0');
	        IDEX_sign_extend_o <= (OTHERS => '0');
	        IDEX_rs1_o         <= (OTHERS => '0');
	        IDEX_rs2_o         <= (OTHERS => '0');
	        IDEX_rd_o          <= (OTHERS => '0');
	        IDEX_RegWrite_o    <= '0';
	        IDEX_MemtoReg_o    <= '0';
	        IDEX_MemRead_o     <= '0';
	        IDEX_MemWrite_o    <= '0';
	        IDEX_Branch_o      <= '0';
	        IDEX_Jal_o         <= '0';
	        IDEX_Jalr_o        <= '0';
	        IDEX_ALUSrc_o      <= '0';
	        IDEX_ALUOp_o       <= (OTHERS => '0');
	        IDEX_UpperIm_o     <= (OTHERS => '0');
	        IDEX_MulOp_o       <= (OTHERS => '0');
	        IDEX_wbsrc_o       <= '0';
	        IDEX_RegDst_o      <= '0';

	    ELSIF rising_edge(clk_i) THEN
	        IF flush_i = '1' OR stall_i = '1' THEN
	            -- Bubble / NOP into ID/EX
	            IDEX_pc_o          <= (OTHERS => '0');
	            IDEX_pc_plus4_o    <= (OTHERS => '0');
	            IDEX_instruction_o <= (OTHERS => '0');
	            IDEX_read_data1_o  <= (OTHERS => '0');
	            IDEX_read_data2_o  <= (OTHERS => '0');
	            IDEX_sign_extend_o <= (OTHERS => '0');
	            IDEX_rs1_o         <= (OTHERS => '0');
	            IDEX_rs2_o         <= (OTHERS => '0');
	            IDEX_rd_o          <= (OTHERS => '0');
	            IDEX_RegWrite_o    <= '0';
	            IDEX_MemtoReg_o    <= '0';
	            IDEX_MemRead_o     <= '0';
	            IDEX_MemWrite_o    <= '0';
	            IDEX_Branch_o      <= '0';
	            IDEX_Jal_o         <= '0';
	            IDEX_Jalr_o        <= '0';
	            IDEX_ALUSrc_o      <= '0';
	            IDEX_ALUOp_o       <= (OTHERS => '0');
	            IDEX_UpperIm_o     <= (OTHERS => '0');
	            IDEX_MulOp_o       <= (OTHERS => '0');
	            IDEX_wbsrc_o       <= '0';
	            IDEX_RegDst_o      <= '0';

	        ELSE
	            -- Normal pipeline advance
	            IDEX_pc_o          <= ID_pc_i;
	            IDEX_pc_plus4_o    <= ID_pc_plus4_i;
	            IDEX_instruction_o <= ID_instruction_i;
	            IDEX_read_data1_o  <= ID_read_data1_i;
	            IDEX_read_data2_o  <= ID_read_data2_i;
	            IDEX_sign_extend_o <= ID_sign_extend_i;
	            IDEX_rs1_o         <= ID_rs1_i;
	            IDEX_rs2_o         <= ID_rs2_i;
	            IDEX_rd_o          <= ID_rd_i;
	            IDEX_RegWrite_o    <= ID_RegWrite_i;
	            IDEX_MemtoReg_o    <= ID_MemtoReg_i;
	            IDEX_MemRead_o     <= ID_MemRead_i;
	            IDEX_MemWrite_o    <= ID_MemWrite_i;
	            IDEX_Branch_o      <= ID_Branch_i;
	            IDEX_Jal_o         <= ID_Jal_i;
	            IDEX_Jalr_o        <= ID_Jalr_i;
	            IDEX_ALUSrc_o      <= ID_ALUSrc_i;
	            IDEX_ALUOp_o       <= ID_ALUOp_i;
	            IDEX_UpperIm_o     <= ID_UpperIm_i;
	            IDEX_MulOp_o       <= ID_MulOp_i;
	            IDEX_wbsrc_o       <= ID_wbsrc_i;
	            IDEX_RegDst_o      <= ID_RegDst_i;
	        END IF;
	    END IF;
	END PROCESS;
END behavior;
