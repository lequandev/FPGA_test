// =============================================================================
// Module      : fsm_control.v
// Project     : Kiwi Nano 4K / Tang Nano 4K - FPGA PWM + UART
// Role        : Member 1 (R&D Khối Lõi RTL & FSM)
// Description : Máy trạng thái FSM Moore 3 chế độ (LOW, HIGH, AUTO)
//               Điều khiển truyền chuỗi kí tự ASCII qua UART khi chuyển trạng thái.
// =============================================================================

module fsm_control (
    input  wire       clk,          // Xung nhịp hệ thống (50 MHz)
    input  wire       rst_n,        // Reset tích cực mức thấp (Active LOW)
    input  wire       btn1_pulse,   // Xung đơn nút 1 (Chuyển thuận: LOW -> HIGH -> AUTO -> LOW)
    input  wire       btn2_pulse,   // Xung đơn nút 2 (Chuyển ngược: LOW -> AUTO -> HIGH -> LOW)
    input  wire       tx_busy,      // Tín hiệu bận từ UART TX (1: bận, 0: rảnh)
    output reg  [1:0] mode,         // Chế độ hiện tại: 2'b00=LOW, 2'b01=HIGH, 2'b10=AUTO
    output reg  [7:0] tx_data,      // Byte ASCII hiện tại cần truyền
    output reg  [3:0] tx_len,       // Độ dài chuỗi ký tự (11 hoặc 12 byte)
    output reg        tx_start      // Xung kích hoạt UART TX truyền 1 byte (1 chu kỳ clock)
);

    // ------------------------------------------------------------------------
    // Trạng thái FSM Moore (Mode State)
    // ------------------------------------------------------------------------
    localparam [1:0] ST_LOW  = 2'b00;
    localparam [1:0] ST_HIGH = 2'b01;
    localparam [1:0] ST_AUTO = 2'b10;

    reg [1:0] state, next_state;

    // ------------------------------------------------------------------------
    // Trình quản lý gửi chuỗi UART Byte-by-Byte
    // ------------------------------------------------------------------------
    reg [3:0] byte_cnt;
    reg       send_trigger;
    reg       tx_busy_d;        // Lưu trạng thái tx_busy ở chu kỳ trước để bắt cạnh xuống
    wire      tx_busy_negedge;

    assign tx_busy_negedge = (tx_busy_d == 1'b1) && (tx_busy == 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            tx_busy_d <= 1'b0;
        else
            tx_busy_d <= tx_busy;
    end

    // ------------------------------------------------------------------------
    // KHỐI 1: FSM State Register & Transition Logic
    // ------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_LOW;
        end else begin
            state <= next_state;
        end
    end

    // Logic chuyển trạng thái Next State (Moore)
    always @(*) begin
        next_state = state;
        if (btn1_pulse) begin
            case (state)
                ST_LOW:  next_state = ST_HIGH;
                ST_HIGH: next_state = ST_AUTO;
                ST_AUTO: next_state = ST_LOW;
                default: next_state = ST_LOW;
            endcase
        end else if (btn2_pulse) begin
            case (state)
                ST_LOW:  next_state = ST_AUTO;
                ST_HIGH: next_state = ST_LOW;
                ST_AUTO: next_state = ST_HIGH;
                default: next_state = ST_LOW;
            endcase
        end
    end

    // Cập nhật Mode output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode <= ST_LOW;
        end else begin
            mode <= state;
        end
    end

    // Phát tín hiệu send_trigger khi Reset hoặc khi State thay đổi
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            send_trigger <= 1'b1; // Trigger gửi tín hiệu ban đầu khi Power-on/Reset
        end else if (state != next_state) begin
            send_trigger <= 1'b1; // Trigger gửi khi chuyển trạng thái
        end else begin
            send_trigger <= 1'b0;
        end
    end

    // ------------------------------------------------------------------------
    // KHỐI 2: ASCII ROM Lookup Table & Tx Length
    // ------------------------------------------------------------------------
    // "MODE: LOW\r\n"  (11 bytes)
    // "MODE: HIGH\r\n" (12 bytes)
    // "MODE: AUTO\r\n" (12 bytes)

    always @(*) begin
        case (state)
            ST_LOW:  tx_len = 4'd11;
            ST_HIGH: tx_len = 4'd12;
            ST_AUTO: tx_len = 4'd12;
            default: tx_len = 4'd11;
        endcase
    end

    function [7:0] get_ascii_byte(input [1:0] st, input [3:0] idx);
        begin
            case (st)
                ST_LOW: begin
                    case (idx)
                        4'd0:  get_ascii_byte = "M";
                        4'd1:  get_ascii_byte = "O";
                        4'd2:  get_ascii_byte = "D";
                        4'd3:  get_ascii_byte = "E";
                        4'd4:  get_ascii_byte = ":";
                        4'd5:  get_ascii_byte = " ";
                        4'd6:  get_ascii_byte = "L";
                        4'd7:  get_ascii_byte = "O";
                        4'd8:  get_ascii_byte = "W";
                        4'd9:  get_ascii_byte = 8'h0D; // \r
                        4'd10: get_ascii_byte = 8'h0A; // \n
                        default: get_ascii_byte = 8'h00;
                    endcase
                end

                ST_HIGH: begin
                    case (idx)
                        4'd0:  get_ascii_byte = "M";
                        4'd1:  get_ascii_byte = "O";
                        4'd2:  get_ascii_byte = "D";
                        4'd3:  get_ascii_byte = "E";
                        4'd4:  get_ascii_byte = ":";
                        4'd5:  get_ascii_byte = " ";
                        4'd6:  get_ascii_byte = "H";
                        4'd7:  get_ascii_byte = "I";
                        4'd8:  get_ascii_byte = "G";
                        4'd9:  get_ascii_byte = "H";
                        4'd10: get_ascii_byte = 8'h0D; // \r
                        4'd11: get_ascii_byte = 8'h0A; // \n
                        default: get_ascii_byte = 8'h00;
                    endcase
                end

                ST_AUTO: begin
                    case (idx)
                        4'd0:  get_ascii_byte = "M";
                        4'd1:  get_ascii_byte = "O";
                        4'd2:  get_ascii_byte = "D";
                        4'd3:  get_ascii_byte = "E";
                        4'd4:  get_ascii_byte = ":";
                        4'd5:  get_ascii_byte = " ";
                        4'd6:  get_ascii_byte = "A";
                        4'd7:  get_ascii_byte = "U";
                        4'd8:  get_ascii_byte = "T";
                        4'd9:  get_ascii_byte = "O";
                        4'd10: get_ascii_byte = 8'h0D; // \r
                        4'd11: get_ascii_byte = 8'h0A; // \n
                        default: get_ascii_byte = 8'h00;
                    endcase
                end
                default: get_ascii_byte = 8'h00;
            endcase
        end
    endfunction

    // ------------------------------------------------------------------------
    // KHỐI 3: Byte Transmission Controller Logic
    // ------------------------------------------------------------------------
    reg is_sending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_cnt   <= 4'd0;
            tx_start   <= 1'b0;
            tx_data    <= 8'h00;
            is_sending <= 1'b0;
        end else begin
            tx_start <= 1'b0; // Mặc định pulse 1 clock

            if (send_trigger) begin
                // Bắt đầu quy trình truyền chuỗi
                is_sending <= 1'b1;
                byte_cnt   <= 4'd0;
                tx_data    <= get_ascii_byte(state, 4'd0);
                tx_start   <= 1'b1;
            end else if (is_sending) begin
                if (tx_busy_negedge) begin
                    if (byte_cnt + 1'b1 < tx_len) begin
                        byte_cnt <= byte_cnt + 1'b1;
                        tx_data  <= get_ascii_byte(state, byte_cnt + 1'b1);
                        tx_start <= 1'b1;
                    end else begin
                        is_sending <= 1'b0;
                        byte_cnt   <= 4'd0;
                    end
                end
            end
        end
    end

endmodule
