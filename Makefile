# =============================================================================
# Makefile – Kiwi Nano 4K PWM + UART Demo
# Toolchain: GoWin EDA (gw_sh)
#
# Targets:
#   make          → Synthesise + place & route  (default)
#   make syn      → Synthesis only
#   make impl     → Place & route only (needs synthesis output)
#   make prog     → Program device via openFPGALoader
#   make clean    → Remove generated output
#   make help     → Show this help
#
# Requirements:
#   • GoWin EDA installed; gw_sh on PATH  -or-  set GW_SH below
#   • openFPGALoader on PATH for 'make prog'
#
# Usage:
#   make            # build bitstream
#   make prog       # flash to board
# =============================================================================

# ---------------------------------------------------------------------------
# Tool paths – override on command line if needed
#   make GW_SH=/path/to/gw_sh
# ---------------------------------------------------------------------------
GW_SH        ?= gw_sh
PROGRAMMER   ?= openFPGALoader
PROG_CABLE   ?= cmsisdap          # cable type: cmsisdap | ft2232 | dirtyJtag

# ---------------------------------------------------------------------------
# Project settings
# ---------------------------------------------------------------------------
TOP          := top
DEVICE       := GW1NR-LV4QN48PC6/I5
PROJECT_TCL  := project.tcl
OUTDIR       := impl/pnr
BITSTREAM    := $(OUTDIR)/kiwi_nano4k_pwm_uart.fs

# ---------------------------------------------------------------------------
# Source files (for dependency tracking)
# ---------------------------------------------------------------------------
VERILOG_SRC  := $(wildcard rtl/*.v)
CST_FILE     := constraints/kiwi_nano4k.cst

# ---------------------------------------------------------------------------
# Default target
# ---------------------------------------------------------------------------
.PHONY: all
all: $(BITSTREAM)

# ---------------------------------------------------------------------------
# Build bitstream (synthesis + PnR via TCL script)
# ---------------------------------------------------------------------------
$(BITSTREAM): $(VERILOG_SRC) $(CST_FILE) $(PROJECT_TCL)
	@echo "==> Running GoWin EDA build..."
	$(GW_SH) -run $(PROJECT_TCL)
	@echo "==> Build complete: $(BITSTREAM)"

# ---------------------------------------------------------------------------
# Synthesis only
# ---------------------------------------------------------------------------
.PHONY: syn
syn: $(VERILOG_SRC) $(CST_FILE)
	@echo "==> Running synthesis only..."
	$(GW_SH) -run $(PROJECT_TCL) -options "run syn"

# ---------------------------------------------------------------------------
# Program device
# ---------------------------------------------------------------------------
.PHONY: prog
prog: $(BITSTREAM)
	@echo "==> Programming device with openFPGALoader..."
	$(PROGRAMMER) -c $(PROG_CABLE) -f $(BITSTREAM)

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
.PHONY: clean
clean:
	@echo "==> Cleaning build outputs..."
	-rmdir /S /Q impl 2>NUL
	@echo "==> Clean complete."

# ---------------------------------------------------------------------------
# Simulation (Icarus Verilog)
# ---------------------------------------------------------------------------
IVERILOG     ?= iverilog
VVP          ?= vvp
SIM_OUTDIR   := sim/sim_out
TB_FILES     := $(wildcard tb/*.v)
RTL_FILES    := $(wildcard rtl/*.v)

.PHONY: sim sim-all sim-clean

# Run single testbench:  make sim TB=tb_pwm
sim: $(RTL_FILES) $(TB_FILES)
	@if not exist "$(SIM_OUTDIR)" mkdir "$(SIM_OUTDIR)"
	@echo "==> Compiling $(TB).v..."
	$(IVERILOG) -g2012 $(RTL_FILES) tb/$(TB).v -o $(SIM_OUTDIR)/$(TB)
	@echo "==> Simulating $(TB)..."
	$(VVP) $(SIM_OUTDIR)/$(TB)

# Run all testbenches via PowerShell runner
sim-all:
	powershell -ExecutionPolicy Bypass -File sim/run_sim.ps1 -All

# Clean simulation outputs
sim-clean:
	@echo "==> Cleaning simulation outputs..."
	-rmdir /S /Q sim\sim_out 2>NUL
	@echo "==> Sim clean complete."

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
.PHONY: help
help:
	@echo.
	@echo  Kiwi Nano 4K - PWM + UART Demo  Makefile
	@echo  ==========================================
	@echo  Targets:
	@echo    make              Build bitstream (syn + PnR)
	@echo    make syn          Synthesis only
	@echo    make prog         Program device via openFPGALoader
	@echo    make sim TB=xxx   Simulate one testbench (iverilog)
	@echo    make sim-all      Simulate all testbenches
	@echo    make clean        Remove FPGA build output
	@echo    make sim-clean    Remove simulation output
	@echo    make help         Show this help
	@echo.
	@echo  Overridable variables:
	@echo    GW_SH        Path to gw_sh        (default: gw_sh)
	@echo    PROGRAMMER   Programmer tool       (default: openFPGALoader)
	@echo    PROG_CABLE   Cable type            (default: cmsisdap)
	@echo    IVERILOG     Path to iverilog      (default: iverilog)
	@echo    VVP          Path to vvp           (default: vvp)
	@echo    TB           Testbench for sim     (default: tb_top)
	@echo.
