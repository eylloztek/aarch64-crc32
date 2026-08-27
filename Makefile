CROSS ?= aarch64-linux-gnu

CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
QEMU ?= qemu-aarch64
PYTHON ?= python3

CLI_TARGET := build/aarch64-crc32
TEST_BITWISE_TARGET := build/test_crc32
TEST_TABLE_TARGET := build/test_crc32_table

COMMON_OBJECT := build/src/crc32_common.o
BITWISE_OBJECT := build/src/crc32_bitwise.o
TABLE_OBJECT := build/src/crc32_table.o
CLI_OBJECT := build/src/main.o
TEST_BITWISE_OBJECT := build/tests/test_crc32.o
TEST_TABLE_OBJECT := build/tests/test_crc32_table.o

LDFLAGS := -nostdlib -static -no-pie -Wl,-e,_start

.PHONY: all run test disasm disasm-bitwise-tests disasm-table-tests clean

all: $(CLI_TARGET) $(TEST_BITWISE_TARGET) $(TEST_TABLE_TARGET)

$(CLI_TARGET): $(COMMON_OBJECT) $(TABLE_OBJECT) $(CLI_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_BITWISE_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(TEST_BITWISE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_TABLE_TARGET): $(COMMON_OBJECT) $(BITWISE_OBJECT) $(TABLE_OBJECT) $(TEST_TABLE_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

build/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) -g -c -o $@ $<

run: $(CLI_TARGET)
	@if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=<path>"; exit 2; fi
	$(QEMU) $(CLI_TARGET) "$(FILE)"

test: $(CLI_TARGET) $(TEST_BITWISE_TARGET) $(TEST_TABLE_TARGET)
	$(QEMU) $(TEST_BITWISE_TARGET)
	$(QEMU) $(TEST_TABLE_TARGET)
	$(PYTHON) tests/test_file_crc32.py --binary $(CLI_TARGET) --qemu $(QEMU)

disasm: $(CLI_TARGET)
	$(OBJDUMP) -d $(CLI_TARGET)

disasm-bitwise-tests: $(TEST_BITWISE_TARGET)
	$(OBJDUMP) -d $(TEST_BITWISE_TARGET)

disasm-table-tests: $(TEST_TABLE_TARGET)
	$(OBJDUMP) -d $(TEST_TABLE_TARGET)

clean:
	rm -rf build