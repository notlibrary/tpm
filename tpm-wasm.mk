CC=emcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f

# Added -DENABLE_NLS=1 and forced the LOCALEDIR virtual root to /locale inside the WASM filesystem
# Added --embed-file to bundle the virtual locale directory directly inside the binary
CFLAGS=-Wall -Os -sSTANDALONE_WASM=1 -DHAVE_MAIN --minify=0 -sMODULARIZE=0 -DENABLE_NLS=1 -DLOCALEDIR=\"/locale\"
CURRENT_DIR=$(CURDIR)
SRC=src
SOURCES=    $(SRC)/tpm.c \
			$(SRC)/prng64_xrp32.c \
			$(SRC)/cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

.PHONY: all clean dist update-po

# Ensure update-po runs BEFORE tpm.wasm is linked so the files exist to be embedded
all: update-po tpm.wasm

tpm.wasm: $(OBJECTS)
	$(CC) $(CFLAGS) --embed-file locale@/locale $(OBJECTS) -o tpm.wasm

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

update-po:
	@find . -maxdepth 2 -name "tpm.po" 2>/dev/null | while read -r po_file; do \
		lang=$$(basename $$(dirname "$$po_file")); \
		if [ "$$lang" != "." ] && [ "$$lang" != "src" ] && [ "$$lang" != "locale" ]; then \
			$(MKDIR) "locale/$$lang/LC_MESSAGES"; \
			msgfmt "$$po_file" -o "locale/$$lang/LC_MESSAGES/tpm.mo"; \
		fi; \
	done
	
clean:	
	$(RM) tpm.wasm $(OBJECTS)
	$(RM) -r tpm-wasm-bin-amd64
	$(RM) tpm-wasm-bin-amd64.tar.gz
	find . -type f -name "*.mo" -delete

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
	