# Build libgrafcet_static.dylib: the C bridge linked against the Lean
# runtime and the Lean-produced module dylib. `lake build` must run
# first (produces .lake/build/lib/lib*.dylib and the module .c objects).

LEAN_TOOLCHAIN := $(shell lean --print-prefix)
LEAN_INCLUDE   := $(LEAN_TOOLCHAIN)/include
LEAN_LIB       := $(LEAN_TOOLCHAIN)/lib/lean

LAKE_LIB       := .lake/build/lib
MODULE_DYLIB   := $(LAKE_LIB)/libtaskweft_x2dgrafcet_x2dstatic_TaskweftGrafcetStatic.dylib

CC     := cc
CFLAGS := -fPIC -O2 -Wall -I$(LEAN_INCLUDE) -Ic_src
LDFLAGS_MAC := -shared -Wl,-rpath,@loader_path -Wl,-rpath,$(LEAN_LIB)

UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    OUT := libgrafcet_static.dylib
    LDFLAGS := $(LDFLAGS_MAC) -install_name @rpath/libgrafcet_static.dylib \
               -L$(LEAN_LIB) -Wl,-rpath,$(LEAN_LIB) \
               -lleanshared -Wl,$(MODULE_DYLIB)
else
    OUT := libgrafcet_static.so
    LDFLAGS := -shared -L$(LEAN_LIB) -Wl,-rpath,$$ORIGIN \
               -Wl,-rpath,$(LEAN_LIB) -lleanshared -l:$(notdir $(MODULE_DYLIB))
endif

all: $(OUT)

$(OUT): c_src/grafcet_static_bridge.c $(MODULE_DYLIB)
	$(CC) $(CFLAGS) c_src/grafcet_static_bridge.c $(LDFLAGS) -o $@

$(MODULE_DYLIB):
	lake build

clean:
	rm -f $(OUT)

.PHONY: all clean
