// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SweetEditorMacDemo",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        // The demo imports the SDK package that lives one level up.
        .package(name: "Apple", path: ".."),
    ],
    targets: [
        .target(
            name: "SweetEditorDemoSupport",
            dependencies: [
                .product(name: "SweetEditorMacOS", package: "Apple"),
            ]
        ),
        .executableTarget(
            name: "SweetEditorMacDemo",
            dependencies: [
                // Reference the macOS product from the parent package.
                .product(name: "SweetEditorMacOS", package: "Apple"),
                "SweetEditorDemoSupport",
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "SweetEditorMacDemoSwiftUI",
            dependencies: [
                .product(name: "SweetEditorMacOS", package: "Apple"),
                "SweetEditorDemoSupport",
            ]
        ),
        .testTarget(
            name: "SweetEditorMacDemoTests",
            dependencies: [
                "SweetEditorMacDemo",
            ]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
