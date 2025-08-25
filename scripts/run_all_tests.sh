#!/bin/bash
# scripts/run_all_tests.sh
# filepath: /home/agplaza/Desktop/fpga_ml/scripts/run_all_tests.sh
# -----------------------------------------------------------------------------
# Test runner script for all FPGA ML testbenches
# Compiles and runs all tests with colorized output and final summary
# -----------------------------------------------------------------------------

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
BUILD_DIR="build"
RTL_SRCS="rtl/fixedpoint.v rtl/mac.v rtl/sgd_update.v rtl/blink.v"
IVERILOG_FLAGS="-g2012 -I rtl"

# Create build directory if it doesn't exist
mkdir -p $BUILD_DIR

# Test modules to run
TESTS=("tb_fixedpoint" "tb_mac" "tb_blink" "tb_sgd")

# Track results
PASSED_TESTS=()
FAILED_TESTS=()

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    FPGA ML Test Suite Runner${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to run a single test
run_test() {
    local test_name=$1
    local test_file="sim/${test_name}.sv"
    local out_file="${BUILD_DIR}/${test_name}.out"
    
    echo -e "${YELLOW}Running ${test_name}...${NC}"
    
    # Compile the test
    if ! iverilog $IVERILOG_FLAGS -o $out_file $test_file $RTL_SRCS 2>/dev/null; then
        echo -e "${RED}[COMPILE FAIL] ${test_name}${NC}"
        FAILED_TESTS+=($test_name)
        return 1
    fi
    
    # Run the test and capture output
    TEST_OUTPUT=$(vvp $out_file 2>&1)
    TEST_EXIT_CODE=$?
    
    # Check if test passed (no failures in output and clean exit)
    if [[ $TEST_EXIT_CODE -eq 0 ]] && ! echo "$TEST_OUTPUT" | grep -q "\[FAIL\]"; then
        echo -e "${GREEN}[PASS] ${test_name}${NC}"
        PASSED_TESTS+=($test_name)
        return 0
    else
        echo -e "${RED}[FAIL] ${test_name}${NC}"
        echo -e "${RED}Output:${NC}"
        echo "$TEST_OUTPUT" | sed 's/^/  /'
        FAILED_TESTS+=($test_name)
        return 1
    fi
}

# Run all tests
for test in "${TESTS[@]}"; do
    if [[ -f "sim/${test}.sv" ]]; then
        run_test $test
    else
        echo -e "${RED}[MISSING] ${test}.sv not found${NC}"
        FAILED_TESTS+=($test)
    fi
    echo ""
done

# Print summary
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}           Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ ${#PASSED_TESTS[@]} -gt 0 ]]; then
    echo -e "${GREEN}Passed Tests (${#PASSED_TESTS[@]}):${NC}"
    for test in "${PASSED_TESTS[@]}"; do
        echo -e "${GREEN}  ✓ ${test}${NC}"
    done
fi

if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    echo -e "${RED}Failed Tests (${#FAILED_TESTS[@]}):${NC}"
    for test in "${FAILED_TESTS[@]}"; do
        echo -e "${RED}  ✗ ${test}${NC}"
    done
fi

echo ""
if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL TESTS PASSED! 🎉${NC}"
    echo -e "${GREEN}Total: ${#PASSED_TESTS[@]}/${#TESTS[@]} tests passed${NC}"
    exit 0
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo -e "${RED}Passed: ${#PASSED_TESTS[@]}/${#TESTS[@]}${NC}"
    exit 1
fi