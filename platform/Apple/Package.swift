// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SweetEditorApple",
    platforms: [
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: [
        .library(name: "SweetEditorIOS", targets: ["SweetEditorIOS"]),
        .library(name: "SweetEditorMacOS", targets: ["SweetEditorMacOS"]),
    ],
    targets: [
        .binaryTarget(
            name: "SweetEditorCoreIOS",
            path: ".build-local/SweetEditorCoreIOS.xcframework"
        ),
        .binaryTarget(
            name: "SweetEditorCoreMacOS",
            path: ".build-local/SweetEditorCoreMacOS.xcframework"
        ),
        .target(
            name: "SweetEditorShared",
            dependencies: [
                .target(name: "SweetEditorCoreIOS", condition: .when(platforms: [.iOS])),
                .target(name: "SweetEditorCoreMacOS", condition: .when(platforms: [.macOS])),
            ],
            path: "SweetEditor-Shared"
        ),
        .target(
            name: "SweetEditorIOS",
            dependencies: ["SweetEditorShared"],
            path: "SweetEditor-iOS"
        ),
        .target(
            name: "SweetEditorMacOS",
            dependencies: ["SweetEditorShared"],
            path: "SweetEditor-macOS"
        ),
        .testTarget(
            name: "SweetEditorSharedTests",
            dependencies: ["SweetEditorShared"],
            path: "Tests/SweetEditorSharedTests"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
