import Foundation
import SweetEditorMacOS
import SweetEditorDemoSupport

final class DemoFileMetadata: EditorMetadata {
    let fileName: String

    init(fileName: String) {
        self.fileName = fileName
    }
}

struct DemoFileSelectionController {
    let sampleFiles: [DemoSampleSupport.DemoSampleFile]
    private(set) var selectedFile: DemoSampleSupport.DemoSampleFile
    private(set) var statusText: String

    init?(sampleFiles: [DemoSampleSupport.DemoSampleFile]) {
        guard let first = sampleFiles.first else { return nil }
        self.sampleFiles = sampleFiles
        self.selectedFile = first
        self.statusText = DemoFileSelectionController.makeStatusText(for: first)
    }

    var fileTitles: [String] {
        sampleFiles.map(\.fileName)
    }

    var currentMetadata: DemoFileMetadata {
        DemoFileMetadata(fileName: selectedFile.fileName)
    }

    mutating func selectFile(named fileName: String) -> DemoSampleSupport.DemoSampleFile {
        if let match = sampleFiles.first(where: { $0.fileName == fileName }) {
            selectedFile = match
            statusText = DemoFileSelectionController.makeStatusText(for: match)
        }
        return selectedFile
    }

    private static func makeStatusText(for file: DemoSampleSupport.DemoSampleFile) -> String {
        "Loaded \(file.fileName)"
    }
}
