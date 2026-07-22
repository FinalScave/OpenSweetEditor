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
        .package(url: "https://github.com/Xiue233/SweetLine-Apple.git", from: "1.3.1"),
    ],
    targets: [
        .target(
            name: "SweetEditorDemoSupport",
            dependencies: [
                .product(name: "SweetEditorMacOS", package: "Apple"),
                .product(name: "SweetLine", package: "SweetLine-Apple"),
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
            path: "SweetEditorMacDemo"
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
