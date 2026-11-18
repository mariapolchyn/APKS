// 1. Генератор відліків баудової швидкості
module baud_rate_gen #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 9600
)(
    input wire clk,
    input wire reset,
    output reg tick
);
    localparam integer DVSR = CLK_FREQ / (BAUD_RATE * 16);
    reg [15:0] count_reg;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count_reg <= 0;
            tick <= 1'b0;
        end else begin
            if (count_reg == (DVSR - 1)) begin
                count_reg <= 0;
                tick <= 1'b1;
            end else begin
                count_reg <= count_reg + 1'b1;
                tick <= 1'b0;
            end
        end
    end
endmodule

// 2. Передавач (UART Transmitter)
module uart_tx (
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire s_tick,
    input wire [7:0] tx_data,
    output reg tx_done,
    output reg tx
);
    reg [1:0] state, next_state;
    reg [3:0] s_count, s_count_next;
    reg [2:0] n_count, n_count_next;
    reg [7:0] b_reg, b_reg_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= 2'b00;
            s_count <= 0;
            n_count <= 0;
            b_reg   <= 0;
            tx      <= 1'b1;
        end else begin
            state   <= next_state;
            s_count <= s_count_next;
            n_count <= n_count_next;
            b_reg   <= b_reg_next;
            tx      <= (state == 2'b00) ? 1'b1 :
                       (state == 2'b01) ? 1'b0 :
                       (state == 2'b10) ? b_reg[0] : 1'b1;
        end
    end

    always @(*) begin
        next_state   = state;
        s_count_next = s_count;
        n_count_next = n_count;
        b_reg_next   = b_reg;
        tx_done      = 1'b0;

        case (state)
            2'b00: begin // IDLE
                if (tx_start) begin
                    next_state   = 2'b01;
                    s_count_next = 0;
                    b_reg_next   = tx_data;
                end
            end
            2'b01: begin // START
                if (s_tick) begin
                    if (s_count == 15) begin
                        next_state   = 2'b10;
                        s_count_next = 0;
                        n_count_next = 0;
                    end else s_count_next = s_count + 1'b1;
                end
            end
            2'b10: begin // DATA
                if (s_tick) begin
                    if (s_count == 15) begin
                        s_count_next = 0;
                        b_reg_next   = b_reg >> 1;
                        if (n_count == 7) next_state = 2'b11;
                        else n_count_next = n_count + 1'b1;
                    end else s_count_next = s_count + 1'b1;
                end
            end
            2'b11: begin // STOP
                if (s_tick) begin
                    if (s_count == 15) begin
                        next_state = 2'b00;
                        tx_done    = 1'b1;
                    end else s_count_next = s_count + 1'b1;
                end
            end
        endcase
    end
endmodule

// 3. Приймач (UART Receiver)
module uart_rx (
    input wire clk,
    input wire reset,
    input wire rx,
    input wire s_tick,
    output reg rx_done,
    output reg [7:0] rx_data
);
    reg [1:0] state, next_state;
    reg [3:0] s_count, s_count_next;
    reg [2:0] n_count, n_count_next;
    reg [7:0] b_reg, b_reg_next;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state   <= 2'b00;
            s_count <= 0;
            n_count <= 0;
            b_reg   <= 0;
            rx_data <= 0;
        end else begin
            state   <= next_state;
            s_count <= s_count_next;
            n_count <= n_count_next;
            b_reg   <= b_reg_next;
            if (rx_done) rx_data <= b_reg_next;
        end
    end

    always @(*) begin
        next_state   = state;
        s_count_next = s_count;
        n_count_next = n_count;
        b_reg_next   = b_reg;
        rx_done      = 1'b0;

        case (state)
            2'b00: begin // IDLE
                if (~rx) begin
                    next_state   = 2'b01;
                    s_count_next = 0;
                end
            end
            2'b01: begin // START
                if (s_tick) begin
                    if (s_count == 7) begin
                        next_state   = 2'b10;
                        s_count_next = 0;
                        n_count_next = 0;
                    end else s_count_next = s_count + 1'b1;
                end
            end
            2'b10: begin // DATA
                if (s_tick) begin
                    if (s_count == 15) begin
                        s_count_next = 0;
                        b_reg_next   = {rx, b_reg[7:1]};
                        if (n_count == 7) next_state = 2'b11;
                        else n_count_next = n_count + 1'b1;
                    end else s_count_next = s_count + 1'b1;
                end
            end
            2'b11: begin // STOP
                if (s_tick) begin
                    if (s_count == 15) begin
                        next_state = 2'b00;
                        rx_done    = 1'b1;
                    end else s_count_next = s_count + 1'b1;
                end
            end
        endcase
    end
endmodule

// 4. Топ-модуль (UART Top)
module uart_top #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire reset,
    input wire tx_start,
    input wire [7:0] tx_data,
    input wire rx,
    output wire tx,
    output wire rx_done,
    output wire tx_done,
    output wire [7:0] rx_data
);
    wire tick;

    baud_rate_gen #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) baud_gen (
        .clk(clk), .reset(reset), .tick(tick)
    );
    uart_tx transmitter (
        .clk(clk), .reset(reset), .tx_start(tx_start), .s_tick(tick),
        .tx_data(tx_data), .tx_done(tx_done), .tx(tx)
    );
    uart_rx receiver (
        .clk(clk), .reset(reset), .rx(rx), .s_tick(tick),
        .rx_done(rx_done), .rx_data(rx_data)
    );
endmodule