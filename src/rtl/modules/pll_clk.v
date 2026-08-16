// =============================================================================
// Module      : pll_clk.v
// Project     : Kiwi Nano 4K / Tang Nano 4K
// Role        : Member 2 (Khối nhân/chia xung PLL 27MHz -> 50MHz)
// =============================================================================

module pll_clk (
    input  wire clk_in,   // 27 MHz OSC
    input  wire rst_n,
    output wire clk_out  // 50 MHz Clock Output
);

    // Mẫu mô phỏng / Pass-through đệm cho RTL synthesis
    // Khi dùng IP Gowin Gowin_rPLL, IP này sẽ thay thế bằng module Gowin rPLL
    assign clk_out = clk_in;

endmodule
