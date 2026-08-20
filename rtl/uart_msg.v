// =============================================================================
// Module      : uart_msg.v
// Project     : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description : UART Message Dispatcher (Sends strings based on mode changes)
// =============================================================================

module uart_msg (
    input  wire       clk,
    input  wire       rst_n,
    
    // From FSM Control
    input  wire [1:0] mode,
    input  wire       mode_changed,

    // To UART TX module
    input  wire       tx_busy,
    output reg  [7:0] tx_data,
    output reg        tx_start
);

    // ------------------------------------------------------------------------
    // FSM States & Mode Definitions
    // ------------------------------------------------------------------------
    localparam [1:0] MODE_LOW  = 2'b00,
                     MODE_HIGH = 2'b01,
                     MODE_AUTO = 2'b10;

    // String Transmission FSM
    localparam [1:0] ST_IDLE  = 2'b00,
                     ST_START = 2'b01,
                     ST_WAIT  = 2'b10;

    // ------------------------------------------------------------------------
    // Internal Registers
    // ------------------------------------------------------------------------
    reg [1:0] tx_state;
    reg [3:0] char_idx;
    reg [3:0] msg_len;
    
    // ASCII strings (max 12 chars)
    reg [7:0] msg_buffer [0:11];

    // ------------------------------------------------------------------------
    // Task to load message based on mode
    // ------------------------------------------------------------------------
    task load_msg;
        input [1:0] current_mode;
        begin
            msg_buffer[0] <= "M"; msg_buffer[1] <= "O"; msg_buffer[2] <= "D"; msg_buffer[3] <= "E"; msg_buffer[4] <= ":"; msg_buffer[5] <= " ";
            case (current_mode)
                MODE_LOW: begin
                    msg_buffer[6] <= "L"; msg_buffer[7] <= "O"; msg_buffer[8] <= "W"; 
                    msg_buffer[9] <= 8'h0D; msg_buffer[10] <= 8'h0A; // \r\n
                    msg_len <= 11;
                end
                MODE_HIGH: begin
                    msg_buffer[6] <= "H"; msg_buffer[7] <= "I"; msg_buffer[8] <= "G"; msg_buffer[9] <= "H"; 
                    msg_buffer[10] <= 8'h0D; msg_buffer[11] <= 8'h0A; // \r\n
                    msg_len <= 12;
                end
                MODE_AUTO: begin
                    msg_buffer[6] <= "A"; msg_buffer[7] <= "U"; msg_buffer[8] <= "T"; msg_buffer[9] <= "O"; 
                    msg_buffer[10] <= 8'h0D; msg_buffer[11] <= 8'h0A; // \r\n
                    msg_len <= 12;
                end
                default: begin
                    msg_len <= 0;
                end
            endcase
        end
    endtask

    // ------------------------------------------------------------------------
    // String Transmission Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= ST_IDLE;
            tx_start <= 1'b0;
            tx_data  <= 8'd0;
            char_idx <= 4'd0;
            msg_len  <= 4'd0;
        end else begin
            // Default assignments
            tx_start <= 1'b0;

            if (mode_changed) begin
                load_msg(mode);
                tx_state <= ST_START;
                char_idx <= 4'd0;
            end else begin
                // String Transmission FSM
                case (tx_state)
                    ST_IDLE: begin
                        char_idx <= 4'd0;
                    end
                    ST_START: begin
                        if (!tx_busy) begin
                            tx_data  <= msg_buffer[char_idx];
                            tx_start <= 1'b1;
                            tx_state <= ST_WAIT;
                        end
                    end
                    ST_WAIT: begin
                        if (tx_busy) begin
                            // Wait for UART TX to finish current byte
                            if (char_idx < msg_len - 1) begin
                                char_idx <= char_idx + 1'b1;
                                tx_state <= ST_START;
                            end else begin
                                tx_state <= ST_IDLE;
                            end
                        end
                    end
                    default: tx_state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule