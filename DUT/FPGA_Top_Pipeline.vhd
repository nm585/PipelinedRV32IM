LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.cond_compilation_package.ALL;
USE work.aux_package.ALL;
--------------------------------------------------------------
-- LAB5 page 8, Figure 8: Pipelined RISC-V architecture top entity
--------------------------------------------------------------

ENTITY FPGA_Top_Pipeline IS
    GENERIC (
        WORD_GRANULARITY : boolean := G_WORD_GRANULARITY;
        DATA_BUS_WIDTH   : integer := 32;
        ITCM_ADDR_WIDTH  : integer := G_ADDRWIDTH;
        DTCM_ADDR_WIDTH  : integer := G_ADDRWIDTH;
        PC_WIDTH         : integer := G_PC_WIDTH;
        MA_WIDTH         : integer := G_MA_WIDTH;
        DATA_WORDS_NUM   : integer := G_DATA_WORDSNUM;
        CLK_CNT_WIDTH    : integer := 16
    );
    PORT (
        CLOCK_50_i       : IN  STD_LOGIC;
        KEY0_i           : IN  STD_LOGIC;
        SW_i             : IN  STD_LOGIC_VECTOR(7 DOWNTO 0);

        clkcnt_o         : OUT STD_LOGIC_VECTOR(CLK_CNT_WIDTH-1 DOWNTO 0);

        IFpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        IFinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        IDpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        IDinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        EXpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        EXinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        MEMpc_o          : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        MEMinstruction_o : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
        WBpc_o           : OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
        WBinstruction_o  : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

        STRIGGER_o       : OUT STD_LOGIC;
        FHCNT_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        STCNT_o          : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END FPGA_Top_Pipeline;
-------------------------------------------------------------------------------

ARCHITECTURE tp_pipe OF FPGA_Top_Pipeline IS

    SIGNAL key0_pressed_seen_q : STD_LOGIC := '0';
    SIGNAL rst_req_w           : STD_LOGIC;
    SIGNAL rst_sync_reg        : STD_LOGIC_VECTOR(1 DOWNTO 0) := (others => '0');

BEGIN

    -- Remember that KEY0 was pressed at least once after FPGA configuration
    process(CLOCK_50_i)
    begin
        if rising_edge(CLOCK_50_i) then
            if KEY0_i = '0' then
                key0_pressed_seen_q <= '1';
            end if;
        end if;
    end process;

    -- Hold the core in reset until KEY0 was pressed.
    -- Also keep reset active while KEY0 is currently pressed.
    rst_req_w <= '1' when (key0_pressed_seen_q = '0') or (KEY0_i = '0') else '0';

    -- Synchronize reset request into the core's reset input
    process(CLOCK_50_i)
    begin
        if rising_edge(CLOCK_50_i) then
            rst_sync_reg <= rst_sync_reg(0) & rst_req_w;
        end if;
    end process;

    CORE : RV32I_CORE
        GENERIC MAP (
            WORD_GRANULARITY => WORD_GRANULARITY,
            MODELSIM         => G_MODELSIM,  -- FPGA / Quartus mode, activates PLL inside RV32I_CORE
            DATA_BUS_WIDTH   => DATA_BUS_WIDTH,
            ITCM_ADDR_WIDTH  => ITCM_ADDR_WIDTH,
            DTCM_ADDR_WIDTH  => DTCM_ADDR_WIDTH,
            PC_WIDTH         => PC_WIDTH,
            MA_WIDTH         => MA_WIDTH,
            DATA_WORDS_NUM   => DATA_WORDS_NUM,
            CLK_CNT_WIDTH    => CLK_CNT_WIDTH
        )
        PORT MAP (
            rst_i            => rst_sync_reg(1),  -- synchronized KEY0 reset: held until KEY0 pressed once, see above
            clk_i            => CLOCK_50_i,

            IFpc_o           => IFpc_o,
            IFinstruction_o  => IFinstruction_o,
            IDpc_o           => IDpc_o,
            IDinstruction_o  => IDinstruction_o,
            EXpc_o           => EXpc_o,
            EXinstruction_o  => EXinstruction_o,
            MEMpc_o          => MEMpc_o,
            MEMinstruction_o => MEMinstruction_o,
            WBpc_o           => WBpc_o,
            WBinstruction_o  => WBinstruction_o,

            mclk_cnt_o       => clkcnt_o,

            BPADDR_i         => SW_i,      -- breakpoint address, fed by SW7-SW0
            STCNT_o          => STCNT_o,
            FHCNT_o          => FHCNT_o,
            st_trigger_o     => STRIGGER_o
        );

END tp_pipe;
