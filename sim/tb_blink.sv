`timescale 1ns/1ps
`default_nettype none

module tb_blink;

  // DUT signals
  reg  clk_12mhz;
  wire led;

  // Clock generation (much faster than real 12MHz for simulation)
  initial clk_12mhz = 0;
  always #5 clk_12mhz = ~clk_12mhz; // 100MHz sim clock (10ns period)

  // Instantiate DUT
  blink dut (
    .clk_12mhz(clk_12mhz),
    .led(led)
  );

  // Test variables
  reg [23:0] expected_counter;
  reg expected_led;
  integer cycle_count;

  // Color codes for output
  parameter GREEN = "\033[0;32m";
  parameter RED = "\033[0;31m";
  parameter NC = "\033[0m"; // No Color

  // Main test sequence
  initial begin
    $display("== tb_blink: Starting tests ==");
    
    // Initialize
    expected_counter = 24'd0;
    cycle_count = 0;
    
    // Wait a few clock cycles and check counter behavior
    repeat(10) begin
      expected_counter = expected_counter + 1;
      @(posedge clk_12mhz);
      #1; // Small delay to let combinational logic settle
      cycle_count = cycle_count + 1;
      
      // Check counter value
      if (dut.counter !== expected_counter) begin
        $display("%s[FAIL] Cycle %0d: Expected counter=%0d, got=%0d%s", 
                 RED, cycle_count, expected_counter, dut.counter, NC);
        $finish;
      end
      
      // Check LED output (should be counter[23])
      expected_led = expected_counter[23];
      if (led !== expected_led) begin
        $display("%s[FAIL] Cycle %0d: Expected LED=%b, got=%b%s", 
                 RED, cycle_count, expected_led, led, NC);
        $finish;
      end
    end
    
    $display("%s[PASS] Counter increments correctly for %0d cycles%s", GREEN, cycle_count, NC);
    
    // Test LED logic by checking the combinational assignment
    // Test case 1: counter with bit 23 = 0
    force dut.counter = 24'h400000; // bit 23 = 0, bit 22 = 1
    #1; // Let combinational logic settle
    if (led !== 1'b0) begin
      $display("%s[FAIL] LED should be low when counter[23]=0, got LED=%b%s", RED, led, NC);
      $finish;
    end
    $display("%s[PASS] LED correctly low when counter[23]=0%s", GREEN, NC);
    
    // Test case 2: counter with bit 23 = 1  
    force dut.counter = 24'h800000; // bit 23 = 1
    #1; // Let combinational logic settle
    if (led !== 1'b1) begin
      $display("%s[FAIL] LED should be high when counter[23]=1, got LED=%b%s", RED, led, NC);
      $finish;
    end
    $display("%s[PASS] LED correctly high when counter[23]=1%s", GREEN, NC);
    
    // Test case 3: counter with bit 23 = 1 and other bits set
    force dut.counter = 24'hFFFFFF; // all bits high including bit 23
    #1; // Let combinational logic settle
    if (led !== 1'b1) begin
      $display("%s[FAIL] LED should be high when counter[23]=1 (all bits set), got LED=%b%s", RED, led, NC);
      $finish;
    end
    $display("%s[PASS] LED correctly high when counter[23]=1 (all bits set)%s", GREEN, NC);
    
    // Release the force and verify normal operation resumes
    release dut.counter;
    
    // Let the counter run a few more cycles to verify it works normally
    expected_counter = dut.counter; // Get current value
    repeat(5) begin
      expected_counter = expected_counter + 1;
      @(posedge clk_12mhz);
      #1;
      
      if (dut.counter !== expected_counter) begin
        $display("%s[FAIL] After release: Expected counter=%0d, got=%0d%s", 
                 RED, expected_counter, dut.counter, NC);
        $finish;
      end
      
      expected_led = expected_counter[23];
      if (led !== expected_led) begin
        $display("%s[FAIL] After release: Expected LED=%b, got=%b%s", 
                 RED, expected_led, led, NC);
        $finish;
      end
    end
    
    $display("%s[PASS] Normal operation resumed after force/release%s", GREEN, NC);
    
    $display("== tb_blink: ALL TESTS PASSED ==");
    $finish;
  end

  // Timeout to prevent infinite simulation
  initial begin
    #1000000; // 1ms timeout
    $display("%s[TIMEOUT] Simulation timed out%s", RED, NC);
    $finish;
  end

endmodule

`default_nettype wire