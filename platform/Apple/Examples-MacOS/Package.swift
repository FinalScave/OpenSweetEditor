// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SweetEditorMacDemo",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "SweetEditorMacDemo", targets: ["SweetEditorMacDemo"]),
        .executable(name: "SweetEditorMacDemoSwiftUI", targets: ["SweetEditorMacDemoSwiftUI"]),
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
            ],
            path: "SweetEditorDemoSupport"
        ),
        .executableTarget(
            name: "SweetEditorMacDemo",
            dependencies: [
                // Reference the macOS product from the parent package.
                .product(name: "SweetEditorMacOS", package: "Apple"),
                "SweetEditorDemoSupport",
            ],
            path: "SweetEditorMacDemo",
            resources: [
                .process("Resources"),
            ]
        ),
        .executableTarget(
            name: "SweetEditorMacDemoSwiftUI",
            dependencies: [
                .product(name: "SweetEditorMacOS", package: "Apple"),
                "SweetEditorDemoSupport",
            ],
            path: "SweetEditorMacDemoSwiftUI"
        ),
    ],
    swiftLanguageVersions: [.v5]
)
