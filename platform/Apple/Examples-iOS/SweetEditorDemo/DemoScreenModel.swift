import Combine
import SweetEditoriOS

@MainActor
final class DemoScreenModel: ObservableObject {
    @Published private(set) var currentFileName: String
    @Published private(set) var statusText: String
    @Published private(set) var documentText: String
    @Published private(set) var isLoadingDocument: Bool
    @Published private(set) var shouldApplyDecorations: Bool
    @Published private(set) var isDarkTheme = true
    @Published private(set) var wrapMode: WrapMode = .none

    private var fileSelectionController: DemoFileSelectionController
    private let loadsSynchronously: Bool
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0
    private var hasStartedInitialLoad = false

    convenience init() {
        self.init(sampleFiles: DemoSampleSupport.availableSampleFiles())
    }

    init(sampleFiles: [DemoSampleSupport.DemoSampleFile], loadsSynchronously: Bool = false) {
        guard let controller = DemoFileSelectionController(sampleFiles: sampleFiles) else {
            fatalError("DemoScreenModel requires at least one sample file")
        }

        self.fileSelectionController = controller
        self.loadsSynchronously = loadsSynchronously
        self.currentFileName = controller.currentFile.fileName
        self.statusText = Self.idleStatusText(for: controller.currentFile)
        self.documentText = ""
        self.isLoadingDocument = false
        self.shouldApplyDecorations = false

        if loadsSynchronously {
            applyLoadedFile(controller.currentFile)
        }
    }

    deinit {
        loadTask?.cancel()
    }

    var fileNames: [String] {
        fileSelectionController.fileNames
    }

    func selectFile(named fileName: String) {
        let file = fileSelectionController.selectFile(named: fileName)
        hasStartedInitialLoad = true
        currentFileName = file.fileName

        if loadsSynchronously {
            applyLoadedFile(file)
        } else {
            statusText = Self.loadingStatusText(for: file)
            isLoadingDocument = true
            shouldApplyDecorations = false
            beginLoading(file)
        }
    }

    func toggleTheme() {
        isDarkTheme.toggle()
    }

    func cycleWrapMode() {
        wrapMode = DemoWrapModeCycle.next(after: wrapMode)
    }

    func startInitialLoadIfNeeded() {
        guard !loadsSynchronously, !hasStartedInitialLoad else {
            return
        }

        hasStartedInitialLoad = true
        beginLoadingCurrentFile()
    }

    func reloadCurrentFile() {
        guard !loadsSynchronously else {
            applyLoadedFile(fileSelectionController.currentFile)
            return
        }

        hasStartedInitialLoad = true
        let file = fileSelectionController.currentFile
        statusText = Self.loadingStatusText(for: file)
        isLoadingDocument = true
        shouldApplyDecorations = false
        beginLoading(file)
    }

    private func beginLoadingCurrentFile() {
        beginLoading(fileSelectionController.currentFile)
    }

    private func beginLoading(_ file: DemoSampleSupport.DemoSampleFile) {
        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration

        loadTask = Task { [file] in
            let text = await Self.readText(for: file)
            guard !Task.isCancelled,
                  generation == loadGeneration,
                  currentFileName == file.fileName else {
                return
            }

            documentText = text
            isLoadingDocument = false
            shouldApplyDecorations = file.supportsDemoDecorations
            statusText = "Loaded \(file.fileName)"
        }
    }

    private func applyLoadedFile(_ file: DemoSampleSupport.DemoSampleFile) {
        statusText = "Loaded \(file.fileName)"
        documentText = file.loadText()
        isLoadingDocument = false
        shouldApplyDecorations = file.supportsDemoDecorations
    }

    private static func loadingStatusText(for file: DemoSampleSupport.DemoSampleFile) -> String {
        "Loading \(file.fileName)…"
    }

    private static func idleStatusText(for file: DemoSampleSupport.DemoSampleFile) -> String {
        "Ready to load \(file.fileName)"
    }

    nonisolated private static func readText(for file: DemoSampleSupport.DemoSampleFile) async -> String {
        await Task.detached(priority: .userInitiated) {
            file.loadText()
        }.value
    }
}
