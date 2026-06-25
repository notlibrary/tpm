#TPM WASM makefile

CC=emcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f
CFLAGS=-Wall -Os -sSTANDALONE_WASM=1 -DHAVE_MAIN --minify=0 -sMODULARIZE=0 
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
	
	@if [ -d locale ]; then \
		find locale -name "*.mo" | while read -r mo_file; do \
			lang_dir=$$(dirname "$$mo_file"); \
			$(MKDIR) "tpm-wasm-bin-amd64/$$lang_dir"; \
			cp "$$mo_file" "tpm-wasm-bin-amd64/$$lang_dir/"; \
		done; \
	fi
	
	tar -czf tpm-wasm-bin-amd64.tar.gz tpm-wasm-bin-amd64