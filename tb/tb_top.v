// =============================================================================
// Testbench : tb_top.v
// DUT       : top.v (Kiwi Nano 4K – LED PWM + UART Demo)
//
// Simulation: Icarus Verilog (iverilog) or ModelSim / Questa
//   iverilog -g2012 -I../rtl tb_top.v ../rtl/top.v ../rtl/pwm.v \
//            ../rtl/uart_tx.v ../rtl/uart_msg.v ../rtl/btn_debounce.v \
//            -o sim_out/tb_top && vvp sim_out/tb_top
//
// What this TB exercises:
//   1. Power-on reset sequence
//   2. BTN1 press  → PWM duty increases
//   3. BTN2 press  → PWM duty decreases
//   4. UART TX line monitored; captured byte printed to console
// =============================================================================

`timescale 1ns / 1ps

module tb_top;

    // =========================================================================
    // DUT I/O
    // =========================================================================
    reg  clk_in  = 1'b0;
    reg  btn_1   = 1'b1;   // Active-low → default released
    reg  btn_2   = 1'b1;
    wire led_pwm;
    wire uart_tx;

    // =========================================================================
    // DUT instantiation
    // =========================================================================
    top dut (
        .clk_in  (clk_in),
        .btn_1   (btn_1),
        .btn_2   (btn_2),
        .led_pwm (led_pwm),
        .uart_tx (uart_tx)
    );

    // =========================================================================
    // 50 MHz clock (period = 20 ns)
    // =========================================================================
    localparam CLK_PERIOD = 20; // ns
    always #(CLK_PERIOD/2) clk_in = ~clk_in;

    // =========================================================================
    // UART monitor – captures bytes transmitted by DUT and prints them
    // =========================================================================
    localparam BAUD_RATE   = 115_200;
    localparam BAUD_PERIOD = 1_000_000_000 / BAUD_RATE; // ns per bit

    integer  uart_byte;
    integer  bit_cnt;
    reg      uart_prev = 1'b1;
    real     uart_bit_time;

    task automatic capture_uart_byte;
        integer i;
        reg [7:0] rx_byte;
    begin
        // Wait for start bit (falling edge)
        @(negedge uart_tx);
        // Sample middle of start bit
        #(BAUD_PERIOD / 2);
        rx_byte = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            #BAUD_PERIOD;
            rx_byte[i] = uart_tx; // LSB first
        end
        // Skip stop bit
        #BAUD_PERIOD;
        $write("%c", rx_byte);
    end
    endtask

    // =========================================================================
    // UART listener thread (runs in background)
    // =========================================================================
    integer uart_char_cnt = 0;
    initial begin
        $display("[UART] Monitor started (115200 8N1)");
        forever begin
            capture_uart_byte;
            uart_char_cnt = uart_char_cnt + 1;
        end
    end

    // =========================================================================
    // Helper tasks
    // =========================================================================

    // Wait N clock cycles
    task wait_clks(input integer n);
        integer i;
        for (i = 0; i < n; i = i + 1)
            @(posedge clk_in);
    endtask

    // Press button for N ms (active-low)
    task press_btn1(input integer hold_ms);
    begin
        $display("[TB] BTN1 pressed (%0d ms)", hold_ms);
        btn_1 = 1'b0;
        #(hold_ms * 1_000_000); // ns
        btn_1 = 1'b1;
        $display("[TB] BTN1 released");
    end
    endtask

    task press_btn2(input integer hold_ms);
    begin
        $display("[TB] BTN2 pressed (%0d ms)", hold_ms);
        btn_2 = 1'b0;
        #(hold_ms * 1_000_000);
        btn_2 = 1'b1;
        $display("[TB] BTN2 released");
    end
    endtask

    // =========================================================================
    // Stimulus
    // =========================================================================
    initial begin
        // ---- Dump waveforms ------------------------------------------------
        $dumpfile("sim_out/tb_top.vcd");
        $dumpvars(0, tb_top);

        $display("=================================================");
        $display("  Kiwi Nano 4K – top.v Testbench");
        $display("=================================================");

        // ---- Power-on reset (both buttons released) ------------------------
        btn_1 = 1'b1;
        btn_2 = 1'b1;
        wait_clks(50);
        $display("[TB] Reset released – design should be running");

        // ---- Wait for first UART transmission (500 ms simulated) -----------
        // NOTE: 500 ms @ 50 MHz = 25 000 000 cycles; skip in sim with short wait
        $display("[TB] Waiting for UART status report...");
        #(6_000_000); // 6 ms sim time (covers debounce + partial uart)

        // ---- Test: BTN1 single press (duty UP) -----------------------------
        press_btn1(25); // 25 ms > 20 ms debounce
        wait_clks(100);

        // ---- Test: BTN2 single press (duty DOWN) ---------------------------
        press_btn2(25);
        wait_clks(100);

        // ---- Test: BTN1 long press (auto-repeat ramp) ----------------------
        $display("[TB] BTN1 long press – auto-repeat starts after 1s hold");
        // In real HW: 1 second; in sim just check logic trigger timing
        btn_1 = 1'b0;
        #(30_000_000); // 30 ms sim – enough to see a few debounce/pwm cycles
        btn_1 = 1'b1;
        wait_clks(200);

        // ---- Finish --------------------------------------------------------
        $display("[TB] Simulation complete. UART chars captured: %0d", uart_char_cnt);
        $display("=================================================");
        $finish;
    end

    // =========================================================================
    // Timeout watchdog (10 ms sim time)
    // =========================================================================
    initial begin
        #100_000_000; // 100 ms
        $display("[TB] TIMEOUT – simulation forcibly ended");
        $finish;
    end

endmodule
