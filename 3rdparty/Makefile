SPIRV_TOOLS_DIR?=SPIRV-Tools
SPIRV_EXTERNAL_DIR:=$(SPIRV_TOOLS_DIR)/external
BUILD_DIR:=$(SPIRV_TOOLS_DIR)/build
ifeq ($(origin CMAKE), undefined)
  CMAKE := $(shell ./find-cmake.sh)
endif
NCPUS:=$(shell sysctl -n hw.ncpu)

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
	$(CMAKE) -B $(BUILD_DIR) -S $(SPIRV_TOOLS_DIR) -DCMAKE_BUILD_TYPE=RelWithDebInfo

$(SPIRV_EXTERNAL_DIR)/SPIRV-Headers:
	pushd $(SPIRV_TOOLS_DIR); git clone https://github.com/KhronosGroup/SPIRV-Headers.git external/SPIRV-Headers; popd
