SUBDIRS = src . tests
dist_doc_DATA = README.md
man_MANS = tpm.1
EXTRA_DIST = tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm-ubuntu.mk tpm.1 pick.sql LICENSE locale/tpm.pot

AM_CFLAGS = -DENABLE_NLS=1 -DLOCALEDIR=\"$(localedir)\"

PO_FILES = $(shell find . -maxdepth 3 -name "tpm.po" 2>/dev/null)
MO_FILES = $(patsubst ./%,locale/%/LC_MESSAGES/tpm.mo,$(patsubst %/tpm.po,%,$(PO_FILES)))

mylocaledir = $(datadir)/locale
nobase_nodist_mylocale_DATA = $(MO_FILES)

all-local: $(MO_FILES)

locale/%/LC_MESSAGES/tpm.mo: %/tpm.po
	$(MKDIR_P) locale/$*/LC_MESSAGES
	$(MSGFMT) $< -o $@

dist-hook:
	@echo "Copying source .po files from $(srcdir) to dist package..."
	@find "$(srcdir)/locale" -name "tpm.po" 2>/dev/null | while read -r po_file; do \
		lang=$${po_file%/tpm.po}; lang=$${lang##*/}; \
		if [ -n "$$lang" ] && [ "$$lang" != "locale" ]; then \
			$(MKDIR_P) "$(distdir)/locale/$$lang"; \
			cp -f "$$po_file" "$(distdir)/locale/$$lang/tpm.po"; \
			echo "Distributed: locale/$$lang/tpm.po"; \
		fi; \
	done

clean-local:
	find . -type f -name "*.mo" -delete
