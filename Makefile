# NIF for the FBD static analyser. Links against the Lean-produced
# analyser and C bridge from RFD 2144, vendored at
# thirdparty/taskweft-fbd-static.
#
# It was ../taskweft-fbd-static, a sibling checkout the goal manifest
# places. That path exists on a desk and nowhere else, so CI clones this
# repository alone and the build stopped at "No such file or directory". A
# submodule is blocklisted -- repo status cannot see a second dependency
# mechanism -- so the source is subtree'd in and is an ordinary directory.

ERL_INCLUDE := $(shell erl -eval 'io:format("~ts", [code:root_dir()])' -s init stop -noshell)/erts-$(shell erl -eval 'io:format("~ts", [erlang:system_info(version)])' -s init stop -noshell)/include

STATIC_ROOT := thirdparty/taskweft-fbd-static

CXX     := c++
CXXFLAGS := -std=c++17 -O2 -fPIC -Wall -I$(ERL_INCLUDE)

UNAME_S := $(shell uname -s)
# The analyser is a dylib on macOS and a shared object elsewhere; the NIF is
# .so on both, because that is what the emulator loads. Naming the analyser
# .dylib unconditionally, as this did, meant the target never existed on Linux
# and make had nothing to build.
ifeq ($(UNAME_S),Darwin)
    LDFLAGS := -shared -undefined dynamic_lookup -Wl,-rpath,@loader_path
    SO_EXT := so
    LIB_EXT := dylib
else
    LDFLAGS := -shared -Wl,-rpath,\$$ORIGIN
    SO_EXT := so
    LIB_EXT := so
endif

STATIC_LIB := $(STATIC_ROOT)/libfbd_static.$(LIB_EXT)

TARGET := priv/fbd_static_nif.$(SO_EXT)
PRIV_LIB := priv/libfbd_static.$(LIB_EXT)

all: $(TARGET) $(PRIV_LIB)

$(STATIC_LIB):
	$(MAKE) -C $(STATIC_ROOT)

$(TARGET): c_src/fbd_static_nif.cpp $(STATIC_LIB)
	@mkdir -p priv
	$(CXX) $(CXXFLAGS) c_src/fbd_static_nif.cpp \
	  -L$(STATIC_ROOT) -lfbd_static \
	  $(LDFLAGS) -o $@

$(PRIV_LIB): $(STATIC_LIB)
	@mkdir -p priv
	cp $(STATIC_LIB) $(PRIV_LIB)

clean:
	rm -f $(TARGET) $(PRIV_LIB)

.PHONY: all clean
