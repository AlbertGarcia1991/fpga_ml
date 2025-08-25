# Makefile — iCEBreaker
# Tooling: yosys + nextpnr-ice40 + icestorm + iverilog

# -------------------------------
# Configuration
# -------------------------------
TOP        ?= rtl/top.v
PCF        ?= constraints/icebreaker.pcf
BUILD_DIR  ?= build
FAMILY     ?= ice40
DEVICE     ?= up5k
PACKAGE    ?= sg48
FREQ_MHZ   ?= 12

# Tools
YOSYS      ?= yosys
NEXTPNR    ?= nextpnr-ice40
ICEPACK    ?= icepack
ICEPROG    ?= iceprog
IVERILOG   ?= iverilog
VVP        ?= vvp

YOSYS_SCRIPT := $(BUILD_DIR)/synth.ys
JSON        := $(BUILD_DIR)/top.json
ASC         := $(BUILD_DIR)/top.asc
BIN         := $(BUILD_DIR)/top.bin

# -------------------------------
# Phony targets
# -------------------------------
.PHONY: all env-check sim build prog clean dirs

all: build

dirs:
	@mkdir -p $(BUILD_DIR)

env-check:
	@bash scripts/env_check.sh

# -------------------------------
# Simulation
# -------------------------------
SIM_SRCS := $(wildcard sim/*.sv) $(wildcard sim/*.v)
sim:
ifeq ($(strip $(SIM_SRCS)),)
	@echo "[sim] No testbenches found in ./sim yet — skipping."
else
	@echo "[sim] Building and running simulations..."
	$(IVERILOG) -g2012 -I rtl -o $(BUILD_DIR)/sim.out $(SIM_SRCS)
	$(VVP) $(BUILD_DIR)/sim.out
endif

# -------------------------------
# Build flow (synth → place&route → pack)
# -------------------------------
$(YOSYS_SCRIPT): | dirs
	@if [ ! -f "$(TOP)" ]; then \
		echo "[build] Missing $(TOP). Add RTL before building."; \
		exit 1; \
	fi
	@if [ ! -f "$(PCF)" ]; then \
		echo "[build] Missing $(PCF). Add constraints before building."; \
		exit 1; \
	fi
	@echo "[yosys] Writing synth script to $(YOSYS_SCRIPT)"
	@printf "read_verilog -sv %s\n" "$(TOP)" > $(YOSYS_SCRIPT)
	@printf "hierarchy -check -top top\n" >> $(YOSYS_SCRIPT)
	@printf "proc; opt; fsm; opt; techmap; opt\n" >> $(YOSYS_SCRIPT)
	@printf "synth_ice40 -top top -json %s\n" "$(JSON)" >> $(YOSYS_SCRIPT)

$(JSON): $(TOP) $(PCF) $(YOSYS_SCRIPT) | dirs
	@echo "[yosys] Synthesizing → $(JSON)"
	$(YOSYS) -q -s $(YOSYS_SCRIPT)

$(ASC): $(JSON) $(PCF) | dirs
	@echo "[nextpnr] Placing & routing → $(ASC)"
	$(NEXTPNR) --$(FAMILY) --$(DEVICE) --package $(PACKAGE) \
		--json $(JSON) --pcf $(PCF) --asc $(ASC) --freq $(FREQ_MHZ)

$(BIN): $(ASC) | dirs
	@echo "[icepack] Packing bitstream → $(BIN)"
	$(ICEPACK) $(ASC) $(BIN)

build: $(BIN)
	@echo "[build] Done: $(BIN)"

prog: $(BIN)
	@echo "[iceprog] Programming board with $(BIN)"
	$(ICEPROG) $(BIN)

clean:
	@echo "[clean] Removing build outputs"
	@rm -rf $(BUILD_DIR)
