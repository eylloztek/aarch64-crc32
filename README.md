# AArch64 CRC32

[![CI](https://github.com/eylloztek/aarch64-crc32/actions/workflows/ci.yml/badge.svg)](https://github.com/eylloztek/aarch64-crc32/actions/workflows/ci.yml)

Pure AArch64 assembly implementations of CRC-32 for Linux, including bitwise, table-driven, and ARMv8 hardware-assisted engines.

The CRC algorithms, streaming API, Linux file-processing CLI, hexadecimal formatter, and benchmark harness are implemented in AArch64 assembly. Python is used only for test orchestration, independent checksum verification, benchmark aggregation, and reporting.

> **Note**
>
> CRC-32 is an error-detection checksum, not a cryptographic hash. This project is intended for systems programming and AArch64 learning. It must not be used for authentication, tamper resistance, password hashing, or other security-sensitive purposes.

## Features

* Pure AArch64 CRC-32 implementations
* Bit-by-bit reference implementation
* 256-entry table-driven implementation
* ARMv8 CRC extension implementation
* Incremental `init → update → finalize` streaming API
* File processing through direct Linux syscalls
* Fixed-size streaming I/O buffer
* No libc dependency
* Static AArch64 executables
* Known CRC-32 test vectors
* Binary-data and boundary-condition tests
* Cross-implementation equivalence tests
* File integration tests
* QEMU-based cross-platform development
* Benchmark suite for all three engines
* Native AArch64 benchmark support
* Automated release validation
* GitHub Actions CI

## CRC Variant

This project implements the standard reflected CRC-32 commonly known as CRC-32/ISO-HDLC.

| Parameter                     | Value        |
| ----------------------------- | ------------ |
| Width                         | 32 bits      |
| Polynomial                    | `0x04C11DB7` |
| Reflected polynomial          | `0xEDB88320` |
| Initial value                 | `0xFFFFFFFF` |
| Reflect input                 | Yes          |
| Reflect output                | Yes          |
| Final XOR                     | `0xFFFFFFFF` |
| Check value for `"123456789"` | `0xCBF43926` |

The ARM hardware implementation uses the `CRC32B`, `CRC32H`, `CRC32W`, and `CRC32X` instructions.

The `CRC32C*` instruction family is intentionally not used because it implements CRC-32C/Castagnoli rather than the CRC-32 variant used by this project.

## Implementations

### Bitwise

The baseline implementation processes every input byte one bit at a time.

```text
byte
  ↓
XOR with CRC state
  ↓
8 × shift / conditional polynomial XOR
```

Characteristics:

* No lookup table
* Small memory footprint
* Instruction-heavy
* Useful as a readable scalar baseline

Main symbols:

```text
crc32_update_bitwise
crc32_bitwise
```

A compatibility alias named `crc32_update` also points to the bitwise update implementation.

### Table-driven

The table-driven implementation replaces eight per-bit iterations with a 256-entry lookup table.

The update equation is:

```text
index = (state XOR byte) & 0xFF
state = (state >> 8) XOR table[index]
```

Characteristics:

* 1024-byte lookup table
* One table lookup per byte
* Faster scalar software implementation
* Default engine used by the portable CLI

Main symbols:

```text
crc32_update_table
crc32_tablewise
```

### ARMv8 hardware-assisted

The hardware implementation uses the ARM CRC extension.

It processes data using the widest available operation and handles the remaining tail with narrower instructions:

```text
8 bytes → CRC32X
4 bytes → CRC32W
2 bytes → CRC32H
1 byte  → CRC32B
```

Main symbols:

```text
crc32_update_hw
crc32_hardware
```

This implementation requires an AArch64 CPU with the CRC32 architectural extension.

The hardware-specific executable does not currently perform runtime CPU-feature detection. The default CLI therefore remains table-driven.

## Streaming API

All implementations share the same internal CRC state format.

Conceptually:

```text
crc32_init()
      ↓
crc32_update(...)
      ↓
crc32_update(...)
      ↓
...
      ↓
crc32_finalize()
```

A C-style representation of the assembly ABI is:

```c
uint32_t crc32_init(void);

uint32_t crc32_update_bitwise(
    uint32_t state,
    const uint8_t *data,
    uint64_t length
);

uint32_t crc32_update_table(
    uint32_t state,
    const uint8_t *data,
    uint64_t length
);

uint32_t crc32_update_hw(
    uint32_t state,
    const uint8_t *data,
    uint64_t length
);

uint32_t crc32_finalize(uint32_t state);
```

The one-shot convenience interfaces are conceptually:

```c
uint32_t crc32_bitwise(const uint8_t *data, uint64_t length);
uint32_t crc32_tablewise(const uint8_t *data, uint64_t length);
uint32_t crc32_hardware(const uint8_t *data, uint64_t length);
```

These declarations document the AAPCS64 register interface. The CRC implementations themselves are written in assembly.

## File Processing

The CLI does not load the entire input file into memory.

The default path is:

```text
argv[1]
   ↓
openat()
   ↓
read() into 4096-byte buffer
   ↓
crc32_update_table()
   ↓
read()
   ↓
...
   ↓
EOF
   ↓
close()
   ↓
crc32_finalize()
   ↓
hexadecimal conversion
   ↓
write()
```

The program communicates directly with the Linux kernel and does not use libc.

Linux syscalls used include:

* `openat`
* `read`
* `close`
* `write`
* `exit`

The benchmark harness additionally uses `clock_gettime`.

## Requirements

The project can be cross-built on an x86-64 Linux machine and executed through QEMU user-mode emulation.

On Ubuntu/Debian:

```bash
sudo apt update

sudo apt install \
    gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    qemu-user \
    make \
    python3
```

## Build

Build all command-line tools, tests, and benchmarks:

```bash
make
```

Important generated executables include:

```text
build/aarch64-crc32
build/aarch64-crc32-hw

build/test_crc32
build/test_crc32_table
build/test_crc32_hw

build/bench_crc32_bitwise
build/bench_crc32_table
build/bench_crc32_hw
```

Generated build artifacts are intentionally excluded from Git.

## Usage

### Portable table-driven CLI

```bash
make run FILE=<path>
```

or directly:

```bash
qemu-aarch64 build/aarch64-crc32 <path>
```

Example:

```bash
printf '123456789' > sample.txt

qemu-aarch64 build/aarch64-crc32 sample.txt
```

Output:

```text
CBF43926
```

### ARM CRC extension CLI

Under QEMU:

```bash
make run-hw FILE=<path>
```

or:

```bash
qemu-aarch64 -cpu max build/aarch64-crc32-hw <path>
```

On native AArch64 Linux with the CRC extension:

```bash
./build/aarch64-crc32-hw <path>
```

Do not execute the hardware variant on a processor that does not provide the ARM CRC extension.

## Tests

Run the complete functional test suite:

```bash
make test
```

The test suite contains separate validation layers.

### Bitwise assembly tests

```text
build/test_crc32
```

Covers:

* Empty input
* Single-byte input
* Standard CRC vector
* Multi-byte text
* Binary input
* Chunked streaming
* Zero-length updates
* Byte-at-a-time streaming
* Split binary streaming

### Table-driven assembly tests

```text
build/test_crc32_table
```

Adds:

* Lookup-table implementation validation
* `0x00` through `0xFF` input coverage
* Internal streaming-state verification
* Bitwise/table equivalence

### Hardware assembly tests

```text
build/test_crc32_hw
```

Tests:

* `CRC32B`
* `CRC32H`
* `CRC32W`
* `CRC32X`
* Mixed-width tail handling
* Streaming behavior
* Zero-length updates
* Bitwise/table/hardware equivalence

### File integration tests

The Python integration test generates temporary files and independently computes the expected CRC using Python's standard library.

It validates:

* Empty files
* Standard CRC vector
* Text files
* Binary files
* All possible byte values
* Exact 4096-byte buffer boundaries
* Multi-read 10000-byte files
* Missing command-line arguments
* Missing files
* Read failures

Python is not used as part of the CRC implementation.

## Benchmarking

The benchmark suite measures the CRC engines separately from file I/O.

Each test processes exactly 8 MiB of data using one of three buffer sizes:

| Buffer | Iterations | Total |
| -----: | ---------: | ----: |
|  4 KiB |       2048 | 8 MiB |
| 64 KiB |        128 | 8 MiB |
|  1 MiB |          8 | 8 MiB |

Run a structural one-sample benchmark check:

```bash
make benchmark-check
```

Run the normal five-sample QEMU benchmark:

```bash
make benchmark
```

The runner reports:

* Median execution time
* Minimum execution time
* Maximum execution time
* Throughput in MiB/s
* Relative speed compared with the bitwise engine

### Example QEMU results

The following values were measured under an Ubuntu guest running in VirtualBox, using `qemu-aarch64 -cpu max`.

Each result is the median of five samples.

| Buffer |     Bitwise | Table-driven |     Hardware |
| -----: | ----------: | -----------: | -----------: |
|  4 KiB | 21.20 MiB/s | 264.32 MiB/s | 349.03 MiB/s |
| 64 KiB | 20.23 MiB/s | 274.43 MiB/s | 364.66 MiB/s |
|  1 MiB | 19.28 MiB/s | 276.17 MiB/s | 371.35 MiB/s |

Relative to the bitwise implementation:

| Buffer | Table-driven | Hardware |
| -----: | -----------: | -------: |
|  4 KiB |       12.47× |   16.47× |
| 64 KiB |       13.57× |   18.03× |
|  1 MiB |       14.33× |   19.27× |

These numbers describe the QEMU/VirtualBox test environment only.

They must not be interpreted as physical ARM processor performance. QEMU translates and emulates guest instructions, including the ARM CRC extension.

### Native AArch64 benchmark

On an actual AArch64 Linux machine:

```bash
make benchmark-native
```

The hardware benchmark requires a processor supporting the ARM CRC extension.

Native hardware measurements should be preferred for real performance comparisons.

## Release Validation

Run the complete local release validation:

```bash
make release-check
```

This performs:

* Toolchain availability checks
* Python syntax validation
* Clean rebuild
* Assembly unit tests
* File integration tests
* Benchmark structural validation
* ARM CRC instruction verification
* Default CLI portability verification
* Required symbol validation

A successful run ends with:

```text
Status : READY FOR CI CONFIRMATION
```

A release tag should only be created after GitHub Actions is also green for the exact commit being released.

## Disassembly and Inspection

Inspect the default CLI:

```bash
make disasm
```

Inspect the hardware CLI:

```bash
make disasm-hw
```

Find ARM CRC instructions:

```bash
aarch64-linux-gnu-objdump -d build/aarch64-crc32-hw \
    | grep -E "crc32[bwhx]"
```

Inspect exported symbols:

```bash
aarch64-linux-gnu-nm build/test_crc32_hw | grep crc32
```

These commands are useful for verifying both ABI structure and the exact instructions emitted into the executable.

## Project Structure

```text
.
├── benchmarks/
│   ├── bench_crc32.S
│   └── run_benchmarks.py
├── scripts/
│   └── release_check.sh
├── src/
│   ├── crc32_common.S
│   ├── crc32_bitwise.S
│   ├── crc32_table.S
│   ├── crc32_hw.S
│   └── main.S
├── tests/
│   ├── test_crc32.S
│   ├── test_crc32_table.S
│   ├── test_crc32_hw.S
│   └── test_file_crc32.py
├── Makefile
└── README.md
```

## Development Progression

The project was intentionally built in incremental stages:

1. Bitwise CRC-32 implementation
2. Modular assembly API and test harness
3. Streaming `init/update/finalize` interface
4. Linux file-processing CLI
5. Table-driven scalar implementation
6. ARMv8 CRC extension implementation
7. Comparative benchmark suite
8. CI, documentation, and release validation

This progression keeps the optimized implementations comparable with the original scalar baseline.

## Design Goals

The project focuses on:

* AArch64 instruction-level programming
* AAPCS64 calling convention
* Register allocation
* Stack discipline
* Bitwise operations
* Indexed addressing
* Lookup tables
* Hardware instruction extensions
* Linux syscall interfaces
* Binary data processing
* Incremental algorithms
* Benchmark methodology
* Cross-compilation
* QEMU-based validation

## Current Limitations

* Linux only
* No runtime ARM CRC-extension detection
* Default file buffer size is fixed at 4096 bytes
* CLI accepts one file per invocation
* No recursive directory processing
* Benchmark results under QEMU are not representative of native ARM hardware
* CRC-32 provides no cryptographic security

These limitations are intentional for the current scope of the project.
