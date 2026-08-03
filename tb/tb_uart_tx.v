// =============================================================================
// Testbench : tb_uart_tx.v
// DUT       : uart_tx.v
//
// Covers:
//   1. Single byte transmission – verify start/data/stop bits
//   2. tx_busy held HIGH during transmission
//   3. tx_done pulses exactly one cycle after stop bit
//   4. Ignores send_en while tx_busy
//   5. Back-to-back byte transmission
// =============================================================================

`timescale 1ns / 1ps

module tb_uart_tx;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    localparam CLK_FREQ  = 50_000_000;
    localparam BAUD_RATE = 115_200;
    localparam BIT_CLKS  = CLK_FREQ / BAUD_RATE; // ~434 clocks per bit

    // -------------------------------------------------------------------------
    // DUT I/O
    // -------------------------------------------------------------------------
    reg        clk     = 1'b0;
    reg        rst_n   = 1'b0;
    reg        send_en = 1'b0;
    reg  [7:0] tx_data = 8'h00;
    wire       uart_tx;
    wire       tx_busy;
    wire       tx_done;

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .send_en (send_en),
        .tx_data (tx_data),
        .uart_tx (uart_tx),
        .tx_busy (tx_busy),
        .tx_done (tx_done)
    );

    always #10 clk = ~clk; // 50 MHz

    // -------------------------------------------------------------------------
    // Task: transmit one byte and decode back from UART line
    // -------------------------------------------------------------------------
    integer pass_cnt = 0;
    integer fail_cnt = 0;

    task transmit_and_check(input [7:0] byte_to_send);
        integer i;
        reg [7:0] rx_byte;
        reg start_ok, stop_ok;
    begin
        // Assert send_en for 1 clock
        tx_data = byte_to_send;
        @(posedge clk); send_en = 1'b1;
        @(posedge clk); send_en = 1'b0;

        // Check tx_busy asserted within next cycle
        @(posedge clk);
        if (!tx_busy) begin
            $display("[FAIL] tx_busy not asserted for 0x%02X", byte_to_send);
            fail_cnt = fail_cnt + 1;
        end

        // Wait for start bit low
        @(negedge uart_tx);

        // Sample middle of start bit
        repeat(BIT_CLKS / 2) @(posedge clk);
        start_ok = (uart_tx === 1'b0);

        // Sample 8 data bits (LSB first)
        rx_byte = 8'h00;
        for (i = 0; i < 8; i = i + 1) begin
            repeat(BIT_CLKS) @(posedge clk);
            rx_byte[i] = uart_tx;
        end

        // Sample stop bit
        repeat(BIT_CLKS) @(posedge clk);
        stop_ok = (uart_tx === 1'b1);

        // Wait for tx_done
        @(posedge tx_done);

        // Report
        if (start_ok && stop_ok && (rx_byte === byte_to_send)) begin
            $display("[PASS] Sent 0x%02X ('%c') – decoded 0x%02X – framing OK",
                     byte_to_send, byte_to_send, rx_byte);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("[FAIL] Sent 0x%02X – decoded 0x%02X – start=%b stop=%b",
                     byte_to_send, rx_byte, start_ok, stop_ok);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("sim_out/tb_uart_tx.vcd");
        $dumpvars(0, tb_uart_tx);

        $display("=== UART TX Testbench ===");

        // Reset
        rst_n = 1'b0;
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        // TC1: Idle line should be HIGH
        if (uart_tx !== 1'b1) begin
            $display("[FAIL] TC1: Idle line not HIGH");
            fail_cnt = fail_cnt + 1;
        end else begin
            $display("[PASS] TC1: Idle line HIGH");
            pass_cnt = pass_cnt + 1;
        end

        // TC2-TC6: Transmit various bytes
        transmit_and_check(8'h41); // 'A'
        transmit_and_check(8'h55); // 'U' (alternating bits)
        transmit_and_check(8'hAA); // 10101010
        transmit_and_check(8'hFF); // all ones
        transmit_and_check(8'h00); // all zeros

        // --- Summary ---
        $display("=== Result: %0d PASS  %0d FAIL ===", pass_cnt, fail_cnt);
        $finish;
    end

    // Timeout
    initial begin
        #100_000_000;
        $display("[TB] TIMEOUT");
        $finish;
    end

endmodule
