CC=gcc
CP=cp -f
MKDIR=mkdir -p
RM=rm
CFLAGS=
CURRENT_DIR=$(CURDIR)
all: tpm install clean

tpm: 
	$(CC) $(CFLAGS) tpm.c -o tpm
install: 
	cp $(CURRENT_DIR)/tpm /usr/local/bin/
clean:	
	rm $(CURRENT_DIR)/tpm 
