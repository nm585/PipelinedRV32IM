--============================================================================
-- Copyright 2026
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- EX/MEM Pipeline Register
-- Flushes on flush_i (no stall handling here). flush_i is '1' when the
-- resolving JALR/JAL/branch instruction is in EX/MEM; on that edge MEM/WB
-- samples the current EX/MEM outputs before they are overwritten, so the
-- resolving instruction's write-back still commits, while the wrong-path
-- instruction loaded from EX is bubbled.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.all;

ENTITY EXMEM_Reg IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH		: integer := G_PC_WIDTH
	);
	PORT(
		clk_i	: IN STD_LOGIC;
		rst_i	: IN STD_LOGIC;
		flush_i	: IN STD_LOGIC;

		-- Inputs (from EXECUTE + Multiplier Stage 1)
		EX_pc_i				: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_pc_plus4_i		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_instruction_i	: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_alu_res_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_addr_gen_i		: IN STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EX_brTaken_i		: IN STD_LOGIC;
		EX_read_data2_i		: IN STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EX_P0_i				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P1_i				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P2_i				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_P3_i				: IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		EX_rd_i				: IN STD_LOGIC_VECTOR(4 DOWNTO 0);
		EX_RegWrite_i		: IN STD_LOGIC;
		EX_MemtoReg_i		: IN STD_LOGIC;
		EX_MemRead_i		: IN STD_LOGIC;
		EX_MemWrite_i		: IN STD_LOGIC;
		EX_Branch_i			: IN STD_LOGIC;
		EX_Jal_i			: IN STD_LOGIC;
		EX_Jalr_i			: IN STD_LOGIC;
		EX_MulOp_i			: IN STD_LOGIC_VECTOR(6 DOWNTO 0);
		EX_wbsrc_i			: IN STD_LOGIC;
		EX_RegDst_i			: IN STD_LOGIC;
		EX_pcimm_redirect_ctrl_i : IN STD_LOGIC;

		-- Outputs (to DMEMORY + Multiplier Stage 2)
		EXMEM_pc_o			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXMEM_pc_plus4_o	: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXMEM_instruction_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EXMEM_alu_res_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EXMEM_addr_gen_o	: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		EXMEM_brTaken_o		: OUT STD_LOGIC;
		EXMEM_read_data2_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		EXMEM_P0_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		EXMEM_P1_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		EXMEM_P2_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		EXMEM_P3_o			: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		EXMEM_rd_o			: OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		EXMEM_RegWrite_o	: OUT STD_LOGIC;
		EXMEM_MemtoReg_o	: OUT STD_LOGIC;
		EXMEM_MemRead_o		: OUT STD_LOGIC;
		EXMEM_MemWrite_o	: OUT STD_LOGIC;
		EXMEM_Branch_o		: OUT STD_LOGIC;
		EXMEM_Jal_o			: OUT STD_LOGIC;
		EXMEM_Jalr_o		: OUT STD_LOGIC;
		EXMEM_MulOp_o		: OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
		EXMEM_wbsrc_o		: OUT STD_LOGIC;
		EXMEM_RegDst_o		: OUT STD_LOGIC;
		EXMEM_pcimm_redirect_ctrl_o : OUT STD_LOGIC
	);
END EXMEM_Reg;

ARCHITECTURE behavior OF EXMEM_Reg IS
BEGIN
	PROCESS(clk_i, rst_i)
	BEGIN
	    IF rst_i = '1' THEN
	        EXMEM_pc_o         <= (OTHERS => '0');
	        EXMEM_pc_plus4_o   <= (OTHERS => '0');
	        EXMEM_instruction_o<= (OTHERS => '0');
	        EXMEM_alu_res_o    <= (OTHERS => '0');
	        EXMEM_addr_gen_o   <= (OTHERS => '0');
	        EXMEM_brTaken_o    <= '0';
	        EXMEM_read_data2_o <= (OTHERS => '0');
	        EXMEM_P0_o         <= (OTHERS => '0');
	        EXMEM_P1_o         <= (OTHERS => '0');
	        EXMEM_P2_o         <= (OTHERS => '0');
	        EXMEM_P3_o         <= (OTHERS => '0');
	        EXMEM_rd_o         <= (OTHERS => '0');
	        EXMEM_RegWrite_o   <= '0';
	        EXMEM_MemtoReg_o   <= '0';
	        EXMEM_MemRead_o    <= '0';
	        EXMEM_MemWrite_o   <= '0';
	        EXMEM_Branch_o     <= '0';
	        EXMEM_Jal_o        <= '0';
	        EXMEM_Jalr_o       <= '0';
	        EXMEM_MulOp_o      <= (OTHERS => '0');
	        EXMEM_wbsrc_o      <= '0';
	        EXMEM_RegDst_o     <= '0';
	        EXMEM_pcimm_redirect_ctrl_o <= '0';

	    ELSIF rising_edge(clk_i) THEN
	        IF flush_i = '1' THEN
	            EXMEM_pc_o         <= (OTHERS => '0');
	            EXMEM_pc_plus4_o   <= (OTHERS => '0');
	            EXMEM_instruction_o<= (OTHERS => '0');
	            EXMEM_alu_res_o    <= (OTHERS => '0');
	            EXMEM_addr_gen_o   <= (OTHERS => '0');
	            EXMEM_brTaken_o    <= '0';
	            EXMEM_read_data2_o <= (OTHERS => '0');
	            EXMEM_P0_o         <= (OTHERS => '0');
	            EXMEM_P1_o         <= (OTHERS => '0');
	            EXMEM_P2_o         <= (OTHERS => '0');
	            EXMEM_P3_o         <= (OTHERS => '0');
	            EXMEM_rd_o         <= (OTHERS => '0');
	            EXMEM_RegWrite_o   <= '0';
	            EXMEM_MemtoReg_o   <= '0';
	            EXMEM_MemRead_o    <= '0';
	            EXMEM_MemWrite_o   <= '0';
	            EXMEM_Branch_o     <= '0';
	            EXMEM_Jal_o        <= '0';
	            EXMEM_Jalr_o       <= '0';
	            EXMEM_MulOp_o      <= (OTHERS => '0');
	            EXMEM_wbsrc_o      <= '0';
	            EXMEM_RegDst_o     <= '0';
	            EXMEM_pcimm_redirect_ctrl_o <= '0';

	        ELSE
	            EXMEM_pc_o         <= EX_pc_i;
	            EXMEM_pc_plus4_o   <= EX_pc_plus4_i;
	            EXMEM_instruction_o<= EX_instruction_i;
	            EXMEM_alu_res_o    <= EX_alu_res_i;
	            EXMEM_addr_gen_o   <= EX_addr_gen_i;
	            EXMEM_brTaken_o    <= EX_brTaken_i;
	            EXMEM_read_data2_o <= EX_read_data2_i;
	            EXMEM_P0_o         <= EX_P0_i;
	            EXMEM_P1_o         <= EX_P1_i;
	            EXMEM_P2_o         <= EX_P2_i;
	            EXMEM_P3_o         <= EX_P3_i;
	            EXMEM_rd_o         <= EX_rd_i;
	            EXMEM_RegWrite_o   <= EX_RegWrite_i;
	            EXMEM_MemtoReg_o   <= EX_MemtoReg_i;
	            EXMEM_MemRead_o    <= EX_MemRead_i;
	            EXMEM_MemWrite_o   <= EX_MemWrite_i;
	            EXMEM_Branch_o     <= EX_Branch_i;
	            EXMEM_Jal_o        <= EX_Jal_i;
	            EXMEM_Jalr_o       <= EX_Jalr_i;
	            EXMEM_MulOp_o      <= EX_MulOp_i;
	            EXMEM_wbsrc_o      <= EX_wbsrc_i;
	            EXMEM_RegDst_o     <= EX_RegDst_i;
	            EXMEM_pcimm_redirect_ctrl_o <= EX_pcimm_redirect_ctrl_i;
	        END IF;
	    END IF;
	END PROCESS;
END behavior;
