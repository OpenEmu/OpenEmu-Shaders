SPIRV_TOOLS_DIR?=SPIRV-Tools
SPIRV_EXTERNAL_DIR:=$(SPIRV_TOOLS_DIR)/external
BUILD_DIR:=$(SPIRV_TOOLS_DIR)/build
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

all: libSPIRV-Tools-opt.a

libSPIRV-Tools-opt.a: $(BUILD_DIR)/source/opt/libSPIRV-Tools-opt.a
.PHONY : libSPIRV-Tools-opt.a

$(BUILD_DIR)/source/opt/libSPIRV-Tools-opt.a: $(BUILD_DIR)/CMakeCache.txt
	mkdir -p $(BUILD_DIR)
	$(MAKE) -j$(NCPUS) -C $(BUILD_DIR) SPIRV-Tools-opt

clean:
	$(MAKE) -C $(BUILD_DIR) clean
	rm -rf $(BUILD_DIR)
	rm -rf $(SPIRV_EXTERNAL_DIR)/SPIRV-Headers
.PHONY : clean

$(BUILD_DIR)/CMakeCache.txt: $(SPIRV_TOOLS_DIR)/CMakeLists.txt $(SPIRV_EXTERNAL_DIR)/SPIRV-Headers
	mkdir -p $(BUILD_DIR)
	$(CMAKE) -B $(BUILD_DIR) -S $(SPIRV_TOOLS_DIR) -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_OSX_ARCHITECTURES='$(TARGET_ARCHITECTURES)' -DSPIRV_WERROR=OFF

$(SPIRV_EXTERNAL_DIR)/SPIRV-Headers:
	pushd $(SPIRV_TOOLS_DIR); git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/SPIRV-Headers; popd

print:
	@echo '$(TARGET_ARCHITECTURES)'
