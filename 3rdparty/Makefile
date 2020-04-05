# SPIRV-Tools 
SPIRV_TOOLS_DIR?=SPIRV-Tools
SPIRV_TOOLS_EXTERNAL_DIR:=$(SPIRV_TOOLS_DIR)/external
SPIRV_TOOLS_BUILD_DIR:=$(SPIRV_TOOLS_DIR)/build

# glslang
GLSLANG_DIR?=glslang
GLSLANG_BUILD_DIR:=$(GLSLANG_DIR)/build

ifeq ($(origin CMAKE), undefined)
  CMAKE := $(shell ./find-cmake.sh)
endif
NCPUS:=$(shell sysctl -n hw.ncpu)

# Determine if the current SDK version is Big Sur or later
# 
# NOTE: 
# When running Xcode 12 on Intel hardware, the SDK returns 10.16.
# On Apple SI, SDK returns 11.0
MACOS_SDK_VERSION := $(shell xcrun --sdk macosx --show-sdk-version)

# need to check the current SDK is either >= 10.16 or 11.0
TARGET_ARCHITECTURES := $(shell ./version_gte.sh $(MACOS_SDK_VERSION) 11.0 || ./version_gte.sh $(MACOS_SDK_VERSION) 10.16 && echo 'arm64;x86_64' || echo 'x86_64')

all: libSPIRV-Tools-opt.a build_info.h

install: all
.PHONY: install

clean: clean-spirv clean-glslang
.PHONY: clean

# glslang

clean-glslang:
	$(MAKE) -C $(GLSLANG_BUILD_DIR) clean
	rm -rf $(GLSLANG_BUILD_DIR)
.PHONY: clean-glslang

build_info.h: $(GLSLANG_BUILD_DIR)/include/glslang/build_info.h
.PHONY: build_info.h

$(GLSLANG_BUILD_DIR)/include/glslang/build_info.h: $(GLSLANG_DIR)/CHANGES.md $(GLSLANG_DIR)/build_info.h.tmpl $(GLSLANG_BUILD_DIR)/CMakeCache.txt
	$(MAKE) -C $(GLSLANG_BUILD_DIR) glslang-build-info/fast

$(GLSLANG_BUILD_DIR)/CMakeCache.txt: $(GLSLANG_DIR)/CMakeLists.txt
	mkdir -p $(GLSLANG_BUILD_DIR)
	$(CMAKE) -B $(GLSLANG_BUILD_DIR) -S $(GLSLANG_DIR)

# SPIRV-Tools

clean-spirv:
	$(MAKE) -C $(SPIRV_TOOLS_BUILD_DIR) clean
	rm -rf $(SPIRV_TOOLS_BUILD_DIR)
	rm -rf $(SPIRV_TOOLS_EXTERNAL_DIR)/SPIRV-Headers
.PHONY : clean-spirv

libSPIRV-Tools-opt.a: $(SPIRV_TOOLS_BUILD_DIR)/source/opt/libSPIRV-Tools-opt.a
.PHONY : libSPIRV-Tools-opt.a

$(SPIRV_TOOLS_BUILD_DIR)/source/opt/libSPIRV-Tools-opt.a: $(SPIRV_TOOLS_BUILD_DIR)/CMakeCache.txt
	mkdir -p $(SPIRV_TOOLS_BUILD_DIR)
	$(MAKE) -j$(NCPUS) -C $(SPIRV_TOOLS_BUILD_DIR) SPIRV-Tools-opt

$(SPIRV_TOOLS_BUILD_DIR)/CMakeCache.txt: $(SPIRV_TOOLS_DIR)/CMakeLists.txt $(SPIRV_TOOLS_EXTERNAL_DIR)/SPIRV-Headers
	mkdir -p $(SPIRV_TOOLS_BUILD_DIR)
	$(CMAKE) -B $(SPIRV_TOOLS_BUILD_DIR) -S $(SPIRV_TOOLS_DIR) -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_OSX_ARCHITECTURES='$(TARGET_ARCHITECTURES)' -DSPIRV_WERROR=OFF

$(SPIRV_TOOLS_EXTERNAL_DIR)/SPIRV-Headers:
	pushd $(SPIRV_TOOLS_DIR); git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/SPIRV-Headers; popd

print:
	@echo '$(TARGET_ARCHITECTURES)'
