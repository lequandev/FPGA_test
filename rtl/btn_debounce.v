// =============================================================================
// Module      : btn_debounce.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// =============================================================================

module btn_debounce #(
    parameter CLK_FREQ    = 50_000_000,
    parameter DEBOUNCE_MS = 20
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,
    output reg  btn_state,
    output reg  btn_press,
    output reg  btn_rel
);

    // ------------------------------------------------------------------------
    // Constants & Parameters
    // ------------------------------------------------------------------------
    localparam CNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS - 1;
    localparam CNT_WIDTH = $clog2(CNT_MAX + 1);

    // ------------------------------------------------------------------------
    // Signals & Next-State Logic
    // ------------------------------------------------------------------------
    // Synchronizer Flops
    reg  btn_sync_0, btn_sync_1;
    wire btn_sync_0_next, btn_sync_1_next;

    // Debounce Counter Registers
    reg  [CNT_WIDTH-1:0] cnt;
    wire [CNT_WIDTH-1:0] cnt_next;
    wire                 cnt_add1;
    wire                 is_cnt_max;

    // State & Edge Detector Logic
    wire btn_state_next;
    wire btn_press_next;
    wire btn_rel_next;

    // =========================================================================
    // KHỐI 1: DOUBLE FLOP SYNCHRONIZER
    // =========================================================================
    assign btn_sync_0_next = btn_in;
    assign btn_sync_1_next = btn_sync_0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b1;
            btn_sync_1 <= 1'b1;
        end else begin
            btn_sync_0 <= btn_sync_0_next;
            btn_sync_1 <= btn_sync_1_next;
        end
    end

    // =========================================================================
    // KHỐI 2: DEBOUNCE TIMER COUNTER
    // =========================================================================
    wire is_input_changed;
    assign is_input_changed = (btn_sync_1 != btn_state);
    assign is_cnt_max       = (cnt >= CNT_MAX);
    assign cnt_add1         = cnt + 1'b1;

    assign cnt_next = (!is_input_changed) ? {CNT_WIDTH{1'b0}} :
                      (is_cnt_max)        ? {CNT_WIDTH{1'b0}} : (cnt + 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_WIDTH{1'b0}};
        end else begin
            cnt <= cnt_next;
        end
    end

    // =========================================================================
    // KHỐI 3: STATE UPDATE & EDGE PULSE GENERATION
    // =========================================================================
    assign btn_state_next = (is_input_changed && is_cnt_max) ? btn_sync_1 : btn_state;

    assign btn_press_next = (is_input_changed && is_cnt_max) && (btn_sync_1 == 1'b0);

    assign btn_rel_next   = (is_input_changed && is_cnt_max) && (btn_sync_1 == 1'b1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_state <= 1'b1;
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;
        end else begin
            btn_state <= btn_state_next;
            btn_press <= btn_press_next;
            btn_rel   <= btn_rel_next;
        end
    end

endmodule