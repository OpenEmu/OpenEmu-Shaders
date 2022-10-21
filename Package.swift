// swift-tools-version:5.3
import PackageDescription

let version = "1.21.1"
let tag = "v1.21.1"
let checksum = "5cd765a356fefb457aa2192545fa67c09c37a2d4b42cafb8b5628aa9a20bd5bd"
let url = "https://github.com/OpenEmu/OpenEmu-Shaders/releases/download/\(tag)/OpenEmuShaders-\(version).xcframework.zip"

let package = Package(
    name: "OpenEmuShaders",
    targets: [
        .binaryTarget(
            name: "OpenEmuShaders",
            url: url,
            checksum: checksum),
    ])
