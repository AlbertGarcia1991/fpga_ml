// rtl/sgd_update.v
// -----------------------------------------------------------------------------
// SGD/LMS update engine (combinational) for fixed-point linear regression.
//
// Update rule (per sample):
//   e      = y - yhat
//   grad_i = eta * e * x_i
//   w_i'   = w_i + grad_i                         (if lambda == 0)
//   or
//   w_i'   = (1 - lambda) * w_i + grad_i          (if lambda != 0)
//   b'     = b + eta * e
//
// Notes:
// - Fixed-point format: Qm.n via WIDTH and FRACTION parameters (default Q16.16).
// - Uses fp_add and fp_mul from fixedpoint.v (must be on include path).
// - No state; outputs are next values given current inputs.
// - x and w are provided/returned as flattened buses to avoid array ports.
//
// Interface:
//  * x_flat     : [N_FEATURES*WIDTH-1:0]  concatenation of x_i (x_0 is lowest bits)
//  * w_in_flat  : ditto for input weights
//  * w_out_flat : ditto for output weights
//
// Synthesis: purely combinational; register at the call site if needed.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

`include "fixedpoint.v"

module sgd_update #(
  parameter N_FEATURES = 8,
  parameter WIDTH      = 32,
  parameter FRACTION   = 16
) (
  // Inputs
  input  wire signed [N_FEATURES*WIDTH-1:0] x_flat,     // concatenated features
  input  wire signed [N_FEATURES*WIDTH-1:0] w_in_flat,  // concatenated current weights
  input  wire signed [WIDTH-1:0]            b_in,
  input  wire signed [WIDTH-1:0]            y_true,
  input  wire signed [WIDTH-1:0]            y_hat,
  input  wire signed [WIDTH-1:0]            eta,        // learning rate
  input  wire signed [WIDTH-1:0]            lambda,     // L2 decay (0 to disable)

  // Outputs
  output wire signed [N_FEATURES*WIDTH-1:0] w_out_flat, // concatenated new weights
  output wire signed [WIDTH-1:0]            b_out,
  output wire                               sat_o       // saturation occurred anywhere
);
  // --------------------------
  // Local arrays for unpacked views
  // --------------------------
  wire signed [WIDTH-1:0] x      [0:N_FEATURES-1];
  wire signed [WIDTH-1:0] w_in   [0:N_FEATURES-1];
  wire signed [WIDTH-1:0] w_out  [0:N_FEATURES-1];

  genvar gi_unpk;
  generate
    for (gi_unpk = 0; gi_unpk < N_FEATURES; gi_unpk = gi_unpk + 1) begin : UNPACK
      localparam integer S = gi_unpk*WIDTH;
      assign x[gi_unpk]    = x_flat   [S + WIDTH - 1 : S];
      assign w_in[gi_unpk] = w_in_flat[S + WIDTH - 1 : S];
    end
  endgenerate

  // --------------------------
  // Error e = y_true - y_hat (saturating)
  // --------------------------
  wire signed [WIDTH-1:0] y_hat_neg = -y_hat;
  wire signed [WIDTH-1:0] e;
  wire sat_add_e;

  fp_add #(.WIDTH(WIDTH)) u_add_err (
    .a  (y_true),
    .b  (y_hat_neg),
    .y  (e),
    .sat(sat_add_e)
  );

  // --------------------------
  // Common term: g = eta * e
  // --------------------------
  wire signed [WIDTH-1:0] g;
  wire sat_mul_g;

  fp_mul #(.WIDTH(WIDTH), .FRACTION(FRACTION)) u_mul_g (
    .a  (eta),
    .b  (e),
    .y  (g),
    .sat(sat_mul_g)
  );

  // --------------------------
  // Bias update: b_out = b_in + g
  // --------------------------
  wire sat_add_b;
  fp_add #(.WIDTH(WIDTH)) u_add_b (
    .a  (b_in),
    .b  (g),
    .y  (b_out),
    .sat(sat_add_b)
  );

  // --------------------------
  // Weights update for each feature
  // grad_i = g * x_i
  // if (lambda == 0)        : w'_i = w_i + grad_i
  // else (use weight decay) : w'_i = (1 - lambda) * w_i + grad_i
  // --------------------------
  wire use_decay;
  assign use_decay = (lambda != {WIDTH{1'b0}});

  // (1 - lambda)
  wire signed [WIDTH-1:0] one_q;
  assign one_q = ({{(WIDTH-1){1'b0}}, 1'b1} << FRACTION); // 1.0 in Q
  wire signed [WIDTH-1:0] one_minus_lambda;
  wire sat_add_oml;
  fp_add #(.WIDTH(WIDTH)) u_one_minus_lambda (
    .a  (one_q),
    .b  (-lambda),
    .y  (one_minus_lambda),
    .sat(sat_add_oml)
  );

  // Per-feature update datapath
  wire sat_any_weights;

  reg sat_accum;  // OR-reduction of all sat flags
  integer k;

  // Per-feature wires
  wire signed [WIDTH-1:0] grad   [0:N_FEATURES-1];
  wire                    sat_gr  [0:N_FEATURES-1];

  wire signed [WIDTH-1:0] decayed[0:N_FEATURES-1];
  wire                    sat_dec [0:N_FEATURES-1];

  wire signed [WIDTH-1:0] sum_w  [0:N_FEATURES-1];
  wire                    sat_sum [0:N_FEATURES-1];

  genvar gi;
  generate
    for (gi = 0; gi < N_FEATURES; gi = gi + 1) begin : PER_FEAT
      // grad_i = g * x_i
      fp_mul #(.WIDTH(WIDTH), .FRACTION(FRACTION)) u_mul_grad (
        .a  (g),
        .b  (x[gi]),
        .y  (grad[gi]),
        .sat(sat_gr[gi])
      );

      // decayed = (1 - lambda) * w_in  (only used if use_decay)
      fp_mul #(.WIDTH(WIDTH), .FRACTION(FRACTION)) u_mul_decay (
        .a  (one_minus_lambda),
        .b  (w_in[gi]),
        .y  (decayed[gi]),
        .sat(sat_dec[gi])
      );

      // sum_w = (use_decay ? decayed : w_in) + grad
      wire signed [WIDTH-1:0] base_w = use_decay ? decayed[gi] : w_in[gi];

      fp_add #(.WIDTH(WIDTH)) u_add_w (
        .a  (base_w),
        .b  (grad[gi]),
        .y  (sum_w[gi]),
        .sat(sat_sum[gi])
      );

      // Final output assign
      assign w_out[gi] = sum_w[gi];
    end
  endgenerate

  // OR-reduce all saturation flags
  always @* begin
    sat_accum = sat_add_e | sat_mul_g | sat_add_b | sat_add_oml;
    for (k = 0; k < N_FEATURES; k = k + 1) begin
      sat_accum = sat_accum | sat_gr[k] | sat_dec[k] | sat_sum[k];
    end
  end

  assign sat_any_weights = sat_accum;
  assign sat_o = sat_any_weights;

  // Repack output weights
  genvar gi_pk;
  generate
    for (gi_pk = 0; gi_pk < N_FEATURES; gi_pk = gi_pk + 1) begin : PACK
      localparam integer S2 = gi_pk*WIDTH;
      assign w_out_flat[S2 + WIDTH - 1 : S2] = w_out[gi_pk];
    end
  endgenerate

endmodule

`default_nettype wire
