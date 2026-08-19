// =============================================================================
// Module      : top_test_pwm.v
// Project     : Kiwi 1P5 EVK - PWM Mode Switcher (GW1N-UV1P5)
// =============================================================================

module top_test_pwm (
    input  wire clk_in,     // Clock đầu vào cấp từ chân ngoài (GCLK)
    input  wire btn_1,      // Nút bấm 1: Chuyển đổi Mode (S1 - Pin 35)
    input  wire btn_2,      // Nút bấm 2: Reset về Mode ban đầu (S2 - Pin 36)
    output wire led_pwm     // LED PWM (D3 - Pin 27)
);

    // -------------------------------------------------------------------------
    // 1. KHỐI PLL: TẠO XUNG 50 MHz TỪ CLOCK ĐẦU VÀO
    // -------------------------------------------------------------------------
    wire clk_50m;
    wire pll_lock;

    // Khởi tạo IP Core Gowin_rPLL từ công cụ IP Core Generator
    Gowin_rPLL u_pll (
        .clkout (clk_50m),  // 50 MHz output
        .lock   (pll_lock), // 1 khi clock đã ổn định
        .clkin  (clk_in)    // Clock đầu vào
    );

    // -------------------------------------------------------------------------
    // 2. POWER-ON RESET (Đồng bộ theo clk_50m và pll_lock)
    // -------------------------------------------------------------------------
    reg [7:0] rst_cnt = 8'd0;
    reg       sys_rst_n = 1'b0;

    always @(posedge clk_50m or negedge pll_lock) begin
        if (!pll_lock) begin
            rst_cnt   <= 8'd0;
            sys_rst_n <= 1'b0;
        end else begin
            if (rst_cnt == 8'd255) begin
                sys_rst_n <= 1'b1;
            end else begin
                rst_cnt   <= rst_cnt + 1'b1;
                sys_rst_n <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 3. CHỐNG DỘI PHÍM CHO CẢ 2 NÚT (Debounce 20ms @ 50 MHz)
    // -------------------------------------------------------------------------
    wire btn1_press;
    wire btn2_press;

    btn_debounce #(
        .CLK_FREQ    (50_000_000),
        .DEBOUNCE_MS (20)
    ) u_db1 (
        .clk       (clk_50m),
        .rst_n     (sys_rst_n),
        .btn_in    (btn_1),
        .btn_state (),
        .btn_press (btn1_press),
        .btn_rel   ()
    );

    btn_debounce #(
        .CLK_FREQ    (50_000_000),
        .DEBOUNCE_MS (20)
    ) u_db2 (
        .clk       (clk_50m),
        .rst_n     (sys_rst_n),
        .btn_in    (btn_2),
        .btn_state (),
        .btn_press (btn2_press),
        .btn_rel   ()
    );

    // -------------------------------------------------------------------------
    // 4. QUẢN LÝ CHẾ ĐỘ HOẠT ĐỘNG (00: OFF, 01: 25%, 10: 100%, 11: AUTO)
    // -------------------------------------------------------------------------
    reg [1:0] current_mode;

    always @(posedge clk_50m or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            current_mode <= 2'b00;
        end else if (btn2_press) begin
            current_mode <= 2'b00; // Nút 2: Reset mode về OFF
        end else if (btn1_press) begin
            current_mode <= current_mode + 1'b1; // Nút 1: Chuyển tuần tự mode
        end
    end

    // -------------------------------------------------------------------------
    // 5. KHỐI TẠO XUNG PWM & XUẤT RA LED ACTIVE-HIGH
    // -------------------------------------------------------------------------
    wire raw_pwm_out;

    pwm u_pwm (
        .clk     (clk_50m),
        .rst_n   (sys_rst_n),
        .mode    (current_mode),
        .pwm_out (raw_pwm_out)
    );

    // LED trên board Kiwi 1P5 kết nối kiểu Active-High (Mức 1 = Sáng)
    assign led_pwm = raw_pwm_out;

endmodule