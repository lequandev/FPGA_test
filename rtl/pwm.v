// ============================================================================
// Module      : pwm_led_controller.v
// Target FPGA : Tang Nano 4K / Gowin GW1NSR-4C
// ============================================================================

module pwm_led_controller (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] mode,
    output reg        pwm_out
);

    // ------------------------------------------------------------------------
    // Local Parameters
    // ------------------------------------------------------------------------
    localparam [8:0]  PRESCALER_MAX = 9'd263;
    localparam [16:0] STEP_MAX      = 17'd105468;
    localparam [7:0]  DUTY_25       = 8'd64;
    localparam [7:0]  DUTY_100      = 8'd255;

    // ------------------------------------------------------------------------
    // Registers (Flip-Flops)
    // ------------------------------------------------------------------------
    reg [8:0]  prescaler_cnt;
    reg [7:0]  pwm_cnt;
    reg [16:0] step_cnt;
    reg [7:0]  auto_duty;
    reg        dir;

    // =========================================================================
    // KHỐI 1: PRESCALER COUNTER (9-bit)
    // =========================================================================
    wire       prescaler_hit_max;
    wire [8:0] prescaler_add1;
    wire [8:0] prescaler_cnt_next;

    // Comparator
    assign prescaler_hit_max  = (prescaler_cnt >= PRESCALER_MAX);

    // Adder +1
    assign prescaler_add1     = prescaler_cnt + 1'b1;

    // MUX 2:1
    assign prescaler_cnt_next = (prescaler_hit_max) ? 9'd0 : prescaler_add1;

    // DFF Register (9-bit)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prescaler_cnt <= 9'd0;
        else        prescaler_cnt <= prescaler_cnt_next;
    end

    // =========================================================================
    // KHỐI 2: PWM COUNTER (8-bit)
    // =========================================================================
    wire [7:0] pwm_add1;
    wire [7:0] pwm_cnt_next;

    // Adder +1
    assign pwm_add1     = pwm_cnt + 1'b1;

    // MUX 2:1
    assign pwm_cnt_next = (prescaler_hit_max) ? pwm_add1 : pwm_cnt;

    // DFF Register (8-bit)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pwm_cnt <= 8'd0;
        else        pwm_cnt <= pwm_cnt_next;
    end

    // =========================================================================
    // KHỐI 3: STEP COUNTER (17-bit)
    // =========================================================================
    wire        is_mode_auto;
    wire        step_hit_max;
    wire [16:0] step_add1;
    wire [16:0] step_cnt_next;

    // Comparator AUTO mode
    assign is_mode_auto  = (mode == 2'b11);

    // Comparator STEP_MAX
    assign step_hit_max  = (step_cnt >= STEP_MAX);

    // Adder +1
    assign step_add1     = step_cnt + 1'b1;

    // MUX 3:1
    assign step_cnt_next = (!is_mode_auto) ? 17'd0 :
                           (step_hit_max)  ? 17'd0 : step_add1;

    // DFF Register (17-bit)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) step_cnt <= 17'd0;
        else        step_cnt <= step_cnt_next;
    end

    // =========================================================================
    // KHỐI 4: AUTO BREATHING LOGIC
    // =========================================================================
    wire       is_duty_max;
    wire       is_duty_min;
    wire [7:0] auto_duty_add1;
    wire [7:0] auto_duty_sub1;

    // Comparators
    assign is_duty_max    = (auto_duty == 8'd255);
    assign is_duty_min    = (auto_duty == 8'd0);

    // Adder & Subtractor
    assign auto_duty_add1 = auto_duty + 1'b1;
    assign auto_duty_sub1 = auto_duty - 1'b1;

    // MUX dir_next
    wire dir_next_temp;
    assign dir_next_temp = (dir == 1'b0) ? (is_duty_max ? 1'b1 : 1'b0) :
                                           (is_duty_min ? 1'b0 : 1'b1);

    wire dir_next;
    assign dir_next = (!is_mode_auto) ? 1'b0 :
                      (step_hit_max)  ? dir_next_temp : dir;

    // MUX auto_duty_next
    wire [7:0] auto_duty_temp;
    assign auto_duty_temp = (dir == 1'b0) ? (is_duty_max ? auto_duty_sub1 : auto_duty_add1) :
                                            (is_duty_min ? auto_duty_add1 : auto_duty_sub1);

    wire [7:0] auto_duty_next;
    assign auto_duty_next = (!is_mode_auto) ? 8'd0 :
                            (step_hit_max)  ? auto_duty_temp : auto_duty;

    // DFF Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            auto_duty <= 8'd0;
            dir       <= 1'b0;
        end else begin
            auto_duty <= auto_duty_next;
            dir       <= dir_next;
        end
    end

    // =========================================================================
    // KHỐI 5: MODE MUX
    // =========================================================================
    reg [7:0] active_duty;

    always @(*) begin
        case (mode)
            2'b01:   active_duty = DUTY_25;
            2'b10:   active_duty = DUTY_100;
            2'b11:   active_duty = auto_duty;
            default: active_duty = 8'd0;
        endcase
    end

    // =========================================================================
    // KHỐI 6: PWM COMPARATOR & OUTPUT
    // =========================================================================
    wire is_duty_100_percent;
    wire is_cnt_less_than_duty;
    wire pwm_out_next;

    // Comparators
    assign is_duty_100_percent  = (active_duty == 8'd255);
    assign is_cnt_less_than_duty = (pwm_cnt < active_duty);

    // OR / MUX Logic
    assign pwm_out_next = is_duty_100_percent ? 1'b1 : is_cnt_less_than_duty;

    // Output DFF Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) pwm_out <= 1'b0;
        else        pwm_out <= pwm_out_next;
    end

endmodule