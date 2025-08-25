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

## Quick Start

1) **Verify tools**
```bash
make env-check
```