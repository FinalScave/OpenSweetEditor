import Foundation
import CoreGraphics
import Testing
import SweetEditorIOS
@testable import SweetEditorDemo

struct DemoSupportTests {
    @Test
    func sampleFilesProvideExpectedNames() {
        let files = DemoSampleSupport.availableSampleFiles()

        #expect(files.map(\.fileName) == ["example.java", "example.kt", "example.lua", "gc.cpp"])
    }

    @Test
    @MainActor
    func publicCoreAndViewEditingApisStayAvailable() {
        let coreDocument = Document(text: "alpha\nbeta")
        let core = EditorCore(fontSize: 14, fontName: "Menlo")

        _ = core.loadDocument(coreDocument)
        _ = core.setGutterSticky(false)
        _ = core.setGutterVisible(true)
        _ = core.setCursorPosition(TextPosition(line: 1, column: 2))
        _ = core.setSelection(TextRange(
            start: TextPosition(line: 0, column: 1),
            end: TextPosition(line: 0, column: 4)
        ))

        #expect(core.getDocument() === coreDocument)
        #expect(core.getSelection() != nil)

        let view = SweetEditorView(frame: .zero)
        let viewDocument = Document(text: "first\nsecond")
        view.loadDocument(viewDocument)
        view.setCursorPosition(TextPosition(line: 1, column: 3))
        view.setSelection(TextRange(
            start: TextPosition(line: 0, column: 0),
            end: TextPosition(line: 0, column: 5)
        ))

        #expect(view.getDocument() === viewDocument)
        #expect(view.getTotalLineCount() == 2)
        #expect(view.hasSelection())
        #expect(!view.settings.gutterSticky)
        #expect(view.settings.contentStartPadding == 3)
    }

    @Test
    func fileSelectionControllerTracksCurrentFileAndStatus() {
        let files = DemoSampleSupport.availableSampleFiles()
        var controller = DemoFileSelectionController(sampleFiles: files)

        #expect(controller != nil)
        #expect(controller?.currentFile.fileName == "example.java")
        #expect(controller?.statusText == "Loaded example.java")

        let currentFile = controller?.selectFile(named: "example.lua")

        #expect(currentFile?.fileName == "example.lua")
        #expect(controller?.currentFile.fileName == "example.lua")
        #expect(controller?.statusText == "Loaded example.lua")
    }

    @Test
    @MainActor
    func screenModelTracksFileThemeAndWrapState() {
        let model = DemoScreenModel(sampleFiles: DemoSampleSupport.availableSampleFiles(), loadsSynchronously: true)

        #expect(model.currentFileName == "example.java")
        #expect(model.statusText == "Loaded example.java")
        #expect(model.isDarkTheme)
        #expect(model.wrapMode == .none)
        #expect(model.documentText.contains("package com.sweetline.example;"))

        model.selectFile(named: "example.kt")
        model.toggleTheme()
        model.cycleWrapMode()

        #expect(model.currentFileName == "example.kt")
        #expect(model.statusText == "Loaded example.kt")
        #expect(!model.isDarkTheme)
        #expect(model.wrapMode == .charBreak)
        #expect(model.documentText.contains("// Kotlin sample"))
    }

    @Test
    @MainActor
    func screenModelTracksDocumentReloadTokenSeparatelyFromEditBuffer() {
        let model = DemoScreenModel(sampleFiles: DemoSampleSupport.availableSampleFiles(), loadsSynchronously: true)
        let initialReloadToken = model.documentReloadToken
        let initialText = model.documentText

        model.updateDocumentText(initialText + "\n// local edit")

        #expect(model.documentText.hasSuffix("// local edit"))
        #expect(model.documentReloadToken == initialReloadToken)

        model.selectFile(named: "example.kt")

        #expect(model.documentReloadToken == initialReloadToken + 1)
        #expect(model.documentText.contains("// Kotlin sample"))
    }

    @Test
    @MainActor
    func sweetLineProviderProjectsSyntaxIndentAndRainbowBrackets() {
        let source = """
        int main() {
            if (true) {
                return 0;
            }
        }
        """
        let view = SweetEditorView(frame: .zero)
        view.loadDocument(text: source)
        let provider = SweetLineDecorationProvider(
            editorProvider: { [weak view] in view },
            fileNameProvider: { "sample.cpp" }
        )
        let receiver = CapturingDecorationReceiver()
        let lineCount = view.getDocument()?.getLineCount() ?? 0

        provider.provideDecorations(
            context: DecorationContext(
                visibleLineRange: IntRange(start: 0, end: lineCount - 1),
                totalLineCount: lineCount,
                textChanges: [],
                languageConfiguration: nil,
                editorMetadata: nil
            ),
            receiver: receiver
        )

        #expect(!(receiver.result?.syntaxSpans ?? [:]).isEmpty)
        #expect(!(receiver.result?.overlaySpans ?? [:]).isEmpty)
        #expect(!(receiver.result?.indentGuides ?? []).isEmpty)
    }

    @Test
    func toolbarTitleAlwaysUsesPrimaryForegroundRole() {
        switch DemoToolbarStyle.titleRole(isDarkTheme: true) {
        case .primary:
            #expect(Bool(true))
        case .secondary:
            Issue.record("Expected primary role for dark theme title")
        }

        switch DemoToolbarStyle.titleRole(isDarkTheme: false) {
        case .primary:
            #expect(Bool(true))
        case .secondary:
            Issue.record("Expected primary role for light theme title")
        }
    }
}

private final class CapturingDecorationReceiver: DecorationReceiver {
    var result: DecorationResult?
    var isCancelled: Bool { false }

    func accept(_ result: DecorationResult) -> Bool {
        self.result = result
        return true
    }
}
