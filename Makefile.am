SUBDIRS = src . tests
dist_doc_DATA = README.md
man_MANS = tpm.1
EXTRA_DIST = tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm-ubuntu.mk tpm.1 pick.sql LICENSE

AM_CFLAGS = -DENABLE_NLS=1 -DLOCALEDIR=\"$(localedir)\"

PO_FILES = $(shell find . -maxdepth 2 -name "tpm.po" 2>/dev/null)
MO_FILES = $(patsubst ./%,locale/%/LC_MESSAGES/tpm.mo,$(patsubst %/tpm.po,%,$(PO_FILES)))

mylocaledir = $(datadir)/locale
nobase_nodist_mylocale_DATA = $(MO_FILES)

all-local: $(MO_FILES)

locale/%/LC_MESSAGES/tpm.mo: %/tpm.po
	$(MKDIR_P) locale/$*/LC_MESSAGES
	$(MSGFMT) $< -o $@

dist-hook:
	@if [ -d $(srcdir)/locale ]; then \
		echo "Copying compiled .mo files to dist package..."; \
		cd $(srcdir) && find locale -name "*.mo" | while read -r mo_file; do \
			$(MKDIR_P) "$(distdir)/`dirname $$mo_file`"; \
			cp -f "$$mo_file" "$(distdir)/$$mo_file"; \
		done; \
	fi

clean-local:
	find . -type f -name "*.mo" -delete