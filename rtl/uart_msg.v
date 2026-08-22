// =============================================================================
// Module      : uart_msg.v
// Project     : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description : Formats mode strings and dispatches bytes to external uart_tx
// =============================================================================

module uart_msg (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] mode,
    input  wire       mode_changed,
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start
);

    localparam [1:0] IDLE      = 2'b00,
                     LOAD_STR  = 2'b01,
                     SEND_BYTE = 2'b10,
                     WAIT_TX   = 2'b11;

    reg [1:0] state;
    reg [4:0] byte_idx;
    reg [4:0] msg_len;
    reg [7:0] msg_buf [0:23];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            byte_idx <= 5'd0;
            msg_len  <= 5'd0;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                IDLE: begin
                    byte_idx <= 5'd0;
                    if (mode_changed) begin
                        state <= LOAD_STR;
                    end
                end

                LOAD_STR: begin
                    // Nạp chuỗi thông báo tương ứng với Mode
                    case (mode)
                        2'b00: begin // "MODE: LOW\r\n" (11 ký tự)
                            msg_buf[0]  <= "M"; msg_buf[1]  <= "O"; msg_buf[2]  <= "D"; msg_buf[3]  <= "E";
                            msg_buf[4]  <= ":"; msg_buf[5]  <= " "; msg_buf[6]  <= "L"; msg_buf[7]  <= "O";
                            msg_buf[8]  <= "W"; msg_buf[9]  <= 8'h0D; msg_buf[10] <= 8'h0A;
                            msg_len     <= 5'd11;
                        end
                        2'b01: begin // "MODE: HIGH\r\n" (12 ký tự)
                            msg_buf[0]  <= "M"; msg_buf[1]  <= "O"; msg_buf[2]  <= "D"; msg_buf[3]  <= "E";
                            msg_buf[4]  <= ":"; msg_buf[5]  <= " "; msg_buf[6]  <= "H"; msg_buf[7]  <= "I";
                            msg_buf[8]  <= "G"; msg_buf[9]  <= "H"; msg_buf[10] <= 8'h0D; msg_buf[11] <= 8'h0A;
                            msg_len     <= 5'd12;
                        end
                        2'b10: begin // "MODE: AUTO\r\n" (12 ký tự)
                            msg_buf[0]  <= "M"; msg_buf[1]  <= "O"; msg_buf[2]  <= "D"; msg_buf[3]  <= "E";
                            msg_buf[4]  <= ":"; msg_buf[5]  <= " "; msg_buf[6]  <= "A"; msg_buf[7]  <= "U";
                            msg_buf[8]  <= "T"; msg_buf[9]  <= "O"; msg_buf[10] <= 8'h0D; msg_buf[11] <= 8'h0A;
                            msg_len     <= 5'd12;
                        end
                        2'b11: begin // "MODE: OFF\r\n" (11 ký tự)
                            msg_buf[0]  <= "M"; msg_buf[1]  <= "O"; msg_buf[2]  <= "D"; msg_buf[3]  <= "E";
                            msg_buf[4]  <= ":"; msg_buf[5]  <= " "; msg_buf[6]  <= "O"; msg_buf[7]  <= "F";
                            msg_buf[8]  <= "F"; msg_buf[9]  <= 8'h0D; msg_buf[10] <= 8'h0A;
                            msg_len     <= 5'd11;
                        end
                    endcase
                    state <= SEND_BYTE;
                end

                SEND_BYTE: begin
                    if (!tx_busy) begin
                        tx_data  <= msg_buf[byte_idx];
                        tx_start <= 1'b1;
                        state    <= WAIT_TX;
                    end
                end

                WAIT_TX: begin
                    // Đợi đến khi tx_busy tích cực rồi mới tăng index gửi byte tiếp theo
                    if (tx_busy) begin
                        if (byte_idx + 1'b1 < msg_len) begin
                            byte_idx <= byte_idx + 1'b1;
                            state    <= SEND_BYTE;
                        end else begin
                            state    <= IDLE;
                        end
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule