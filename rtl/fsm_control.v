// =============================================================================
// Module      : fsm_control.v
// Project     : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description : Main FSM Controller handling mode transitions.
// =============================================================================

module fsm_control (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       btn1_pulse,
    input  wire       btn2_pulse,

    output reg  [1:0] mode,
    output reg        mode_changed
);

    // ------------------------------------------------------------------------
    // FSM Modes
    // ------------------------------------------------------------------------
    localparam [1:0] MODE_LOW  = 2'b00,
                     MODE_HIGH = 2'b01,
                     MODE_AUTO = 2'b10;

    reg first_boot;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode         <= MODE_LOW;
            mode_changed <= 1'b0;
            first_boot   <= 1'b1;
        end else begin
            mode_changed <= 1'b0; // Default: no change

            // Trigger mode_changed once immediately after boot to send initial UART message
            if (first_boot) begin
                mode_changed <= 1'b1;
                first_boot   <= 1'b0;
            end else begin
                if (btn2_pulse) begin
                    // Button 2: Switch to AUTO directly
                    if (mode != MODE_AUTO) begin
                        mode         <= MODE_AUTO;
                        mode_changed <= 1'b1;
                    end
                end else if (btn1_pulse) begin
                    // Button 1: Toggle LOW <-> HIGH, or AUTO -> LOW
                    case (mode)
                        MODE_LOW: begin
                            mode         <= MODE_HIGH;
                            mode_changed <= 1'b1;
                        end
                        MODE_HIGH: begin
                            mode         <= MODE_LOW;
                            mode_changed <= 1'b1;
                        end
                        MODE_AUTO: begin
                            mode         <= MODE_LOW;
                            mode_changed <= 1'b1;
                        end
                        default: begin
                            mode         <= MODE_LOW;
                            mode_changed <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

endmodule
