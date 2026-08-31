#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REQUIRED_TOOLS=(
    make
    python3
    qemu-aarch64
    aarch64-linux-gnu-gcc
    aarch64-linux-gnu-objdump
    aarch64-linux-gnu-nm
)

print_section() {
    echo
    echo "=============================================================================="
    echo "$1"
    echo "=============================================================================="
}

fail() {
    echo "[FAIL] $1" >&2
    exit 1
}

print_section "Toolchain Check"

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        fail "Required tool not found: $tool"
    fi

    echo "[PASS] $tool"
done

print_section "Python Syntax Check"

python3 -m py_compile tests/test_file_crc32.py benchmarks/run_benchmarks.py

echo "[PASS] Python helper scripts compiled successfully."

print_section "Clean Build"

make clean
make

echo "[PASS] All targets built successfully."

print_section "Functional Tests"

make test

echo "[PASS] Unit and integration tests completed successfully."

print_section "Benchmark Structural Validation"

make benchmark-check

echo "[PASS] Benchmark harness completed successfully."

print_section "Hardware CRC Instruction Validation"

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

HW_DISASM="$TEMP_DIR/hardware.disasm"
DEFAULT_DISASM="$TEMP_DIR/default.disasm"

aarch64-linux-gnu-objdump -d build/aarch64-crc32-hw > "$HW_DISASM"
aarch64-linux-gnu-objdump -d build/aarch64-crc32 > "$DEFAULT_DISASM"

for instruction in crc32b crc32h crc32w crc32x; do
    if ! grep -Eq "[[:space:]]${instruction}[[:space:]]" "$HW_DISASM"; then
        fail "Hardware binary does not contain expected instruction: $instruction"
    fi

    echo "[PASS] Hardware binary contains $instruction."
done

if grep -Eq '[[:space:]]crc32(b|h|w|x)[[:space:]]' "$DEFAULT_DISASM"; then
    fail "Default table-driven CLI unexpectedly contains ARM CRC instructions."
fi

echo "[PASS] Default CLI remains independent of the ARM CRC extension."

print_section "Symbol Validation"

aarch64-linux-gnu-nm build/test_crc32_hw > "$TEMP_DIR/hardware.symbols"

for symbol in crc32_init crc32_finalize crc32_update_bitwise crc32_update_table crc32_update_hw crc32_hardware; do
    if ! grep -Eq "[[:space:]][Tt][[:space:]]${symbol}$" "$TEMP_DIR/hardware.symbols"; then
        fail "Expected symbol not found: $symbol"
    fi

    echo "[PASS] Symbol found: $symbol"
done

print_section "Release Validation Result"

echo "Status : READY FOR CI CONFIRMATION"
echo
echo "Local release validation completed successfully."
echo "Confirm that GitHub Actions is green for this exact commit before creating the v0.1.0 tag."