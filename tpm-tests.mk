#TPM Tests makefile

CC=gcc
CP=cp -f
MKDIR=mkdir -p
RM=rm -f
CFLAGS=-Wall -g 
LIBS=-pthread -lcheck_pic -lcheck -lpthread -lrt -lm -lsubunit
SRC=src

LIB_SOURCES= $(SRC)/tpm.c $(SRC)/prng64_xrp32.c $(SRC)/cfg_parse.c
TEST_SOURCES= tests/tpm_battery.c

OBJECTS= tpm.o prng64_xrp32.o cfg_parse.o tpm_battery.o

.PHONY: all clean check

all: tpm_battery

%.o: $(SRC)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: tests/%.c
	$(CC) $(CFLAGS) -c $< -o $@

tpm_battery: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm_battery $(LIBS)

check: tpm_battery
	@echo fire TPM tests 
	./tpm_battery

clean:
	$(RM) *.o tpm_battery