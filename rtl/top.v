// =============================================================================
// Module  : top.v
// Project : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description: Top-level design with 3 PWM Modes (25%, 100%, AUTO)
// =============================================================================

module top (
    input  wire clk_in,   // 27 MHz clock input (from board)
    input  wire btn_1,    // Push button 1 (active-low)
    input  wire btn_2,    // Push button 2 (active-low)
    output wire led_pwm,  // PWM-dimmed LED
    output wire uart_tx   // UART TX (115200 8N1)
);

    localparam CLK_FREQ  = 50_000_000;
    localparam BAUD_RATE = 115_200;

    wire sys_clk;
    
    Gowin_rPLL pll_inst (
        .clkouta(sys_clk),
        .clkin  (clk_in)   
    );
    
    reg [4:0] rst_cnt = 5'd0;
    reg       rst_n   = 1'b0;
    
    always @(posedge sys_clk) begin
        if (!rst_n) begin
            if (rst_cnt == 5'd31)
                rst_n <= 1'b1; // Đã sửa lỗi: 1'b1 (trước đó bị gõ nhầm thành 1 me1)
            else
                rst_cnt <= rst_cnt + 1'b1;
        end
    end

    // 1. Button Debouncers
    wire btn1_pulse;
    wire btn2_pulse;

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (10)
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
        .DEBOUNCE_MS (10)
    ) u_deb2 (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .btn_in    (btn_2),
        .btn_state (),
        .btn_press (btn2_pulse),
        .btn_rel   ()
    );

    // 2. FSM Controller & UART Message Dispatcher
    wire [1:0] current_mode;
    wire       mode_changed;
    wire       tx_busy;
    wire [7:0] tx_data;
    wire       tx_start;

    fsm_control u_fsm (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .btn1_pulse   (btn1_pulse),
        .btn2_pulse   (btn2_pulse),
        .mode         (current_mode),
        .mode_changed (mode_changed)
    );

    uart_msg u_msg (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .mode         (current_mode),
        .mode_changed (mode_changed),
        .tx_busy      (tx_busy),
        .tx_data      (tx_data),
        .tx_start     (tx_start)
    );

    // 3. PWM Generator (3 Modes: 25%, 100%, AUTO)
    pwm u_pwm (
        .clk     (sys_clk),
        .rst_n   (rst_n),
        .mode    (current_mode),
        .pwm_out (led_pwm)
    );

    // 4. UART Transmitter
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