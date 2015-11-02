KATI ?= $(HOST_OUT_EXECUTABLES)/ckati
MAKEPARALLEL ?= $(HOST_OUT_EXECUTABLES)/makeparallel

KATI_OUTPUT_PATTERNS := $(OUT_DIR)/build%.ninja $(OUT_DIR)/ninja%.sh
NINJA_GOALS := droid showcommands
# A list of goals which affect parsing of make.
PARSE_TIME_MAKE_GOALS := \
	$(PARSE_TIME_MAKE_GOALS) \
	$(dont_bother_goals) \
	APP-% \
	DUMP_% \
	ECLIPSE-% \
	PRODUCT-% \
	boottarball-nodeps \
	btnod \
	build-art% \
	build_kernel-nodeps \
	clean-oat% \
	continuous_instrumentation_tests \
	continuous_native_tests \
	cts \
	custom_images \
	deps-license \
	dicttool_aosp \
	dist \
	dump-products \
	dumpvar-% \
	eng \
	fusion \
	oem_image \
	online-system-api-sdk-docs \
	pdk \
	platform \
	platform-java \
	product-graph \
	samplecode \
	sdk \
	sdk_addon \
	sdk_repo \
	snod \
	stnod \
	systemimage-nodeps \
	systemtarball-nodeps \
	target-files-package \
	test-art% \
	user \
	userdataimage \
	userdebug \
	valgrind-test-art% \
	win_sdk \
	winsdk-tools

-include vendor/google/build/ninja_config.mk

ANDROID_TARGETS := $(filter-out $(KATI_OUTPUT_PATTERNS) $(NINJA_GOALS),$(ORIGINAL_MAKECMDGOALS))
EXTRA_TARGETS := $(filter-out $(KATI_OUTPUT_PATTERNS) $(NINJA_GOALS),$(filter-out $(ORIGINAL_MAKECMDGOALS),$(MAKECMDGOALS)))
KATI_TARGETS := $(filter $(PARSE_TIME_MAKE_GOALS),$(ANDROID_TARGETS))

define replace_space_and_slash
$(subst /,_,$(subst $(space),_,$(sort $1)))
endef

KATI_NINJA_SUFFIX := -$(TARGET_PRODUCT)
ifneq ($(KATI_TARGETS),)
KATI_NINJA_SUFFIX := $(KATI_NINJA_SUFFIX)-$(call replace_space_and_slash,$(KATI_TARGETS))
endif
ifneq ($(ONE_SHOT_MAKEFILE),)
KATI_NINJA_SUFFIX := $(KATI_NINJA_SUFFIX)-mmm-$(call replace_space_and_slash,$(ONE_SHOT_MAKEFILE))
endif
ifneq ($(BUILD_MODULES_IN_PATHS),)
KATI_NINJA_SUFFIX := $(KATI_NINJA_SUFFIX)-mmma-$(call replace_space_and_slash,$(BUILD_MODULES_IN_PATHS))
endif

my_checksum_suffix :=
ifneq ($(KATI_NINJA_SUFFIX),)
my_ninja_suffix_too_long := $(filter 1, $(shell v='$(KATI_NINJA_SUFFIX)' && echo $$(($${$(pound)v} > 64))))
ifneq ($(my_ninja_suffix_too_long),)
# Replace the suffix with a checksum if it gets too long.
my_checksum_suffix := $(KATI_NINJA_SUFFIX)
KATI_NINJA_SUFFIX := -$(word 1, $(shell echo $(my_checksum_suffix) | $(MD5SUM)))
endif
endif

KATI_BUILD_NINJA := $(OUT_DIR)/build$(KATI_NINJA_SUFFIX).ninja
KATI_NINJA_SH := $(OUT_DIR)/ninja$(KATI_NINJA_SUFFIX).sh

# Write out a file mapping checksum to the real suffix.
ifneq ($(my_checksum_suffix),)
my_ninja_suffix_file := $(basename $(KATI_BUILD_NINJA)).suf
$(shell mkdir -p $(dir $(my_ninja_suffix_file)) && \
    echo $(my_checksum_suffix) > $(my_ninja_suffix_file))
endif

ifeq (,$(NINJA_STATUS))
NINJA_STATUS := [%p %s/%t]$(space)
endif

ifneq (,$(filter showcommands,$(ORIGINAL_MAKECMDGOALS)))
NINJA_ARGS += "-v"
PHONY: showcommands
showcommands: droid
endif

ifdef USE_GOMA
KATI_MAKEPARALLEL := $(MAKEPARALLEL)
# Ninja runs remote jobs (i.e., commands which contain gomacc) with
# this parallelism. Note the parallelism of all other jobs is still
# limited by the -j flag passed to GNU make.
NINJA_REMOTE_NUM_JOBS ?= 500
NINJA_ARGS += -j$(NINJA_REMOTE_NUM_JOBS)
else
NINJA_MAKEPARALLEL := $(MAKEPARALLEL) --ninja
endif

droid $(ANDROID_TARGETS) $(EXTRA_TARGETS): ninja_wrapper
	@#empty

.PHONY: ninja_wrapper
ninja_wrapper: $(KATI_BUILD_NINJA) $(MAKEPARALLEL)
	@echo Starting build with ninja
	+$(hide) PATH=prebuilts/ninja/$(HOST_PREBUILT_TAG)/:$$PATH NINJA_STATUS="$(NINJA_STATUS)" $(NINJA_MAKEPARALLEL) $(KATI_NINJA_SH) $(filter-out dist,$(ANDROID_TARGETS)) -C $(TOP) $(NINJA_ARGS)

KATI_FIND_EMULATOR := --use_find_emulator
ifeq ($(KATI_EMULATE_FIND),false)
  KATI_FIND_EMULATOR :=
endif
$(KATI_BUILD_NINJA): $(KATI) $(MAKEPARALLEL) FORCE
	@echo Running kati to generate build$(KATI_NINJA_SUFFIX).ninja...
	+$(hide) $(KATI_MAKEPARALLEL) $(KATI) --ninja --ninja_dir=$(OUT_DIR) --ninja_suffix=$(KATI_NINJA_SUFFIX) --regen --ignore_dirty=$(OUT_DIR)/% --ignore_optional_include=$(OUT_DIR)/%.P --detect_android_echo $(KATI_FIND_EMULATOR) -f build/core/main.mk $(KATI_TARGETS) --gen_all_targets BUILDING_WITH_NINJA=true

KATI_CXX := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_CFLAGS) $(CLANG_HOST_GLOBAL_CPPFLAGS)
KATI_LD := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_LDFLAGS)
# Build static ckati. Unfortunately Mac OS X doesn't officially support static exectuables.
ifeq ($(BUILD_OS),linux)
KATI_LD += -static
endif

KATI_INTERMEDIATES_PATH := $(HOST_OUT_INTERMEDIATES)/EXECUTABLES/ckati_intermediates
KATI_BIN_PATH := $(HOST_OUT_EXECUTABLES)
include build/kati/Makefile.ckati

MAKEPARALLEL_CXX := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_CFLAGS) $(CLANG_HOST_GLOBAL_CPPFLAGS)
MAKEPARALLEL_LD := $(CLANG_CXX) $(CLANG_HOST_GLOBAL_LDFLAGS)
# Build static makeparallel. Unfortunately Mac OS X doesn't officially support static exectuables.
ifeq ($(BUILD_OS),linux)
MAKEPARALLEL_LD += -static
endif

MAKEPARALLEL_INTERMEDIATES_PATH := $(HOST_OUT_INTERMEDIATES)/EXECUTABLES/makeparallel_intermediates
MAKEPARALLEL_BIN_PATH := $(HOST_OUT_EXECUTABLES)
include build/tools/makeparallel/Makefile

.PHONY: FORCE
FORCE:
