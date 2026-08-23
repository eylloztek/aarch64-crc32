CROSS ?= aarch64-linux-gnu

CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
QEMU ?= qemu-aarch64

TARGET := build/aarch64-crc32
SRC := src/main.S

LDFLAGS := -nostdlib -static -no-pie -Wl,-e,_start

.PHONY: all run test disasm clean

all: $(TARGET)

$(TARGET): $(SRC) | build
	$(CC) -g $(LDFLAGS) -o $@ $<

build:
	mkdir -p build

run: $(TARGET)
	$(QEMU) $(TARGET)

test: $(TARGET)
	$(QEMU) $(TARGET)

disasm: $(TARGET)
	$(OBJDUMP) -d $(TARGET)

clean:
	rm -rf build