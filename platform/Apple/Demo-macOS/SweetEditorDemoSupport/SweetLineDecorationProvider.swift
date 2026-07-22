import Foundation
import SweetEditorMacOS
import SweetLine

public final class SweetLineDecorationProvider: DecorationProvider {
    private static let styleColor = EditorTheme.styleUserBase + 1
    private static let styleURL = EditorTheme.styleUserBase + 2
    private static let bracketStyleBase = EditorTheme.styleUserBase + 10
    private static let unmatchedBracketStyle = EditorTheme.styleUserBase + 16
    private static let bracketColorCount: Int32 = 6
    private static let engineResult = Result<HighlightEngine, Error> {
        let engine = try HighlightEngine()
        try registerStyles(in: engine)
        let syntaxURLs = DemoSampleSupport.syntaxFileURLs()
        guard !syntaxURLs.isEmpty else {
            throw ProviderError.missingSyntaxResources
        }
        for url in syntaxURLs {
            try engine.compileSyntax(fromJson: String(contentsOf: url, encoding: .utf8))
        }
        return engine
    }

    private let editorProvider: () -> SweetEditorView?
    private let fileNameProvider: () -> String
    private let sessionID = UUID().uuidString
    private var analyzer: DocumentAnalyzer?
    private var analyzerURI: String?
    private var sourceDocumentID: ObjectIdentifier?
    private var analyzedFileName = ""
    private var didReportError = false

    public init(
        editorProvider: @escaping () -> SweetEditorView?,
        fileNameProvider: @escaping () -> String
    ) {
        self.editorProvider = editorProvider
        self.fileNameProvider = fileNameProvider
    }

    deinit {
        if case let .success(engine) = Self.engineResult {
            resetAnalyzer(engine: engine)
        }
    }

    public var capabilities: DecorationType {
        [.syntaxHighlight, .overlayHighlight, .foldRegion, .indentGuide]
    }

    public func provideDecorations(context: DecorationContext, receiver: DecorationReceiver) {
        guard !receiver.isCancelled else { return }
        guard case let .success(engine) = Self.engineResult else {
            reportEngineErrorIfNeeded()
            acceptEmpty(receiver)
            return
        }
        guard let sourceDocument = editorProvider()?.getDocument() else {
            resetAnalyzer(engine: engine)
            acceptEmpty(receiver)
            return
        }

        let fileName = normalizedFileName(fileNameProvider())
        let documentID = ObjectIdentifier(sourceDocument)
        let rebuilt = analyzer == nil
            || sourceDocumentID != documentID
            || analyzedFileName != fileName
        let visibleRange = makeVisibleRange(context)

        do {
            if rebuilt {
                try rebuildAnalyzer(
                    engine: engine,
                    sourceText: sourceDocument.getText(),
                    documentID: documentID,
                    fileName: fileName
                )
            }
            guard let analyzer else {
                throw ProviderError.analyzerUnavailable(fileName)
            }

            let highlight: DocumentHighlightSlice
            if rebuilt || context.textChanges.isEmpty {
                highlight = try analyzer.analyzeLineRange(visibleRange)
            } else {
                var current = DocumentHighlightSlice()
                for change in context.textChanges {
                    guard !receiver.isCancelled else { return }
                    current = try analyzer.analyzeIncrementalInLineRange(
                        range: convertRange(
                            startLine: Int(change.range.start.line),
                            startColumn: Int(change.range.start.column),
                            endLine: Int(change.range.end.line),
                            endColumn: Int(change.range.end.column)
                        ),
                        newText: change.newText,
                        visibleRange: visibleRange
                    )
                }
                highlight = current
            }

            let guideResult = try analyzer.analyzeIndentGuidesInLineRange(visibleRange)
            let bracketResult = try analyzer.analyzeBracketPairsInLineRange(visibleRange)
            guard !receiver.isCancelled else { return }

            let syntaxMode: DecorationApplyMode = rebuilt ? .replaceAll : .replaceRange
            _ = receiver.accept(DecorationResult(
                syntaxSpans: makeSyntaxSpans(highlight),
                overlaySpans: makeRainbowBracketSpans(bracketResult),
                indentGuides: makeIndentGuides(guideResult),
                foldRegions: makeFoldRegions(guideResult),
                syntaxSpansMode: syntaxMode,
                overlaySpansMode: .replaceRange,
                indentGuidesMode: .replaceRange,
                foldRegionsMode: .replaceRange
            ))
        } catch {
            resetAnalyzer(engine: engine)
            report(error)
            acceptEmpty(receiver)
        }
    }

    public static func makeTheme(isDark: Bool) -> EditorTheme {
        var theme = isDark ? EditorTheme.xcodeDark() : EditorTheme.xcodeLight()
        let color = isDark ? UInt32(0xFFD0BF69) : UInt32(0xFF1C00CF)
        let url = isDark ? UInt32(0xFF5482FF) : UInt32(0xFF0E0EFF)
        let bracketColors: [UInt32] = isDark
            ? [0xFF5482FF, 0xFFD0BF69, 0xFF67B7A4, 0xFFA167E6, 0xFF5DD8FF, 0xFFFC6A5D]
            : [0xFF0E0EFF, 0xFFA36F00, 0xFF326D74, 0xFF6C36A9, 0xFF0B4F79, 0xFFC41A16]

        theme.defineTextStyle(styleColor, style: TextStyle(color: Int32(bitPattern: color)))
        theme.defineTextStyle(styleURL, style: TextStyle(color: Int32(bitPattern: url)))
        for (index, value) in bracketColors.enumerated() {
            theme.defineTextStyle(
                bracketStyleBase + Int32(index),
                style: TextStyle(color: Int32(bitPattern: value))
            )
        }
        let unmatched = UInt32(0xFFF74A4A)
        theme.defineTextStyle(
            unmatchedBracketStyle,
            style: TextStyle(color: Int32(bitPattern: unmatched))
        )
        return theme
    }

    private func rebuildAnalyzer(
        engine: HighlightEngine,
        sourceText: String,
        documentID: ObjectIdentifier,
        fileName: String
    ) throws {
        resetAnalyzer(engine: engine)
        let uri = "file:///sweeteditor-demo/\(sessionID)/\(fileName)"
        let document = try SweetLine.Document(uri: uri, text: sourceText)
        guard let analyzer = try engine.loadDocument(document) else {
            throw ProviderError.analyzerUnavailable(fileName)
        }
        self.analyzer = analyzer
        analyzerURI = uri
        sourceDocumentID = documentID
        analyzedFileName = fileName
    }

    private func resetAnalyzer(engine: HighlightEngine) {
        analyzer?.close()
        analyzer = nil
        if let analyzerURI {
            try? engine.removeDocument(uri: analyzerURI)
        }
        analyzerURI = nil
        sourceDocumentID = nil
        analyzedFileName = ""
    }

    private func makeVisibleRange(_ context: DecorationContext) -> LineRange {
        let start = max(0, Int(context.visibleLineRange.start))
        let end = min(context.totalLineCount - 1, Int(context.visibleLineRange.end))
        return LineRange(startLine: start, lineCount: max(0, end - start + 1))
    }

    private func convertRange(
        startLine: Int,
        startColumn: Int,
        endLine: Int,
        endColumn: Int
    ) -> SweetLine.TextRange {
        SweetLine.TextRange(
            start: SweetLine.TextPosition(line: startLine, column: startColumn),
            end: SweetLine.TextPosition(line: endLine, column: endColumn)
        )
    }

    private func makeSyntaxSpans(_ highlight: DocumentHighlightSlice) -> [Int: [StyleSpan]] {
        var result: [Int: [StyleSpan]] = [:]
        for line in highlight.lines {
            for token in line.spans {
                guard case let .styleId(styleID) = token.style,
                      styleID > 0,
                      token.range.start.line == token.range.end.line else {
                    continue
                }
                let length = token.range.end.column - token.range.start.column
                guard length > 0 else { continue }
                result[token.range.start.line, default: []].append(StyleSpan(
                    column: token.range.start.column,
                    length: length,
                    styleId: Int(styleID)
                ))
            }
        }
        return result
    }

    private func makeRainbowBracketSpans(_ brackets: BracketPairResult) -> [Int: [StyleSpan]] {
        var result: [Int: [StyleSpan]] = [:]
        for line in brackets.lines {
            for token in line.tokens where token.range.start.line == token.range.end.line {
                let length = token.range.end.column - token.range.start.column
                guard length > 0 else { continue }
                let styleID = token.matchState == .unmatched
                    ? Self.unmatchedBracketStyle
                    : Self.bracketStyleBase + Int32(token.depth % Int(Self.bracketColorCount))
                result[token.range.start.line, default: []].append(StyleSpan(
                    column: token.range.start.column,
                    length: length,
                    styleId: Int(styleID)
                ))
            }
        }
        return result
    }

    private func makeIndentGuides(_ guides: IndentGuideResult) -> [IndentGuide] {
        guides.guideLines.compactMap { guide in
            guard guide.endLine >= guide.startLine else { return nil }
            let column = max(0, guide.column)
            return IndentGuide(
                startLine: guide.startLine,
                startColumn: column,
                endLine: guide.endLine,
                endColumn: column
            )
        }
    }

    private func makeFoldRegions(_ guides: IndentGuideResult) -> [FoldRegion] {
        var seen: [Int: Set<Int>] = [:]
        return guides.guideLines.compactMap { guide in
            guard guide.endLine > guide.startLine,
                  seen[guide.startLine, default: []].insert(guide.endLine).inserted else {
                return nil
            }
            return FoldRegion(startLine: guide.startLine, endLine: guide.endLine, collapsed: false)
        }
    }

    private func normalizedFileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "sample.cpp" : trimmed
    }

    private func acceptEmpty(_ receiver: DecorationReceiver) {
        _ = receiver.accept(DecorationResult(
            syntaxSpans: [:],
            overlaySpans: [:],
            indentGuides: [],
            foldRegions: [],
            syntaxSpansMode: .replaceAll,
            overlaySpansMode: .replaceAll,
            indentGuidesMode: .replaceAll,
            foldRegionsMode: .replaceAll
        ))
    }

    private func reportEngineErrorIfNeeded() {
        guard !didReportError,
              case let .failure(error) = Self.engineResult else { return }
        didReportError = true
        report(error)
    }

    private func report(_ error: Error) {
        print("SweetLine decoration analysis failed: \(error)")
    }

    private static func registerStyles(in engine: HighlightEngine) throws {
        let styles: [(String, Int32)] = [
            ("keyword", EditorTheme.styleKeyword),
            ("type", EditorTheme.styleType),
            ("string", EditorTheme.styleString),
            ("comment", EditorTheme.styleComment),
            ("preprocessor", EditorTheme.stylePreprocessor),
            ("macro", EditorTheme.stylePreprocessor),
            ("method", EditorTheme.styleFunction),
            ("function", EditorTheme.styleFunction),
            ("variable", EditorTheme.styleVariable),
            ("field", EditorTheme.styleVariable),
            ("number", EditorTheme.styleNumber),
            ("class", EditorTheme.styleClass),
            ("builtin", EditorTheme.styleBuiltin),
            ("annotation", EditorTheme.styleAnnotation),
            ("punctuation", EditorTheme.stylePunctuation),
            ("color", styleColor),
            ("url", styleURL),
        ]
        for (name, styleID) in styles {
            try engine.registerStyleName(name, id: styleID)
        }
    }

    private enum ProviderError: Error {
        case missingSyntaxResources
        case analyzerUnavailable(String)
    }
}
