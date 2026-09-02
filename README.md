# RV32IM — 5‑Stage Pipeline CPU

A 5‑stage pipelined RV32IM core in VHDL, with full forwarding, hazard stalling and
branch flushing. Core top‑level entity: **`RV32I_CORE`** (`DUT/RV32I_CORE.vhd`);
FPGA board wrapper: **`FPGA_Top_Pipeline`** (`DUT/FPGA_Top_Pipeline.vhd`).

Course context: *Advanced CPU Architecture and Hardware Accelerators Lab 361‑1‑4693, BGU.*

## Target development board

This project was designed and built to run on the **Terasic DE10-Standard** development kit, based on the Intel Cyclone V SoC FPGA.

---

## Pipeline stages

| Stage | Name | Main block |
|-------|------|-----------|
| 1 | **IF**  – Instruction Fetch  | `DUT/IFETCH.VHD` + ITCM |
| 2 | **ID**  – Instruction Decode | `DUT/IDECODE.VHD` + `DUT/CONTROL.VHD` |
| 3 | **EX**  – Execute            | `DUT/EXECUTE.VHD` + forwarding + multiply (`Multpller1.VHD`, `Multpller2_16bit.vhd`) |
| 4 | **MEM** – Memory Access      | `DUT/DMEMORY.VHD` + DTCM |
| 5 | **WB**  – Write Back         | write back into the register file |

### Pipeline registers
`DUT/IFID_REG.vhd`, `DUT/IDEX_REG.vhd`, `DUT/EXMEM_REG.vhd`, `DUT/MEMWB_REG.vhd`

### Hazard handling
- **Data hazards:** forwarding via `DUT/ForwardingUnit.VHD`.
- **Load‑use / MUL stalls:** `DUT/StallConditionUnit.VHD`.
- **Branches / jumps:** pipeline flush of the speculative slot.
- **Performance / IPC:** `DUT/IPC_UNIT.vhd` (cycle / instruction counting for IPC).

### Packages
- `DUT/cond_compilation_package.vhd` — build switches (`G_MODELSIM`, `G_WORD_GRANULARITY`, TCM size).
- `DUT/const_package.vhd` — TCM geometry constants (8 KiB TCM).
- `DUT/aux_package.vhd` — component declarations.

### FPGA support
- `DUT/FPGA_Top_Pipeline.vhd` — board top (clock, KEY reset, SW breakpoint, debug outputs).
- `DUT/PLL.vhd` — on‑chip PLL, used only when `G_MODELSIM = 0`.

### Verification
- `TB/tb_RV32I.vhd` — pipeline testbench.
- `SIM/` — simulation scripts (e.g. `RV32I.do`).
- `Quartus/` — Quartus project for synthesis / SignalTap.

---

## Configuration (`DUT/cond_compilation_package.vhd`)

| Constant | Current value | Meaning |
|----------|---------------|---------|
| `G_MODELSIM` | `0` | `0` = FPGA (PLL active, what `FPGA_Top_Pipeline` expects), `1` = simulation |
| `G_WORD_GRANULARITY` | `True` | word‑addressed vs byte‑addressed data memory |
| `G_ADDRWIDTH` / `G_DATA_WORDSNUM` / `G_PC_WIDTH` / `G_MA_WIDTH` | 8 KiB TCM | memory geometry |

> To **simulate** the core in ModelSim, set `G_MODELSIM = 1` so the clock bypasses the PLL.

---

## Building for the FPGA (Quartus)

1. Open the project under `Quartus/` (add all `DUT/*.vhd` files).
2. Set **`FPGA_Top_Pipeline`** as the top‑level entity.
3. Keep `G_MODELSIM = 0` (enables the PLL).
4. Assign pins (board clock, KEY reset, SW breakpoint address, debug/PC/instruction
   outputs and counters) and connect them to SignalTap.
5. Compile and program; trigger SignalTap on the breakpoint match.

---

## Simulating (ModelSim / QuestaSim)

Set `G_MODELSIM = 1`, then run the provided script:

```tcl
do SIM/RV32I.do
```

…or compile manually: packages → leaf blocks → pipeline registers → hazard units →
`RV32I_CORE` → `TB/tb_RV32I.vhd`, then `vsim work.tb_RV32I; run -all`.
