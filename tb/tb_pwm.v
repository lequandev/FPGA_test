// =============================================================================
// Testbench : tb_pwm.v
// DUT       : pwm.v
//
// Covers:
//   1. Default 50% duty cycle after reset
//   2. duty_up   → each pulse increases duty by 1 step
//   3. duty_down → each pulse decreases duty by 1 step
//   4. Saturation: no overflow at 255, no underflow at 0
// =============================================================================

`timescale 1ns / 1ps

module tb_pwm;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg  clk        = 1'b0;
    reg  rst_n      = 1'b0;
    reg  duty_up    = 1'b0;
    reg  duty_down  = 1'b0;
    wire pwm_out;

    // -------------------------------------------------------------------------
    // Expose internal duty_cycle for checking (works in Icarus/ModelSim)
    // -------------------------------------------------------------------------
    wire [7:0] duty_cycle_obs = dut.duty_cycle;

    pwm #(
        .CLK_FREQ (50_000_000),
        .PWM_FREQ (1_000)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .duty_up   (duty_up),
        .duty_down (duty_down),
        .pwm_out   (pwm_out)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Helper: send one-cycle pulse
    // -------------------------------------------------------------------------
    task send_up;
    begin
        @(posedge clk); duty_up = 1'b1;
        @(posedge clk); duty_up = 1'b0;
    end
    endtask

    task send_down;
    begin
        @(posedge clk); duty_down = 1'b1;
        @(posedge clk); duty_down = 1'b0;
    end
    endtask

    // -------------------------------------------------------------------------
    // Checker task
    // -------------------------------------------------------------------------
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check(input [7:0] expected, input [127:0] test_name);
    begin
        @(posedge clk); #1;
        if (duty_cycle_obs === expected) begin
            $display("[PASS] %s : duty_cycle = %0d", test_name, duty_cycle_obs);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s : expected %0d, got %0d", test_name, expected, duty_cycle_obs);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("sim_out/tb_pwm.vcd");
        $dumpvars(0, tb_pwm);

        $display("=== PWM Testbench ===");

        // --- Reset ---
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // TC1: After reset, duty_cycle should be 128 (50%)
        check(8'd128, "TC1_reset_50pct");

        // TC2: One duty_up pulse → 129
        send_up;
        check(8'd129, "TC2_up_once");

        // TC3: Three more up pulses → 132
        send_up; send_up; send_up;
        check(8'd132, "TC3_up_3more");

        // TC4: One duty_down → 131
        send_down;
        check(8'd131, "TC4_down_once");

        // TC5: Saturation at 255 – ramp up to 255, then one more up
        // Fast: force duty_cycle near 255 by many pulses (or direct force if available)
        begin : ramp_up
            integer i;
            for (i = 0; i < 124; i = i + 1) send_up; // 131+124=255
        end
        check(8'd255, "TC5_saturate_high");
        send_up; // should stay at 255
        check(8'd255, "TC5_no_overflow");

        // TC6: Saturation at 0
        begin : ramp_down
            integer j;
            for (j = 0; j < 255; j = j + 1) send_down;
        end
        check(8'd0, "TC6_saturate_low");
        send_down; // should stay at 0
        check(8'd0, "TC6_no_underflow");

        // --- Summary ---
        $display("=== Result: %0d PASS  %0d FAIL ===", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
