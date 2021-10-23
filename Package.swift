// swift-tools-version:5.3
import PackageDescription

let version = "1.19.1"
let tag = "v1.19.1"
let checksum = "32bbd8eb7516e37f6cb643ecd6e19a8380b9cc2f04b898eb7ab37c915ff05276"
let url = "https://github.com/OpenEmu/OpenEmu-Shaders/releases/download/\(tag)/OpenEmuShaders-\(version).xcframework.zip"

let package = Package(
    name: "OpenEmuShaders",
    platforms: [
        .macOS(.v10_14)
    ],
    products: [
        .library(
            name: "OpenEmuShaders",
            targets: ["OpenEmuShaders"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "OpenEmuShaders",
            url: url,
            checksum: checksum
        )
    ]
)
