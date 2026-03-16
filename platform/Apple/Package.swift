// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SweetEditorApple",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(name: "SweetEditoriOS", targets: ["SweetEditoriOS"]),
        .library(name: "SweetEditorMacOS", targets: ["SweetEditorMacOS"]),
    ],
    targets: [
        .binaryTarget(
            name: "SweetNativeCore",
            path: "binaries/SweetNativeCore.xcframework"
        ),
        .target(
            name: "SweetEditorBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SweetEditorCoreInternal",
            dependencies: ["SweetEditorBridge", "SweetNativeCore"]
        ),
        .target(
            name: "SweetEditoriOS",
            dependencies: ["SweetEditorCoreInternal"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-access-control"]),
            ]
        ),
        .target(
            name: "SweetEditorMacOS",
            dependencies: ["SweetEditorCoreInternal"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-disable-access-control"]),
            ]
        ),
        .testTarget(
            name: "SweetEditoriOSTests",
            dependencies: ["SweetEditoriOS"],
            path: "Tests/SweetEditoriOSTests"
        ),
        .testTarget(
            name: "SweetEditorMacOSTests",
            dependencies: ["SweetEditorMacOS"],
            path: "Tests/SweetEditorMacOSTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
