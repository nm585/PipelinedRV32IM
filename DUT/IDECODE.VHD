--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Idecode module — Register File + immediate sign extension (pipeline stage 2)
--
-- Pipeline changes vs. single-cycle:
--   • RF write-back uses wb_wdata_i / wb_rd_i / wb_regwrite_i from MEM/WB stage.
--     The WB mux (ALUres / DTCMdata / MULres / PC+4) is computed in RV32I_CORE.
--   • rs1_o, rs2_o, rd_o forwarded for ID/EX register, Forwarding Unit, Stall Unit.
--   • instruction_i is the IF/ID register output (ifid_instr_o from IFETCH).
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE work.const_package.all;


ENTITY Idecode IS
	generic(
		PC_WIDTH       : integer := 10;
		DATA_BUS_WIDTH : integer := 32
	);
	PORT(
		clk_i          : IN  STD_LOGIC;
		rst_i          : IN  STD_LOGIC;
		-- IF/ID register output (current instruction in decode stage)
		instruction_i  : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

		-- Write-back from WB stage (sourced from MEM/WB via WB mux in core)
		wb_wdata_i     : IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		wb_rd_i        : IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		wb_regwrite_i  : IN  STD_LOGIC;

		-- To ID/EX register
		read_data1_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_o   : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		SignExt_o      : OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		-- Register address fields (for pipeline regs, forwarding unit, stall unit)
		rs1_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		rs2_o          : OUT STD_LOGIC_VECTOR(4 DOWNTO 0);
		rd_o           : OUT STD_LOGIC_VECTOR(4 DOWNTO 0)
	);
END Idecode;


ARCHITECTURE behavior OF Idecode IS
	TYPE register_file IS ARRAY (0 TO 31) OF STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL RF_q          : register_file;

	SIGNAL opc_w         : STD_LOGIC_VECTOR(6 DOWNTO 0);
	SIGNAL rs1_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rs2_w         : STD_LOGIC_VECTOR(4 DOWNTO 0);
	SIGNAL rd_w          : STD_LOGIC_VECTOR(4 DOWNTO 0);

	SIGNAL Iimm_w        : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL Simm_w        : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL SBimm_w       : STD_LOGIC_VECTOR(11 DOWNTO 0);
	SIGNAL Uimm_w        : STD_LOGIC_VECTOR(19 DOWNTO 0);
	SIGNAL UJimm_w       : STD_LOGIC_VECTOR(19 DOWNTO 0);

	SIGNAL SignExt_Iimm_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_Simm_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_SBimm_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_Uimm_w  : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL SignExt_UJimm_w : STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN

	-- Instruction field decode
	opc_w <= instruction_i(6  DOWNTO 0);
	rs1_w <= instruction_i(19 DOWNTO 15);
	rs2_w <= instruction_i(24 DOWNTO 20);
	rd_w  <= instruction_i(11 DOWNTO 7);

	-- Expose register address fields to pipeline
	rs1_o <= rs1_w;
	rs2_o <= rs2_w;
	rd_o  <= rd_w;

	-- RF combinational read ports
	read_data1_o <= RF_q(CONV_INTEGER(rs1_w));
	read_data2_o <= RF_q(CONV_INTEGER(rs2_w));

	-- Immediate field extraction
	Iimm_w  <= instruction_i(31 DOWNTO 20);
	Simm_w  <= instruction_i(31 DOWNTO 25) & instruction_i(11 DOWNTO 7);
	SBimm_w <= instruction_i(31) & instruction_i(7) &
	           instruction_i(30 DOWNTO 25) & instruction_i(11 DOWNTO 8);
	Uimm_w  <= instruction_i(31 DOWNTO 12);
	UJimm_w <= instruction_i(31) & instruction_i(19 DOWNTO 12) &
	           instruction_i(20) & instruction_i(30 DOWNTO 21);

	-- Sign extension
	SignExt_Iimm_w  <= ZEROS_IMM20 & Iimm_w  WHEN NOT Iimm_w(11)  ELSE ONES_IMM20 & Iimm_w;
	SignExt_Simm_w  <= ZEROS_IMM20 & Simm_w  WHEN NOT Simm_w(11)  ELSE ONES_IMM20 & Simm_w;
	SignExt_SBimm_w <= ZEROS_IMM20 & SBimm_w WHEN NOT SBimm_w(11) ELSE ONES_IMM20 & SBimm_w;
	SignExt_Uimm_w  <= ZEROS_IMM12 & Uimm_w  WHEN NOT Uimm_w(19)  ELSE ONES_IMM12 & Uimm_w;
	SignExt_UJimm_w <= ZEROS_IMM12 & UJimm_w WHEN NOT UJimm_w(19) ELSE ONES_IMM12 & UJimm_w;

	WITH opc_w SELECT
		SignExt_o <=
			SignExt_Iimm_w                          WHEN ITYPE_OPC,
			SignExt_Iimm_w                          WHEN INST_JALR(6 DOWNTO 0),
			SignExt_Iimm_w                          WHEN INST_LB(6 DOWNTO 0),
			SignExt_Simm_w                          WHEN STYPE_OPC,
			SignExt_SBimm_w                         WHEN SBTYPE_OPC,
			SignExt_Uimm_w(19 DOWNTO 0) & ZEROS_IMM12  WHEN UTYPE_OPC,
			SignExt_UJimm_w                         WHEN UJTYPE_OPC,
			(OTHERS => '0')                         WHEN OTHERS;

	--===========================================================================
	-- Register File — write port
	-- Clocked on rising edge; write source is WB stage (MEM/WB register + WB mux).
	-- x0 is hard-wired to zero and never written.
	--===========================================================================
	PROCESS(clk_i, rst_i)
	BEGIN
		IF rst_i = '1' THEN
			FOR i IN 0 TO 31 LOOP
				RF_q(i) <= CONV_STD_LOGIC_VECTOR(0, 32);
			END LOOP;
		ELSIF falling_edge(clk_i) THEN
			IF wb_regwrite_i = '1' AND wb_rd_i /= "00000" THEN
				RF_q(CONV_INTEGER(wb_rd_i)) <= wb_wdata_i;
			END IF;
		END IF;
	END PROCESS;

END behavior;
