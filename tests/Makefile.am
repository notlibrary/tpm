AM_CFLAGS = -Wall -g -lcheck -lsubunit -lm -lrt -lpthread 
TESTS = tpm_battery
check_PROGRAMS = tpm_battery
check_tpm_battery_SOURCES = tpm_battery.c $(top_builddir)/src/tpm.h
check_tpm_battery_CFLAGS = @CHECK_CFLAGS@
check_tpm_battery_LDADD = $(top_builddir)/src/tpm.la @CHECK_LIBS@


tpm_battery_SOURCES = tpm_battery.c $(top_builddir)/src/tpm.c $(top_builddir)/src/cfg_parse.c $(top_builddir)/src/prng64_xrp32.c

OBJECTS = tpm_battery.o $(top_builddir)/src/tpm.o $(top_builddir)/src/prng64_xrp32.o $(top_builddir)/src/cfg_parse.o 
	
	
EXTRA_DIST = tpm_battery.c

tpm_battery: $(OBJECTS)
	$(CC) $(AM_CFLAGS) $(OBJECTS) -o tpm_battery
$(OBJECTS): $(tpm_SOURCES)
	$(CC) $(AM_CFLAGS) -c $(tpm_SOURCES)
	