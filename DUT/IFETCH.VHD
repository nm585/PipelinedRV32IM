--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- IFETCH: PC register, ITCM, PC+4 adder, redirect muxes (IF stage only).
-- The IF/ID pipeline register now lives in IFID_REG.vhd; this module exposes
-- the combinational IF-stage outputs {if_pc_o, if_pc4_o, if_instr_o}.
--
-- Two-mux PC-select logic:
--   Mux 1 (redirect_target_w) : redirect_active_i → 1=ex_brtarget_i / 0=if_pc4_w
--   Mux 2 (pc_next_w, final)  : jalr_sel_i → 1=ex_jalrtgt_i / 0=redirect_target_w
-- jalr_sel_i has absolute priority: when it's '1', redirect_active_i is ignored.
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;


ENTITY Ifetch IS
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

		-- EX-stage / EX-MEM-stage feedback for PC redirect.
		-- ex_brtarget_i, ex_jalrtgt_i, jalr_sel_i and redirect_active_i are all
		-- EX/MEM-stage (registered), matching flush_w's timing in RV32I_CORE.vhd.
		ex_brtarget_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);   -- EX/MEM-stage (registered) branch/JAL target
		ex_jalrtgt_i		: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);   -- EX/MEM-stage (registered) JALR target
		jalr_sel_i			: IN  STD_LOGIC;                               -- EX/MEM-stage Jalr flag (mux 2 select)
		redirect_active_i	: IN  STD_LOGIC;                               -- EX/MEM-stage Jal/taken-branch flag (mux 1 select)

		-- Stall control (from StallConditionUnit)
		pc_write_i			: IN  STD_LOGIC;   -- '0' freezes PC on load-use stall

		-- IF-stage outputs (combinational; captured by IFID_Reg)
		if_pc_o				: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);   -- current PC (also Signal-Tap trigger)
		if_pc4_o			: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);   -- PC + 4
		if_instr_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)  -- ITCM instruction word
	);
END Ifetch;


ARCHITECTURE behavior OF Ifetch IS

	SIGNAL pc_q					: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL if_pc4_w				: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL redirect_target_w	: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL pc_next_w			: STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
	SIGNAL itcm_addr_w			: STD_LOGIC_VECTOR(ITCM_ADDR_WIDTH-1 DOWNTO 0);
	SIGNAL if_instr_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL rst_q				: STD_LOGIC;

BEGIN

	--=======================================
	-- ITCM (ROM)
	--=======================================
	inst_memory : altsyncram
	GENERIC MAP (
		operation_mode				=> "ROM",
		width_a						=> DATA_BUS_WIDTH,
		widthad_a					=> ITCM_ADDR_WIDTH,
		numwords_a					=> WORDS_NUM,
		lpm_hint					=> "ENABLE_RUNTIME_MOD = YES,INSTANCE_NAME = ITCM",
		lpm_type					=> "altsyncram",
		outdata_reg_a				=> "UNREGISTERED",
		init_file					=> "C:\LABS\lab5\BenchmarkApps\test2\RV32IM\man_compiled\bin\M9K-intel\ITCM.hex",
		intended_device_family		=> "Cyclone"
	)
	PORT MAP (
		clock0		=> clk_i,
		address_a	=> itcm_addr_w,
		q_a			=> if_instr_w
	);


	--=======================================
	-- PC + 4  (combinatorial)
	--=======================================
	if_pc4_w <= pc_q + 4;

	--=======================================
	-- Inner mux:  JALR target  vs  branch/JAL target
	--=======================================
	redirect_target_w <=
		ex_brtarget_i  WHEN redirect_active_i = '1' ELSE
		if_pc4_w;

	--=======================================
	-- Outer mux:  redirect  vs  sequential (PC+4)
	--=======================================
	pc_next_w <=
		(OTHERS => '0') WHEN rst_i = '1' ELSE
		ex_jalrtgt_i    WHEN jalr_sel_i = '1' ELSE
		redirect_target_w;

	--=======================================
	-- PC register  (ena = pc_write_i)
	--=======================================
	PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			pc_q <= (OTHERS => '0');
		ELSIF rising_edge(clk_i) THEN
			IF pc_write_i = '1' THEN
				pc_q <= pc_next_w;
			END IF;
		END IF;
	END PROCESS;

	--=======================================
	-- ITCM address
	-- Driven by pc_next_w so the ITCM internal address register
	-- and the PC register are clocked with the same value:
	-- after the rising edge both pc_q and if_instr_w reflect pc_next_w.
	--=======================================
	G_ADDR :
	IF (WORD_GRANULARITY = True) GENERATE
		-- During stall (pc_write='0') re-register pc_q so ITCM stays in sync
		-- with the frozen PC register.  Without this, altsyncram advances its
		-- internal address to pc_next_w even while PC is held, causing the
		-- instruction at the stalled PC to be skipped on the next fetch.
		itcm_addr_w <=
			pc_q(ITCM_ADDR_WIDTH+1 DOWNTO 2)   WHEN pc_write_i = '0' ELSE
			pc_next_w(ITCM_ADDR_WIDTH+1 DOWNTO 2);
	ELSIF (WORD_GRANULARITY = False) GENERATE
		itcm_addr_w <=
			pc_q(ITCM_ADDR_WIDTH-1 DOWNTO 0)   WHEN pc_write_i = '0' ELSE
			pc_next_w(ITCM_ADDR_WIDTH-1 DOWNTO 0);
	END GENERATE;

	--=======================================
	-- IF-stage outputs (combinational) — registered downstream by IFID_Reg.
	-- if_pc_o also feeds the Signal-Tap trigger: STRIGGER = (if_pc_o == BPADDR_i)
	--=======================================
	if_pc_o    <= pc_q;
	if_pc4_o   <= if_pc4_w;
	if_instr_o <= if_instr_w;

END behavior;
