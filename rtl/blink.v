// rtl/blink.v
// -----------------------------------------------------------------------------
// Hello World: Blink an LED on the iCEBreaker v1.0 board.
// Clock: 12 MHz external oscillator
// LED:   On-board USER LED (active high, pin mapping in .pcf)
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module blink (
    input  wire clk_12mhz,   // 12 MHz oscillator
    output wire led          // LED output
);

    // Counter big enough to divide 12 MHz down to ~1 Hz
    reg [23:0] counter = 24'd0;

    always @(posedge clk_12mhz) begin
        counter <= counter + 1'b1;
    end

    assign led = counter[23]; // ~0.7 Hz blink

endmodule

`default_nettype wire
