// =============================================================================
// Module      : debounce.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// Role        : Member 2 (Khối chống nảy nút bấm)
// =============================================================================

module debounce #(
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

    localparam CNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS - 1;
    localparam CNT_WIDTH = $clog2(CNT_MAX + 1);

    reg  btn_sync_0, btn_sync_1;
    reg  [CNT_WIDTH-1:0] cnt;

    wire is_input_changed = (btn_sync_1 != btn_state);
    wire is_cnt_max       = (cnt >= CNT_MAX);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_sync_0 <= 1'b1;
            btn_sync_1 <= 1'b1;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_state <= 1'b1;
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;
        end else begin
            btn_press <= 1'b0;
            btn_rel   <= 1'b0;
            if (is_input_changed && is_cnt_max) begin
                btn_state <= btn_sync_1;
                if (btn_sync_1 == 1'b0)
                    btn_press <= 1'b1;
                else
                    btn_rel   <= 1'b1;
            end
        end
    end

endmodule
