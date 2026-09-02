--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Forwarding Unit: detects RAW hazards and selects forwarding source
--   Forward_X = "10" → forward from EX/MEM (one instruction behind)
--   Forward_X = "01" → forward from MEM/WB (two instructions behind)
--   Forward_X = "00" → no hazard, use register file value
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY ForwardingUnit IS
    PORT(
        -- Source registers of instruction currently in EX stage (from ID/EX register)
        IDEX_rs1       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        IDEX_rs2       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        -- Destination and write-enable of instruction in MEM stage (from EX/MEM register)
        EXMEM_rd       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        EXMEM_RegWrite : IN  STD_LOGIC;
        -- Destination and write-enable of instruction in WB stage (from MEM/WB register)
        MEMWB_rd       : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
        MEMWB_RegWrite : IN  STD_LOGIC;
        -- Forwarding select outputs
        Forward_Ain    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        Forward_Bin    : OUT STD_LOGIC_VECTOR(1 DOWNTO 0)
    );
END ForwardingUnit;

ARCHITECTURE behavior OF ForwardingUnit IS
BEGIN

    -- Forwarding for ALU A input (rs1)
    PROCESS(IDEX_rs1, EXMEM_rd, EXMEM_RegWrite, MEMWB_rd, MEMWB_RegWrite)
    BEGIN
        -- EX hazard has priority: instruction in MEM just produced the value we need
        IF (EXMEM_RegWrite = '1' AND
            EXMEM_rd /= "00000" AND
            EXMEM_rd = IDEX_rs1) THEN
            Forward_Ain <= "10";

        -- MEM hazard: instruction in WB has the value (only if EX hazard not triggered)
        ELSIF (MEMWB_RegWrite = '1' AND
               MEMWB_rd /= "00000" AND
               MEMWB_rd = IDEX_rs1) THEN
            Forward_Ain <= "01";

        ELSE
            Forward_Ain <= "00";
        END IF;
    END PROCESS;

    -- Forwarding for ALU B input (rs2)
    PROCESS(IDEX_rs2, EXMEM_rd, EXMEM_RegWrite, MEMWB_rd, MEMWB_RegWrite)
    BEGIN
        IF (EXMEM_RegWrite = '1' AND
            EXMEM_rd /= "00000" AND
            EXMEM_rd = IDEX_rs2) THEN
            Forward_Bin <= "10";

        ELSIF (MEMWB_RegWrite = '1' AND
               MEMWB_rd /= "00000" AND
               MEMWB_rd = IDEX_rs2) THEN
            Forward_Bin <= "01";

        ELSE
            Forward_Bin <= "00";
        END IF;
    END PROCESS;

END behavior;
