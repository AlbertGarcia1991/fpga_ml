// sim/tb_fixedpoint.sv
// filepath: /home/agplaza/Desktop/fpga_ml/sim/tb_fixedpoint.sv
// -----------------------------------------------------------------------------
// Unit tests for fixed-point primitives (Q16.16 by default).
// Uses simple tasks to check results and saturation flags.
// Run with: make sim (once Makefile is wired; currently a no-op until sim/*.sv exists)
// -----------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module tb_fixedpoint;

  parameter WIDTH    = 32;
  parameter FRACTION = 16;

  // Fixed-point constants (Q16.16)
  parameter signed [WIDTH-1:0] FP_MAX = 32'h7FFFFFFF;  // Maximum positive value
  parameter signed [WIDTH-1:0] FP_MIN = 32'h80000000;  // Maximum negative value

  // DUT wires
  wire signed [WIDTH-1:0] a, b, y_add, y_mul;
  wire sat_add, sat_mul;
  
  // Internal registers for driving inputs
  reg signed [WIDTH-1:0] a_reg, b_reg;
  assign a = a_reg;
  assign b = b_reg;

  // Instantiate add/mul
  fp_add #(.WIDTH(WIDTH)) u_add (
    .a(a), .b(b), .y(y_add), .sat(sat_add)
  );

  fp_mul #(.WIDTH(WIDTH), .FRACTION(FRACTION)) u_mul (
    .a(a), .b(b), .y(y_mul), .sat(sat_mul)
  );

  // Helpers: convert real to Q16.16 and back (for readability)
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

  // Manual absolute value function
  function real abs_real;
    input real x;
    begin
      abs_real = (x < 0.0) ? -x : x;
    end
  endfunction

  task check_add;
    input [8*20:1] name;  // String parameter
    input real ra, rb, rexp;
    input exp_sat;
    real y;
    begin
      a_reg = q_from_real(ra);
      b_reg = q_from_real(rb);
      #1;
      y = real_from_q(y_add);
      if ((exp_sat != sat_add) || (abs_real(y - rexp) > 1e-4 && !exp_sat)) begin
        $display("[ADD][FAIL] %s: a=%f b=%f -> got y=%f sat=%0d, exp y=%f sat=%0d",
                  name, ra, rb, y, sat_add, rexp, exp_sat);
        $finish;
      end else begin
        $display("[ADD][PASS] %s: y=%f sat=%0d", name, y, sat_add);
      end
    end
  endtask

  task check_mul;
    input [8*20:1] name;  // String parameter
    input real ra, rb, rexp;
    input exp_sat;
    input real tol;
    real y;
    begin
      a_reg = q_from_real(ra);
      b_reg = q_from_real(rb);
      #1;
      y = real_from_q(y_mul);
      if ((exp_sat != sat_mul) || ((abs_real(y - rexp) > tol) && !exp_sat)) begin
        $display("[MUL][FAIL] %s: a=%f b=%f -> got y=%f sat=%0d, exp y=%f sat=%0d",
                  name, ra, rb, y, sat_mul, rexp, exp_sat);
        $finish;
      end else begin
        $display("[MUL][PASS] %s: y=%f sat=%0d", name, y, sat_mul);
      end
    end
  endtask

  initial begin
    $display("== tb_fixedpoint (Q%0d.%0d) ==", WIDTH-FRACTION, FRACTION);

    // --- Addition tests ---
    check_add("add.simple",  1.25,  2.50,  3.75, 0);
    check_add("add.neg",    -1.00,  0.25, -0.75, 0);

    // Force positive overflow: max + 1.0 -> saturate
    a_reg = FP_MAX;
    b_reg = q_from_real(1.0);
    #1;
    if (!sat_add || (y_add != FP_MAX)) begin
      $display("[ADD][FAIL] overflow+ not saturated");
      $finish;
    end else $display("[ADD][PASS] overflow positive");

    // Force negative overflow: min - 1.0 -> saturate
    a_reg = FP_MIN;
    b_reg = q_from_real(-1.0);
    #1;
    if (!sat_add || (y_add != FP_MIN)) begin
      $display("[ADD][FAIL] overflow- not saturated");
      $finish;
    end else $display("[ADD][PASS] overflow negative");

    // --- Multiplication tests ---
    check_mul("mul.simple",   2.0,  0.5,  1.0, 0, 1e-4);
    check_mul("mul.neg",     -3.0, -0.5,  1.5, 0, 1e-4);
    check_mul("mul.round",     1.0,  0.3333, 0.3333, 0, 1e-3);

    // Mul overflow: large * large -> saturate to max
    a_reg = q_from_real(32767.0);   // near max for Q16.16 integer part
    b_reg = q_from_real(1000.0);
    #1;
    if (!sat_mul || (y_mul != FP_MAX)) begin
      $display("[MUL][FAIL] overflow+ not saturated");
      $finish;
    end else $display("[MUL][PASS] overflow positive");

    // Negative overflow saturation
    a_reg = q_from_real(-32768.0);
    b_reg = q_from_real(1000.0);
    #1;
    if (!sat_mul || (y_mul != FP_MIN)) begin
      $display("[MUL][FAIL] overflow- not saturated");
      $finish;
    end else $display("[MUL][PASS] overflow negative");

    $display("== tb_fixedpoint: ALL TESTS PASSED ==");
    $finish;
  end

endmodule

`default_nettype wire
