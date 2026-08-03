// =============================================================================
// Module  : top.v
// Project : Kiwi Nano 4K – LED PWM + UART Demo
// Board   : GoWin Kiwi Nano 4K (GW1NR-LV4QN48PC6/I5)
// Tools   : GoWin EDA (gw_sh / GOWIN IDE)
//
// Description:
//   Top-level design.
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │  clk_in (50 MHz) ──► [GoWin RPLL] ──► 50 MHz sys_clk           │
//   │                                                                  │
//   │  btn_1 (active-low) ──► [debounce] ──► press pulse              │
//   │     • Short press  : PWM duty UP (+1 step)                      │
//   │     • Hold 1s      : continuous ramp UP                         │
//   │                                                                  │
//   │  btn_2 (active-low) ──► [debounce] ──► press pulse              │
//   │     • Short press  : PWM duty DOWN (-1 step)                    │
//   │     • Hold 1s      : continuous ramp DOWN                       │
//   │                                                                  │
//   │  [PWM gen] ──► led_pwm                                          │
//   │                                                                  │
//   │  Every 500 ms: send status over uart_tx (115200 8N1)            │
//   │     "B1:P B2:R D:050%\r\n"                                      │
//   └─────────────────────────────────────────────────────────────────┘
//
// Pin Constraints (kiwi_nano4k.cst):
//   clk_in  → 33  (LVCMOS33)
//   btn_1   → 14  (LVCMOS18, pull-up = active-low)
//   btn_2   → 15  (LVCMOS18, pull-up = active-low)
//   led_pwm → 10  (LVCMOS33)
//   uart_tx → 16  (LVCMOS33)
// =============================================================================

module top (
    input  wire clk_in,   // 50 MHz board oscillator
    input  wire btn_1,    // Push button 1 (active-low)
    input  wire btn_2,    // Push button 2 (active-low)
    output wire led_pwm,  // PWM-dimmed LED
    output wire uart_tx   // UART TX (115200 8N1)
);

    // =========================================================================
    // Parameters
    // =========================================================================
    localparam CLK_FREQ   = 50_000_000;
    localparam BAUD_RATE  = 115_200;
    localparam PWM_FREQ   = 1_000;       // 1 kHz PWM
    localparam REPORT_MS  = 500;         // UART status every 500 ms

    // =========================================================================
    // Clock / Reset
    // =========================================================================
    // GoWin boards provide a clean 50 MHz crystal; pass through directly.
    // (Insert RPLL here if you need a different frequency.)
    wire sys_clk = clk_in;

    // Power-on reset: hold reset for 16 clock cycles
    reg [4:0] rst_cnt = 5'd0;
    reg       rst_n   = 1'b0;
    always @(posedge sys_clk) begin
        if (!rst_n) begin
            if (rst_cnt == 5'd31)
                rst_n <= 1'b1;
            else
                rst_cnt <= rst_cnt + 1;
        end
    end

    // =========================================================================
    // Button debouncers
    // =========================================================================
    wire btn1_state, btn1_press, btn1_rel;
    wire btn2_state, btn2_press, btn2_rel;

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (20)
    ) u_deb1 (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .btn_in    (btn_1),
        .btn_state (btn1_state),
        .btn_press (btn1_press),
        .btn_rel   (btn1_rel)
    );

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (20)
    ) u_deb2 (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .btn_in    (btn_2),
        .btn_state (btn2_state),
        .btn_press (btn2_press),
        .btn_rel   (btn2_rel)
    );

    // =========================================================================
    // Auto-repeat: hold button 1s → continuous change at 10 Hz
    // =========================================================================
    localparam integer HOLD_CLKS   = CLK_FREQ;           // 1 s
    localparam integer REPEAT_CLKS = CLK_FREQ / 10;      // 100 ms

    reg [25:0] hold1_cnt, hold2_cnt;
    reg [23:0] rep1_cnt,  rep2_cnt;
    reg        auto1,     auto2;

    wire duty_up   = btn1_press | (auto1 & (rep1_cnt == 0));
    wire duty_down = btn2_press | (auto2 & (rep2_cnt == 0));

    always @(posedge sys_clk) begin
        if (!rst_n) begin
            hold1_cnt <= 0; rep1_cnt <= 0; auto1 <= 0;
            hold2_cnt <= 0; rep2_cnt <= 0; auto2 <= 0;
        end else begin
            // ---- Button 1 hold / auto-repeat --------------------------------
            if (btn1_state == 1'b0) begin // Pressed (active-low)
                if (hold1_cnt < HOLD_CLKS)
                    hold1_cnt <= hold1_cnt + 1;
                else
                    auto1 <= 1'b1;

                if (auto1) begin
                    if (rep1_cnt < REPEAT_CLKS - 1)
                        rep1_cnt <= rep1_cnt + 1;
                    else
                        rep1_cnt <= 0;
                end
            end else begin
                hold1_cnt <= 0; rep1_cnt <= 0; auto1 <= 0;
            end

            // ---- Button 2 hold / auto-repeat --------------------------------
            if (btn2_state == 1'b0) begin
                if (hold2_cnt < HOLD_CLKS)
                    hold2_cnt <= hold2_cnt + 1;
                else
                    auto2 <= 1'b1;

                if (auto2) begin
                    if (rep2_cnt < REPEAT_CLKS - 1)
                        rep2_cnt <= rep2_cnt + 1;
                    else
                        rep2_cnt <= 0;
                end
            end else begin
                hold2_cnt <= 0; rep2_cnt <= 0; auto2 <= 0;
            end
        end
    end

    // =========================================================================
    // PWM Generator
    // =========================================================================
    pwm #(
        .CLK_FREQ (CLK_FREQ),
        .PWM_FREQ (PWM_FREQ)
    ) u_pwm (
        .clk       (sys_clk),
        .rst_n     (rst_n),
        .duty_up   (duty_up),
        .duty_down (duty_down),
        .pwm_out   (led_pwm)
    );

    // =========================================================================
    // Duty % calculation (for UART display, approximate)
    // =========================================================================
    // duty_cycle is 0-255 → map to 0-100
    // We expose duty_pct via a small counter that follows the PWM module's
    // internal state. We reconstruct it by tracking up/down presses.
    reg [7:0] duty_cnt; // mirrors pwm.duty_cycle
    always @(posedge sys_clk) begin
        if (!rst_n) begin
            duty_cnt <= 8'd128;
        end else begin
            if (duty_up   && duty_cnt < 255) duty_cnt <= duty_cnt + 1;
            if (duty_down && duty_cnt > 0  ) duty_cnt <= duty_cnt - 1;
        end
    end
    // 0-100% = duty_cnt * 100 / 255  (integer approx)
    wire [7:0] duty_pct = (duty_cnt * 8'd100) >> 8; // fast approx / 256

    // =========================================================================
    // Periodic UART status report (every REPORT_MS ms)
    // =========================================================================
    localparam integer REPORT_CLKS = CLK_FREQ / 1000 * REPORT_MS;
    reg [24:0] report_cnt;
    reg        report_trig;

    always @(posedge sys_clk) begin
        if (!rst_n) begin
            report_cnt  <= 0;
            report_trig <= 1'b0;
        end else begin
            report_trig <= 1'b0;
            if (report_cnt >= REPORT_CLKS - 1) begin
                report_cnt  <= 0;
                report_trig <= 1'b1;
            end else begin
                report_cnt <= report_cnt + 1;
            end
        end
    end

    // =========================================================================
    // UART Message Sender
    // =========================================================================
    uart_msg #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_msg (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .send_trigger (report_trig),
        .btn1_pressed (~btn1_state), // invert: 0=released → pressed=1
        .btn2_pressed (~btn2_state),
        .duty_pct     (duty_pct),
        .uart_tx      (uart_tx),
        .msg_busy     ()             // unused
    );

endmodule
