SUBDIRS = src . tests
dist_doc_DATA = README.md
man_MANS = tpm.1
EXTRA_DIST = tpm.conf.sample toothpastes.sample toothpastes-enhanced.sample tpm-ubuntu.mk tpm.1 pick.sql LICENSE

localedir = $(datadir)/locale

nobase_nodist_locale_DATA = $(wildcard locale/*/LC_MESSAGES/*.mo)

dist-hook:
	@if [ -d $(srcdir)/locale ]; then \
		echo "Copying compiled .mo files to dist package..."; \
		cd $(srcdir) && find locale -name "*.mo" | while read -r mo_file; do \
			$(MKDIR_P) "$(distdir)/`dirname $$mo_file`"; \
			cp -f "$$mo_file" "$(distdir)/$$mo_file"; \
		done; \
	fi

clean-local:
	rm -f locale/*/LC_MESSAGES/*.mo