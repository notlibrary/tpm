CC=gcc
CP=cp -f
MKDIR=mkdir -p
RM=rm
CFLAGS=
CURRENT_DIR=$(CURDIR)
SOURCES=    tpm.c \
			prng64_xrp32.c \
			cfg_parse.c
			
OBJECTS=    tpm.o \
			prng64_xrp32.o \
			cfg_parse.o

all: tpm install clean
tpm: $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o tpm
$(OBJECTS): $(SOURCES)
	$(CC) $(CFLAGS) -c $(SOURCES)
install: 
	cp $(CURRENT_DIR)/tpm /usr/local/bin/
clean:	
	rm $(CURRENT_DIR)/tpm $(OBJECTS)
distr:
	mkdir -p tpm-linux-bin
	cp tpm.conf.sample toothpastes.sample tpm README.md tpm-linux-bin
	tar -czf tpm-linux-bin.tar.gz tpm-linux-bin