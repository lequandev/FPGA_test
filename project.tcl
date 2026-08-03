# =============================================================================
# project.tcl – GoWin EDA TCL build script
# Project : Kiwi Nano 4K – LED PWM + UART Demo
# Device  : GW1NR-LV4QN48PC6/I5  (GoWin Kiwi Nano 4K)
# Tools   : GoWin EDA (gw_sh)
#
# Usage:
#   gw_sh -run project.tcl          (from repo root or via Makefile)
# =============================================================================

# --------------------------------------------------------------------------
# Device & project settings
# --------------------------------------------------------------------------
set_device GW1NR-LV4QN48PC6/I5 -name GW1NR-4

# --------------------------------------------------------------------------
# RTL source files
# --------------------------------------------------------------------------
add_file rtl/pwm.v
add_file rtl/uart_tx.v
add_file rtl/btn_debounce.v
add_file rtl/uart_msg.v
add_file rtl/top.v

# --------------------------------------------------------------------------
# Constraints
# --------------------------------------------------------------------------
add_file constraints/kiwi_nano4k.cst

# --------------------------------------------------------------------------
# Synthesis options
# --------------------------------------------------------------------------
set_option -synthesis_tool gowinsynthesis
set_option -top_module     top
set_option -verilog_std    sysv2017

# --------------------------------------------------------------------------
# Implementation options
# --------------------------------------------------------------------------
set_option -output_base_name kiwi_nano4k_pwm_uart
set_option -place_option     1
set_option -route_option     1

# --------------------------------------------------------------------------
# Run implementation
# --------------------------------------------------------------------------
run all
