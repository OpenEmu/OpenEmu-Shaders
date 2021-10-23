// swift-tools-version:5.3
import PackageDescription

let version = "1.19.2"
let tag = "v1.19.2"
let checksum = "335715c1664f8c2ada476c65a8b35715ee29e36ee19ec3388bd517750fd1fe4f"
let url = "https://github.com/OpenEmu/OpenEmu-Shaders/releases/download/\(tag)/OpenEmuShaders-\(version).xcframework.zip"

let package = Package(
    name: "OpenEmuShaders",
    platforms: [
        .macOS(.v10_14),
    ],
    products: [
        .library(
            name: "OpenEmuShaders",
            targets: ["OpenEmuShaders"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "OpenEmuShaders",
            url: url,
            checksum: checksum
        ),
    ]
)
