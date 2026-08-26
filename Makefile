CROSS ?= aarch64-linux-gnu

CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
QEMU ?= qemu-aarch64
PYTHON ?= python3

CLI_TARGET := build/aarch64-crc32
TEST_TARGET := build/test_crc32

CRC_OBJECT := build/src/crc32_bitwise.o
CLI_OBJECT := build/src/main.o
TEST_OBJECT := build/tests/test_crc32.o

LDFLAGS := -nostdlib -static -no-pie -Wl,-e,_start

.PHONY: all run test disasm disasm-tests clean

all: $(CLI_TARGET) $(TEST_TARGET)

$(CLI_TARGET): $(CRC_OBJECT) $(CLI_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

$(TEST_TARGET): $(CRC_OBJECT) $(TEST_OBJECT)
	$(CC) $(LDFLAGS) -o $@ $^

build/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) -g -c -o $@ $<

run: $(CLI_TARGET)
	@if [ -z "$(FILE)" ]; then echo "Usage: make run FILE=<path>"; exit 2; fi
	$(QEMU) $(CLI_TARGET) "$(FILE)"

test: $(CLI_TARGET) $(TEST_TARGET)
	$(QEMU) $(TEST_TARGET)
	$(PYTHON) tests/test_file_crc32.py --binary $(CLI_TARGET) --qemu $(QEMU)

disasm: $(CLI_TARGET)
	$(OBJDUMP) -d $(CLI_TARGET)

disasm-tests: $(TEST_TARGET)
	$(OBJDUMP) -d $(TEST_TARGET)

clean:
	rm -rf build