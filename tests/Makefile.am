check_PROGRAMS = tpm_battery
tpm_battery_SOURCES = \
    tpm_battery.c \
    $(top_srcdir)/src/tpm.c \
    $(top_srcdir)/src/cfg_parse.c \
    $(top_srcdir)/src/prng64_xrp32.c

tpm_battery_CFLAGS = -Wall -g -I$(top_srcdir)/src -DTESTING
tpm_battery_LDADD = -lcheck -lsubunit -lrt -lm -lpthread
TESTS = tpm_battery
EXTRA_DIST = tpm_battery.c