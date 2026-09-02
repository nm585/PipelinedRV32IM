--============================================================================
-- Copyright 2026
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Multiplier Stage 2 (MEM stage): combine partial products
-- M=P1+P2, RESULT = P0 + (M<<8) + (P3<<16)
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


ENTITY Multiplier_Stage2 IS
	GENERIC (
		DATA_BUS_WIDTH : integer := 32
	);
	PORT (
		--Inputs: partial products from Stage 1 (via EX/MEM register)
		P0_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		P1_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		P2_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		P3_i      : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
		-- Width matches the opcode field (7 bits, instruction[6:0]) as a placeholder
		-- for future M-extension variants (MULH/MULHSU/MULHU/DIV/...); only
		-- "is this any mul op" matters today.
		MULOP     : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);

		--Output
		MUL_res_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);
END Multiplier_Stage2;


ARCHITECTURE struct OF Multiplier_Stage2 IS

	SIGNAL M_w      : unsigned(16 DOWNTO 0);
	SIGNAL result_w : unsigned(31 DOWNTO 0);

BEGIN

	-- Stage 2: M = P1 + P2  (17-bit to capture carry)
	M_w <= ('0' & unsigned(P1_i)) + ('0' & unsigned(P2_i));

	-- RESULT = P0 + (M<<8) + (P3<<16)
	result_w <= ("0000000000000000" & unsigned(P0_i))    +
	            ("0000000" & M_w & "00000000")           +
	            (unsigned(P3_i) & "0000000000000000");

	MUL_res_o <= std_logic_vector(result_w) WHEN MULOP /= "0000000" ELSE (OTHERS => '0');

END struct;
