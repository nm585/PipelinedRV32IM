--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- IPC / Breakpoint support unit (LAB5, task definition page 8)
--
-- Collects the auxiliary signals that the top entity must expose for
-- applications' IPC calculation and Signal-Tap breakpoint debug:
--
--   i.   STCNT_o  - stall  counter (8-bit), cleared on reset, counts on the
--                   clock rising edge each cycle a core stall occurs.
--   ii.  FHCNT_o  - flush  counter (8-bit), cleared on reset, counts on the
--                   clock rising edge each cycle a core flush occurs.
--   iii. st_trigger_o - Signal-Tap trigger: asserted when the fetch-stage PC
--                       (IFPC, word granularity) equals the breakpoint address
--                       BPADDR_i (fed by SW7-SW0 on the FPGA board).
--
-- The clock counter (CLKCNT_o) already exists in the core (mclk_cnt_o); together
-- with STCNT_o/FHCNT_o it lets software compute:
--   IPC = (CLKCNT_o - (STCNT_o + 4 + depth*FHCNT_o)) / CLKCNT_o = 1/CPI
-- where 'depth' is the pipeline depth penalty per flush.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY IPC_unit IS
    GENERIC (
        PC_WIDTH      : integer := 10;  -- width of the IF-stage PC (IFPC)
        CNT_WIDTH     : integer := 8;   -- STCNT_o / FHCNT_o width (page 8: 8-bit)
        BPADDR_WIDTH  : integer := 8    -- breakpoint address width (SW7-SW0)
    );
    PORT (
        --Inputs
        clk_i        : IN  STD_LOGIC;
        rst_i        : IN  STD_LOGIC;
        stall_i      : IN  STD_LOGIC;                                   -- core stall   (Stall_w)
        flush_i      : IN  STD_LOGIC;                                   -- core flush   (flush_w)
        if_pc_i      : IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);       -- IFPC (word granularity)
        BPADDR_i     : IN  STD_LOGIC_VECTOR(BPADDR_WIDTH-1 DOWNTO 0);   -- breakpoint addr (SW7-SW0)

        --Outputs
        STCNT_o      : OUT STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);      -- stall counter
        FHCNT_o      : OUT STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);      -- flush counter
        st_trigger_o : OUT STD_LOGIC                                    -- Signal-Tap trigger
    );
END IPC_unit;

ARCHITECTURE behave OF IPC_unit IS

    SIGNAL stcnt_q  : STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);
    SIGNAL fhcnt_q  : STD_LOGIC_VECTOR(CNT_WIDTH-1 DOWNTO 0);
    SIGNAL bpaddr_q : STD_LOGIC_VECTOR(BPADDR_WIDTH-1 DOWNTO 0);

BEGIN
    --------------------------------------------------------------------------
    -- (i) Stall counter : +1 on every rising edge a stall is active.
    --     Saturates at all-ones to avoid wrap-around corrupting the IPC math.
    --------------------------------------------------------------------------
    PROCESS (clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            stcnt_q <= (OTHERS => '0');
        ELSIF rising_edge(clk_i) THEN
            IF stall_i = '1' AND stcnt_q /= (stcnt_q'RANGE => '1') THEN  -- saturate at all-ones
                stcnt_q <= stcnt_q + 1;
            END IF;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    -- (ii) Flush counter : +1 on every rising edge a flush is active.
    --------------------------------------------------------------------------
    PROCESS (clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            fhcnt_q <= (OTHERS => '0');
        ELSIF rising_edge(clk_i) THEN
            IF flush_i = '1' AND fhcnt_q /= (fhcnt_q'RANGE => '1') THEN
                fhcnt_q <= fhcnt_q + 1;
            END IF;
        END IF;
    END PROCESS;

    STCNT_o <= stcnt_q;
    FHCNT_o <= fhcnt_q;

    --------------------------------------------------------------------------
    -- (iii) Breakpoint address register : cleared on reset, otherwise captures
    --       SW7-SW0 (BPADDR_i input). Page 8 specifies BPADDR_i as a register
    --       cleared on reset.
    --------------------------------------------------------------------------
    PROCESS (clk_i, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            bpaddr_q <= (OTHERS => '0');
        ELSIF rising_edge(clk_i) THEN
            bpaddr_q <= BPADDR_i;
        END IF;
    END PROCESS;

    --------------------------------------------------------------------------
    --       Signal-Tap trigger : IFPC == BPADDR (word granularity).
    --       Compare the low BPADDR_WIDTH bits of the fetch PC to the
    --       registered breakpoint address.
    --------------------------------------------------------------------------
    st_trigger_o <= '1' WHEN if_pc_i(BPADDR_WIDTH-1 DOWNTO 0) = bpaddr_q ELSE '0';

END behave;
