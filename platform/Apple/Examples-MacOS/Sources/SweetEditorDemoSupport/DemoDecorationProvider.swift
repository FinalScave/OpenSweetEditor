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
    private let featureQueue = DispatchQueue(label: "sweeteditor.demo.decoration.features", attributes: .concurrent)
    private var enabledFeaturesValue: DemoDecorationFeature = .all

    public init(documentLinesProvider: @escaping () -> [String] = { [] }) {
        self.documentLinesProvider = documentLinesProvider
    }

    public var capabilities: DecorationType {
        [.inlayHint, .phantomText, .diagnostic, .foldRegion, .indentGuide, .bracketGuide, .flowGuide, .separatorGuide]
    }

    public func isFeatureEnabled(_ feature: DemoDecorationFeature) -> Bool {
        featureQueue.sync {
            enabledFeaturesValue.contains(feature)
        }
    }

    public func setFeatureEnabled(_ feature: DemoDecorationFeature, enabled: Bool) {
        featureQueue.sync(flags: .barrier) {
            if enabled {
                self.enabledFeaturesValue.insert(feature)
            } else {
                self.enabledFeaturesValue.remove(feature)
            }
        }
    }

    public func provideDecorations(context: DecorationContext, receiver: DecorationReceiver) {
        let features = featureQueue.sync { enabledFeaturesValue }
        let lines = documentLinesProvider()
        guard !lines.isEmpty else {
            return
        }

        let visibleRange = makeVisibleRange(context: context)
        let blocks = resolveBlocks(lines: lines)

        let inlayHints = features.contains(.inlayHints) ? resolveInlayHints(lines: lines, visibleRange: visibleRange) : [:]
        let phantomTexts = features.contains(.phantomTexts) ? resolvePhantomTexts(lines: lines, blocks: blocks, visibleRange: visibleRange) : [:]
        let diagnostics = features.contains(.diagnostics) ? resolveDiagnostics(lines: lines, visibleRange: visibleRange) : [:]
        let foldRegions = features.contains(.foldRegions) ? resolveFoldRegions(blocks: blocks) : []
        let guidePack = features.contains(.structureGuides) ? resolveGuides(blocks: blocks, lines: lines, visibleRange: visibleRange) : .empty

        _ = receiver.accept(
            DecorationResult(
                inlayHints: inlayHints,
                diagnostics: diagnostics,
                indentGuides: guidePack.indentGuides,
                bracketGuides: guidePack.bracketGuides,
                flowGuides: guidePack.flowGuides,
                separatorGuides: guidePack.separatorGuides,
                foldRegions: foldRegions,
                phantomTexts: phantomTexts
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
            indentGuides: [],
            bracketGuides: [],
            flowGuides: [],
            separatorGuides: []
        )
    }

    private struct IndentGuideKey: Hashable {
        let startLine: Int
        let endLine: Int
        let column: Int
    }

    private func makeVisibleRange(context: DecorationContext) -> ClosedRange<Int> {
        let safeStart = max(0, context.visibleStartLine - 24)
        let safeEnd = min(max(0, context.totalLineCount - 1), context.visibleEndLine + 24)
        return safeStart...max(safeStart, safeEnd)
    }

    private func resolveBlocks(lines: [String]) -> [Block] {
        struct OpenBrace {
            let line: Int
            let column: Int
            let depth: Int
        }

        var stack: [OpenBrace] = []
        var blocks: [Block] = []

        for (lineIndex, line) in lines.enumerated() {
            for (columnIndex, scalar) in line.unicodeScalars.enumerated() {
                if scalar == "{" {
                    stack.append(OpenBrace(line: lineIndex, column: columnIndex, depth: stack.count))
                } else if scalar == "}", let opening = stack.popLast() {
                    if lineIndex > opening.line {
                        blocks.append(
                            Block(
                                startLine: opening.line,
                                startColumn: opening.column,
                                endLine: lineIndex,
                                endColumn: columnIndex,
                                depth: opening.depth
                            )
                        )
                    }
                }
            }
        }

        return blocks.sorted {
            if $0.startLine == $1.startLine {
                return $0.depth < $1.depth
            }
            return $0.startLine < $1.startLine
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

    private func resolveGuides(blocks: [Block], lines: [String], visibleRange: ClosedRange<Int>) -> GuidePack {
        var indentGuides: [DecorationResult.IndentGuideItem] = []
        var seenGuides = Set<IndentGuideKey>()

        for block in blocks where block.endLine >= visibleRange.lowerBound && block.startLine <= visibleRange.upperBound {
            if (block.endLine - block.startLine) < 2 {
                continue
            }

            if block.depth > 5 {
                continue
            }

            guard let guideColumn = resolveIndentColumn(for: block, lines: lines), guideColumn > 0 else {
                continue
            }

            let startLine = block.startLine
            let endLine = block.endLine
            let key = IndentGuideKey(startLine: startLine, endLine: endLine, column: guideColumn)
            if seenGuides.contains(key) {
                continue
            }
            seenGuides.insert(key)

            indentGuides.append(
                DecorationResult.IndentGuideItem(
                    start: TextPosition(line: startLine, column: guideColumn),
                    end: TextPosition(line: endLine, column: guideColumn)
                )
            )
        }

        return GuidePack(
            indentGuides: indentGuides,
            bracketGuides: [],
            flowGuides: [],
            separatorGuides: []
        )
    }

    private func resolveIndentColumn(for block: Block, lines: [String]) -> Int? {
        let bodyStartLine = block.startLine + 1
        if bodyStartLine >= block.endLine {
            return nil
        }

        var minIndent: Int?
        for lineIndex in bodyStartLine..<block.endLine {
            guard lineIndex < lines.count else { continue }
            let line = lines[lineIndex]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "{" || trimmed == "}" {
                continue
            }

            let indent = leadingWhitespaceColumn(in: line)
            if indent <= 0 {
                continue
            }

            if let current = minIndent {
                minIndent = min(current, indent)
            } else {
                minIndent = indent
            }
        }

        if let minIndent {
            return max(1, minIndent - 1)
        }

        return nil
    }

    private func leadingWhitespaceColumn(in line: String) -> Int {
        var column = 0
        for character in line {
            if character == " " || character == "\t" {
                column += 1
            } else {
                break
            }
        }
        return column
    }

    private func resolveInlayHints(lines: [String], visibleRange: ClosedRange<Int>) -> [Int: [DecorationResult.InlayHintItem]] {
        var result: [Int: [DecorationResult.InlayHintItem]] = [:]

        for lineIndex in visibleRange {
            guard lineIndex < lines.count else { continue }
            let line = lines[lineIndex]

            if let tokenColumn = column(of: "const", in: line) {
                result[lineIndex, default: []].append(.init(column: tokenColumn, kind: .text("immut: ")))
            }

            if let tokenColumn = column(of: "return", in: line) {
                result[lineIndex, default: []].append(.init(column: tokenColumn, kind: .text("flow: ")))
            }

            if let tokenColumn = column(of: "Point", in: line), line.contains("Point ") {
                let palette: [Int32] = [
                    Int32(bitPattern: 0xFF4CAF50),
                    Int32(bitPattern: 0xFF2196F3),
                    Int32(bitPattern: 0xFFFF9800),
                ]
                let color = palette[lineIndex % palette.count]
                result[lineIndex, default: []].append(.init(column: tokenColumn, kind: .color(color)))
            }
        }

        return result
    }

    private func resolvePhantomTexts(
        lines: [String],
        blocks: [Block],
        visibleRange: ClosedRange<Int>
    ) -> [Int: [DecorationResult.PhantomTextItem]] {
        var result: [Int: [DecorationResult.PhantomTextItem]] = [:]

        for block in blocks where visibleRange.contains(block.endLine) {
            guard block.endLine < lines.count else { continue }
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

    private func resolveDiagnostics(lines: [String], visibleRange: ClosedRange<Int>) -> [Int: [DecorationResult.DiagnosticItem]] {
        var result: [Int: [DecorationResult.DiagnosticItem]] = [:]

        for lineIndex in visibleRange {
            guard lineIndex < lines.count else { continue }
            let line = lines[lineIndex]

            if let column = column(of: "std::sqrt", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: Int32("std::sqrt".count), severity: 1, color: 0)
                )
            }

            if let column = column(of: "return", in: line), line.contains("return ") {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: Int32("return".count), severity: 2, color: 0)
                )
            }

            if let column = column(of: "lineCount", in: line) {
                result[lineIndex, default: []].append(
                    .init(column: Int32(column), length: Int32("lineCount".count), severity: 3, color: Int32(bitPattern: 0xFFFF8C00))
                )
            }
        }

        return result
    }

    private func column(of token: String, in line: String) -> Int? {
        guard let range = line.range(of: token) else { return nil }
        return line.distance(from: line.startIndex, to: range.lowerBound)
    }
}
