AM_CFLAGS = -Wall -g 
LIBS=-pthread -lcheck_pic -lcheck -lpthread -lrt -lm -lsubunit
TESTS = tpm_battery
SRC=src
check_PROGRAMS = tpm_battery
check_tpm_battery_SOURCES = tpm_battery.c $(top_builddir)/src/tpm.h
check_tpm_battery_CFLAGS = @CHECK_CFLAGS@
check_tpm_battery_LDADD = $(top_builddir)/src/tpm.la @CHECK_LIBS@

tpm_battery_LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o $@
tpm_battery_SOURCES = $(top_builddir)/src/tpm.c $(top_builddir)/src/cfg_parse.c $(top_builddir)/src/prng64_xrp32.c
TEST_SOURCES=tpm_battery.c
OBJECTS = tpm_battery.o tpm.o $(top_builddir)/src/prng64_xrp32.o $(top_builddir)/src/cfg_parse.o 
	
	
EXTRA_DIST = tpm_battery.c

%.o: $(top_builddir)/$(SRC)/%.c
	$(CC) $(AM_CFLAGS) -c $< -o $@

%.o: $(top_builddir)/tests/%.c
	$(CC) $(AM_CFLAGS) -c $< -o $@

tpm_battery: $(OBJECTS)
	$(CC) $(AM_CFLAGS) $(OBJECTS) -o tpm_battery $(LIBS)
