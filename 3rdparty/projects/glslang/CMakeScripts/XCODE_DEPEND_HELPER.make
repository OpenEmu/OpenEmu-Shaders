# DO NOT EDIT
# This makefile makes sure all linkable targets are
# up-to-date with anything they link to
default:
	echo "Do not invoke directly"

# Rules to remove targets that are older than anything to which they
# link.  This forces Xcode to relink the targets from scratch.  It
# does not seem to check these dependencies itself.
PostBuild.OGLCompiler.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/Debug/libOGLCompiler.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/Debug/libOGLCompiler.a


PostBuild.OSDependent.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/Debug/libOSDependent.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/Debug/libOSDependent.a


PostBuild.SPIRV.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPIRV.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPIRV.a


PostBuild.SPVRemapper.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPVRemapper.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Debug/libSPVRemapper.a


PostBuild.glslang.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/Debug/libglslang.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/Debug/libglslang.a


PostBuild.OGLCompiler.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/Release/libOGLCompiler.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/Release/libOGLCompiler.a


PostBuild.OSDependent.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/Release/libOSDependent.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/Release/libOSDependent.a


PostBuild.SPIRV.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPIRV.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPIRV.a


PostBuild.SPVRemapper.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPVRemapper.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/Release/libSPVRemapper.a


PostBuild.glslang.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/Release/libglslang.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/Release/libglslang.a


PostBuild.OGLCompiler.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/MinSizeRel/libOGLCompiler.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/MinSizeRel/libOGLCompiler.a


PostBuild.OSDependent.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/MinSizeRel/libOSDependent.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/MinSizeRel/libOSDependent.a


PostBuild.SPIRV.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPIRV.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPIRV.a


PostBuild.SPVRemapper.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPVRemapper.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/MinSizeRel/libSPVRemapper.a


PostBuild.glslang.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/MinSizeRel/libglslang.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/MinSizeRel/libglslang.a


PostBuild.OGLCompiler.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/RelWithDebInfo/libOGLCompiler.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/OGLCompilersDLL/RelWithDebInfo/libOGLCompiler.a


PostBuild.OSDependent.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/RelWithDebInfo/libOSDependent.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/OSDependent/Unix/RelWithDebInfo/libOSDependent.a


PostBuild.SPIRV.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPIRV.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPIRV.a


PostBuild.SPVRemapper.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPVRemapper.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/SPIRV/RelWithDebInfo/libSPVRemapper.a


PostBuild.glslang.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/RelWithDebInfo/libglslang.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/glslang/glslang/RelWithDebInfo/libglslang.a




# For each target create a dummy ruleso the target does not have to exist
