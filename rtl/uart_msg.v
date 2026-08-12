// =============================================================================
// Module      : uart_msg.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// Description : String-message formatting and transmission over UART
// =============================================================================

module uart_msg #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       send_trigger,
    input  wire       btn1_pressed,
    input  wire       btn2_pressed,
    input  wire [7:0] duty_pct,
    output wire       uart_tx,
    output wire       msg_busy
);

    // ------------------------------------------------------------------------
    // Constants & Parameters
    // ------------------------------------------------------------------------
    localparam [1:0] IDLE      = 2'b00,
                     LOAD_MSG  = 2'b01,
                     SEND_BYTE = 2'b10,
                     WAIT_TX   = 2'b11;

    // ------------------------------------------------------------------------
    // Signals & Internal Registers
    // ------------------------------------------------------------------------
    reg  [7:0] tx_byte;
    reg        tx_start;
    wire       tx_busy;

    reg  [4:0] byte_idx;
    reg  [1:0] state;

    // ASCII Converter
    wire [7:0] pwm_hundreds = 8'h30 + (duty_pct / 100);
    wire [7:0] pwm_tens     = 8'h30 + ((duty_pct % 100) / 10);
    wire [7:0] pwm_ones     = 8'h30 + (duty_pct % 10);

    // ROM Message Buffer (23 Bytes: "BTN1:X BTN2:X PWM:XXX\r\n")
    reg  [7:0] msg_rom [0:22];

    assign msg_busy = (state != IDLE);

    // =========================================================================
    // KHỐI 1: UART TRANSMITTER SUBMODULE INSTANCE
    // =========================================================================
    uart_tx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) u_uart_tx (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_byte),
        .tx_out   (uart_tx),
        .tx_busy  (tx_busy)
    );

    // =========================================================================
    // KHỐI 2: MESSAGE FORMATTING & FSM CONTROLLER
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= IDLE;
            byte_idx <= 5'd0;
            tx_start <= 1'b0;
            tx_byte  <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            case (state)
                IDLE: begin
                    byte_idx <= 5'd0;
                    if (send_trigger) begin
                        msg_rom[0]  <= "B"; msg_rom[1]  <= "T"; msg_rom[2]  <= "N"; msg_rom[3]  <= "1"; msg_rom[4]  <= ":";
                        msg_rom[5]  <= btn1_pressed ? "1" : "0";
                        msg_rom[6]  <= " "; msg_rom[7]  <= "B"; msg_rom[8]  <= "T"; msg_rom[9]  <= "N"; msg_rom[10] <= "2"; msg_rom[11] <= ":";
                        msg_rom[12] <= btn2_pressed ? "1" : "0";
                        msg_rom[13] <= " "; msg_rom[14] <= "P"; msg_rom[15] <= "W"; msg_rom[16] <= "M"; msg_rom[17] <= ":";
                        msg_rom[18] <= pwm_hundreds;
                        msg_rom[19] <= pwm_tens;
                        msg_rom[20] <= pwm_ones;
                        msg_rom[21] <= 8'h0D; // '\r'
                        msg_rom[22] <= 8'h0A; // '\n'

                        state <= SEND_BYTE;
                    end
                end

                SEND_BYTE: begin
                    if (!tx_busy) begin
                        tx_byte  <= msg_rom[byte_idx];
                        tx_start <= 1'b1;
                        state    <= WAIT_TX;
                    end
                end

                WAIT_TX: begin
                    if (tx_busy) begin
                        if (byte_idx < 5'd22) begin
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