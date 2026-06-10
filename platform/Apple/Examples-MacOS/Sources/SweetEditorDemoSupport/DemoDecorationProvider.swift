import Foundation
import SweetEditorMacOS

public struct DemoDecorationFeature: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let inlayHints = DemoDecorationFeature(rawValue: 1 << 0)
    public static let phantomTexts = DemoDecorationFeature(rawValue: 1 << 1)
    public static let diagnostics = DemoDecorationFeature(rawValue: 1 << 2)
    public static let foldRegions = DemoDecorationFeature(rawValue: 1 << 3)
    public static let structureGuides = DemoDecorationFeature(rawValue: 1 << 4)

    public static let all: DemoDecorationFeature = [
        .inlayHints,
        .phantomTexts,
        .diagnostics,
        .foldRegions,
        .structureGuides,
    ]
}

public final class DemoDecorationProvider: DecorationProvider {
    private let documentLinesProvider: () -> [String]
    private let featureQueue = DispatchQueue(
        label: "sweeteditor.demo.decoration.features", attributes: .concurrent)
    private var enabledFeaturesValue: DemoDecorationFeature = .all

    public init(documentLinesProvider: @escaping () -> [String] = { [] }) {
        self.documentLinesProvider = documentLinesProvider
    }

    public var capabilities: DecorationType {
        [
            .inlayHint, .phantomText, .diagnostic, .foldRegion, .indentGuide, .bracketGuide,
            .flowGuide, .separatorGuide,
        ]
    }

    public func isFeatureEnabled(_ feature: DemoDecorationFeature) -> Bool {
        featureQueue.sync { enabledFeaturesValue.contains(feature) }
    }

    public func setFeatureEnabled(_ feature: DemoDecorationFeature, enabled: Bool) {
        featureQueue.sync(flags: .barrier) {
            if enabled {
                enabledFeaturesValue.insert(feature)
            } else {
                enabledFeaturesValue.remove(feature)
            }
        }
    }

    public func provideDecorations(context: DecorationContext, receiver: DecorationReceiver) {
        let features = featureQueue.sync { enabledFeaturesValue }
        let lines = documentLinesProvider()
        guard !lines.isEmpty else { return }

        let visibleRange = makeVisibleRange(context: context)
        let blocks = resolveBlocks(lines: lines)

        let inlayHints =
            features.contains(.inlayHints)
            ? resolveInlayHints(lines: lines, visibleRange: visibleRange) : [:]
        let phantomTexts =
            features.contains(.phantomTexts)
            ? resolvePhantomTexts(lines: lines, blocks: blocks, visibleRange: visibleRange) : [:]
        let diagnostics =
            features.contains(.diagnostics)
            ? resolveDiagnostics(lines: lines, visibleRange: visibleRange) : [:]
        let foldRegions = features.contains(.foldRegions) ? resolveFoldRegions(blocks: blocks) : []
        let guidePack =
            features.contains(.structureGuides)
            ? resolveGuides(blocks: blocks, lines: lines, visibleRange: visibleRange) : .empty

        _ = receiver.accept(
            DecorationResult(
                inlayHints: inlayHints,
                diagnostics: diagnostics,
                indentGuides: guidePack.indentGuides,
                bracketGuides: guidePack.bracketGuides,
                flowGuides: guidePack.flowGuides,
                separatorGuides: guidePack.separatorGuides,
                foldRegions: foldRegions,
                phantomTexts: phantomTexts,
                inlayHintsMode: .replaceRange,
                diagnosticsMode: .replaceRange,
                indentGuidesMode: .replaceRange,
                bracketGuidesMode: .replaceRange,
                flowGuidesMode: .replaceRange,
                separatorGuidesMode: .replaceRange,
                foldRegionsMode: .replaceAll,
                phantomTextsMode: .replaceRange
            )
        )
    }

    private struct Block {
        let startLine: Int
        let startColumn: Int
        let endLine: Int
        let endColumn: Int
        let depth: Int
    }

    private struct GuidePack {
        let indentGuides: [DecorationResult.IndentGuideItem]
        let bracketGuides: [DecorationResult.BracketGuideItem]
        let flowGuides: [DecorationResult.FlowGuideItem]
        let separatorGuides: [DecorationResult.SeparatorGuideItem]

        static let empty = GuidePack(
            indentGuides: [], bracketGuides: [], flowGuides: [], separatorGuides: [])
    }

    private func makeVisibleRange(context: DecorationContext) -> ClosedRange<Int> {
        let safeStart = max(0, context.visibleLineRange.start - 24)
        let safeEnd = max(safeStart, min(context.totalLineCount - 1, context.visibleLineRange.end + 24))
        return safeStart...safeEnd
    }

    private func resolveBlocks(lines: [String]) -> [Block] {
        struct OpenBrace {
            let line: Int
            let column: Int
            let depth: Int
        }

        var stack: [OpenBrace] = []
        var blocks: [Block] = []
        blocks.reserveCapacity(lines.count / 2)

        var inBlockComment = false

        for (lineIndex, line) in lines.enumerated() {
            let utf16 = line.utf16
            var i = utf16.startIndex
            let end = utf16.endIndex
            var column = 0

            var inString = false
            var inChar = false
            var escapeNext = false

            while i < end {
                let codeUnit = utf16[i]
                var step = 1

                let nextI = utf16.index(after: i)
                let nextCodeUnit = nextI < end ? utf16[nextI] : 0

                if inBlockComment {
                    if codeUnit == 0x002A && nextCodeUnit == 0x002F {  // "*/"
                        inBlockComment = false
                        step = 2
                    }
                } else if inString {
                    if escapeNext {
                        escapeNext = false
                    } else if codeUnit == 0x005C {  // "\"
                        escapeNext = true
                    } else if codeUnit == 0x0022 {  // "\""
                        inString = false
                    }
                } else if inChar {
                    if escapeNext {
                        escapeNext = false
                    } else if codeUnit == 0x005C {  // "\"
                        escapeNext = true
                    } else if codeUnit == 0x0027 {  // "'"
                        inChar = false
                    }
                } else {
                    if codeUnit == 0x002F && nextCodeUnit == 0x002F {  // "//"
                        break
                    } else if codeUnit == 0x002F && nextCodeUnit == 0x002A {  // "/*"
                        inBlockComment = true
                        step = 2
                    } else if codeUnit == 0x0022 {  // "\""
                        inString = true
                    } else if codeUnit == 0x0027 {  // "'"
                        inChar = true
                    } else if codeUnit == 0x007B {  // "{"
                        stack.append(OpenBrace(line: lineIndex, column: column, depth: stack.count))
                    } else if codeUnit == 0x007D {  // "}"
                        if let opening = stack.popLast(), lineIndex > opening.line {
                            blocks.append(
                                Block(
                                    startLine: opening.line,
                                    startColumn: opening.column,
                                    endLine: lineIndex,
                                    endColumn: column,
                                    depth: opening.depth
                                )
                            )
                        }
                    }
                }

                if step == 2 {
                    i = utf16.index(after: nextI)
                    column += 2
                } else {
                    i = nextI
                    column += 1
                }
            }
        }

        return blocks.sorted {
            $0.startLine == $1.startLine ? $0.depth < $1.depth : $0.startLine < $1.startLine
        }
    }

    private func resolveFoldRegions(blocks: [Block]) -> [DecorationResult.FoldRegionItem] {
        blocks
            .filter { ($0.endLine - $0.startLine) >= 2 }
            .prefix(18)
            .map {
                DecorationResult.FoldRegionItem(
                    startLine: $0.startLine,
                    endLine: $0.endLine,
                    collapsed: $0.depth >= 3
                )
            }
    }

    private func resolveGuides(blocks: [Block], lines: [String], visibleRange: ClosedRange<Int>)
        -> GuidePack
    {
        var indentGuides: [DecorationResult.IndentGuideItem] = []
        indentGuides.reserveCapacity(blocks.count)

        for block in blocks {
            guard block.endLine >= visibleRange.lowerBound,
                block.startLine <= visibleRange.upperBound,
                (block.endLine - block.startLine) >= 2,
                block.depth <= 5
            else {
                continue
            }

            let guideColumn = leadingWhitespaceColumn(in: lines[block.startLine])
            guard guideColumn > 0 else { continue }

            indentGuides.append(
                DecorationResult.IndentGuideItem(
                    start: TextPosition(line: block.startLine, column: guideColumn),
                    end: TextPosition(line: block.endLine, column: guideColumn)
                )
            )
        }

        return GuidePack(
            indentGuides: indentGuides, bracketGuides: [], flowGuides: [], separatorGuides: [])
    }

    private func leadingWhitespaceColumn(in line: String) -> Int {
        var column = 0
        for codeUnit in line.utf16 {
            if codeUnit == 0x0020 || codeUnit == 0x0009 {  // Space or Tab
                column += 1
            } else {
                break
            }
        }
        return column
    }

    private func resolveInlayHints(lines: [String], visibleRange: ClosedRange<Int>) -> [Int:
        [DecorationResult.InlayHintItem]]
    {
        var result: [Int: [DecorationResult.InlayHintItem]] = [:]

        for lineIndex in visibleRange {
            guard lineIndex < lines.count else { continue }
            let line = lines[lineIndex]

            if let tokenColumn = column(of: "const", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: tokenColumn, kind: .text("immut: ")))
            }

            if let tokenColumn = column(of: "return", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: tokenColumn, kind: .text("flow: ")))
            }

            if line.contains("Point "), let tokenColumn = column(of: "Point", in: line) {
                let palette: [Int32] = [
                    Int32(bitPattern: 0xFF4C_AF50),
                    Int32(bitPattern: 0xFF21_96F3),
                    Int32(bitPattern: 0xFFFF_9800),
                ]
                result[lineIndex, default: []].append(
                    .init(column: tokenColumn, kind: .color(palette[lineIndex % palette.count])))
            }
        }

        return result
    }

    private func resolvePhantomTexts(
        lines: [String], blocks: [Block], visibleRange: ClosedRange<Int>
    ) -> [Int: [DecorationResult.PhantomTextItem]] {
        var result: [Int: [DecorationResult.PhantomTextItem]] = [:]

        for block in blocks
        where visibleRange.contains(block.endLine) && block.endLine < lines.count {
            let text = lines[block.startLine]
            let tag: String

            if text.contains("class ") {
                tag = " // end class scope"
            } else if text.contains("struct ") {
                tag = " // end struct scope"
            } else if text.contains("namespace ") {
                tag = " // end namespace"
            } else if text.contains("main(") {
                tag = " // end entrypoint"
            } else {
                tag = " // end block"
            }

            result[block.endLine, default: []].append(
                DecorationResult.PhantomTextItem(column: max(1, block.endColumn + 2), text: tag)
            )
        }

        return result
    }

    private func resolveDiagnostics(lines: [String], visibleRange: ClosedRange<Int>) -> [Int:
        [DecorationResult.DiagnosticItem]]
    {
        var result: [Int: [DecorationResult.DiagnosticItem]] = [:]

        for lineIndex in visibleRange {
            guard lineIndex < lines.count else { continue }
            let line = lines[lineIndex]

            if let column = column(of: "std::sqrt", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: 9, severity: 1))
            }

            if line.contains("return "), let column = column(of: "return", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: 6, severity: 2))
            }

            if let column = column(of: "lineCount", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: 9, severity: 3))
            }
        }

        return result
    }

    private func column(of token: String, in line: String) -> Int? {
        guard let range = line.range(of: token) else { return nil }
        return line.distance(from: line.startIndex, to: range.lowerBound)
    }
}
