// =============================================================================
// Module  : Gowin_rPLL (Dummy for Simulation)
// Project : Kiwi 1P5 / Nano 4K - FPGA 2026
// Description:
//   This is a bypass dummy model for the Gowin_rPLL IP Core.
//   It allows testbenches to simulate the design without requiring the
//   proprietary Gowin simulation library.
//   It ignores the 27MHz input and forcibly generates a 50MHz clock.
// =============================================================================

`timescale 1ns / 1ps

module Gowin_rPLL (
    output reg clkout,
    input  wire clkin
);

    // Generate 50MHz clock (20ns period -> 10ns half-period)
    initial begin
        clkout = 1'b0;
        forever #10 clkout = ~clkout;
    end

endmodule
