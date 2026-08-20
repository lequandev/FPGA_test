// =============================================================================
// Testbench : tb_top.v
// DUT       : top.v (Kiwi 1P5 - FPGA 2026)
//
// Simulation: Icarus Verilog (iverilog) or ModelSim / Questa
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

    // UART listener thread (runs in background)
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
    task wait_ms(input integer ms);
    begin
        #(ms * 1_000_000); // 1 ms = 1,000,000 ns
    end
    endtask

    task press_btn1(input integer hold_ms);
    begin
        $display("\n[TB] --- BTN1 pressed (%0d ms) ---", hold_ms);
        btn_1 = 1'b0;
        wait_ms(hold_ms);
        btn_1 = 1'b1;
        $display("[TB] BTN1 released");
        // Wait 15ms for debounce to register the release state (requires 10ms)
        // and for UART transmission to complete (if any)
        wait_ms(15); 
    end
    endtask

    task press_btn2(input integer hold_ms);
    begin
        $display("\n[TB] --- BTN2 pressed (%0d ms) ---", hold_ms);
        btn_2 = 1'b0;
        wait_ms(hold_ms);
        btn_2 = 1'b1;
        $display("[TB] BTN2 released");
        // Wait 15ms for debounce to register the release state (requires 10ms)
        // and for UART transmission to complete (if any)
        wait_ms(15);
    end
    endtask

    // =========================================================================
    // Stimulus (Test Plan FPGA_Team_Assignments.md)
    // =========================================================================
    initial begin
        $dumpfile("sim_out.vcd");
        $dumpvars(0, tb_top);

        $display("=================================================");
        $display("  Kiwi 1P5 – FPGA 2026 Testbench");
        $display("=================================================");

        // TC1: Power-on Reset
        $display("\n[TC1] Power-on Reset");
        btn_1 = 1'b1;
        btn_2 = 1'b1;
        // Internal reset releases after 32 clock cycles
        // UART takes ~1.1ms to transmit "MODE: LOW\r\n"
        wait_ms(3);
        $display("[TB] Expect: 'MODE: LOW\\r\\n' string appears above");

        // TC2: Button 1, 1st press -> HIGH
        $display("\n[TC2] Press BTN1 (Switch to HIGH)");
        press_btn1(15); // Press for 15ms (> 10ms debounce)
        $display("[TB] Expect: 'MODE: HIGH\\r\\n' string appears above");

        // TC3: Button 1, 2nd press -> LOW
        $display("\n[TC3] Press BTN1 2nd time (Switch to LOW)");
        press_btn1(15);
        $display("[TB] Expect: 'MODE: LOW\\r\\n' string appears above");

        // TC4: Button 2 -> AUTO
        $display("\n[TC4] Press BTN2 (Switch to AUTO)");
        press_btn2(15);
        $display("[TB] Expect: 'MODE: AUTO\\r\\n' string appears above");

        // TC5: Bounce test (Button noise < 10ms)
        $display("\n[TC5] Bounce Test (Continuous press/release < 10ms)");
        $display("[TB] Simulating BTN1 noise: press 2ms, release 2ms, press 2ms...");
        btn_1 = 1'b0; wait_ms(2);
        btn_1 = 1'b1; wait_ms(2);
        btn_1 = 1'b0; wait_ms(3);
        btn_1 = 1'b1; wait_ms(5);
        $display("[TB] Expect: No additional UART strings transmitted (10ms debounce not met)");
        wait_ms(5);

        // TC6: In AUTO mode, press BTN1 -> LOW
        $display("\n[TC6] In AUTO mode, Press BTN1 (Switch to LOW)");
        press_btn1(15);
        $display("[TB] Expect: 'MODE: LOW\\r\\n' string appears above");

        // TC7: In LOW mode, press BTN2 -> AUTO
        $display("\n[TC7] In LOW mode, Press BTN2 (Switch to AUTO)");
        press_btn2(15);
        $display("[TB] Expect: 'MODE: AUTO\\r\\n' string appears above");

        // TC8: In AUTO mode, press BTN2 again -> Remains AUTO (Check spam prevention)
        $display("\n[TC8] In AUTO mode, Press BTN2 again (Keep AUTO)");
        press_btn2(15);
        $display("[TB] Expect: NO additional UART strings (prevents spam in AUTO)");

        // TC9: Press both buttons simultaneously (BTN1 & BTN2)
        // FSM logic: btn2_pulse has priority, transitions to AUTO if not already AUTO
        $display("\n[TC9] Press both buttons simultaneously (Priority to AUTO transition)");
        $display("[TB] --- BTN1 & BTN2 pressed (15 ms) ---");
        // First switch to LOW for testing (since TC8 left it in AUTO)
        press_btn1(15); 
        $display("[TB] Switched to LOW.");
        
        btn_1 = 1'b0;
        btn_2 = 1'b0;
        wait_ms(15);
        btn_1 = 1'b1;
        btn_2 = 1'b1;
        $display("[TB] BTN1 & BTN2 released");
        wait_ms(15);
        $display("[TB] Expect: 'MODE: AUTO\\r\\n' string appears above due to btn2 priority");
        $display("  Simulation Complete");
        $display("=================================================");
        $finish;
    end

    // Timeout (Prevents infinite loops)
    initial begin
        #(500_000_000); // 500 ms timeout
        $display("[TB] TIMEOUT – simulation forcibly ended");
        $finish;
    end

endmodule
