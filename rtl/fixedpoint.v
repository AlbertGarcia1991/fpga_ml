// rtl/fixedpoint.v
// -----------------------------------------------------------------------------
// Fixed-point utilities for FPGA linear regression core.
// Defaults to Q16.16 on 32-bit signed values.
//
// Provides:
//   - fp_add: saturating fixed-point addition
//   - fp_mul: saturating fixed-point multiplication with rounding
//
// Notes:
//   * Addition does not change the Q format.
//   * Multiplication: (Qm.n * Qm.n) -> Qm.n via arithmetic shift-right by FRACTION
//     with rounding-to-nearest and saturation.
//   * All operations expose a 'sat' flag when saturation occurred.
//
// This file uses standard Verilog for iVerilog compatibility.
// -----------------------------------------------------------------------------

`ifndef FIXEDPOINT_V
`define FIXEDPOINT_V

// -----------------------------------------------------------------------------
// fp_add: Saturating fixed-point addition (format preserved)
// y = a + b with saturation to signed WIDTH range.
// -----------------------------------------------------------------------------
module fp_add #(
  parameter WIDTH = 32
) (
  input  signed [WIDTH-1:0] a,
  input  signed [WIDTH-1:0] b,
  output signed [WIDTH-1:0] y,
  output                    sat
);
  // Local parameters for max/min values
  localparam signed [WIDTH-1:0] FP_MAX = {1'b0, {(WIDTH-1){1'b1}}};  // 0x7FFFFFFF for WIDTH=32
  localparam signed [WIDTH-1:0] FP_MIN = {1'b1, {(WIDTH-1){1'b0}}};  // 0x80000000 for WIDTH=32

  // One extra bit for detecting overflow in two's complement addition
  reg signed [WIDTH:0] sum_ext;
  reg sat_reg;
  reg signed [WIDTH-1:0] y_reg;

  always @(*) begin
    sum_ext = {a[WIDTH-1], a} + {b[WIDTH-1], b};
    
    // Saturation logic
    if (sum_ext > FP_MAX) begin
      sat_reg = 1'b1;
      y_reg = FP_MAX;
    end else if (sum_ext < FP_MIN) begin
      sat_reg = 1'b1;
      y_reg = FP_MIN;
    end else begin
      sat_reg = 1'b0;
      y_reg = sum_ext[WIDTH-1:0];
    end
  end

  assign y = y_reg;
  assign sat = sat_reg;
endmodule


// -----------------------------------------------------------------------------
// fp_mul: Saturating fixed-point multiply with rounding-to-nearest
// For Qm.n: (a*b) >> FRACTION, with + 0.5 ulp for rounding.
// -----------------------------------------------------------------------------
module fp_mul #(
  parameter WIDTH = 32,
  parameter FRACTION = 16
) (
  input  signed [WIDTH-1:0] a,
  input  signed [WIDTH-1:0] b,
  output signed [WIDTH-1:0] y,
  output                    sat
);
  // Local parameters for max/min values
  localparam signed [WIDTH-1:0] FP_MAX = {1'b0, {(WIDTH-1){1'b1}}};  // 0x7FFFFFFF for WIDTH=32
  localparam signed [WIDTH-1:0] FP_MIN = {1'b1, {(WIDTH-1){1'b0}}};  // 0x80000000 for WIDTH=32
  
  // Rounding constant (0.5 in fixed-point at FRACTION position)
  localparam signed [2*WIDTH-1:0] ROUND_CONST = 1 << (FRACTION-1);

  // Full precision product (e.g., 64-bit for 32x32)
  reg signed [2*WIDTH-1:0] prod_full;
  reg signed [2*WIDTH-1:0] prod_round;
  reg signed [2*WIDTH-1:0] shifted;
  reg signed [WIDTH-1:0] y_reg;
  reg sat_reg;

  always @(*) begin
    prod_full = a * b;

    // Rounding: add 0.5 ulp at the FRACTION bit position
    // For negative numbers, we need to add bias for proper rounding
    if (prod_full >= 0) begin
      prod_round = prod_full + ROUND_CONST;
    end else begin
      prod_round = prod_full + ROUND_CONST;
    end

    // Arithmetic shift right to restore Q format
    shifted = prod_round >>> FRACTION;

    // Saturation to WIDTH bits
    if (shifted > FP_MAX) begin
      sat_reg = 1'b1;
      y_reg = FP_MAX;
    end else if (shifted < FP_MIN) begin
      sat_reg = 1'b1;
      y_reg = FP_MIN;
    end else begin
      sat_reg = 1'b0;
      y_reg = shifted[WIDTH-1:0];
    end
  end

  assign y = y_reg;
  assign sat = sat_reg;
endmodule

`endif // FIXEDPOINT_V
