# Install script for directory: /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
  set(CMAKE_INSTALL_PREFIX "/usr/local")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
  if(BUILD_TYPE)
    string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
           CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
  else()
    set(CMAKE_INSTALL_CONFIG_NAME "Release")
  endif()
  message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
  if(COMPONENT)
    message(STATUS "Install component: \"${COMPONENT}\"")
    set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
  else()
    set(CMAKE_INSTALL_COMPONENT)
  endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
  set(CMAKE_CROSSCOMPILING "FALSE")
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPVRemapper.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPVRemapper.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPVRemapper.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPVRemapper.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPVRemapper.a")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  if("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ee][Aa][Ss][Ee])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Mm][Ii][Nn][Ss][Ii][Zz][Ee][Rr][Ee][Ll])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  elseif("${CMAKE_INSTALL_CONFIG_NAME}" MATCHES "^([Rr][Ee][Ll][Ww][Ii][Tt][Hh][Dd][Ee][Bb][Ii][Nn][Ff][Oo])$")
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY FILES "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPIRV.a")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a" AND
       NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
      execute_process(COMMAND "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/ranlib" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/libSPIRV.a")
    endif()
  endif()
endif()

if("x${CMAKE_INSTALL_COMPONENT}x" STREQUAL "xUnspecifiedx" OR NOT CMAKE_INSTALL_COMPONENT)
  file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/SPIRV" TYPE FILE FILES
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/bitutils.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/spirv.hpp"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GLSL.std.450.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GLSL.ext.EXT.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GLSL.ext.KHR.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GlslangToSpv.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/hex_float.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/Logger.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/SpvBuilder.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/spvIR.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/doc.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/SpvTools.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/disassemble.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GLSL.ext.AMD.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/GLSL.ext.NV.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/SPVRemapper.h"
    "/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/glslang/SPIRV/doc.h"
    )
endif()

