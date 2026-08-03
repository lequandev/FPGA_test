// =============================================================================
// Module  : uart_tx.v
// Project : Kiwi Nano 4K – LED PWM Demo
// Board   : GoWin Kiwi Nano 4K (GW1NR-LV4QN48PC6/I5)
//
// Description:
//   Simple 8N1 UART transmitter.
//   When send_en goes HIGH for one clock cycle and tx_busy is LOW,
//   tx_data is serialised and sent on uart_tx at the configured baud rate.
//   tx_done pulses HIGH for one clock when transmission finishes.
// =============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,  // System clock (Hz)
    parameter BAUD_RATE = 115_200      // UART baud rate (bps)
)(
    input  wire       clk,      // System clock
    input  wire       rst_n,    // Active-low synchronous reset
    input  wire       send_en,  // Start transmission (1-cycle pulse)
    input  wire [7:0] tx_data,  // Byte to transmit
    output reg        uart_tx,  // UART TX line (idle HIGH)
    output wire       tx_busy,  // HIGH while transmitting
    output reg        tx_done   // 1-cycle pulse when byte sent
);

    // -------------------------------------------------------------------------
    // Baud rate divider
    // -------------------------------------------------------------------------
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer CNT_WIDTH    = $clog2(CLKS_PER_BIT);

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    localparam [2:0] ST_IDLE  = 3'd0,
                     ST_START = 3'd1,
                     ST_DATA  = 3'd2,
                     ST_STOP  = 3'd3;

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    reg [2:0]          state;
    reg [CNT_WIDTH-1:0] baud_cnt;
    reg [2:0]          bit_idx;   // Bit pointer 0-7
    reg [7:0]          shift_reg; // Shadow copy of tx_data

    assign tx_busy = (state != ST_IDLE);

    // -------------------------------------------------------------------------
    // FSM
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            uart_tx   <= 1'b1;   // Idle HIGH
            baud_cnt  <= 0;
            bit_idx   <= 0;
            shift_reg <= 8'h00;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0; // default de-assert

            case (state)
                // ----------------------------------------------------------
                ST_IDLE: begin
                    uart_tx <= 1'b1;
                    if (send_en) begin
                        shift_reg <= tx_data;
                        baud_cnt  <= 0;
                        state     <= ST_START;
                    end
                end

                // ----------------------------------------------------------
                ST_START: begin
                    uart_tx <= 1'b0; // Start bit (LOW)
                    if (baud_cnt < CLKS_PER_BIT - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        bit_idx  <= 0;
                        state    <= ST_DATA;
                    end
                end

                // ----------------------------------------------------------
                ST_DATA: begin
                    uart_tx <= shift_reg[bit_idx]; // LSB first
                    if (baud_cnt < CLKS_PER_BIT - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        if (bit_idx < 7) begin
                            bit_idx <= bit_idx + 1;
                        end else begin
                            state <= ST_STOP;
                        end
                    end
                end

                // ----------------------------------------------------------
                ST_STOP: begin
                    uart_tx <= 1'b1; // Stop bit (HIGH)
                    if (baud_cnt < CLKS_PER_BIT - 1) begin
                        baud_cnt <= baud_cnt + 1;
                    end else begin
                        baud_cnt <= 0;
                        tx_done  <= 1'b1;
                        state    <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
