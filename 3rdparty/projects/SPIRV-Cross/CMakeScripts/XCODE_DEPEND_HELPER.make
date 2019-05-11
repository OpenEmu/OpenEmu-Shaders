# DO NOT EDIT
# This makefile makes sure all linkable targets are
# up-to-date with anything they link to
default:
	echo "Do not invoke directly"

# Rules to remove targets that are older than anything to which they
# link.  This forces Xcode to relink the targets from scratch.  It
# does not seem to check these dependencies itself.
PostBuild.spirv-cross-c.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-c.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-c.a


PostBuild.spirv-cross-core.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-core.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-core.a


PostBuild.spirv-cross-glsl.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-glsl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-glsl.a


PostBuild.spirv-cross-msl.Debug:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-msl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Debug/libspirv-cross-msl.a


PostBuild.spirv-cross-c.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-c.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-c.a


PostBuild.spirv-cross-core.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-core.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-core.a


PostBuild.spirv-cross-glsl.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-glsl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-glsl.a


PostBuild.spirv-cross-msl.Release:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-msl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/Release/libspirv-cross-msl.a


PostBuild.spirv-cross-c.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-c.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-c.a


PostBuild.spirv-cross-core.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-core.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-core.a


PostBuild.spirv-cross-glsl.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-glsl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-glsl.a


PostBuild.spirv-cross-msl.MinSizeRel:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-msl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/MinSizeRel/libspirv-cross-msl.a


PostBuild.spirv-cross-c.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-c.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-c.a


PostBuild.spirv-cross-core.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-core.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-core.a


PostBuild.spirv-cross-glsl.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-glsl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-glsl.a


PostBuild.spirv-cross-msl.RelWithDebInfo:
/Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-msl.a:
	/bin/rm -f /Volumes/Data/projects/macos/OpenEmu/OpenEmu-Shaders/3rdparty/projects/SPIRV-Cross/RelWithDebInfo/libspirv-cross-msl.a




# For each target create a dummy ruleso the target does not have to exist
