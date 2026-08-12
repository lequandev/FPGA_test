// =============================================================================
// Module      : uart_tx.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// Description : Low-level UART transmitter (8-bit Data, 1 Stop bit, No Parity)
// =============================================================================

module uart_tx #(
    parameter CLK_FREQ  = 50_000_000,
    parameter BAUD_RATE = 115_200
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx_out,
    output wire       tx_busy
);

    // ------------------------------------------------------------------------
    // Constants & Parameters
    // ------------------------------------------------------------------------
    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    // ------------------------------------------------------------------------
    // Registers & Signals
    // ------------------------------------------------------------------------
    reg [1:0] state;
    reg [8:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] tx_data_reg;

    assign tx_busy = (state != IDLE);

    // =========================================================================
    // KHỐI 1: BAUD RATE COUNTER & FSM CONTROLLER
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            tx_out      <= 1'b1;
            clk_count   <= 9'd0;
            bit_index   <= 3'd0;
            tx_data_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx_out    <= 1'b1;
                    clk_count <= 9'd0;
                    bit_index <= 3'd0;

                    if (tx_start) begin
                        tx_data_reg <= tx_data;
                        state       <= START;
                    end
                end

                START: begin
                    tx_out <= 1'b0;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 9'd0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx_out <= tx_data_reg[bit_index];

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 9'd0;
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'd0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_out <= 1'b1;

                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 9'd0;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule