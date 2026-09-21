# Build libgrafcet_static: the C bridge linked against the Lean runtime and
# the Lean-produced module library. `lake build` must run first.
#
# lake names that library for the platform and this named it .dylib
# everywhere, so a Linux link failed on a file lake never produces:
#
#   ld: cannot find -l:libtaskweft_..._TaskweftGrafcetStatic.dylib
#
# Windows differs in two ways, not one: the extension is .dll AND there is no
# lib prefix. Measured by running lake there, which is the only way it shows --
# a Darwin/else split looks correct until a third platform arrives.
#
#   macOS    lib<name>.dylib
#   Linux    lib<name>.so
#   Windows     <name>.dll

LEAN_TOOLCHAIN := $(shell lean --print-prefix)
LEAN_INCLUDE   := $(LEAN_TOOLCHAIN)/include
LEAN_LIB       := $(LEAN_TOOLCHAIN)/lib/lean

LAKE_LIB       := .lake/build/lib
MODULE_NAME    := taskweft_x2dgrafcet_x2dstatic_TaskweftGrafcetStatic

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    MODULE_FILE := lib$(MODULE_NAME).dylib
else ifneq (,$(filter MINGW% MSYS% CYGWIN%,$(UNAME_S)))
    MODULE_FILE := $(MODULE_NAME).dll
else
    MODULE_FILE := lib$(MODULE_NAME).so
endif

MODULE_LIB := $(LAKE_LIB)/$(MODULE_FILE)

CC     := cc
CFLAGS := -fPIC -O2 -Wall -I$(LEAN_INCLUDE) -Ic_src
LDFLAGS_MAC := -shared -Wl,-rpath,@loader_path -Wl,-rpath,$(LEAN_LIB)

ifeq ($(UNAME_S),Darwin)
    OUT := libgrafcet_static.dylib
    LDFLAGS := $(LDFLAGS_MAC) -install_name @rpath/libgrafcet_static.dylib \
               -L$(LEAN_LIB) -Wl,-rpath,$(LEAN_LIB) \
               -lleanshared -Wl,$(MODULE_LIB)
else
    OUT := libgrafcet_static.so
    LDFLAGS := -shared -L$(LEAN_LIB) -Wl,-rpath,$$ORIGIN \
               -Wl,-rpath,$(LEAN_LIB) -lleanshared -l:$(notdir $(MODULE_LIB))
endif

all: $(OUT)

$(OUT): c_src/grafcet_static_bridge.c $(MODULE_LIB)
	$(CC) $(CFLAGS) c_src/grafcet_static_bridge.c $(LDFLAGS) -o $@

$(MODULE_LIB):
	lake build

clean:
	rm -f $(OUT)

.PHONY: all clean
