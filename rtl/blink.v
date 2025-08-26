// rtl/blink.v
// -----------------------------------------------------------------------------
// Hello World: Blink an LED on the iCEBreaker v1.0 board.
// Clock: 12 MHz external oscillator
// LED:   On-board USER LED (active high, pin mapping in .pcf)
// -----------------------------------------------------------------------------

// COMPILER DIRECTIVES START WITH `

`timescale 1ns/1ps
`default_nettype none

module blink (
    input  wire clk_12mhz,   // 12 MHz oscillator
    output wire green_led,
    output wire red_led
);
    // REG STORE VAUES FROM ONE ASSIGNMENT TO THE NEXT (DO NOT CONFURE WITH REGISTER)
    // WIRE IS A PHYSICAL CONNECTOR BETWEEN INSTANCES, THEY DO NOT STORE VALUES.

    // Counter big enough to divide 12 MHz down to ~1 Hz
    // REG FORMAT: [left_range:right_range], hence:
    //  - reg [0:7] -> 8-bit reg with MSB as the 0th bit
    //  - reg [7:0] -> 8-bit reg with MSB as the 8th bit
    reg [23:0] counter1 = 24'd0;  // VARIABLE FORMAT: [size_bits]'[base][value]
    reg [23:0] counter2 = 24'd0;

    always @(posedge clk_12mhz) begin
        counter1 <= counter1 + 1'b1;
        counter2 <= counter2 + 2'd2;
    end


    assign green_led = counter1[23]; // ~0.7 Hz blink
    assign red_led = counter2[23]; // ~1.4 Hz blink

endmodule

`default_nettype wire
