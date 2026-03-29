import Foundation

enum DemoSampleSupport {
    struct DemoSampleFile: Equatable, Sendable {
        let fileName: String
        let supportsDemoDecorations: Bool

        private let textLoader: @Sendable () -> String

        init(fileName: String, supportsDemoDecorations: Bool, textLoader: @escaping @Sendable () -> String) {
            self.fileName = fileName
            self.supportsDemoDecorations = supportsDemoDecorations
            self.textLoader = textLoader
        }

        var text: String {
            textLoader()
        }

        nonisolated func loadText() -> String {
            textLoader()
        }

        static func == (lhs: DemoSampleFile, rhs: DemoSampleFile) -> Bool {
            lhs.fileName == rhs.fileName && lhs.supportsDemoDecorations == rhs.supportsDemoDecorations
        }
    }

    static func availableSampleFiles() -> [DemoSampleFile] {
        sampleNames.map { fileName in
            DemoSampleFile(
                fileName: fileName,
                supportsDemoDecorations: decoratedSampleNames.contains(fileName),
                textLoader: {
                    loadBundledSampleText(named: fileName) ?? fallbackText(for: fileName)
                }
            )
        }
    }

    private static let sampleNames = [
        "example.java",
        "example.kt",
        "example.lua",
        "nlohmann-json.hpp",
        "View.java",
    ]

    private static let decoratedSampleNames: Set<String> = [
        "example.java",
        "example.kt",
        "example.lua",
    ]

    nonisolated private static func loadBundledSampleText(named fileName: String) -> String? {
        let fileURL = bundledSampleURL(named: fileName)
        return fileURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }

    nonisolated private static func bundledSampleURL(named fileName: String) -> URL? {
        let name = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension

        for bundle in candidateBundles() {
            if let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "files") {
                return url
            }
        }

        return nil
    }

    nonisolated private static func candidateBundles() -> [Bundle] {
        var seenPaths = Set<String>()
        let bundles = [Bundle.main, Bundle(for: BundleLocator.self)] + Bundle.allBundles + Bundle.allFrameworks

        return bundles.filter { bundle in
            seenPaths.insert(bundle.bundlePath).inserted
        }
    }

    nonisolated private static func fallbackText(for fileName: String) -> String {
        "// Missing bundled sample: \(fileName)"
    }

    private final class BundleLocator {}
}
