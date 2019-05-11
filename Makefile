# TODO(sgc): update glslang submodule

# regenerate projects

.PHONY: gen-glslang gen-spirv

gen-glslang:
	cmake -G Xcode -S 3rdparty/glslang -B 3rdparty/projects/glslang \
		-D ENABLE_GLSLANG_BINARIES=OFF \
		-D ENABLE_HLSL=OFF

# TODO(sgc): update SPIRV-Cross submodule


gen-spirv:
	cmake -G Xcode -S 3rdparty/SPIRV-Cross -B 3rdparty/projects/SPIRV-Cross \
		-D SPIRV_CROSS_CLI=OFF \
		-D SPIRV_CROSS_ENABLE_TESTS=OFF \
		-D SPIRV_CROSS_ENABLE_HLSL=OFF \
		-D SPIRV_CROSS_ENABLE_UTIL=OFF \
		-D SPIRV_CROSS_ENABLE_CPP=OFF \
		-D SPIRV_CROSS_ENABLE_REFLECT=OFF



