// =============================================================================
// Testbench : tb_pwm.v
// DUT       : pwm.v
// =============================================================================

`timescale 1ns / 1ps

module tb_pwm;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg  [1:0] mode    = 2'b00;
    wire       pwm_out;

    // Expose internal active_duty for checking
    wire [7:0] active_duty_obs = dut.active_duty;

    pwm dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .mode    (mode),
        .pwm_out (pwm_out)
    );

    // 50 MHz clock
    always #10 clk = ~clk;

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check(input [7:0] expected, input [127:0] test_name);
    begin
        @(posedge clk); #1;
        if (active_duty_obs === expected) begin
            $display("[PASS] %s : active_duty = %0d", test_name, active_duty_obs);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s : expected %0d, got %0d", test_name, expected, active_duty_obs);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    initial begin
        $dumpfile("sim_out/tb_pwm.vcd");
        $dumpvars(0, tb_pwm);

        $display("=== PWM Testbench ===");

        // Reset
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // TC1: Mode LOW (00) -> Duty should be 64 (25%)
        mode = 2'b00;
        repeat(10) @(posedge clk);
        check(8'd64, "TC1_Mode_LOW");

        // TC2: Mode HIGH (01) -> Duty should be 255 (100%)
        mode = 2'b01;
        repeat(10) @(posedge clk);
        check(8'd255, "TC2_Mode_HIGH");

        // TC3: Mode AUTO (10) -> Duty should start at 0 and increase
        mode = 2'b10;
        repeat(10) @(posedge clk);
        check(8'd0, "TC3_Mode_AUTO_Start");
        
        // Wait for it to step up (STEP_MAX is ~196077 clocks)
        // Wait 200,000 clocks to ensure it stepped at least once
        repeat(200_000) @(posedge clk);
        if (active_duty_obs > 0) begin
            $display("[PASS] TC4_Mode_AUTO_Breathing : active_duty increased to %0d", active_duty_obs);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] TC4_Mode_AUTO_Breathing : active_duty did not increase (still %0d)", active_duty_obs);
            fail_cnt = fail_cnt + 1;
        end

        // --- Summary ---
        $display("=== Result: %0d PASS  %0d FAIL ===", pass_cnt, fail_cnt);
        $finish;
    end

    // Timeout
    initial begin
        #50_000_000;
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule
