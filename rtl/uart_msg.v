// =============================================================================
// Module  : uart_msg.v
// Project : Kiwi Nano 4K
//
// Description:
//   Simple string-message sender over UART.
//   Stores a ROM message (up to 64 bytes) and sends it byte-by-byte whenever
//   send_trigger pulses HIGH. Ignores new triggers while busy.
//
//   Default message: "BTN1:? BTN2:? PWM:XXX\r\n"
//   Caller updates duty_pct (0-100) and btn1/btn2 state each trigger.
// =============================================================================

module uart_msg #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       send_trigger, // 1-cycle pulse: start sending message
    input  wire       btn1_pressed, // current state of button 1 (1=pressed)
    input  wire       btn2_pressed, // current state of button 2 (1=pressed)
    input  wire [7:0] duty_pct,     // duty cycle 0-100
    output wire       uart_tx,
    output wire       msg_busy      // HIGH while sending
);

    // -------------------------------------------------------------------------
    // UART TX instance
    // -------------------------------------------------------------------------
    reg        tx_send;
    reg  [7:0] tx_byte;
    wire       tx_busy;
    wire       tx_done;

    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_tx (
        .clk     (clk),
        .rst_n   (rst_n),
        .send_en (tx_send),
        .tx_data (tx_byte),
        .uart_tx (uart_tx),
        .tx_busy (tx_busy),
        .tx_done (tx_done)
    );

    // -------------------------------------------------------------------------
    // Build message: "B1:P B2:P D:100\r\n"  (max 18 chars)
    //   B1: P/R  B2: P/R  D: 000
    // -------------------------------------------------------------------------
    reg [7:0]  msg  [0:17]; // message buffer (18 bytes max)
    reg [4:0]  msg_len;
    reg [4:0]  byte_idx;
    reg        active;
    reg [7:0]  duty_latch;
    reg        b1, b2;

    assign msg_busy = active;

    // Hundred/Tens/Units of duty_pct (0-100)
    wire [7:0] d_h = (duty_latch / 100)      + 8'd48; // '0'-'9'
    wire [7:0] d_t = (duty_latch % 100) / 10 + 8'd48;
    wire [7:0] d_u = (duty_latch % 10)       + 8'd48;

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            active    <= 1'b0;
            byte_idx  <= 0;
            tx_send   <= 1'b0;
        end else begin
            tx_send <= 1'b0;

            if (!active) begin
                if (send_trigger) begin
                    // Latch current state
                    b1         <= btn1_pressed;
                    b2         <= btn2_pressed;
                    duty_latch <= (duty_pct > 100) ? 8'd100 : duty_pct;
                    active     <= 1'b1;
                    byte_idx   <= 0;
                end
            end else begin
                // Build and send each character
                if (!tx_busy && !tx_send) begin
                    case (byte_idx)
                        5'd0:  tx_byte <= "B";
                        5'd1:  tx_byte <= "1";
                        5'd2:  tx_byte <= ":";
                        5'd3:  tx_byte <= b1 ? "P" : "R"; // P=Pressed R=Released
                        5'd4:  tx_byte <= " ";
                        5'd5:  tx_byte <= "B";
                        5'd6:  tx_byte <= "2";
                        5'd7:  tx_byte <= ":";
                        5'd8:  tx_byte <= b2 ? "P" : "R";
                        5'd9:  tx_byte <= " ";
                        5'd10: tx_byte <= "D";
                        5'd11: tx_byte <= ":";
                        5'd12: tx_byte <= d_h;
                        5'd13: tx_byte <= d_t;
                        5'd14: tx_byte <= d_u;
                        5'd15: tx_byte <= "%";
                        5'd16: tx_byte <= 8'h0D; // CR
                        5'd17: tx_byte <= 8'h0A; // LF
                        default: tx_byte <= " ";
                    endcase

                    tx_send  <= 1'b1;
                    byte_idx <= byte_idx + 1;

                    if (byte_idx >= 5'd17) begin
                        active <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
