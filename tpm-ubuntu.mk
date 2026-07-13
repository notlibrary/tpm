#TPM manual Ubuntu Makefile
CC=gcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f

PREFIX    = /usr/local
BINDIR    = $(PREFIX)/bin
SHAREDIR  = $(PREFIX)/share
MANDIR    = $(SHAREDIR)/man/man1
LOCALEDIR = $(SHAREDIR)/locale

CFLAGS=-Wall -Os -DHAVE_MAIN -DENABLE_NLS=1 -DLOCALEDIR=\"$(LOCALEDIR)\"
CURRENT_DIR=$(CURDIR)
SRC=src
SOURCES=    $(SRC)/tpm.c \
			$(SRC)/prng64_xrp32.c \
			$(SRC)/cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

.PHONY: all install uninstall clean dist update-po

all: tpm docs update-po

tpm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

docs:
	gzip -k -f tpm.1

update-po:
	@find . -maxdepth 3 -name "*.po" 2>/dev/null | while read -r po_file; do \
		lang=$${po_file%/tpm.po}; lang=$${lang##*/}; \
		if [ -n "$$lang" ] && [ "$$lang" != "." ] && [ "$$lang" != "src" ]; then \
			$(MKDIR) "locale/$$lang/LC_MESSAGES"; \
			msgfmt "$$po_file" -o "locale/$$lang/LC_MESSAGES/tpm.mo"; \
			echo "Compiled $$po_file -> locale/$$lang/LC_MESSAGES/tpm.mo"; \
		fi; \
	done
	
install: all
	$(MKDIR) $(DESTDIR)$(BINDIR)
	$(CP) $(CURRENT_DIR)/tpm $(DESTDIR)$(BINDIR)/
	
	$(MKDIR) $(DESTDIR)$(MANDIR)
	$(CP) tpm.1.gz $(DESTDIR)$(MANDIR)/tpm.1.gz
	
	@if [ -d locale ]; then \
		find locale -name "*.mo" | while read -r mo_file; do \
			lang_dir=$$(dirname "$$mo_file"); \
			$(MKDIR) "$(DESTDIR)$(SHAREDIR)/$$lang_dir"; \
			$(CP) "$$mo_file" "$(DESTDIR)$(SHAREDIR)/$$lang_dir/"; \
		done; \
	fi

uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/tpm
	$(RM) $(DESTDIR)$(MANDIR)/tpm.1.gz
	$(RM) -r $(DESTDIR)$(LOCALEDIR)/fr/LC_MESSAGES/tpm.mo

clean:	
	$(RM) tpm $(OBJECTS)
	$(RM) -r tpm-linux-bin-amd64 dist
	$(RM) tpm.1.gz tpm-linux-bin-amd64.tar.gz
	find . -type f -name "*.mo" -delete

dist: all
	$(RM) -r tpm-linux-bin-amd64
	$(MKDIR) tpm-linux-bin-amd64
	$(CP) tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm README.md tpm.1.gz LICENSE tpm-linux-bin-amd64/ 2>/dev/null || true
	
	@if [ -d locale ]; then \
		find locale -name "*.mo" | while read -r mo_file; do \
			lang_dir=$$(dirname "$$mo_file"); \
			$(MKDIR) "tpm-linux-bin-amd64/$$lang_dir"; \
			$(CP) "$$mo_file" "tpm-linux-bin-amd64/$$lang_dir/"; \
		done; \
	fi
	
	tar -czf tpm-linux-bin-amd64.tar.gz tpm-linux-bin-amd64