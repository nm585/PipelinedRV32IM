--============================================================================
-- Copyright 2026 Hananya Ribo
-- Advanced CPU architecture and Hardware Accelerators Lab 361-1-4693 BGU
-- Execute module — ALU + branch-address adder + forwarding muxes (pipeline stage 3)
--
-- Forwarding MUX truth table (fwd_ain_i / fwd_bin_i):
--   "00" → ID/EX register file value  (no hazard)
--   "10" → EX/MEM ALU result          (1-cycle RAW)
--   "01" → MEM/WB write-back data     (2-cycle RAW)
--
-- fwd_b_o carries the forwarded rs2 value BEFORE the ALUSrc mux;
-- the EX/MEM register uses it as store-data (SW/SH/SB).
--============================================================================
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_SIGNED.ALL;
USE work.const_package.all;


ENTITY Execute IS
	generic(
		DATA_BUS_WIDTH	: integer := 32;
		PC_WIDTH		: integer := 10
	);
	PORT(
		-- From ID/EX pipeline register
		read_data1_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		read_data2_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		sign_extend_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		UpperIm_ctrl_i	: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
		ALUOp_ctrl_i	: IN  STD_LOGIC_VECTOR(4 DOWNTO 0);
		ALUSrc_ctrl_i	: IN  STD_LOGIC;
		pc_i			: IN  STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);

		-- Forwarding control (from ForwardingUnit)
		fwd_ain_i		: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);   -- select for ALU A input
		fwd_bin_i		: IN  STD_LOGIC_VECTOR(1 DOWNTO 0);   -- select for ALU B / store data

		-- Forwarding data sources
		exmem_alu_res_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- from EX/MEM
		memwb_wdata_i	: IN  STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);  -- from MEM/WB

		-- Outputs
		brTaken_o		: OUT STD_LOGIC;
		alu_res_o		: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
		addr_gen_o		: OUT STD_LOGIC_VECTOR(PC_WIDTH-1 DOWNTO 0);
		fwd_b_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);   -- forwarded rs2 (for store)
		fwd_a_o			: OUT STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0)
	);	
END Execute;


ARCHITECTURE struct OF Execute IS

	-- Forwarding mux outputs
	SIGNAL fwd_a_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL fwd_b_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- ALU operands (after all muxes)
	SIGNAL ain_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL bin_w				: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	-- Reused sub-expressions
	SIGNAL sub_res_w			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL ltu_res_w			: STD_LOGIC;
	SIGNAL eq_res_w				: STD_LOGIC;
	SIGNAL msbneq_res_w			: STD_LOGIC;
	SIGNAL alu_res_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brTaken_w			: STD_LOGIC;

	-- Barrel-shifter intermediates
	SIGNAL brl_shl_s1_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shl_s2_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shl_s3_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shl_s4_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

	SIGNAL brl_shr_s1_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shr_s2_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shr_s3_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shr_s4_r			: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);
	SIGNAL brl_shr_pad_r		: STD_LOGIC_VECTOR(DATA_BUS_WIDTH-1 DOWNTO 0);

BEGIN

	--------------------------------------------------------------------
	-- Branch / JAL address generator:  addr_gen = PC + (sign_extend << 1)
	--------------------------------------------------------------------
	addr_gen_o <= pc_i(PC_WIDTH-1 DOWNTO 0) +
	              (sign_extend_i(PC_WIDTH-3 DOWNTO 0) & '0');

	--------------------------------------------------------------------
-- A operand
--------------------------------------------------------------------
WITH UpperIm_ctrl_i SELECT
    fwd_a_w <=
        read_data1_i                                               WHEN "00",
        ((DATA_BUS_WIDTH-PC_WIDTH-1) DOWNTO 0 => '0') & pc_i       WHEN "01",
        (OTHERS => '0')                                            WHEN OTHERS;

ain_w <=
    exmem_alu_res_i WHEN fwd_ain_i = "10" ELSE
    memwb_wdata_i   WHEN fwd_ain_i = "01" ELSE
    fwd_a_w;

fwd_a_o <= ain_w;


--------------------------------------------------------------------
-- B operand
--------------------------------------------------------------------

fwd_b_w <=
    exmem_alu_res_i WHEN fwd_bin_i = "10" ELSE
    memwb_wdata_i   WHEN fwd_bin_i = "01" ELSE
    read_data2_i;

bin_w <=
    sign_extend_i WHEN ALUSrc_ctrl_i = '1' ELSE
    fwd_b_w;

fwd_b_o <= fwd_b_w;
	--------------------------------------------------------------------
	-- Reused sub-expressions
	--------------------------------------------------------------------
	sub_res_w    <= ain_w - bin_w;
	ltu_res_w    <= '1' WHEN ain_w < bin_w           ELSE '0';
	eq_res_w     <= '1' WHEN ain_w = bin_w            ELSE '0';
	msbneq_res_w <= '1' WHEN ain_w(31) /= bin_w(31)  ELSE '0';

	--------------------------------------------------------------------
	-- ALU
	--------------------------------------------------------------------
	PROCESS(ALL)
	BEGIN
		alu_res_r    <= (OTHERS => '0');
		brTaken_w    <= '0';
		brl_shl_s1_r <= (OTHERS => '0');
		brl_shl_s2_r <= (OTHERS => '0');
		brl_shl_s3_r <= (OTHERS => '0');
		brl_shl_s4_r <= (OTHERS => '0');
		brl_shr_s1_r <= (OTHERS => '0');
		brl_shr_s2_r <= (OTHERS => '0');
		brl_shr_s3_r <= (OTHERS => '0');
		brl_shr_s4_r <= (OTHERS => '0');
		brl_shr_pad_r <= (OTHERS => '0');

		CASE ALUOp_ctrl_i IS
			------------------------------------------------------
			-- Arithmetic
			------------------------------------------------------
			WHEN ALU_ADD =>
				alu_res_r <= ain_w + bin_w;

			WHEN ALU_SUB =>
				alu_res_r <= sub_res_w;

			------------------------------------------------------
			-- Logic
			------------------------------------------------------
			WHEN ALU_AND =>
				alu_res_r <= ain_w AND bin_w;

			WHEN ALU_OR =>
				alu_res_r <= ain_w OR bin_w;

			WHEN ALU_XOR =>
				alu_res_r <= ain_w XOR bin_w;

			------------------------------------------------------
			-- Shift left (barrel)
			------------------------------------------------------
			WHEN ALU_SHIFTL =>
				IF bin_w(0) = '1' THEN brl_shl_s1_r <= ain_w(30 DOWNTO 0) & '0';
				ELSE                    brl_shl_s1_r <= ain_w;  END IF;

				IF bin_w(1) = '1' THEN brl_shl_s2_r <= brl_shl_s1_r(29 DOWNTO 0) & "00";
				ELSE                    brl_shl_s2_r <= brl_shl_s1_r;  END IF;

				IF bin_w(2) = '1' THEN brl_shl_s3_r <= brl_shl_s2_r(27 DOWNTO 0) & "0000";
				ELSE                    brl_shl_s3_r <= brl_shl_s2_r;  END IF;

				IF bin_w(3) = '1' THEN brl_shl_s4_r <= brl_shl_s3_r(23 DOWNTO 0) & x"00";
				ELSE                    brl_shl_s4_r <= brl_shl_s3_r;  END IF;

				IF bin_w(4) = '1' THEN alu_res_r <= brl_shl_s4_r(15 DOWNTO 0) & x"0000";
				ELSE                    alu_res_r <= brl_shl_s4_r;  END IF;

			------------------------------------------------------
			-- Shift right (barrel, logical + arithmetic)
			------------------------------------------------------
			WHEN ALU_SHIFTR | ALU_SHIFTR_ARITH =>
				IF ain_w(31) = '1' AND ALUOp_ctrl_i = ALU_SHIFTR_ARITH THEN
					brl_shr_pad_r <= 32x"FFFF";
				ELSE
					brl_shr_pad_r <= 32x"0000";
				END IF;

				IF bin_w(0) = '1' THEN brl_shr_s1_r <= brl_shr_pad_r(31) & ain_w(31 DOWNTO 1);
				ELSE                    brl_shr_s1_r <= ain_w;  END IF;

				IF bin_w(1) = '1' THEN brl_shr_s2_r <= brl_shr_pad_r(31 DOWNTO 30) & brl_shr_s1_r(31 DOWNTO 2);
				ELSE                    brl_shr_s2_r <= brl_shr_s1_r;  END IF;

				IF bin_w(2) = '1' THEN brl_shr_s3_r <= brl_shr_pad_r(31 DOWNTO 28) & brl_shr_s2_r(31 DOWNTO 4);
				ELSE                    brl_shr_s3_r <= brl_shr_s2_r;  END IF;

				IF bin_w(3) = '1' THEN brl_shr_s4_r <= brl_shr_pad_r(31 DOWNTO 24) & brl_shr_s3_r(31 DOWNTO 8);
				ELSE                    brl_shr_s4_r <= brl_shr_s3_r;  END IF;

				IF bin_w(4) = '1' THEN alu_res_r <= brl_shr_pad_r(31 DOWNTO 16) & brl_shr_s4_r(31 DOWNTO 16);
				ELSE                    alu_res_r <= brl_shr_s4_r;  END IF;

			------------------------------------------------------
			-- Comparison
			------------------------------------------------------
			WHEN ALU_LESS_THAN_SIGNED =>
				IF msbneq_res_w THEN
					alu_res_r <= (0 => ain_w(31),   OTHERS => '0');
				ELSE
					alu_res_r <= (0 => sub_res_w(31), OTHERS => '0');
				END IF;

			WHEN ALU_LESS_THAN_UNSIGNED =>
				alu_res_r <= (0 => ltu_res_w, OTHERS => '0');

			------------------------------------------------------
			-- Conditional branches
			------------------------------------------------------
			WHEN ALU_BEQ =>
				brTaken_w <= eq_res_w;

			WHEN ALU_BNE =>
				brTaken_w <= NOT eq_res_w;

			WHEN ALU_BLT =>
				IF msbneq_res_w THEN brTaken_w <= ain_w(31);
				ELSE                  brTaken_w <= sub_res_w(31);  END IF;

			WHEN ALU_BGE =>
				IF msbneq_res_w THEN brTaken_w <= bin_w(31);
				ELSE                  brTaken_w <= NOT sub_res_w(31);  END IF;

			WHEN ALU_BLTU =>
				brTaken_w <= ltu_res_w;

			WHEN ALU_BGEU =>
				brTaken_w <= NOT ltu_res_w;

			WHEN OTHERS =>
				NULL;

		END CASE;
	END PROCESS;

	alu_res_o <= alu_res_r;
	brTaken_o <= brTaken_w;

END struct;
