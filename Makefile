CROSS ?= aarch64-linux-gnu

CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
QEMU ?= qemu-aarch64
PYTHON ?= python3

CRC_ARCH_FLAGS := -march=armv8-a+crc

CLI_TARGET := build/aarch64-crc32
HW_CLI_TARGET := build/aarch64-crc32-hw

TEST_BITWISE_TARGET := build/test_crc32
TEST_TABLE_TARGET := build/test_crc32_table
TEST_HW_TARGET := build/test_crc32_hw

COMMON_OBJECT := build/src/crc32_common.o
BITWISE_OBJECT := build/src/crc32_bitwise.o
TABLE_OBJECT := build/src/crc32_table.o
HW_OBJECT := build/src/crc32_hw.o

MAIN_TABLE_OBJECT := build/src/main_table.o
MAIN_HW_OBJECT := build/src/main_hw.o

TEST_BITWISE_OBJECT := build/tests/test_crc32.o
TEST_TABLE_OBJECT := build/tests/test_crc32_table.o
TEST_HW_OBJECT := build/tests/test_crc32_hw.o

BENCH_BITWISE_TARGET := build/bench_crc32_bitwise
BENCH_TABLE_TARGET := build/bench_crc32_table
BENCH_HW_TARGET := build/bench_crc32_hw

BENCH_BITWISE_OBJECT := build/benchmarks/bench_crc32_bitwise.o
BENCH_TABLE_OBJECT := build/benchmarks/bench_crc32_table.o
BENCH_HW_OBJECT := build/benchmarks/bench_crc32_hw.o

LDFLAGS := -nostdlib -static -no-pie -Wl,-e,_start

.PHONY: all run run-hw test disasm disasm-hw disasm-hw-tests clean benchmark benchmark-check benchmark-native

all: $(CLI_TARGET) $(HW_CLI_TARGET) $(TEST_BITWISE_TARGET) $(TEST_TABLE_TARGET) $(TEST_HW_TARGET) $(BENCH_BITWISE_TARGET) $(BENCH_TABLE_TARGET) $(BENCH_HW_TARGET)

$(CLI_TARGET): $(COMMON_OBJECT) $(TABLE_OBJECT) $(MAIN_TABLE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(HW_CLI_TARGET): $(COMMON_OBJECT) $(HW_OBJECT) $(MAIN_HW_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_BITWISE_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(TEST_BITWISE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_TABLE_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(TABLE_OBJECT) $(TEST_TABLE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_HW_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(TABLE_OBJECT) $(HW_OBJECT) $(TEST_HW_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(MAIN_TABLE_OBJECT): src/main.S
	mkdir -p $(dir $@)
	$(CC) -g -DCRC32_UPDATE_FN=crc32_update_table -c -o $@ $<

$(MAIN_HW_OBJECT): src/main.S
	mkdir -p $(dir $@)
	$(CC) -g -DCRC32_UPDATE_FN=crc32_update_hw -c -o $@ $<

$(HW_OBJECT): src/crc32_hw.S
	mkdir -p $(dir $@)
	$(CC) -g $(CRC_ARCH_FLAGS) -c -o $@ $<

$(BENCH_BITWISE_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(BENCH_BITWISE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(BENCH_TABLE_TARGET): $(COMMON_OBJECT) $(TABLE_OBJECT) $(BENCH_TABLE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(BENCH_HW_TARGET): $(COMMON_OBJECT) $(HW_OBJECT) $(BENCH_HW_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^


$(BENCH_BITWISE_OBJECT): benchmarks/bench_crc32.S
	mkdir -p $(dir $@)
	$(CC) -g -DCRC32_UPDATE_FN=crc32_update_bitwise -c -o $@ $<

$(BENCH_TABLE_OBJECT): benchmarks/bench_crc32.S
	mkdir -p $(dir $@)
	$(CC) -g -DCRC32_UPDATE_FN=crc32_update_table -c -o $@ $<

$(BENCH_HW_OBJECT): benchmarks/bench_crc32.S
	mkdir -p $(dir $@)
	$(CC) -g -DCRC32_UPDATE_FN=crc32_update_hw -c -o $@ $<

benchmark-check: $(BENCH_BITWISE_TARGET) $(BENCH_TABLE_TARGET) $(BENCH_HW_TARGET)
	$(PYTHON) benchmarks/run_benchmarks.py \
		--bitwise $(BENCH_BITWISE_TARGET) \
		--table $(BENCH_TABLE_TARGET) \
		--hardware $(BENCH_HW_TARGET) \
		--qemu $(QEMU) \
		--samples 1

benchmark: $(BENCH_BITWISE_TARGET) $(BENCH_TABLE_TARGET) $(BENCH_HW_TARGET)
	$(PYTHON) benchmarks/run_benchmarks.py \
		--bitwise $(BENCH_BITWISE_TARGET) \
		--table $(BENCH_TABLE_TARGET) \
		--hardware $(BENCH_HW_TARGET) \
		--qemu $(QEMU) \
		--samples 5

benchmark-native: $(BENCH_BITWISE_TARGET) $(BENCH_TABLE_TARGET) $(BENCH_HW_TARGET)
	$(PYTHON) benchmarks/run_benchmarks.py \
		--bitwise $(BENCH_BITWISE_TARGET) \
		--table $(BENCH_TABLE_TARGET) \
		--hardware $(BENCH_HW_TARGET) \
		--native \
		--samples 7

build/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) -g -c -o $@ $<

run: $(CLI_TARGET)
	@if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=<path>"; exit 2; fi
	$(QEMU) $(CLI_TARGET) "$(FILE)"

run-hw: $(HW_CLI_TARGET)
	@if [ -z "$(FILE)" ]; then echo "Usage: make run-hw FILE=<path>"; exit 2; fi
	$(QEMU) -cpu max $(HW_CLI_TARGET) "$(FILE)"

test: $(CLI_TARGET) $(HW_CLI_TARGET) $(TEST_BITWISE_TARGET) $(TEST_TABLE_TARGET) $(TEST_HW_TARGET)
	$(QEMU) $(TEST_BITWISE_TARGET)
	$(QEMU) $(TEST_TABLE_TARGET)
	$(QEMU) -cpu max $(TEST_HW_TARGET)
	$(PYTHON) tests/test_file_crc32.py --binary $(CLI_TARGET) --qemu $(QEMU) --label table
	$(PYTHON) tests/test_file_crc32.py --binary $(HW_CLI_TARGET) --qemu $(QEMU) --cpu max --label hardware

disasm: $(CLI_TARGET)
	$(OBJDUMP) -d $(CLI_TARGET)

disasm-hw: $(HW_CLI_TARGET)
	$(OBJDUMP) -d $(HW_CLI_TARGET)

disasm-hw-tests: $(TEST_HW_TARGET)
	$(OBJDUMP) -d $(TEST_HW_TARGET)

clean:
	rm -rf build