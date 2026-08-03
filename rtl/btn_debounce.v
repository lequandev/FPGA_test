// =============================================================================
// Module  : btn_debounce.v
// Project : Kiwi Nano 4K
//
// Description:
//   Generic push-button debouncer (active-low input).
//   Waits DEBOUNCE_MS milliseconds of stable state before registering a change.
//   Outputs:
//     btn_state : debounced level (0 = pressed, 1 = released, active-low)
//     btn_press : single-clock pulse when button is pressed  (falling edge)
//     btn_rel   : single-clock pulse when button is released (rising edge)
// =============================================================================

module btn_debounce #(
    parameter CLK_FREQ    = 50_000_000, // System clock (Hz)
    parameter DEBOUNCE_MS = 20          // Debounce time (ms)
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,    // Raw active-low button input
    output reg  btn_state, // Debounced level
    output reg  btn_press, // 1-cycle pulse on press
    output reg  btn_rel    // 1-cycle pulse on release
);

    localparam integer DEBOUNCE_CLKS = CLK_FREQ / 1000 * DEBOUNCE_MS;
    localparam integer CNT_WIDTH     = $clog2(DEBOUNCE_CLKS);

    reg [CNT_WIDTH-1:0] cnt;
    reg btn_sync0, btn_sync1, btn_prev;

    // -------------------------------------------------------------------------
    // Two-stage synchroniser for metastability
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        btn_sync0 <= btn_in;
        btn_sync1 <= btn_sync0;
    end

    // -------------------------------------------------------------------------
    // Debounce counter
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt       <= 0;
            btn_state <= 1'b1; // Released
            btn_prev  <= 1'b1;
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;
        end else begin
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;

            if (btn_sync1 != btn_state) begin
                cnt <= cnt + 1;
                if (cnt >= DEBOUNCE_CLKS - 1) begin
                    cnt       <= 0;
                    btn_state <= btn_sync1;
                    btn_press <= (~btn_sync1); // pressed when LOW
                    btn_rel   <= ( btn_sync1); // released when HIGH
                end
            end else begin
                cnt <= 0;
            end
        end
    end

endmodule
