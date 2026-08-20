// =============================================================================
// Module  : top.v
// Project : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description:
//   Top-level design integrating PLL (bypassed for sim, pass-through), 
//   Debounce, FSM (uart_msg), PWM, and UART TX.
// =============================================================================

module top (
    input  wire clk_in,   // 50 MHz clock input
    input  wire btn_1,    // Push button 1 (active-low)
    input  wire btn_2,    // Push button 2 (active-low)
    output wire led_pwm,  // PWM-dimmed LED
    output wire uart_tx   // UART TX (115200 8N1)
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_FREQ  = 50_000_000;
    localparam BAUD_RATE = 115_200;

    // =========================================================================
    // Clock & Power-On Reset
    // =========================================================================
    wire sys_clk = clk_in; // Assuming 50MHz is provided directly.
    
    reg [4:0] rst_cnt = 5'd0;
    reg       rst_n   = 1'b0;
    
    always @(posedge sys_clk) begin
        if (!rst_n) begin
            if (rst_cnt == 5'd31)
                rst_n <= 1'b1;
            else
                rst_cnt <= rst_cnt + 1'b1;
        end
    end

    // =========================================================================
    // 1. Button Debouncers
    // =========================================================================
    wire btn1_pulse;
    wire btn2_pulse;

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (10) // 10ms debounce
    ) u_deb1 (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .btn_in    (btn_1),
        .btn_state (),
        .btn_press (btn1_pulse),
        .btn_rel   ()
    );

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (10) // 10ms debounce
    ) u_deb2 (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .btn_in    (btn_2),
        .btn_state (),
        .btn_press (btn2_pulse),
        .btn_rel   ()
    );

    // =========================================================================
    // 2. FSM Controller & UART Message Dispatcher
    // =========================================================================
    wire [1:0] current_mode;
    wire       tx_busy;
    wire [7:0] tx_data;
    wire       tx_start;

    uart_msg u_fsm (
        .clk        (sys_clk),
        .rst_n      (rst_n),
        .btn1_pulse (btn1_pulse),
        .btn2_pulse (btn2_pulse),
        .mode       (current_mode),
        .tx_busy    (tx_busy),
        .tx_data    (tx_data),
        .tx_start   (tx_start)
    );

    // =========================================================================
    // 3. PWM Generator
    // =========================================================================
    pwm u_pwm (
        .clk     (sys_clk),
        .rst_n   (rst_n),
        .mode    (current_mode),
        .pwm_out (led_pwm)
    );

    // =========================================================================
    // 4. UART Transmitter
    // =========================================================================
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_tx (
        .clk      (sys_clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx_out   (uart_tx),
        .tx_busy  (tx_busy)
    );

endmodule
