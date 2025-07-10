# =================================================================================
# DarkPlacesRM Engine Component Makefile
#
# This Makefile is designed to be both:
# 1. A standalone build system that can auto-detect the user's platform.
# 2. An integrable component that respects configuration passed from a parent.
#
# All auto-detection uses the '?=' operator, allowing variables like CC,
# DP_MAKE_TARGET, etc., to be overridden by the calling environment.
# =================================================================================

# VPATH is used in recursive calls from the 'build-obj' directories.
VPATH := ../../../

# Platform Auto-Detection (if not provided by parent)
ifndef DP_MAKE_TARGET
	ifeq ($(OS),Windows_NT)
		DP_MAKE_TARGET := mingw
	else
		UNAME_S := $(shell uname -s)
		ifeq ($(UNAME_S),Linux)
			DP_MAKE_TARGET := linux
		else ifeq ($(UNAME_S),Darwin)
			DP_MAKE_TARGET := macosx
		else ifneq ($(filter %BSD,$(UNAME_S)),)
			DP_MAKE_TARGET := bsd
		else ifeq ($(UNAME_S),SunOS)
			DP_MAKE_TARGET := sunos
		endif
	endif
endif

# Default Toolchain and Configurable Variables
CC?=$(CROSSPREFIX)gcc
STRIP?=strip
WINDRES?=$(CROSSPREFIX)windres
SDL_CONFIG?=sdl2-config

# Configurable paths for the Web (Emscripten) build
HTML_SHELL_FILE?=$(VPATH)rexuiz-in.html
HTML_PRELOAD_DIR?=$(VPATH)webassets@/

# Default Optimizations and Features (can be overridden)
CPUOPTIMIZATIONS?=-fno-math-errno -ffinite-math-only -fno-rounding-math -fno-signaling-nans -fno-trapping-math
DP_VIDEO_CAPTURE?=enabled
DP_VOIP?=enabled
DP_LINK_ZLIB?=shared
DP_LINK_JPEG?=shared
DP_LINK_PNG?=shared
DP_LINK_OGGVORBIS?=shared
DP_LINK_OPUS?=shared
DP_LINK_VPX?=shared
DP_LIBMICROHTTPD?=static

# SSE detection (only if not provided)
ifndef DP_SSE
	UNAME_M := $(shell uname -m)
	ifeq ($(filter x86_64 i%86, $(UNAME_M)),)
		DP_SSE := 0
	else
		DP_SSE := 1
	endif
endif

# Filesystem Configuration
DP_FS_USERDIRMODE?=USERDIRMODE_SAVEDGAMES
ifdef DP_FS_BASEDIR
    CFLAGS_FS:=-DDP_FS_BASEDIR=\"$(DP_FS_BASEDIR)\"
endif
CFLAGS_FS+=-DUSERDIRMODE_PREFERED=$(DP_FS_USERDIRMODE)

# Static variable definitions that depend on the above configs
ifeq ($(DP_SDL_STATIC),yes)
	SDLCONFIG_LIBS?=`$(SDL_CONFIG) --static-libs`
else
	SDLCONFIG_LIBS?=`$(SDL_CONFIG) --libs`
endif
SDLCONFIG_CFLAGS?=`$(SDL_CONFIG) --cflags`

ifeq ($(DP_VIDEO_CAPTURE), enabled)
	CFLAGS_VIDEO_CAPTURE=-DCONFIG_VIDEO_CAPTURE
	OBJ_VIDEO_CAPTURE=cap_avi.o cap_ogg.o
else
	CFLAGS_VIDEO_CAPTURE=
	OBJ_VIDEO_CAPTURE=
endif

ifeq ($(DP_VOIP), enabled)
	CFLAGS_VOIP=-DCONFIG_VOIP
	OBJ_VOIP=snd_voip.o
else
	CFLAGS_VOIP=
	OBJ_VOIP=
endif

# Object File Lists
OBJ_SND_COMMON=snd_main.o snd_mem.o snd_mix.o snd_ogg.o snd_wav.o $(OBJ_VOIP)
OBJ_CD_COMMON=cd_shared.o

OBJ_CL= \
	gl_backend.o gl_rmain.o gl_textures.o cl_input.o r_shadow.o \
	sbar.o cl_particles.o cl_screen.o cl_video.o clvm_cmds.o gl_draw.o \
	gl_rsurf.o meshqueue.o r_explosion.o r_lerpanim.o r_lightning.o \
	r_modules.o r_sky.o r_sprites.o vid_shared.o vid_touchscreen.o \
	ft2.o csprogs.o cl_parse.o cl_main.o cl_demo.o keys.o timedemo.o \
	wad.o cl_dyntexture.o cl_collision.o discord.o dpvsimpledecode.o \
	view.o net_file_client.o

OBJ_COMMON= \
	palette.o crypto.o host.o mathlib.o image.o sv_main.o world.o bih.o \
	cmd.o collision.o common.o console.o curves.o cvar.o filematch.o \
	fractalnoise.o fs.o utf8lib.o hmac.o host_cmd.o image_png.o jpeg.o \
	lhnet.o libcurl.o matrixlib.o mdfour.o \
	mod_skeletal_animatevertices_sse.o mod_skeletal_animatevertices_generic.o \
	model_alias.o model_brush.o model_shared.o model_sprite.o \
	net_httpserver.o netconn.o polygon.o protocol.o prvm_cmds.o prvm_edict.o \
	prvm_exec.o random.o sha256.o siphash.o stats.o sv_demo.o sv_move.o \
	sv_phys.o sv_user.o svbsp.o svvm_cmds.o sys_shared.o zone.o slre.o \
	model_compile.o net_file_server.o model_assimp.c

OBJ_MENU=menu.o mvm_cmds.o

ifeq ($(DP_MAKE_TARGET), mingw)
	OBJ_SV_THREAD=thread_win.o
else
	OBJ_SV_THREAD=thread_pthread.o
endif

# builddate.c is not compiled to a .o because it should be recompiled every time
OBJ_SV= builddate.c sys_sv.o $(OBJ_SV_THREAD) $(OBJ_COMMON)
OBJ_SDL= builddate.c sys_sdl.o vid_sdl.o thread_sdl.o $(OBJ_MENU) $(OBJ_SND_COMMON) snd_sdl.o $(OBJ_CD_COMMON) $(OBJ_VIDEO_CAPTURE) $(OBJ_COMMON) $(OBJ_CL)

# Compilation Flags
CFLAGS_COMMON=$(CFLAGS_MAKEDEP) $(CFLAGS_FS) $(CFLAGS_WARNINGS) $(CFLAGS_LIBZ) $(CFLAGS_LIBJPEG) $(CFLAGS_LIBPNG) $(CFLAGS_NET) $(CFLAGS_LIBMICROHTTPD) $(CFLAGS_VOIP) -D_FILE_OFFSET_BITS=64 -D__KERNEL_STRICT_NAMES -I.
CFLAGS_CLIENT=-DCONFIG_MENU -DCONFIG_CD $(CFLAGS_VIDEO_CAPTURE) $(CFLAGS_OGGVORBIS) $(CFLAGS_OPUS) $(CFLAGS_FREETYPE) $(CFLAGS_GL) $(CFLAGS_VPX)
CFLAGS_SERVER=-DCONFIG_SV
CFLAGS_DEBUG=-ggdb -fsanitize=address,bounds
CFLAGS_PROFILE=-g -pg -ggdb -fprofile-arcs
CFLAGS_RELEASE=
CFLAGS_RELEASE_PROFILE=-fbranch-probabilities
CFLAGS_SDL=
CFLAGS_WARNINGS=-Wall -Wno-ignored-optimization-argument -Wno-unused-command-line-argument -Wno-missing-field-initializers -Wold-style-definition -Wstrict-prototypes -Wsign-compare -Wdeclaration-after-statement -Wmissing-prototypes

ifeq ($(DP_SSE),1)
	CFLAGS_SSE=-msse
	CFLAGS_SSE2=-msse2
else
	CFLAGS_SSE=
	CFLAGS_SSE2=
endif

OPTIM_DEBUG=$(CPUOPTIMIZATIONS)
OPTIM_RELEASE=-O3 -fno-strict-aliasing $(CPUOPTIMIZATIONS)

# Linker Flags
LDFLAGS_DEBUG=-g -ggdb $(OPTIM_DEBUG) -DSVNREVISION=`{ test -d .svn && svnversion; } || { test -d .git && git describe --always; } || echo -` -DBUILDTYPE=debug -fsanitize=address,bounds
LDFLAGS_PROFILE=-g -pg -fprofile-arcs $(OPTIM_RELEASE) -DSVNREVISION=`{ test -d .svn && svnversion; } || { test -d .git && git describe --always; } || echo -` -DBUILDTYPE=profile
LDFLAGS_RELEASE=$(OPTIM_RELEASE) -DSVNREVISION=`{ test -d .svn && svnversion; } || { test -d .git && git describe --always; } || echo -` -DBUILDTYPE=release

LDFLAGS_COMMONSV=$(LIB_ODE) $(LIB_Z) $(LIB_JPEG) $(LIB_PNG) $(LIB_CRYPTO) $(LIB_CRYPTO_RIJNDAEL) $(LIB_LIBMICROHTTPD)
LDFLAGS_COMMONCL=$(LIB_OGGVORBIS) $(LIB_OPUS) $(LIB_FREETYPE) $(LIB_GL) $(LIB_VPX)

# Platform-Specific Executable Names and Linker Flags
# Default to Unix-like
EXE_SV?=rexuiz-dedicated
EXE_SDL?=rexuiz-sdl
LDFLAGS_UNIXCOMMON=-lm $(LDFLAGS_COMMONSV)
LDFLAGS_UNIXSDL=$(SDLCONFIG_LIBS) $(LDFLAGS_COMMONCL)

# Linux
ifeq ($(DP_MAKE_TARGET), linux)
	LDFLAGS_SV=$(LDFLAGS_UNIXCOMMON) -lrt -ldl -pthread
	LDFLAGS_SDL=$(LDFLAGS_UNIXCOMMON) -lrt -ldl $(LDFLAGS_UNIXSDL)
endif

# Android
ifeq ($(DP_MAKE_TARGET), android)
	LDFLAGS_SDL=$(LDFLAGS_UNIXCOMMON) $(LDFLAGS_UNIXSDL)
endif

# Mac OS X
ifeq ($(DP_MAKE_TARGET), macosx)
	LDFLAGS_SV=$(LDFLAGS_UNIXCOMMON) -ldl
	LDFLAGS_SDL=$(LDFLAGS_UNIXCOMMON) $(LDFLAGS_COMMONCL) -ldl -framework IOKit $(SDLCONFIG_LIBS)
endif

# Windows (MinGW)
ifeq ($(DP_MAKE_TARGET), mingw)
	MINGWARCH ?= i686
	EXE_SV=rexuiz-dedicated-$(MINGWARCH).exe
	EXE_SDL=rexuiz-sdl-$(MINGWARCH).exe
	OBJ_ICON_REXUIZ=rexuiz.o
	ifeq ($(MINGWARCH), i686)
		LDFLAGS_WINCOMMON:=-Wl,--large-address-aware
	endif
	LDFLAGS_SV=-static $(LDFLAGS_WINCOMMON) -mconsole -lwinmm -lws2_32 $(LDFLAGS_COMMONSV)
	LDFLAGS_SDL=-static $(LDFLAGS_WINCOMMON) $(SDLCONFIG_LIBS) -lwinmm -lws2_32 $(LDFLAGS_COMMONSV) $(LDFLAGS_COMMONCL)
endif

# Library Linking Flags (determined by DP_LINK_* variables)
ifeq ($(DP_VIDEO_CAPTURE), enabled)
	OGGVORBIS_PKGS = ogg vorbis vorbisenc vorbisfile theora theoraenc
else
	OGGVORBIS_PKGS = ogg vorbis vorbisfile
endif

ifeq ($(DP_LINK_OGGVORBIS), static)
	CFLAGS_OGGVORBIS=`pkg-config --cflags $(OGGVORBIS_PKGS)` -DLINK_TO_LIBVORBIS
	LIB_OGGVORBIS=`pkg-config --static --libs $(OGGVORBIS_PKGS)`
endif

ifeq ($(DP_LIBMICROHTTPD),static)
	CFLAGS_LIBMICROHTTPD=-DUSE_LIBMICROHTTPD `pkg-config --cflags libmicrohttpd`
	LIB_LIBMICROHTTPD=`pkg-config --static --libs libmicrohttpd`
endif
ifeq ($(DP_LINK_ZLIB), static)
	CFLAGS_LIBZ=`pkg-config --cflags zlib`
	LIB_Z=`pkg-config --static --libs zlib`
endif
ifeq ($(DP_LINK_JPEG), static)
	CFLAGS_LIBJPEG=`pkg-config --cflags libjpeg`
	LIB_JPEG=`pkg-config --static --libs libjpeg`
endif
ifeq ($(DP_LINK_PNG), static)
	CFLAGS_LIBPNG=`pkg-config --cflags libpng`
	LIB_PNG=`pkg-config --static --libs libpng`
endif
ifeq ($(DP_LINK_OPUS), static)
	CFLAGS_OPUS=`pkg-config --cflags opus`
	LIB_OPUS=`pkg-config --static --libs opus`
endif
ifeq ($(DP_LINK_VPX), static)
	CFLAGS_VPX=`pkg-config --cflags vpx` -DLINK_TO_VPX
	LIB_VPX=`pkg-config --static --libs vpx`
endif

# Makefile Rules & Targets
.PHONY: all clean clean-profile help sv-rexuiz sdl-rexuiz android-rexuiz html-rexuiz release

# Default to release build
all: release

release: sv-rexuiz sdl-rexuiz

help:
	@echo "DarkPlacesRM Standalone/Component Build System"
	@echo
	@echo "As a standalone project, 'make' or 'make all' will build release binaries."
	@echo "Available targets: sv-rexuiz, sdl-rexuiz, android-rexuiz, html-rexuiz, clean"
	@echo
	@echo "This Makefile also works as a component. Configuration variables"
	@echo "(like CC, DP_MAKE_TARGET, etc.) can be passed from a parent Makefile."

# Main entry points called by the root Makefile
sv-rexuiz:
	$(MAKE) bin-release EXE='$(EXE_SV)' CFLAGS_FEATURES='$(CFLAGS_SERVER)' LDFLAGS_COMMON='$(LDFLAGS_SV)' LEVEL=1
sdl-rexuiz:
	$(MAKE) bin-release EXE='$(EXE_SDL)' CFLAGS_FEATURES='$(CFLAGS_CLIENT)' CFLAGS_SDL='$(SDLCONFIG_CFLAGS)' LDFLAGS_COMMON='$(LDFLAGS_SDL)' LEVEL=1

# Android Target
android-rexuiz:
	$(MAKE) bin-release-so EXE='librexuiz-android.so' CFLAGS_FEATURES='$(CFLAGS_CLIENT)' CFLAGS_SDL='$(SDLCONFIG_CFLAGS)' LDFLAGS_COMMON='$(LDFLAGS_SDL)' LEVEL=1

# Web/HTML Target
html-rexuiz:
	$(MAKE) bin-release-nostrip EXE='rexuiz.html' CFLAGS_FEATURES='$(CLIENT)' CFLAGS_SDL='$(SDLCONFIG_CFLAGS)' LDFLAGS_COMMON='$(LDFLAGS_SDL)' LEVEL=1

# Recursive Build Logic
# These targets create the build directory and call make recursively
bin-release:
	@if [ "$(LEVEL)" != 1 ]; then $(MAKE) help; false; fi
	@echo "========== $(EXE) (release) =========="
	$(MAKE) prepare BUILD_DIR=build-obj/release/$(EXE)
	$(MAKE) -C build-obj/release/$(EXE) $(EXE) \
		CFLAGS='$(CFLAGS_COMMON) $(CFLAGS_SDL) $(CFLAGS_FEATURES) $(CFLAGS_EXTRA) $(CFLAGS_RELEASE) $(OPTIM_RELEASE)'\
		LDFLAGS='$(LDFLAGS_RELEASE) $(LDFLAGS_COMMON)' LEVEL=2
	$(STRIP) $(EXE)

bin-release-so:
	@if [ "$(LEVEL)" != 1 ]; then $(MAKE) help; false; fi
	@echo "========== $(EXE) (release shared object) =========="
	$(MAKE) prepare BUILD_DIR=build-obj/release/$(EXE)
	$(MAKE) -C build-obj/release/$(EXE) $(EXE) \
		CFLAGS='$(CFLAGS_COMMON) $(CFLAGS_SDL) $(CFLAGS_FEATURES) $(CFLAGS_EXTRA) $(CFLAGS_RELEASE) $(OPTIM_RELEASE)'\
		LDFLAGS='-shared $(LDFLAGS_RELEASE) $(LDFLAGS_COMMON)' LEVEL=2
	$(STRIP) $(EXE)

bin-release-nostrip:
	@if [ "$(LEVEL)" != 1 ]; then $(MAKE) help; false; fi
	@echo "========== $(EXE) (release nostrip) =========="
	$(MAKE) prepare BUILD_DIR=build-obj/release/$(EXE)
	$(MAKE) -C build-obj/release/$(EXE) $(EXE) \
		CFLAGS='$(CFLAGS_COMMON) $(CFLAGS_SDL) $(CFLAGS_FEATURES) $(CFLAGS_EXTRA) $(CFLAGS_RELEASE) $(OPTIM_RELEASE)'\
		LDFLAGS='$(LDFLAGS_RELEASE) $(LDFLAGS_COMMON)' LEVEL=2

prepare:
	@mkdir -p $(BUILD_DIR)
	@cp -f Makefile $(BUILD_DIR)/

# Compilation and Linking Rules (executed inside build-obj)
DO_CC = $(CC) $(CFLAGS) -c $< -o $@
DO_LD = $(CC) $(CFLAGS_WARNINGS) $(CPUOPTIMIZATIONS) -o ../../../$@ $^ $(LDFLAGS)

mod_skeletal_animatevertices_sse.o: mod_skeletal_animatevertices_sse.c
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_CC) $(CFLAGS_SSE)

rexuiz.o: %.o : %.rc
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(WINDRES) -o $@ $<

.c.o:
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_CC)

$(EXE_SV): $(OBJ_SV) $(OBJ_ICON_REXUIZ)
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_LD)

$(EXE_SDL): $(OBJ_SDL) $(OBJ_ICON_REXUIZ)
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_LD)

librexuiz-android.so: $(OBJ_SDL) $(OBJ_ICON_REXUIZ)
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_LD)

rexuiz.html: $(OBJ_SDL) $(OBJ_ICON_REXUIZ)
	@if [ "$(LEVEL)" != 2 ]; then $(MAKE) help; false; fi
	$(DO_LD) --shell-file $(HTML_SHELL_FILE) --preload-file $(HTML_PRELOAD_DIR)

# Clean Targets
clean:
	@echo "Cleaning DarkPlacesRM object files..."
	-rm -rf build-obj/ *.exe *.so *.html
	-rm -f rexuiz-sdl rexuiz-dedicated

clean-profile: clean
	-rm -f *.gcda *.gcno

# Dependency files
-include *.d