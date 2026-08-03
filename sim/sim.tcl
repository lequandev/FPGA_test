# =============================================================================
# sim/sim.tcl – ModelSim / Questa simulation script
# Project : Kiwi Nano 4K – LED PWM + UART Demo
#
# Usage from ModelSim console:
#   do sim/sim.tcl                    (runs tb_top)
#   do sim/sim.tcl tb_pwm             (runs tb_pwm)
#   do sim/sim.tcl tb_uart_tx         (runs tb_uart_tx)
# =============================================================================

# Default testbench
if {[llength $argv] > 0} {
    set TB_NAME [lindex $argv 0]
} else {
    set TB_NAME "tb_top"
}

set RTL_DIR "rtl"
set TB_DIR  "tb"
set WORK    "work"

# ---------------------------------------------------------------------------
# Create/clear work library
# ---------------------------------------------------------------------------
if {[file exists $WORK]} {
    vdel -lib $WORK -all
}
vlib $WORK
vmap work $WORK

# ---------------------------------------------------------------------------
# Compile RTL
# ---------------------------------------------------------------------------
puts "==> Compiling RTL..."
vlog -sv "$RTL_DIR/pwm.v"
vlog -sv "$RTL_DIR/uart_tx.v"
vlog -sv "$RTL_DIR/btn_debounce.v"
vlog -sv "$RTL_DIR/uart_msg.v"
vlog -sv "$RTL_DIR/top.v"

# ---------------------------------------------------------------------------
# Compile testbench
# ---------------------------------------------------------------------------
puts "==> Compiling testbench: $TB_NAME..."
vlog -sv "$TB_DIR/$TB_NAME.v"

# ---------------------------------------------------------------------------
# Simulate
# ---------------------------------------------------------------------------
puts "==> Starting simulation: $TB_NAME..."
vsim -t 1ns -lib $WORK $TB_NAME

# Add all signals to wave window
add wave -recursive *

# Run simulation
run -all

puts "==> Simulation complete."
