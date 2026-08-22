// =============================================================================
// Module      : btn_debounce.v
// Project     : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description : Debounce single button input and generate 1-cycle press pulse
// =============================================================================

module btn_debounce #(
    parameter CLK_FREQ    = 50_000_000,
    parameter DEBOUNCE_MS = 10
)(
    input  wire clk,
    input  wire rst_n,
    input  wire btn_in,        // Nút nhấn vật lý (Active-Low)
    output reg  btn_state,     // Trạng thái đã lọc rung (0 = Pressed, 1 = Released)
    output reg  btn_press,     // Xung 1 chu kỳ khi vừa nhấn nút
    output reg  btn_rel        // Xung 1 chu kỳ khi vừa thả nút
);

    localparam CNT_MAX = (CLK_FREQ / 1000) * DEBOUNCE_MS;

    // 2-FF Synchronizer
    reg [1:0] sync;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sync <= 2'b11;
        else
            sync <= {sync[0], btn_in};
    end

    // Debounce Counter & Edge Detection
    reg [31:0] cnt;
    reg        btn_state_prev;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt            <= 32'd0;
            btn_state      <= 1'b1;
            btn_state_prev <= 1'b1;
            btn_press      <= 1'b0;
            btn_rel        <= 1'b0;
        end else begin
            if (sync[1] != btn_state) begin
                cnt <= cnt + 1'b1;
                if (cnt >= CNT_MAX) begin
                    btn_state <= sync[1];
                    cnt       <= 32'd0;
                end
            end else begin
                cnt <= 32'd0;
            end

            btn_state_prev <= btn_state;
            btn_press      <= (btn_state_prev == 1'b1 && btn_state == 1'b0);
            btn_rel        <= (btn_state_prev == 1'b0 && btn_state == 1'b1);
        end
    end

endmodule