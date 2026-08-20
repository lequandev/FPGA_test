// =============================================================================
// Module      : pwm.v
// Project     : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description : PWM Generator for LED control
// =============================================================================

module pwm (
    input  wire       clk,        // 50 MHz Clock
    input  wire       rst_n,      // Reset tích cực mức thấp
    input  wire [1:0] mode,       // 00: LOW (25%), 01: HIGH (100%), 10: AUTO (Breathing)
    output reg        pwm_out     // Ngõ ra logic PWM (Active High)
);

    // Tần số PWM = 50MHz / (196 * 256) ≈ 996.4 Hz (1 kHz)
    localparam [7:0]  PRESCALER_MAX = 8'd195;
    
    // Tần số 50MHz: 2.0s cho 510 bước biến thiên Duty (255 lên + 255 xuống)
    // STEP_MAX = (50,000,000 * 2.0) / 510 - 1 = 196,077
    localparam [17:0] STEP_MAX      = 18'd196077;

    localparam [7:0]  DUTY_25       = 8'd64;   // 25% Duty
    localparam [7:0]  DUTY_100      = 8'd255;  // 100% Duty

    reg [7:0]  prescaler_cnt;
    reg [7:0]  pwm_cnt;
    reg [17:0] step_cnt;
    reg [7:0]  auto_duty;
    reg        dir;
    reg [7:0]  active_duty;

    // 1. Bộ chia tần (Prescaler)
    wire prescaler_hit_max = (prescaler_cnt >= PRESCALER_MAX);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            prescaler_cnt <= 8'd0;
        else 
            prescaler_cnt <= (prescaler_hit_max) ? 8'd0 : (prescaler_cnt + 1'b1);
    end

    // 2. Bộ đếm PWM (0 -> 255)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            pwm_cnt <= 8'd0;
        else if (prescaler_hit_max) 
            pwm_cnt <= pwm_cnt + 1'b1;
    end

    // 3. Bộ đếm thời gian bước chuyển Duty cho chế độ Breathing
    wire is_mode_auto = (mode == 2'b10);
    wire step_hit_max = (step_cnt >= STEP_MAX);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            step_cnt <= 18'd0;
        else if (!is_mode_auto) 
            step_cnt <= 18'd0;
        else 
            step_cnt <= (step_hit_max) ? 18'd0 : (step_cnt + 1'b1);
    end

    // 4. Máy phát Duty tự động (0 -> 255 -> 0 tuần tiến trong 2.0s)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auto_duty <= 8'd0;
            dir       <= 1'b0;
        end else if (!is_mode_auto) begin
            auto_duty <= 8'd0;
            dir       <= 1'b0;
        end else if (step_hit_max) begin
            if (!dir) begin // Đang tăng dần độ sáng
                if (auto_duty == 8'd255) begin
                    dir       <= 1'b1;
                    auto_duty <= 8'd254;
                end else begin
                    auto_duty <= auto_duty + 1'b1;
                end
            end else begin  // Đang giảm dần độ sáng
                if (auto_duty == 8'd0) begin
                    dir       <= 1'b0;
                    auto_duty <= 8'd1;
                end else begin
                    auto_duty <= auto_duty - 1'b1;
                end
            end
        end
    end

    // 5. Mux chọn Duty theo Mode
    always @(*) begin
        case (mode)
            2'b00:   active_duty = DUTY_25;   // LOW
            2'b01:   active_duty = DUTY_100;  // HIGH
            2'b10:   active_duty = auto_duty; // AUTO
            default: active_duty = DUTY_25;   // Fallback to LOW
        endcase
    end

    // 6. Ngõ ra điều chế PWM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else begin
            if (active_duty == 8'd0)
                pwm_out <= 1'b0;
            else if (active_duty == 8'd255)
                pwm_out <= 1'b1;
            else
                pwm_out <= (pwm_cnt < active_duty);
        end
    end

endmodule