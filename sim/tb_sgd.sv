// sim/tb_sgd.v
// -----------------------------------------------------------------------------
// Convergence test for sgd_update.v using Q16.16, N_FEATURES=1.
// Target: y = 2*x + 1  (no noise) — expect w -> 2, b -> 1.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

`include "fixedpoint.v"

module tb_sgd;

  // Parameters
  localparam integer WIDTH      = 32;
  localparam integer FRACTION   = 16;
  localparam integer N_FEATURES = 1;

  // DUT I/O (flattened for x/w)
  reg  signed [N_FEATURES*WIDTH-1:0] x_flat;
  reg  signed [N_FEATURES*WIDTH-1:0] w_in_flat;
  reg  signed [WIDTH-1:0]            b_in;
  reg  signed [WIDTH-1:0]            y_true;
  reg  signed [WIDTH-1:0]            y_hat;
  reg  signed [WIDTH-1:0]            eta;
  reg  signed [WIDTH-1:0]            lambda;

  wire signed [N_FEATURES*WIDTH-1:0] w_out_flat;
  wire signed [WIDTH-1:0]            b_out;
  wire                               sat_o;

  // Instantiate DUT
  sgd_update #(
    .N_FEATURES(N_FEATURES),
    .WIDTH(WIDTH),
    .FRACTION(FRACTION)
  ) dut (
    .x_flat    (x_flat),
    .w_in_flat (w_in_flat),
    .b_in      (b_in),
    .y_true    (y_true),
    .y_hat     (y_hat),
    .eta       (eta),
    .lambda    (lambda),
    .w_out_flat(w_out_flat),
    .b_out     (b_out),
    .sat_o     (sat_o)
  );

  // Helpers: Q16.16 conversions
  function [WIDTH-1:0] q_from_real;
    input real r;
    integer tmp;
    begin
      tmp = $rtoi(r * (1<<FRACTION));
      q_from_real = tmp[WIDTH-1:0];
    end
  endfunction

  function real real_from_q;
    input [WIDTH-1:0] q;
    begin
      real_from_q = $itor($signed(q)) / (1<<FRACTION);
    end
  endfunction

  // Accessors for N=1 (lowest WIDTH slice)
  function [WIDTH-1:0] get_x0(input [N_FEATURES*WIDTH-1:0] bus);
    get_x0 = bus[WIDTH-1:0];
  endfunction
  function [WIDTH-1:0] get_w0(input [N_FEATURES*WIDTH-1:0] bus);
    get_w0 = bus[WIDTH-1:0];
  endfunction
  function [N_FEATURES*WIDTH-1:0] put_w0(input [WIDTH-1:0] w0);
    reg [N_FEATURES*WIDTH-1:0] tmp;
    begin
      tmp = {N_FEATURES*WIDTH{1'b0}};
      tmp[WIDTH-1:0] = w0;
      put_w0 = tmp;
    end
  endfunction

  integer i;
  real xr, yr, w_est, b_est;

  initial begin
    // Initial weights and params
    w_in_flat = put_w0(q_from_real(0.0));
    b_in      = q_from_real(0.0);
    eta       = q_from_real(0.02);     // learning rate
    lambda    = q_from_real(0.0);      // no decay for this test

    // Iterate training
    for (i = 0; i < 800; i = i + 1) begin
      // Sample x in [-2.0, 2.0], deterministic sequence for reproducibility
      xr = -2.0 + (4.0 * (i % 50)) / 49.0;
      yr = 2.0 * xr + 1.0;

      // Pack feature and targets
      x_flat = { {(N_FEATURES*WIDTH - WIDTH){1'b0}}, q_from_real(xr) };
      y_true = q_from_real(yr);

      // Prediction with current weights: y_hat = w*x + b
      // Reuse fixed-point primitives for prediction (inline compute)
      // Compute mul = w*x
      // NOTE: since tb is simple, do the prediction in real then quantize.
      //       This avoids re-instantiating MAC here.
      y_hat = q_from_real( (real_from_q(get_w0(w_in_flat)) * xr) + real_from_q(b_in) );

      // Compute new weights/bias via DUT (combinational), then register them
      #1; // small delta to emulate propagation
      w_in_flat = w_out_flat;
      b_in      = b_out;

      if ((i % 100) == 0) begin
        w_est = real_from_q(get_w0(w_in_flat));
        b_est = real_from_q(b_in);
        $display("[iter=%0d] w=%.4f  b=%.4f  sat=%0d", i, w_est, b_est, sat_o);
      end
    end

    // Final report
    w_est = real_from_q(get_w0(w_in_flat));
    b_est = real_from_q(b_in);
    $display("FINAL: w=%.4f  b=%.4f", w_est, b_est);

    if ($abs(w_est - 2.0) > 0.05 || $abs(b_est - 1.0) > 0.05) begin
      $display("[FAIL] Did not converge close enough to w=2.0, b=1.0");
      $fatal;
    end else begin
      $display("[PASS] Converged to target within tolerance");
    end

    $finish;
  end

endmodule

`default_nettype wire
