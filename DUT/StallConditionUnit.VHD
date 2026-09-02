--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Stall Condition Unit
--
-- Load-use / MUL-use hazard detector (same structure as the reference
-- Stall_cond_unit): the rs1/rs2 source registers are extracted directly from
-- the instruction currently in IF/ID, and compared against the destination
-- register of the instruction in EX (ID/EX). A bubble is inserted when the
-- EX-stage instruction is a load or a MUL (whose real result is not available
-- combinationally this cycle) and the IF/ID instruction needs that result.
-- One stall cycle delays it until the producer reaches MEM/WB, where the
-- ForwardingUnit forwards the resolved write-back value.
--
-- Output:
--   PCwrite_o      = '0'  -> freeze PC register
--   IFID_write_o   = '0'  -> freeze IF/ID register
--   stall_o        = '1'  -> insert bubble into ID/EX
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY StallConditionUnit IS
    PORT (
        -- instruction currently in IF/ID (rs1/rs2 extracted internally)
        IFID_instruction_i : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);

        -- info from the ID/EX stage (EX-stage producer)
        IDEX_rd_i          : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        IDEX_MemRead_i     : IN  STD_LOGIC;                     -- load op
        IDEX_MulOp_i       : IN  STD_LOGIC_VECTOR(6 DOWNTO 0);  -- MUL op (0 = none)

        -- outputs
        stall_o            : OUT STD_LOGIC;
        PCwrite_o          : OUT STD_LOGIC;
        IFID_write_o       : OUT STD_LOGIC
    );
END StallConditionUnit;

ARCHITECTURE behave OF StallConditionUnit IS

    SIGNAL IFID_rs1_w        : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL IFID_rs2_w        : STD_LOGIC_VECTOR(4 DOWNTO 0);
    SIGNAL load_use_hazard_w : STD_LOGIC;

BEGIN

    -- Extract rs1/rs2 from the instruction in IF/ID
    IFID_rs1_w <= IFID_instruction_i(19 DOWNTO 15);
    IFID_rs2_w <= IFID_instruction_i(24 DOWNTO 20);

    -- Detect load-use / MUL-use hazard
    load_use_hazard_w <= '1' WHEN
        (IDEX_MemRead_i = '1' OR IDEX_MulOp_i /= "0000000") AND
        IDEX_rd_i /= "00000" AND
        (
            IDEX_rd_i = IFID_rs1_w OR
            IDEX_rd_i = IFID_rs2_w
        )
    ELSE '0';

    -- Outputs
    stall_o      <= load_use_hazard_w;

    PCwrite_o    <= '0' WHEN load_use_hazard_w = '1' ELSE '1';

    IFID_write_o <= '0' WHEN load_use_hazard_w = '1' ELSE '1';

END behave;
