#TPM WASM makefile

CC=emcc
CP=cp -f
MKDIR=mkdir -p
RM=rm
CFLAGS=-Wall -Os sSTANDALONE_WASM=1 --minify=0 -sMODULARIZE=0 
CURRENT_DIR=$(CURDIR)
SRC=src
SOURCES=    $(SRC)/tpm.c \
			$(SRC)/prng64_xrp32.c \
			$(SRC)/cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

.PHONY: all clean

all: tpm.wasm clean
tpm.wasm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm.wasm
$(OBJECTS): $(SOURCES)
	$(CC) $(CFLAGS) -c $(SOURCES)
clean:	
	rm $(CURRENT_DIR)/tpm.wasm $(OBJECTS)
	rm -rf tpm-wasm-bin-amd64
dist:
	mkdir -p tpm-wasm-bin-amd64
	cp tpm.conf.sample toothpastes.sample tpm.wasm README.md tpm-wasm-bin-amd64
	tar -czf tpm-wasm-bin-amd64.tar.gz tpm-wasm-bin-amd64
