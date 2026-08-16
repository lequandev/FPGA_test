// =============================================================================
// Module      : pwm_gen.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// Role        : Member 2 (Khối phát xung PWM điều khiển độ sáng LED)
// =============================================================================

module pwm_gen (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] mode,     // 00: LOW (0%), 01: HIGH (100%), 10: AUTO (Breathing)
    output reg        pwm_out
);

    localparam [8:0]  PRESCALER_MAX = 9'd263;
    localparam [16:0] STEP_MAX      = 17'd105468;
    localparam [7:0]  DUTY_LOW      = 8'd0;
    localparam [7:0]  DUTY_HIGH     = 8'd255;

    reg [8:0]  prescaler_cnt;
    reg [7:0]  pwm_cnt;
    reg [16:0] step_cnt;
    reg [7:0]  auto_duty;
    reg        dir;

    wire prescaler_hit_max = (prescaler_cnt >= PRESCALER_MAX);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prescaler_cnt <= 9'd0;
        else prescaler_cnt <= prescaler_hit_max ? 9'd0 : prescaler_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pwm_cnt <= 8'd0;
        else if (prescaler_hit_max) pwm_cnt <= pwm_cnt + 1'b1;
    end

    wire is_mode_auto = (mode == 2'b10);
    wire step_hit_max = (step_cnt >= STEP_MAX);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) step_cnt <= 17'd0;
        else if (!is_mode_auto || step_hit_max) step_cnt <= 17'd0;
        else step_cnt <= step_cnt + 1'b1;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auto_duty <= 8'd0;
            dir       <= 1'b0;
        end else if (!is_mode_auto) begin
            auto_duty <= 8'd0;
            dir       <= 1'b0;
        end else if (step_hit_max) begin
            if (!dir) begin
                if (auto_duty == 8'd255) begin
                    dir       <= 1'b1;
                    auto_duty <= auto_duty - 1'b1;
                end else begin
                    auto_duty <= auto_duty + 1'b1;
                end
            end else begin
                if (auto_duty == 8'd0) begin
                    dir       <= 1'b0;
                    auto_duty <= auto_duty + 1'b1;
                end else begin
                    auto_duty <= auto_duty - 1'b1;
                end
            end
        end
    end

    reg [7:0] active_duty;
    always @(*) begin
        case (mode)
            2'b00:   active_duty = DUTY_LOW;   // 0%
            2'b01:   active_duty = DUTY_HIGH;  // 100%
            2'b10:   active_duty = auto_duty;  // AUTO Breathing
            default: active_duty = DUTY_LOW;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pwm_out <= 1'b0;
        else pwm_out <= (active_duty == 8'd255) ? 1'b1 : (pwm_cnt < active_duty);
    end

endmodule
