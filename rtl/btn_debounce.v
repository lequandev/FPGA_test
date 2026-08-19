// =============================================================================
// Module      : btn_debounce.v
// Project     : Kiwi 1P5 EVK
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

    localparam CNT_MAX   = (CLK_FREQ / 1000) * DEBOUNCE_MS - 1;
    localparam CNT_WIDTH = $clog2(CNT_MAX + 1);

    reg  btn_sync_0, btn_sync_1;
    reg  [CNT_WIDTH-1:0] cnt;
    wire is_input_changed;
    wire is_cnt_max;

    // Bộ đồng bộ Double-Flop
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b1;
            btn_sync_1 <= 1'b1;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    assign is_input_changed = (btn_sync_1 != btn_state);
    assign is_cnt_max       = (cnt >= CNT_MAX);

    // Bộ đếm Debounce
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_WIDTH{1'b0}};
        end else begin
            if (!is_input_changed || is_cnt_max)
                cnt <= {CNT_WIDTH{1'b0}};
            else
                cnt <= cnt + 1'b1;
        end
    end

    // Phát xung 1 chu kỳ clock khi nhấn/nhả
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_state <= 1'b1;
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;
        end else begin
            if (is_input_changed && is_cnt_max) begin
                btn_state <= btn_sync_1;
                btn_press <= (btn_sync_1 == 1'b0); // Nút tích cực mức thấp
                btn_rel   <= (btn_sync_1 == 1'b1);
            end else begin
                btn_press <= 1'b0;
                btn_rel   <= 1'b0;
            end
        end
    end

endmodule