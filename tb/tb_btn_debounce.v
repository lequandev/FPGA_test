// =============================================================================
// Testbench : tb_btn_debounce.v
// DUT       : btn_debounce.v
// =============================================================================

`timescale 1ns / 1ps

module tb_btn_debounce;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam CLK_FREQ    = 50_000_000;
    localparam DEBOUNCE_MS = 1; // Use 1ms for faster simulation
    localparam DB_CLKS     = (CLK_FREQ / 1000) * DEBOUNCE_MS;

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg  clk       = 1'b0;
    reg  rst_n     = 1'b0;
    reg  btn_in    = 1'b1;
    wire btn_state;
    wire btn_press;
    wire btn_rel;

    btn_debounce #(
        .CLK_FREQ    (CLK_FREQ),
        .DEBOUNCE_MS (DEBOUNCE_MS)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .btn_in    (btn_in),
        .btn_state (btn_state),
        .btn_press (btn_press),
        .btn_rel   (btn_rel)
    );

    always #10 clk = ~clk; // 50 MHz

    // -------------------------------------------------------------------------
    // Pulse Capture Logic
    // -------------------------------------------------------------------------
    integer press_count = 0;
    integer rel_count   = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            if (btn_press) press_count = press_count + 1;
            if (btn_rel)   rel_count   = rel_count + 1;
        end
    end

    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task check_counts;
        input integer exp_press;
        input integer exp_rel;
        input [127:0] test_name;
    begin
        @(posedge clk);
        if (press_count == exp_press && rel_count == exp_rel) begin
            $display("[PASS] %s", test_name);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] %s - Expected (%0d, %0d), Got (%0d, %0d)",
                     test_name, exp_press, exp_rel, press_count, rel_count);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("sim_out/tb_btn_debounce.vcd");
        $dumpvars(0, tb_btn_debounce);

        $display("=== Button Debounce Testbench ===");

        // Reset
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        if (btn_state !== 1'b1) begin
            $display("[FAIL] Initial state should be 1");
            fail_cnt = fail_cnt + 1;
        end

        // TC1: Clean press
        $display("\n[TC1] Clean press (>1ms)");
        btn_in = 1'b0;
        
        // Wait DB_CLKS + 10 to ensure it triggers
        repeat(DB_CLKS + 10) @(posedge clk);
        check_counts(1, 0, "TC1_CleanPress");

        // TC2: Clean release
        $display("\n[TC2] Clean release (>1ms)");
        btn_in = 1'b1;
        repeat(DB_CLKS + 10) @(posedge clk);
        check_counts(1, 1, "TC2_CleanRelease");

        // TC3: Noisy press (spikes < 1ms)
        $display("\n[TC3] Noisy press (bounce)");
        btn_in = 1'b0; repeat(DB_CLKS / 4) @(posedge clk); // 25% of DB time
        btn_in = 1'b1; repeat(DB_CLKS / 4) @(posedge clk); // release bounce
        btn_in = 1'b0; repeat(DB_CLKS / 4) @(posedge clk); // press bounce
        btn_in = 1'b1; repeat(DB_CLKS / 4) @(posedge clk); // release bounce
        
        // Should NOT have triggered a new press yet
        check_counts(1, 1, "TC3.1_NoPulseDuringBounce");

        // Now hold it steady for > 1ms
        btn_in = 1'b0;
        repeat(DB_CLKS + 10) @(posedge clk);
        check_counts(2, 1, "TC3.2_PulseAfterSteadyPress");

        // TC4: Noisy release (spikes < 1ms)
        $display("\n[TC4] Noisy release (bounce)");
        btn_in = 1'b1; repeat(DB_CLKS / 4) @(posedge clk); 
        btn_in = 1'b0; repeat(DB_CLKS / 4) @(posedge clk); 
        
        check_counts(2, 1, "TC4.1_NoPulseDuringBounce");
        
        btn_in = 1'b1;
        repeat(DB_CLKS + 10) @(posedge clk);
        check_counts(2, 2, "TC4.2_PulseAfterSteadyRelease");

        // --- Summary ---
        $display("=== Result: %0d PASS  %0d FAIL ===", pass_cnt, fail_cnt);
        if (fail_cnt == 0)
            $display("ALL TESTS PASSED");
        else
            $display("SOME TESTS FAILED");

        $finish;
    end

endmodule
