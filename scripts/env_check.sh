#!/usr/bin/env bash
# scripts/env_check.sh
# Verifies the FPGA toolchain and Python are available, printing versions.

set -e

echo "== iCEBreaker Env Check =="

check() {
  local cmd="$1"
  local ver="$2"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "\e[0;31m✗ $cmd not found\e[0;30m"
    return 1
  else
    echo -e "\e[0;32m✓ $cmd found\e[0;30m"
    if [ -n "$ver" ]; then
      # Run version command safely; ignore failures
      eval "$ver" || true
    fi
  fi
}

# Core FPGA tools
check yosys         "yosys -V | head -n0"
check nextpnr-ice40 "nextpnr-ice40 --version -q"
check icepack       "icepack -h 2>&1 | head -n0"
check iceprog       "iceprog --help 2>&1 | head -n0"

# Simulation
check iverilog      "iverilog -V | head -n0" || true
check vvp           "vvp -V 2>&1 | head -n0" || true

# Python
check python3       "python3 --version | head -n0"
check pip3          "pip3 --version | head -n1"

echo "All checks attempted."