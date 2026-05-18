AM_CFLAGS = -Os -Wall
bin_PROGRAMS = tpm
tpm_SOURCES = tpm.c cfg_parse.c prng64_xrp32.c
tpm_LINK = $(CCLD) $(AM_CFLAGS) $(CFLAGS) $(AM_LDFLAGS) $(LDFLAGS) -o $@
tpmdir = src
tpm_HEADERS = tpm.h prng64_xrp32.h cfg_parse.h
OBJECTS = tpm.o prng64_xrp32.o cfg_parse.o
EXTRA_DIST = tpm.h prng64_xrp32.h cfg_parse.h

tpm: $(OBJECTS)
	$(CC) $(AM_CFLAGS) $(OBJECTS) -o tpm
$(OBJECTS): $(rpm_SOURCES)
	$(CC) $(AM_CFLAGS) -c $(tpm_SOURCES)