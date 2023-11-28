ifeq ($(CC),cc)
CC=$(lastword $(subst /, ,$(shell readlink -f `which cc`)))
endif

ifeq ($(findstring gcc,$(CC)),gcc)
CFLAGS += -Wno-stringop-truncation -Wno-stringop-overflow -Wno-format-truncationA
else
CFLAGS += -stdlib=libc++
endif

PLATFORM ?= $(firstword $(subst -, ,$(CC)))
HOST ?= $(word 2, $(subst -, ,$(CC)))

LIB			= build/libaddons.a

DEFINES  = -DNDEBUG -D_GNU_SOURCE
CFLAGS  += -Wall -Wno-multichar -fPIC -ggdb -O2 $(DEFINES) -fdata-sections -ffunction-sections 

CODECS		= ..

INCLUDE = -I$(CODECS)/alac/codec \
	  -I$(CODECS)/faac/include \
	  -I$(CODECS)/flac/include \
	  -I$(CODECS)/shine/src/lib
		  
SOURCES = alac_wrapper.cpp encoder.c

OBJECTS = $(patsubst %.c,build/%.o,$(filter %.c,$(SOURCES)))
OBJECTS += $(patsubst %.cpp,build/%.o,$(filter %.cpp,$(SOURCES)))

all: directory $(OBJECTS) $(LIB)
directory:
	@mkdir -p build
	
$(LIB): $(OBJECTS)
	$(AR) rcs $@ $^

build/%.o : %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@
	
build/%.o : %.cpp
	$(CXX) $(CFLAGS) $(CPPFLAGS) $(INCLUDE) $< -c -o $@

clean: 
	rm -f $(OBJECTS) $(LIB)

