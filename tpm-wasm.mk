#TPM manual WASM release build Makefile
# --- WASI SDK Configuration ---
# Uses the environment variable if set, otherwise defaults to the standard install path
WASI_SDK_PATH ?= /opt/wasi-sdk

CC      = $(WASI_SDK_PATH)/bin/clang
AR      = $(WASI_SDK_PATH)/bin/llvm-ar
RM      = rm -f
CP      = cp -f
MKDIR   = mkdir -p

# Флаги компиляции (исправлен таргет)
CFLAGS  = \
    --sysroot=$(WASI_SDK_PATH)/share/wasi-sysroot \
    --target=wasm32-wasip1 \
    -O2 \
    -Wall \
    -Wextra \
    -DHAVE_MAIN

# Флаги линковки (ОБЯЗАТЕЛЬНО добавлен --sysroot и изменен таргет)
LDFLAGS = \
    --sysroot=$(WASI_SDK_PATH)/share/wasi-sysroot \
    --target=wasm32-wasip1

SRC = src

SOURCES = \
    $(SRC)/tpm.c \
    $(SRC)/prng64_xrp32.c \
    $(SRC)/cfg_parse.c

OBJECTS = \
    tpm.o \
    prng64_xrp32.o \
    cfg_parse.o

.PHONY: all clean dist

all: tpm.wasm

tpm.wasm: $(OBJECTS)
	$(CC) $(LDFLAGS) $(OBJECTS) -o $@

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	$(RM) $(OBJECTS) tpm.wasm
	$(RM) -r tpm-wasm-bin tpm-wasm-bin.tar.gz

dist: all
	$(MKDIR) tpm-wasm-bin
	$(CP) tpm.wasm tpm-wasm-bin
	$(CP) README.md CHANGELOG.md LICENSE toothpastes.sample tpm.conf.sample tpm-wasm-bin 2>/dev/null || true
	tar -czf tpm-wasm-bin.tar.gz tpm-wasm-bin

