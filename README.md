# Kiwi Nano 4K – LED PWM + UART Demo

Verilog design for the **GoWin Kiwi Nano 4K** (`GW1NR-LV4QN48PC6/I5`).

- **BTN1** brightens the LED (PWM duty UP)
- **BTN2** dims the LED (PWM duty DOWN)
- Every **500 ms** the UART sends a status line at **115200 8N1**

```
B1:P B2:R D:075%
```

---

## Project Structure

```
.
├── rtl/                    ← Synthesisable Verilog
│   ├── top.v               Top-level
│   ├── pwm.v               8-bit PWM generator (1 kHz)
│   ├── uart_tx.v           8N1 UART transmitter (115200 baud)
│   ├── uart_msg.v          Status string formatter + sender
│   └── btn_debounce.v      20 ms debouncer + edge-detect
├── tb/                     ← Testbenches
│   ├── tb_top.v            System-level testbench
│   ├── tb_pwm.v            PWM unit tests
│   └── tb_uart_tx.v        UART TX unit tests
├── sim/                    ← Simulation scripts
│   ├── run_sim.ps1         Icarus Verilog runner (PowerShell)
│   └── sim.tcl             ModelSim / Questa script
├── constraints/
│   └── kiwi_nano4k.cst     Pin constraints
├── project.tcl             GoWin EDA build script
├── Makefile                Build / sim / program targets
└── .gitignore
```

---

## Pin Assignments

| Signal    | Pin | Standard  | Notes           |
|-----------|-----|-----------|-----------------|
| `clk_in`  | 33  | LVCMOS33  | 50 MHz oscillator |
| `btn_1`   | 14  | LVCMOS18  | Active-low, pull-up |
| `btn_2`   | 15  | LVCMOS18  | Active-low, pull-up |
| `led_pwm` | 10  | LVCMOS33  | PWM LED output  |
| `uart_tx` | 16  | LVCMOS33  | UART TX 115200 8N1 |

---

## Build (GoWin EDA)

```powershell
# Synthesise + place & route → generates bitstream
make

# Custom gw_sh path
make GW_SH="C:\Gowin\Gowin_V1.9.11\IDE\bin\gw_sh.exe"

# Flash bitstream to board (requires openFPGALoader)
make prog

# Remove build outputs
make clean
```

---

## Simulation (Icarus Verilog)

Install [Icarus Verilog](https://bleyer.org/icarus/) and add to PATH.

```powershell
# Simulate top-level (default)
make sim

# Simulate PWM unit
make sim TB=tb_pwm

# Simulate UART TX unit
make sim TB=tb_uart_tx

# Run all testbenches via PowerShell
make sim-all

# Clean simulation outputs
make sim-clean
```

Or use the PowerShell script directly:

```powershell
powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -TB tb_pwm
powershell -ExecutionPolicy Bypass -File sim\run_sim.ps1 -All
```

VCD waveforms are saved to `sim/sim_out/*.vcd` and can be opened with **GTKWave**.

---

## Simulation (ModelSim / Questa)

```tcl
# From ModelSim console (run from project root):
do sim/sim.tcl           ;# tb_top (default)
do sim/sim.tcl tb_pwm
do sim/sim.tcl tb_uart_tx
```

---

## Design Parameters (easy to change in `top.v`)

| Parameter       | Default   | Description                  |
|-----------------|-----------|------------------------------|
| `CLK_FREQ`      | 50 000 000 | System clock Hz             |
| `BAUD_RATE`     | 115 200   | UART baud rate               |
| `PWM_FREQ`      | 1 000     | PWM frequency (Hz)           |
| `REPORT_MS`     | 500       | UART report interval (ms)    |
| `DEBOUNCE_MS`   | 20        | Button debounce time (ms)    |

---

## License

MIT – use freely.
