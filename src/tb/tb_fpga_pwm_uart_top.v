// =============================================================================
// Module      : tb_fpga_pwm_uart_top.v
// Project     : Kiwi Nano 4K / Tang Nano 4K - FPGA PWM + UART
// Role        : Member 3 (Testbench mô phỏng kiểm thử toàn hệ thống)
// =============================================================================

`timescale 1ns / 1ps

module tb_fpga_pwm_uart_top;

    reg  sys_clk;
    reg  sys_rst_n;
    reg  btn1;
    reg  btn2;
    wire led_pwm;
    wire uart_tx_pin;

    // Unit Under Test (UUT)
    fpga_pwm_uart_top uut (
        .sys_clk     (sys_clk),
        .sys_rst_n   (sys_rst_n),
        .btn1        (btn1),
        .btn2        (btn2),
        .led_pwm     (led_pwm),
        .uart_tx_pin (uart_tx_pin)
    );

    // Clock generator (27 MHz -> ~37.037 ns period)
    always #18.518 sys_clk = ~sys_clk;

    initial begin
        // Khởi tạo
        sys_clk   = 0;
        sys_rst_n = 0;
        btn1      = 1;
        btn2      = 1;

        #200;
        sys_rst_n = 1;
        #500;

        // Giả lập nhấn Nút 1 (Chuyển LOW -> HIGH)
        $display("[TB] Pressing Button 1: LOW -> HIGH");
        btn1 = 0;
        #100;
        btn1 = 1;
        #20000;

        // Giả lập nhấn Nút 1 (Chuyển HIGH -> AUTO)
        $display("[TB] Pressing Button 1: HIGH -> AUTO");
        btn1 = 0;
        #100;
        btn1 = 1;
        #20000;

        // Giả lập nhấn Nút 2 (Chuyển AUTO -> HIGH)
        $display("[TB] Pressing Button 2: AUTO -> HIGH");
        btn2 = 0;
        #100;
        btn2 = 1;
        #20000;

        $display("[TB] Simulation finished successfully.");
        $finish;
    end

    initial begin
        $dumpfile("sim_out.vcd");
        $dumpvars(0, tb_fpga_pwm_uart_top);
    end

endmodule
