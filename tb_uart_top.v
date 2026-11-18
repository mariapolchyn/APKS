`timescale 1ns / 1ps

module tb_uart_top;
    reg clk;
    reg reset;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx;
    wire rx_done;
    wire tx_done;
    wire [7:0] rx_data;

    uart_top #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(115200)
    ) uut (
        .clk(clk),
        .reset(reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .rx(tx), // Loopback: tx з'єднано з rx
        .tx(tx),
        .rx_done(rx_done),
        .tx_done(tx_done),
        .rx_data(rx_data)
    );

    always #10 clk = ~clk;

    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, tb_uart_top);

        clk = 0;
        reset = 1;
        tx_start = 0;
        tx_data = 8'h00;

        #100;
        reset = 0;
        #100;

        // Тестовий байт 0xA5
        tx_data = 8'hA5;
        tx_start = 1;
        #20;
        tx_start = 0;

        wait(rx_done);
        #500;

        // Тестовий байт 0x3C
        tx_data = 8'h3C;
        tx_start = 1;
        #20;
        tx_start = 0;

        wait(rx_done);
        #500;

        $finish;
    end
endmodule