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

PREFIX    = /usr/local
BINDIR    = $(PREFIX)/bin
SHAREDIR  = $(PREFIX)/share
MANDIR    = $(SHAREDIR)/man/man1
LOCALEDIR = $(SHAREDIR)/locale

.PHONY: all install uninstall clean dist

all: tpm docs

tpm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

docs:
	gzip -k -f tpm.1

install: all
	$(MKDIR) $(DESTDIR)$(BINDIR)
	cp $(CURRENT_DIR)/tpm $(DESTDIR)$(BINDIR)/
	
	$(MKDIR) $(DESTDIR)$(MANDIR)
	cp tpm.1.gz $(DESTDIR)$(MANDIR)/tpm.1.gz
	
	@if [ -d locale ]; then \
		find locale -name "*.mo" | while read -r mo_file; do \
			lang_dir=$$(dirname "$$mo_file"); \
			$(MKDIR) "$(DESTDIR)$(SHAREDIR)/$$lang_dir"; \
			cp "$$mo_file" "$(DESTDIR)$(SHAREDIR)/$$lang_dir/"; \
		done; \
	fi

uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/tpm
	$(RM) $(DESTDIR)$(MANDIR)/tpm.1.gz
	$(RM) $(DESTDIR)$(LOCALEDIR)/*/LC_MESSAGES/tpm.mo

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
