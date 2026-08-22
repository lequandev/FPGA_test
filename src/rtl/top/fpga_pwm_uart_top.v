// =============================================================================
// Module      : fpga_pwm_uart_top.v
// Project     : Kiwi Nano 4K / Tang Nano 4K - FPGA PWM + UART
// Role        : Member 1 (R&D Khối Lõi RTL & FSM / Leader)
// Description : Top-level module kết nối 5 sub-modules:
//               1. pll_clk     - Tạo xung clk 50MHz từ sys_clk 27MHz
//               2. debounce    - Khử nảy nút btn1 & btn2
//               3. fsm_control - Quản lý máy trạng thái FSM Moore (LOW, HIGH, AUTO)
//               4. pwm_gen     - Tạo tín hiệu PWM điều khiển độ sáng LED
//               5. uart_tx     - Bộ truyền UART 8N1 gửi chuỗi thông báo trạng thái
// Standard    : Verilog-2001
// =============================================================================

module fpga_pwm_uart_top (
    input  wire sys_clk,        // Xung nhịp thạch anh hệ thống (Pin 33: 27 MHz)
    input  wire sys_rst_n,      // Reset hệ thống tích cực thấp (Active LOW)
    input  wire btn1,           // Nút nhấn 1 (Pin 14, Active LOW, chưa debounce)
    input  wire btn2,           // Nút nhấn 2 (Pin 15, Active LOW, chưa debounce)
    output wire led_pwm,        // Tín hiệu PWM ra LED (Pin 10)
    output wire uart_tx_pin     // Tín hiệu UART TX ra cổng Serial (Pin 16)
);

    // ------------------------------------------------------------------------
    // Internal Wires (Kết nối nội bộ giữa các sub-module)
    // ------------------------------------------------------------------------
    wire       clk_50m;         // Xung nhịp hệ thống 50 MHz sau PLL
    wire       rst_n;           // Reset đồng bộ hoá
    wire       btn1_pulse;      // Xung kích 1 chu kỳ từ nút 1 sau khi debounce
    wire       btn2_pulse;      // Xung kích 1 chu kỳ từ nút 2 sau khi debounce
    wire       btn1_state;      // Trạng thái giữ của nút 1
    wire       btn2_state;      // Trạng thái giữ của nút 2
    wire [1:0] mode;            // Mã chế độ từ FSM (00: LOW, 01: HIGH, 10: AUTO)
    wire [7:0] tx_data;         // Byte ASCII truyền qua UART
    wire [3:0] tx_len;          // Độ dài chuỗi truyền UART
    wire       tx_start;        // Xung kích truyền 1 byte UART
    wire       tx_busy;         // Tín hiệu bận từ UART TX

    assign rst_n = sys_rst_n;

    // =========================================================================
    // 1. KHỐI PLL CLOCK (pll_clk)
    // =========================================================================
    pll_clk u_pll_clk (
        .clk_in  (sys_clk),
        .rst_n   (rst_n),
        .clk_out (clk_50m)
    );

    // =========================================================================
    // 2. KHỐI DEBOUNCE NÚT 1 (debounce - btn1)
    // =========================================================================
    debounce #(
        .CLK_FREQ    (50_000_000),
        .DEBOUNCE_MS (20)
    ) u_debounce_btn1 (
        .clk       (clk_50m),
        .rst_n     (rst_n),
        .btn_in    (btn1),
        .btn_state (btn1_state),
        .btn_press (btn1_pulse),
        .btn_rel   ()
    );

    // =========================================================================
    // 3. KHỐI DEBOUNCE NÚT 2 (debounce - btn2)
    // =========================================================================
    debounce #(
        .CLK_FREQ    (50_000_000),
        .DEBOUNCE_MS (20)
    ) u_debounce_btn2 (
        .clk       (clk_50m),
        .rst_n     (rst_n),
        .btn_in    (btn2),
        .btn_state (btn2_state),
        .btn_press (btn2_pulse),
        .btn_rel   ()
    );

    // =========================================================================
    // 4. KHỐI FSM CONTROLLER (fsm_control)
    // =========================================================================
    fsm_control u_fsm_control (
        .clk        (clk_50m),
        .rst_n      (rst_n),
        .btn1_pulse (btn1_pulse),
        .btn2_pulse (btn2_pulse),
        .tx_busy    (tx_busy),
        .mode       (mode),
        .tx_data    (tx_data),
        .tx_len     (tx_len),
        .tx_start   (tx_start)
    );

    // =========================================================================
    // 5. KHỐI PWM GENERATOR (pwm_gen)
    // =========================================================================
    pwm_gen u_pwm_gen (
        .clk     (clk_50m),
        .rst_n   (rst_n),
        .mode    (mode),
        .pwm_out (led_pwm)
    );

    // =========================================================================
    // 6. KHỐI UART TRANSMITTER (uart_tx)
    // =========================================================================
    uart_tx #(
        .CLK_FREQ  (50_000_000),
        .BAUD_RATE (115_200)
    ) u_uart_tx (
        .clk      (clk_50m),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_out   (uart_tx_pin),
        .tx_busy  (tx_busy)
    );

endmodule
