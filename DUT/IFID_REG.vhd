--============================================================================
-- Copyright 2026
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- IF/ID Pipeline Register
--   flush has priority over enable:
--     flush=1       → insert NOP (zeros)
--     ifid_write=0  → hold current value (stall freeze)
--     ifid_write=1  → capture IF-stage outputs {if_pc, if_pc4, if_instr}
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.all;

ENTITY IFID_Reg IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH		: integer := G_PC_WIDTH
	);
	PORT(
		clk_i			: IN  STD_LOGIC;
		rst_i			: IN  STD_LOGIC;
		flush_i			: IN  STD_LOGIC;   -- '1' inserts NOP (branch/jump taken)
		ifid_write_i	: IN  STD_LOGIC;   -- '0' freezes IF/ID on load-use stall

		-- IF-stage inputs (from IFETCH)
		if_pc_i			: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		if_pc4_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		if_instr_i		: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		-- IF/ID register outputs (to IDECODE / CONTROL / hazard units)
		ifid_pc_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ifid_pc4_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		ifid_instr_o	: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END IFID_Reg;

ARCHITECTURE behavior OF IFID_Reg IS
BEGIN
	PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			ifid_pc_o    <= (OTHERS => '0');
			ifid_pc4_o   <= (OTHERS => '0');
			ifid_instr_o <= (OTHERS => '0');
		ELSIF rising_edge(clk_i) THEN
			IF flush_i = '1' THEN
				ifid_pc_o    <= (OTHERS => '0');
				ifid_pc4_o   <= (OTHERS => '0');
				ifid_instr_o <= (OTHERS => '0');   -- NOP bubble
			ELSIF ifid_write_i = '1' THEN
				ifid_pc_o    <= if_pc_i;
				ifid_pc4_o   <= if_pc4_i;
				ifid_instr_o <= if_instr_i;
			END IF;
			-- ifid_write_i = '0' and flush = '0' → implicit hold (stall)
		END IF;
	END PROCESS;
END behavior;
