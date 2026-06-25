#TPM Linux makefile
#Used to manually build on Ubuntu 
#Alternative to other unixes is autotools tarball build
CC=gcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f
CFLAGS=-Wall -Os -DHAVE_MAIN
CURRENT_DIR=$(CURDIR)
SRC=src
SOURCES=    $(SRC)/tpm.c \
			$(SRC)/prng64_xrp32.c \
			$(SRC)/cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

.PHONY: all install clean dist

all: tpm docs

tpm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

docs:
	gzip -k -f tpm.1

install: all
	cp $(CURRENT_DIR)/tpm /usr/local/bin/
	cp tpm.1.gz /usr/share/man/man1/tpm.1.gz

clean:	
	$(RM) tpm $(OBJECTS)
	$(RM) -r tpm-linux-bin-amd64 dist
	$(RM) tpm.1.gz tpm-linux-bin-amd64.tar.gz

dist: all
	$(MKDIR) tpm-linux-bin-amd64
	cp tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm README.md tpm.1.gz LICENSE tpm-linux-bin-amd64
	
	@if [ -d locale ]; then \
		find locale -name "*.mo" | while read -r mo_file; do \
			lang_dir=$$(dirname "$$mo_file"); \
			$(MKDIR) "tpm-linux-bin-amd64/$$lang_dir"; \
			cp "$$mo_file" "tpm-linux-bin-amd64/$$lang_dir/"; \
		done; \
	fi
	
	tar -czf tpm-linux-bin-amd64.tar.gz tpm-linux-bin-amd64
