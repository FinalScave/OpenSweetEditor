import Foundation

public enum DemoSampleSupport {
    public struct DemoSampleFile: Equatable {
        public let fileName: String
        public let text: String

        public init(fileName: String, text: String) {
            self.fileName = fileName
            self.text = text
        }
    }

    public static func availableSampleFiles() -> [DemoSampleFile] {
        guard let directory = sharedSampleDirectory() else { return [] }
        return loadRegularFiles(in: directory)
    }

    static func syntaxFileURLs() -> [URL] {
        guard let resourceRoot = findSharedResourceRoot(searchStarts: sharedResourceSearchStarts()) else {
            return []
        }
        let directory = resourceRoot.appendingPathComponent("syntaxes", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" && isRegularFile($0) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func sharedSampleDirectory() -> URL? {
        guard let resourceRoot = findSharedResourceRoot(searchStarts: sharedResourceSearchStarts()) else {
            return nil
        }
        let filesDirectory = resourceRoot.appendingPathComponent("files", isDirectory: true)
        return isDirectory(filesDirectory) ? filesDirectory : nil
    }

    static func findSharedResourceRoot(searchStarts: [URL]) -> URL? {
        for start in searchStarts {
            guard start.isFileURL else { continue }
            for ancestor in ancestorDirectories(startingAt: start.standardizedFileURL) {
                for relativePath in ["_res", "platform/_res"] {
                    let candidate = ancestor.appendingPathComponent(relativePath, isDirectory: true)
                    if isDirectory(candidate) {
                        return candidate
                    }
                }
            }
        }
        return nil
    }

    private static func sharedResourceSearchStarts() -> [URL] {
        let sourceDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return [workingDirectory, sourceDirectory, Bundle.main.resourceURL]
            .compactMap { $0?.standardizedFileURL }
    }

    private static func ancestorDirectories(startingAt start: URL) -> [URL] {
        var directories: [URL] = []
        var current: URL? = start.hasDirectoryPath ? start : start.deletingLastPathComponent()
        while let directory = current {
            directories.append(directory)
            let parent = directory.deletingLastPathComponent()
            if parent == directory { break }
            current = parent
        }
        return directories
    }

    private static func loadRegularFiles(in directory: URL) -> [DemoSampleFile] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls
            .filter(isRegularFile)
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
            }
            .compactMap(loadSampleFile(from:))
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true
    }

    private static func loadSampleFile(from url: URL) -> DemoSampleFile? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return DemoSampleFile(fileName: url.lastPathComponent, text: text)
    }
}
