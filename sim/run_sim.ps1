# =============================================================================
# sim/run_sim.ps1 – Simulation runner (Icarus Verilog)
# Project : Kiwi Nano 4K – LED PWM + UART Demo
#
# Requirements: iverilog and vvp on PATH
#   Install:  https://bleyer.org/icarus/  (Windows)
#             or: winget install -e --id IcarusVerilog.IcarusVerilog
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1
#   powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -TB tb_pwm
#   powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -TB tb_uart_tx
#   powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -TB tb_btn_debounce
#   powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -All
# =============================================================================

param(
    [string]$TB   = "tb_top",   # Default testbench
    [switch]$All  = $false      # Run all testbenches
)

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$RTL_DIR = "rtl"
$TB_DIR  = "tb"
$OUT_DIR = "sim\sim_out"

# RTL source list
$RTL_FILES = @(
    "$RTL_DIR\pwm.v",
    "$RTL_DIR\uart_tx.v",
    "$RTL_DIR\btn_debounce.v",
    "$RTL_DIR\fsm_control.v",
    "$RTL_DIR\uart_msg.v",
    "$RTL_DIR\top.v"
)

# All available testbenches
$ALL_TBS = @("tb_pwm", "tb_uart_tx", "tb_btn_debounce", "tb_top")

# ---------------------------------------------------------------------------
# Setup output directory
# ---------------------------------------------------------------------------
if (-not (Test-Path $OUT_DIR)) {
    New-Item -ItemType Directory -Path $OUT_DIR | Out-Null
    Write-Host "[SIM] Created output directory: $OUT_DIR"
}

# ---------------------------------------------------------------------------
# Function: compile and run one TB
# ---------------------------------------------------------------------------
function Run-TB {
    param([string]$tb_name)

    $tb_file  = "$TB_DIR\$tb_name.v"
    $exe_file = "$OUT_DIR\$tb_name"

    if (-not (Test-Path $tb_file)) {
        Write-Host "[ERROR] Testbench not found: $tb_file" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Running: $tb_name" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    # ---- Compile ----
    $compile_args = @("-g2012") + $RTL_FILES + @($tb_file, "-o", $exe_file)
    Write-Host "[SIM] Compiling..." -ForegroundColor Yellow
    & iverilog @compile_args
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Compilation failed for $tb_name" -ForegroundColor Red
        return
    }

    # ---- Simulate ----
    Write-Host "[SIM] Simulating..." -ForegroundColor Yellow
    Push-Location $OUT_DIR
    & vvp "..\$tb_name"   # vvp expects relative path to sim_out
    Pop-Location

    # ---- VCD hint ----
    $vcd = "$OUT_DIR\$tb_name.vcd"
    if (Test-Path $vcd) {
        Write-Host "[SIM] Waveform: $vcd  (open with GTKWave)" -ForegroundColor Green
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if ($All) {
    foreach ($t in $ALL_TBS) { Run-TB $t }
} else {
    Run-TB $TB
}

Write-Host ""
Write-Host "[SIM] Done." -ForegroundColor Green
