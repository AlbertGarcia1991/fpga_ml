// sim/tb_mac.sv
// filepath: /home/agplaza/Desktop/fpga_ml/sim/tb_mac.sv
// -----------------------------------------------------------------------------
// Testbench for rtl/mac.v — fixed-point MAC with bias and 1-cycle latency.
//
// Verifies:
//  - Correct multiply-accumulate with bias in Q16.16
//  - valid_i → valid_o is delayed by exactly 1 cycle
//  - Saturation flag assertion in overflow scenarios
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module tb_mac;

  parameter WIDTH      = 32;
  parameter FRACTION   = 16;
  parameter N_FEATURES = 3;

  // DUT signals
  reg                        clk;
  reg                        rst_n;
  reg                        valid_i;
  reg signed [WIDTH*N_FEATURES-1:0] x_flat;
  reg signed [WIDTH*N_FEATURES-1:0] w_flat;
  reg signed [WIDTH-1:0]     b;
  wire                       valid_o;
  wire signed [WIDTH-1:0]    yhat;
  wire                       sat_o;

  // Clock gen
  initial clk = 0;
  always #5 clk = ~clk; // 100 MHz sim clock (period 10ns) — arbitrary

  // Instantiate DUT
  mac #(.N_FEATURES(N_FEATURES), .WIDTH(WIDTH), .FRACTION(FRACTION)) dut (
    .clk(clk),
    .rst_n(rst_n),
    .valid_i(valid_i),
    .x_flat(x_flat),
    .w_flat(w_flat),
    .b(b),
    .valid_o(valid_o),
    .yhat(yhat),
    .sat_o(sat_o)
  );

  // Helpers: Q16.16 converters
  function signed [WIDTH-1:0] q_from_real;
    input real r;
    integer tmp;
    begin
      tmp = r * (1<<FRACTION);
      q_from_real = tmp[WIDTH-1:0];
    end
  endfunction

  function real real_from_q;
    input signed [WIDTH-1:0] q;
    begin
      real_from_q = $itor(q) / (1<<FRACTION);
    end
  endfunction

  function real abs_real;
    input real x;
    begin
      abs_real = (x < 0.0) ? -x : x;
    end
  endfunction

  task set_vec3;
    input real x0, x1, x2;
    input real w0, w1, w2;
    input real bias;
    begin
      x_flat = {q_from_real(x2), q_from_real(x1), q_from_real(x0)};
      w_flat = {q_from_real(w2), q_from_real(w1), q_from_real(w0)};
      b      = q_from_real(bias);
    end
  endtask

  task send_sample_and_check;
    input [8*20:1] name;
    input real x0, x1, x2;
    input real w0, w1, w2;
    input real bias;
    input real expected;
    input real tol;
    real got;
    begin
      // Set up the inputs
      set_vec3(x0, x1, x2, w0, w1, w2, bias);
      
      // Assert valid for one cycle
      valid_i = 1'b1;
      @(posedge clk);
      
      // Check that output appears in the next cycle
      @(posedge clk);
      if (!valid_o) begin
        $display("[FAIL] %s: valid_o was not asserted on expected cycle", name);
        $finish;
      end
      
      got = real_from_q(yhat);
      if (abs_real(got - expected) > tol) begin
        $display("[FAIL] %s: expected=%f got=%f (tol=%f)", name, expected, got, tol);
        $finish;
      end else begin
        $display("[PASS] %s: yhat=%f within tol=%f (sat=%0d)", name, got, tol, sat_o);
      end
      
      // Clear valid
      valid_i = 1'b0;
    end
  endtask

  // Reset and tests
  initial begin
    $display("== tb_mac: Starting tests ==");
    rst_n   = 1'b0;
    valid_i = 1'b0;
    x_flat  = {3*WIDTH{1'b0}};
    w_flat  = {3*WIDTH{1'b0}};
    b       = {WIDTH{1'b0}};

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    // Case 1: Simple positive values
    // y = 1.0*2.0 + 0.5*4.0 + (-1.0)*(-3.0) + 0.25 = 2 + 2 + 3 + 0.25 = 7.25
    send_sample_and_check("simple.pos", 1.0, 0.5, -1.0, 2.0, 4.0, -3.0, 0.25, 7.25, 1e-3);

    // Case 2: Negatives and bias
    // y = (-2.0)*0.5 + (3.0)*(-1.0) + (0.25)*(8.0) + (-0.5)
    //   = -1.0 -3.0 + 2.0 - 0.5 = -2.5
    send_sample_and_check("neg.mix", -2.0, 3.0, 0.25, 0.5, -1.0, 8.0, -0.5, -2.5, 1e-3);

    // Case 3: Saturation test (large numbers)
    // Force overflow by using near-maximum values
    set_vec3(32767.0, 1000.0, 1000.0, 1000.0, 1000.0, 1000.0, 1000.0);
    valid_i = 1'b1;
    @(posedge clk);
    @(posedge clk);
    if (!valid_o) begin
      $display("[FAIL] sat: valid_o missing");
      $finish;
    end
    if (!sat_o) begin
      $display("[FAIL] sat: expected saturation flag to assert");
      $finish;
    end else begin
      $display("[PASS] saturation flag asserted");
    end
    valid_i = 1'b0;

    $display("== tb_mac: ALL TESTS PASSED ==");
    $finish;
  end

endmodule

`default_nettype wire
