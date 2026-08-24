CROSS ?= aarch64-linux-gnu

CC := $(CROSS)-gcc
OBJDUMP := $(CROSS)-objdump
QEMU ?= qemu-aarch64

TARGET := build/aarch64-crc32

SOURCES := src/crc32_bitwise.S \
           tests/test_crc32.S

OBJECTS := $(patsubst %.S,build/%.o,$(SOURCES))

LDFLAGS := -nostdlib -static -no-pie -Wl,-e,_start

.PHONY: all run test disasm clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $(OBJECTS)

build/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) -g -c -o $@ $<

run: $(TARGET)
	$(QEMU) $(TARGET)

test: $(TARGET)
	$(QEMU) $(TARGET)

disasm: $(TARGET)
	$(OBJDUMP) -d $(TARGET)

clean:
	rm -rf build