# TPM WASM build Makefile
CC=emcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f

CFLAGS=-Wall -Os -sSTANDALONE_WASM=1 -sWASM_BIGINT -DHAVE_MAIN --minify=0 -sMODULARIZE=0
CURRENT_DIR=$(CURDIR)
SRC=src
SOURCES=    $(SRC)/tpm.c \
			$(SRC)/prng64_xrp32.c \
			$(SRC)/cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

.PHONY: all clean dist

all: tpm.wasm

tpm.wasm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm.wasm

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@
	
clean:	
	$(RM) tpm.wasm $(OBJECTS)
	$(RM) -r tpm-wasm-bin-amd64
	$(RM) tpm-wasm-bin-amd64.tar.gz

dist: all
	$(MKDIR) tpm-wasm-bin-amd64
	cp tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm.wasm README.md LICENSE tpm-wasm-bin-amd64
	tar -czf tpm-wasm-bin-amd64.tar.gz tpm-wasm-bin-amd64
