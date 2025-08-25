# iCEBreaker Linear Regression Core (MVP)

On-device **training (SGD/LMS)** and **inference** for a **linear regression** model on the Lattice **iCE40UP5K** (iCEBreaker v1.0b).  
MVP starts **digital-only** (PMOD feature pins), with a **mode pin** (Train/Infer), a **sample strobe**, and a **shared Y pin** used as **target** in training and **PWM output** in inference.

> Toolchain: **Yosys** + **nextpnr-ice40** + **icestorm** (open-source), optional **Icarus Verilog** or **Verilator** for simulation.  
> Host utilities: **Python 3**, with **pyserial** and (optionally) **matplotlib** in later steps.

# Make Targets
* make env-check — Validates presence/versions of yosys, nextpnr-ice40, icepack, iceprog, iverilog, python3.
* make sim — Compiles and runs testbenches (no-op until /sim contains tests).
* make build — Synthesizes, places, routes, and packs a bitstream for iCE40UP5K (expects rtl/top.v and constraints/icebreaker.pcf).
* make prog — Programs the board via iceprog.
* make clean — Removes build/ artifacts.

---

# Implementation Plan#

## 0) Repo Scaffolding & Tooling
- [x] Step 0.1: Initialize repo & directories
- [ ] Step 0.2: CI (optional early) — defer until Docker toolchain image is ready

## 1) Fixed-Point & Core Math (Simulation-first)
- [x] Step 1.1: Fixed-point utilities
- [x] Step 1.2: MAC pipeline
- [x] Step 1.3: SGD update engine

## 2) Control & Sampling Path
- [ ] Step 2.1: CDC + strobe edge detect
- [ ] Step 2.2: Sampler & feature register bank
- [ ] Step 2.3: Shared Y pin mux + PWM DAC
- [ ] Step 2.4: LED status FSM

## 3) UART + Protocol (Phase 1: Core commands)
- [ ] Step 3.1: UART core
- [ ] Step 3.2: Framing + CRC16 + parser
- [ ] Step 3.3: CSR bus glue

## 4) Top Integration (Inference-only, then Training)
- [ ] Step 4.1: Top (inference-only build)
- [ ] Step 4.2: Enable training path

## 5) Constraints & Bitstream
- [ ] Step 5.1: PCF constraints (draft)
- [ ] Step 5.2: Build scripts

## 6) Host CLI (Phase 1: Core ops)
- [ ] Step 6.1: Serial I/O & protocol
- [ ] Step 6.2: Config & weights commands
- [ ] Step 6.3: Train demo & plotting

## 7) Hardware Bring-up (Milestone A)
- [ ] Step 7.1: Smoke tests
- [ ] Step 7.2: Training on-board
- [ ] Step 7.3: UART loopback training

---

## Quick Start

1) **Verify tools**
```bash
make env-check
```