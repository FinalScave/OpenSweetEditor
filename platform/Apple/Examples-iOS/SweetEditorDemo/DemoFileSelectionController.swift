import Foundation

struct DemoFileSelectionController {
    let sampleFiles: [DemoSampleSupport.DemoSampleFile]
    private(set) var currentFile: DemoSampleSupport.DemoSampleFile
    private(set) var statusText: String

    init?(sampleFiles: [DemoSampleSupport.DemoSampleFile]) {
        guard let firstFile = sampleFiles.first else {
            return nil
        }

        self.sampleFiles = sampleFiles
        self.currentFile = firstFile
        self.statusText = Self.makeStatusText(for: firstFile)
    }

    var fileNames: [String] {
        sampleFiles.map(\.fileName)
    }

    mutating func selectFile(named fileName: String) -> DemoSampleSupport.DemoSampleFile {
        if let matchedFile = sampleFiles.first(where: { $0.fileName == fileName }) {
            currentFile = matchedFile
            statusText = Self.makeStatusText(for: matchedFile)
        }

        return currentFile
    }

    private static func makeStatusText(for file: DemoSampleSupport.DemoSampleFile) -> String {
        "Loaded \(file.fileName)"
    }
}
