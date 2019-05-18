# OpenEmu-Shaders
OpenEmuShaders is a framework for rendering multi-pass post processing effects using Metal. 

OpenEmuShaders can load presets from the [slang-shaders](https://github.com/libretro/slang-shaders) project, providing access to an impressive library of effects, such as CRT-Royale

![CRT-Royale](http://emulation.gametechwiki.com/images/4/45/CRT-Royale.png "CRT Royale")

These effects are written in glsl, however, OpenEmuShaders makes use of [glslang](https://github.com/KhronosGroup/glslang) and [SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross) to transfrom the `.glsl` shaders into Metal Shader Language.
