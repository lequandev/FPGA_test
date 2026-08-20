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
    // UART string capture and checker
    // =========================================================================
    localparam BAUD_RATE   = 115_200;
    localparam BAUD_PERIOD = 1_000_000_000 / BAUD_RATE; // ns per bit

    reg [8*15-1:0] captured_string = 0;
    integer captured_len = 0;

    task clear_uart_buffer;
    begin
        captured_string = 0;
        captured_len = 0;
    end
    endtask

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check_uart_string;
        input [8*15-1:0] expected_string;
        input integer expected_len;
        input [127:0] test_name;
    begin
        if (captured_len == expected_len && captured_string == expected_string) begin
            $display("[PASS] %s - Got expected string", test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s - Expected '%s' (len %0d), Got '%s' (len %0d)", 
                     test_name, expected_string, expected_len, captured_string, captured_len);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

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
        
        // Append to buffer
        captured_string = (captured_string << 8) | rx_byte;
        captured_len = captured_len + 1;
    end
    endtask

    // UART listener thread (runs in background)
    initial begin
        $display("[UART] Monitor started (115200 8N1)");
        forever begin
            capture_uart_byte;
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
        wait_ms(15);
    end
    endtask

    // =========================================================================
    // Stimulus (Test Plan FPGA_Team_Assignments.md)
    // =========================================================================
    initial begin
        $dumpfile("sim_out/tb_top.vcd");
        $dumpvars(0, tb_top);

        $display("=================================================");
        $display("  Kiwi 1P5 – FPGA 2026 Testbench");
        $display("=================================================");

        // TC1: Power-on Reset
        $display("\n[TC1] Power-on Reset");
        clear_uart_buffer;
        btn_1 = 1'b1;
        btn_2 = 1'b1;
        wait_ms(3);
        check_uart_string({ "MODE: LOW", 8'h0D, 8'h0A }, 11, "TC1_PowerOn");

        // TC2: Button 1, 1st press -> HIGH
        $display("\n[TC2] Press BTN1 (Switch to HIGH)");
        clear_uart_buffer;
        press_btn1(15); // Press for 15ms (> 10ms debounce)
        check_uart_string({ "MODE: HIGH", 8'h0D, 8'h0A }, 12, "TC2_Btn1_HIGH");

        // TC3: Button 1, 2nd press -> LOW
        $display("\n[TC3] Press BTN1 2nd time (Switch to LOW)");
        clear_uart_buffer;
        press_btn1(15);
        check_uart_string({ "MODE: LOW", 8'h0D, 8'h0A }, 11, "TC3_Btn1_LOW");

        // TC4: Button 2 -> AUTO
        $display("\n[TC4] Press BTN2 (Switch to AUTO)");
        clear_uart_buffer;
        press_btn2(15);
        check_uart_string({ "MODE: AUTO", 8'h0D, 8'h0A }, 12, "TC4_Btn2_AUTO");

        // TC5: Bounce test (Button noise < 10ms)
        $display("\n[TC5] Bounce Test (Continuous press/release < 10ms)");
        clear_uart_buffer;
        btn_1 = 1'b0; wait_ms(2);
        btn_1 = 1'b1; wait_ms(2);
        btn_1 = 1'b0; wait_ms(3);
        btn_1 = 1'b1; wait_ms(5);
        wait_ms(5);
        check_uart_string("", 0, "TC5_Bounce_NoOutput");

        // TC6: In AUTO mode, press BTN1 -> LOW
        $display("\n[TC6] In AUTO mode, Press BTN1 (Switch to LOW)");
        clear_uart_buffer;
        press_btn1(15);
        check_uart_string({ "MODE: LOW", 8'h0D, 8'h0A }, 11, "TC6_AUTO_to_LOW");

        // TC7: In LOW mode, press BTN2 -> AUTO
        $display("\n[TC7] In LOW mode, Press BTN2 (Switch to AUTO)");
        clear_uart_buffer;
        press_btn2(15);
        check_uart_string({ "MODE: AUTO", 8'h0D, 8'h0A }, 12, "TC7_LOW_to_AUTO");

        // TC8: In AUTO mode, press BTN2 again -> Remains AUTO (Check spam prevention)
        $display("\n[TC8] In AUTO mode, Press BTN2 again (Keep AUTO)");
        clear_uart_buffer;
        press_btn2(15);
        check_uart_string("", 0, "TC8_AUTO_SpamPrevent");

        // TC9: Press both buttons simultaneously (BTN1 & BTN2)
        $display("\n[TC9] Press both buttons simultaneously (Priority to AUTO transition)");
        clear_uart_buffer;
        press_btn1(15); 
        check_uart_string({ "MODE: LOW", 8'h0D, 8'h0A }, 11, "TC9_Setup_LOW");
        
        clear_uart_buffer;
        btn_1 = 1'b0;
        btn_2 = 1'b0;
        wait_ms(15);
        btn_1 = 1'b1;
        btn_2 = 1'b1;
        wait_ms(15);
        check_uart_string({ "MODE: AUTO", 8'h0D, 8'h0A }, 12, "TC9_BothBtn_AUTO");

        // --- Summary ---
        $display("\n=================================================");
        $display("=== Result: %0d PASS  %0d FAIL ===", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");
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
