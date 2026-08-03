// =============================================================================
// Module  : pwm.v
// Project : Kiwi Nano 4K – LED PWM Demo
// Board   : GoWin Kiwi Nano 4K (GW1NR-LV4QN48PC6/I5)
//
// Description:
//   8-bit PWM generator.
//   Counter counts 0 to (PWM_PERIOD-1); output HIGH while counter < duty_threshold.
//   duty_up / duty_down change duty cycle by 1/256 steps per single-cycle pulse.
// =============================================================================

module pwm #(
    parameter CLK_FREQ = 50_000_000,  // Input clock frequency (Hz)
    parameter PWM_FREQ = 1_000        // Desired PWM frequency (Hz)
)(
    input  wire clk,        // System clock
    input  wire rst_n,      // Active-low synchronous reset
    input  wire duty_up,    // Pulse: increase duty cycle by 1 step
    input  wire duty_down,  // Pulse: decrease duty cycle by 1 step
    output reg  pwm_out     // PWM output
);

    // -------------------------------------------------------------------------
    // Derived parameters
    // -------------------------------------------------------------------------
    localparam integer PWM_PERIOD = CLK_FREQ / PWM_FREQ;
    localparam integer CNT_WIDTH  = $clog2(PWM_PERIOD);
    localparam integer STEP       = PWM_PERIOD / 256; // 1/256 of period

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    reg [CNT_WIDTH-1:0] counter;
    reg [7:0]           duty_cycle;
    reg [CNT_WIDTH-1:0] duty_threshold;

    // -------------------------------------------------------------------------
    // Free-running period counter
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            counter <= 0;
        end else if (counter >= PWM_PERIOD - 1) begin
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Duty cycle register update
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            duty_cycle     <= 8'd128;          // Start at 50%
            duty_threshold <= PWM_PERIOD >> 1; // 50% threshold
        end else begin
            if (duty_up && (duty_cycle < 8'd255)) begin
                duty_cycle     <= duty_cycle + 1;
                duty_threshold <= duty_threshold + STEP;
            end else if (duty_down && (duty_cycle > 8'd0)) begin
                duty_cycle     <= duty_cycle - 1;
                duty_threshold <= duty_threshold - STEP;
            end
        end
    end

    // -------------------------------------------------------------------------
    // PWM comparator
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n)
            pwm_out <= 1'b0;
        else
            pwm_out <= (counter < duty_threshold) ? 1'b1 : 1'b0;
    end

endmodule
