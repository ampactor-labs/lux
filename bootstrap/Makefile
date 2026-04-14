# Lux Bootstrap — Stage 0 → 1 → 2
#
# Stage 0: Rust VM compiles the Lux compiler to WAT        (lux3.wat)
# Stage 1: WAT → binary WASM; optionally → C → native ELF   (lux3.wasm, lux3-native)
# Stage 2: lux3 compiles itself (the Ouroboros)             (lux4.wat → lux4.wasm)
# Stage check: diff lux3.wat lux4.wat → fixed point reached
#
# Each target is a handler on the build effect. wasmtime and wasm2c are
# borrowed native handlers — the destination is Lux's own x86 emitter.

# ─── Inputs ───────────────────────────────────────────────────────────
PROJECT_ROOT  := $(abspath $(CURDIR)/..)
LUX_SRC       := $(PROJECT_ROOT)/examples/wasm_bootstrap.lux
WASMTIME      := $(HOME)/.wasmtime/bin/wasmtime
WASMTIME_OPTS := --dir $(PROJECT_ROOT) -W max-wasm-stack=33554432

# wasm2c runtime lives with the WABT install. Override if packaged elsewhere.
WABT_RT_DIR   ?= /usr/share/wabt/wasm2c
WABT_RT       := $(WABT_RT_DIR)/wasm-rt-impl.c

BUILD := build

# ─── Phony targets ────────────────────────────────────────────────────
.PHONY: all stage0 stage1 stage1-native stage2 stage2-native check clean help
.DEFAULT_GOAL := help

all: stage2

help:
	@echo "Lux Bootstrap targets:"
	@echo "  make stage0         Rust VM → WAT                (~9 min) → $(BUILD)/lux3.wat"
	@echo "  make stage1         WAT → binary WASM (w/ names) → $(BUILD)/lux3.wasm"
	@echo "  make stage1-native  binary → C → native ELF      → $(BUILD)/lux3-native"
	@echo "  make stage2         wasmtime Ouroboros            → $(BUILD)/lux4.wat"
	@echo "  make stage2-native  native-binary Ouroboros       → $(BUILD)/lux4-native.wat"
	@echo "  make check          diff lux3.wat lux4.wat        → fixed-point verdict"
	@echo "  make clean          remove $(BUILD)/"

$(BUILD):
	mkdir -p $(BUILD)

# ─── Stage 0: Rust VM → WAT ───────────────────────────────────────────
# The Rust VM runs the self-hosted compiler against the bootstrap entry
# point and emits WAT to stdout. We strip the cargo preamble with sed.
stage0: $(BUILD)/lux3.wat
$(BUILD)/lux3.wat: | $(BUILD)
	cd $(PROJECT_ROOT) && cargo run --release -- wasm $(LUX_SRC) \
	  | sed -n '/^(module/,$$p' > bootstrap/$(BUILD)/lux3.wat

# ─── Stage 1: WAT → binary WASM ───────────────────────────────────────
# --debug-names preserves the $name symbolic identifiers that the Lux
# emitter already produces. Cost: ~170 KB. Benefit: wasmtime stacktraces
# are readable, wasm-decompile output is scannable, wasm2c produces
# human-named C functions.
stage1: $(BUILD)/lux3.wasm
$(BUILD)/lux3.wasm: $(BUILD)/lux3.wat
	wat2wasm --debug-names $< -o $@
	wasm-validate $@

# ─── Stage 1-native: binary WASM → C → native ─────────────────────────
# wasm2c emits portable C. With gcc -O2 and a minimal WASI shim, we get
# a standalone native binary. Faster than wasmtime JIT after warmup;
# slower to build initially.
stage1-native: $(BUILD)/lux3-native
$(BUILD)/lux3_native.c $(BUILD)/lux3_native.h: $(BUILD)/lux3.wasm
	cd $(BUILD) && wasm2c lux3.wasm -o lux3_native.c

$(BUILD)/lux3-native: $(BUILD)/lux3_native.c wasi_shim.c
	gcc -O2 -I$(BUILD) -I$(WABT_RT_DIR) \
	    wasi_shim.c $(BUILD)/lux3_native.c $(WABT_RT) \
	    -o $(BUILD)/lux3-native

# ─── Stage 2: Ouroboros via wasmtime ──────────────────────────────────
# lux3.wat compiles itself, outputting lux4.wat. Currently CPU-bound on
# O(N²) list traversals in the compiler source (see AGENTS.md).
stage2: $(BUILD)/lux4.wat
$(BUILD)/lux4.wat: $(BUILD)/lux3.wat
	cat $(LUX_SRC) | $(WASMTIME) run $(WASMTIME_OPTS) $< > $@

# Also turn the result into a binary for comparison and next-stage runs.
$(BUILD)/lux4.wasm: $(BUILD)/lux4.wat
	wat2wasm --debug-names $< -o $@
	wasm-validate $@

# ─── Stage 2-native: Ouroboros via native binary ──────────────────────
# Same fixed-point, different handler (native C instead of wasmtime JIT).
stage2-native: $(BUILD)/lux4-native.wat
$(BUILD)/lux4-native.wat: $(BUILD)/lux3-native
	cat $(LUX_SRC) | $(BUILD)/lux3-native > $@

# ─── Fixed-point check ────────────────────────────────────────────────
# If lux3.wat and lux4.wat are identical, the compiler reached a fixed
# point: it produces itself unchanged. That is Arc 2 complete.
check: $(BUILD)/lux3.wat $(BUILD)/lux4.wat
	@if diff -q $(BUILD)/lux3.wat $(BUILD)/lux4.wat > /dev/null; then \
	  echo "FIXED POINT REACHED — Arc 2 complete"; \
	else \
	  echo "WAT files differ:"; \
	  diff $(BUILD)/lux3.wat $(BUILD)/lux4.wat | head -40; \
	  exit 1; \
	fi


# ─── Canonical-form fixed-point check ─────────────────────────────────
# Strip syntactic noise (comments, whitespace, name-section ordering)
# by round-tripping through wat2wasm + wasm2wat. What survives is
# semantically meaningful — names of identifiers, ordering of sections,
# function bodies. A clean diff here is a stronger guarantee than
# `make check`'s textual diff: handler-state fresh_id numbering
# doesn't matter if the structural shape matches.
check-canonical: $(BUILD)/lux3.wat $(BUILD)/lux4.wat
	@wat2wasm --debug-names $(BUILD)/lux3.wat -o $(BUILD)/lux3.canon.wasm 2>/dev/null
	@wat2wasm --debug-names $(BUILD)/lux4.wat -o $(BUILD)/lux4.canon.wasm 2>/dev/null
	@wasm2wat $(BUILD)/lux3.canon.wasm > $(BUILD)/lux3.canon.wat
	@wasm2wat $(BUILD)/lux4.canon.wasm > $(BUILD)/lux4.canon.wat
	@if diff -q $(BUILD)/lux3.canon.wat $(BUILD)/lux4.canon.wat > /dev/null; then \
	  echo "CANONICAL FIXED POINT — Arc 2 semantically complete"; \
	else \
	  echo "Canonical WAT differs ($$(diff $(BUILD)/lux3.canon.wat $(BUILD)/lux4.canon.wat | wc -l) lines):"; \
	  diff $(BUILD)/lux3.canon.wat $(BUILD)/lux4.canon.wat | head -40; \
	  exit 1; \
	fi

# ─── Per-function decompile diff ──────────────────────────────────────
# wasm-decompile each binary, split into per-function chunks, diff
# function-by-function. The function whose diff is non-empty IS the
# miscompiled function — much faster than wading through 137K lines
# of WAT looking for the divergence.
decompile-diff: $(BUILD)/lux3.wasm $(BUILD)/lux4.wasm
	@wasm-decompile $(BUILD)/lux3.wasm > $(BUILD)/lux3.dc.txt
	@wasm-decompile $(BUILD)/lux4.wasm > $(BUILD)/lux4.dc.txt
	@diff $(BUILD)/lux3.dc.txt $(BUILD)/lux4.dc.txt > $(BUILD)/dc.diff || true
	@echo "Decompile diff written to $(BUILD)/dc.diff ($$(wc -l < $(BUILD)/dc.diff) lines)"
	@echo "First diverging function name:"
	@awk '/^[<>] function /{print; exit}' $(BUILD)/dc.diff || true

clean:
	rm -rf $(BUILD)
