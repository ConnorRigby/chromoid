# Makefile for building the PORT
#
# Makefile targets:
#
# all/install   build and install the PORT
# clean         clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj

NIF = $(PREFIX)/nfc_nif.so

CFLAGS ?= -O2 -Wno-unused-parameter -pedantic -Wall
CFLAGS += $(TARGET_CFLAGS) -Wall -pedantic

CFLAGS += -I$(PREFIX)/include/nfc
CFLAGS += -I$(PREFIX)/include/
LDFLAGS += -L$(PREFIX)/lib/

LDFLAGS += -fPIC -shared
CFLAGS += -fPIC

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

SRC = $(PREFIX)/lib/libnfc.so src/nfc-utils.c src/nfc_nif.c
HEADERS =$(wildcard src/*.h)
OBJ = $(SRC:src/%.c=$(BUILD)/%.o)

calling_from_make:
	mix compile

all: install

install: $(PREFIX) $(BUILD) $(NIF) $(PREFIX)/libnfc.conf

$(PREFIX)/libnfc.conf: config/libnfc.conf
	cp config/libnfc.conf $(PREFIX)/libnfc.conf

$(PREFIX)/lib/libnfc.so: $(BUILD)/libnfc-1.8.0.tar.bz2
	tar -xf $(BUILD)/libnfc-1.8.0.tar.bz2 -C $(BUILD)
	mkdir -p $(BUILD)/libnfc-1.8.0/build
	cd $(BUILD)/libnfc-1.8.0/build && \
	cmake \
	-DLIBNFC_DRIVER_PN53X_USB=no \
	-DLIBNFC_DRIVER_ACR122_USB=no \
	-DLIBNFC_DRIVER_ACR122_USB=no \
	-DLIBNFC_DRIVER_PCSC=no \
	-DLIBNFC_DRIVER_ACR122_PCSC=no \
	-DCMAKE_INSTALL_PREFIX=$(PREFIX) \
	-DLIBNFC_SYSCONFDIR=$(PREFIX) \
	../ && \
	make install
	touch $(PREFIX)/lib/libnfc.so

$(BUILD)/libnfc-1.8.0.tar.bz2:
	wget -O $(BUILD)/libnfc-1.8.0.tar.bz2 https://github.com/nfc-tools/libnfc/releases/download/libnfc-1.8.0/libnfc-1.8.0.tar.bz2

$(OBJ): $(HEADERS) Makefile

$(BUILD)/%.o: src/%.c
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

$(NIF): $(OBJ)
	$(CC) -o $@ $(ERL_LDFLAGS) $(LDFLAGS) -lnfc $^

$(PREFIX) $(BUILD):
	mkdir -p $@

format:
	astyle --style=kr --indent=spaces=4 --align-pointer=name \
	    --align-reference=name --convert-tabs --attach-namespaces \
	    --max-code-length=100 --max-instatement-indent=120 --pad-header \
	    --pad-oper \
	    src/hci_transport.c

clean:
	$(RM) $(NIF) $(OBJ)

.PHONY: all clean calling_from_make install format
