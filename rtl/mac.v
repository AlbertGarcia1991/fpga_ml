// rtl/mac.v
// filepath: /home/agplaza/Desktop/fpga_ml/rtl/mac.v
// -----------------------------------------------------------------------------
// Parameterized fixed-point MAC (Multiply-Accumulate) with bias and 1-cycle
// registered output.
//
// - Q-format defaults to Q16.16 (WIDTH=32, FRACTION=16).
// - Uses fp_mul for each term (x[i] * w[i]) and fp_add to accumulate + bias.
// - Combinational datapath followed by a single output register stage.
// - 'valid_o' is 'valid_i' delayed by 1 cycle.
// - 'sat_o' flags if any mul/add in the chain saturated in the *current* cycle.
//
// Notes:
// * No backpressure (no 'ready'); feed a new sample whenever 'valid_i' is high.
// * If you need backpressure later, add an internal FIFO or ready/valid gating.
// -----------------------------------------------------------------------------

`ifndef MAC_V
`define MAC_V

`timescale 1ns/1ps
`default_nettype none

module mac #(
  parameter N_FEATURES = 8,
  parameter WIDTH      = 32,
  parameter FRACTION   = 16
) (
  input  wire                        clk,
  input  wire                        rst_n,

  // Input operands - flattened arrays for Verilog compatibility
  input  wire                        valid_i,
  input  wire signed [WIDTH*N_FEATURES-1:0] x_flat,   // x[0], x[1], ..., x[N-1]
  input  wire signed [WIDTH*N_FEATURES-1:0] w_flat,   // w[0], w[1], ..., w[N-1]
  input  wire signed [WIDTH-1:0]            b,

  // Outputs (registered, 1-cycle latency)
  output wire                        valid_o,
  output wire signed [WIDTH-1:0]     yhat,
  output wire                        sat_o   // saturation occurred this sample
);

  // Extract individual x and w values from flattened inputs
  wire signed [WIDTH-1:0] x [0:N_FEATURES-1];
  wire signed [WIDTH-1:0] w [0:N_FEATURES-1];
  
  genvar gi;
  generate
    for (gi = 0; gi < N_FEATURES; gi = gi + 1) begin : G_EXTRACT
      assign x[gi] = x_flat[(gi+1)*WIDTH-1:gi*WIDTH];
      assign w[gi] = w_flat[(gi+1)*WIDTH-1:gi*WIDTH];
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 1) Multiply each pair x[i] * w[i]
  // ---------------------------------------------------------------------------
  wire signed [WIDTH-1:0] prod   [0:N_FEATURES-1];
  wire                    sat_mul[0:N_FEATURES-1];

  generate
    for (gi = 0; gi < N_FEATURES; gi = gi + 1) begin : G_MUL
      fp_mul #(.WIDTH(WIDTH), .FRACTION(FRACTION)) u_mul (
        .a  (x[gi]),
        .b  (w[gi]),
        .y  (prod[gi]),
        .sat(sat_mul[gi])
      );
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 2) Accumulate all prod[i] terms using a chain of fp_add modules.
  //     sum = prod[0] + prod[1] + ... + prod[N-1] + bias
  // ---------------------------------------------------------------------------
  // Accumulation wires
  wire signed [WIDTH-1:0] sum_chain [0:N_FEATURES-1];  // partial sums
  wire                    sat_add_chain[0:N_FEATURES-1];

  // Base of chain: sum_chain[0] = prod[0]
  // (No adder here; we propagate zero saturation)
  assign sum_chain[0]     = prod[0];
  assign sat_add_chain[0] = 1'b0;

  generate
    for (gi = 1; gi < N_FEATURES; gi = gi + 1) begin : G_ADD
      fp_add #(.WIDTH(WIDTH)) u_add (
        .a  (sum_chain[gi-1]),
        .b  (prod[gi]),
        .y  (sum_chain[gi]),
        .sat(sat_add_chain[gi])
      );
    end
  endgenerate

  // Add bias
  wire signed [WIDTH-1:0] sum_plus_bias;
  wire                    sat_add_bias;

  fp_add #(.WIDTH(WIDTH)) u_add_bias (
    .a  (sum_chain[N_FEATURES-1]),
    .b  (b),
    .y  (sum_plus_bias),
    .sat(sat_add_bias)
  );

  // Overall saturation for this sample
  reg sat_any_comb;
  integer i;
  always @(*) begin
    sat_any_comb = sat_add_bias;
    for (i = 0; i < N_FEATURES; i = i + 1) begin
      sat_any_comb = sat_any_comb | sat_mul[i];
    end
    for (i = 1; i < N_FEATURES; i = i + 1) begin
      sat_any_comb = sat_any_comb | sat_add_chain[i];
    end
  end

  // ---------------------------------------------------------------------------
  // 3) Output register stage (1-cycle latency)
  // ---------------------------------------------------------------------------
  reg                        valid_q;
  reg signed [WIDTH-1:0]     yhat_q;
  reg                        sat_q;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_q <= 1'b0;
      yhat_q  <= {WIDTH{1'b0}};
      sat_q   <= 1'b0;
    end else begin
      valid_q <= valid_i;
      yhat_q  <= sum_plus_bias;
      sat_q   <= sat_any_comb;
    end
  end

  assign valid_o = valid_q;
  assign yhat    = yhat_q;
  assign sat_o   = sat_q;

endmodule

`default_nettype wire
`endif // MAC_V