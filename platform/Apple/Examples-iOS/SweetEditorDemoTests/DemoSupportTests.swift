import Foundation
import Testing
import SweetEditoriOS
@testable import SweetEditorDemo

struct DemoSupportTests {
    @Test
    func sampleFilesProvideExpectedNames() {
        let files = DemoSampleSupport.availableSampleFiles()

        #expect(files.map(\.fileName) == ["example.java", "example.kt", "example.lua", "nlohmann-json.hpp", "View.java"])
    }

    @Test
    func largeSampleFilesDisableDemoDecorations() {
        let files = DemoSampleSupport.availableSampleFiles()

        let largeFiles = files.filter { !$0.supportsDemoDecorations }

        #expect(largeFiles.map(\.fileName) == ["nlohmann-json.hpp", "View.java"])
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
        #expect(model.shouldApplyDecorations)
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
    func decorationResolverProvidesBasicDemoDecorations() {
        let lines = DemoSampleSupport.availableSampleFiles()[0].text.components(separatedBy: "\n")
        let decorations = DemoDecorationResolver.resolve(lines: lines)

        #expect(!decorations.foldRegions.isEmpty)
        #expect(!decorations.diagnostics.isEmpty)
        #expect(!decorations.textInlays.isEmpty)
        #expect(!decorations.phantomTexts.isEmpty)
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
