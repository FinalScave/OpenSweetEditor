import Foundation
import SweetEditoriOS

enum DemoDecorationResolver {
    static func resolve(lines: [String]) -> EditorResolvedDecorations {
        let blocks = resolveBlocks(lines: lines)

        return EditorResolvedDecorations(
            foldRegions: resolveFoldRegions(blocks: blocks),
            diagnostics: resolveDiagnostics(lines: lines),
            textInlays: resolveTextInlays(lines: lines),
            colorInlays: resolveColorInlays(lines: lines),
            phantomTexts: resolvePhantomTexts(lines: lines, blocks: blocks)
        )
    }

    private struct Block {
        let startLine: Int
        let endLine: Int
        let endColumn: Int
        let openingLineText: String
    }

    private static func resolveBlocks(lines: [String]) -> [Block] {
        var stack: [(line: Int, column: Int)] = []
        var blocks: [Block] = []

        for (lineIndex, line) in lines.enumerated() {
            for (columnIndex, character) in line.enumerated() {
                if character == "{" {
                    stack.append((lineIndex, columnIndex))
                } else if character == "}", let opening = stack.popLast(), lineIndex > opening.line {
                    blocks.append(
                        Block(
                            startLine: opening.line,
                            endLine: lineIndex,
                            endColumn: columnIndex,
                            openingLineText: lines[opening.line]
                        )
                    )
                }
            }
        }

        return blocks
    }

    private static func resolveFoldRegions(blocks: [Block]) -> [EditorFoldRegion] {
        blocks
            .filter { ($0.endLine - $0.startLine) >= 2 }
            .prefix(12)
            .map {
                EditorFoldRegion(
                    startLine: $0.startLine,
                    endLine: $0.endLine,
                    collapsed: false
                )
            }
    }

    private static func resolveDiagnostics(lines: [String]) -> [EditorLineDiagnostics] {
        var diagnosticsByLine: [Int: [EditorDiagnosticItem]] = [:]

        appendDiagnostic(
            containing: "colors = {",
            token: "colors",
            severity: 1,
            color: 0,
            lines: lines,
            diagnosticsByLine: &diagnosticsByLine
        )
        appendDiagnostic(
            containing: "delay(100)",
            token: "delay",
            severity: 2,
            color: 0,
            lines: lines,
            diagnosticsByLine: &diagnosticsByLine
        )
        appendDiagnostic(
            containing: "error(\"something went wrong\")",
            token: "error",
            severity: 3,
            color: 0,
            lines: lines,
            diagnosticsByLine: &diagnosticsByLine
        )

        return diagnosticsByLine.keys.sorted().map { line in
            EditorLineDiagnostics(line: line, items: diagnosticsByLine[line] ?? [])
        }
    }

    private static func appendDiagnostic(
        containing needle: String,
        token: String,
        severity: Int32,
        color: Int32,
        lines: [String],
        diagnosticsByLine: inout [Int: [EditorDiagnosticItem]]
    ) {
        guard let lineIndex = lines.firstIndex(where: { $0.contains(needle) }),
              let column = column(of: token, in: lines[lineIndex]) else {
            return
        }

        diagnosticsByLine[lineIndex, default: []].append(
            EditorDiagnosticItem(
                column: Int32(column),
                length: Int32(token.count),
                severity: severity,
                color: color
            )
        )
    }

    private static func resolveTextInlays(lines: [String]) -> [EditorTextInlay] {
        var items: [EditorTextInlay] = []

        appendTextInlay(containing: "class ", token: "class", label: "type: ", lines: lines, items: &items)
        appendTextInlay(containing: "interface ", token: "interface", label: "api: ", lines: lines, items: &items)
        appendTextInlay(containing: "fun main()", token: "fun", label: "entry: ", lines: lines, items: &items)
        appendTextInlay(containing: "local function greet", token: "local", label: "lua: ", lines: lines, items: &items)

        return items
    }

    private static func appendTextInlay(
        containing needle: String,
        token: String,
        label: String,
        lines: [String],
        items: inout [EditorTextInlay]
    ) {
        guard let lineIndex = lines.firstIndex(where: { $0.contains(needle) }),
              let column = column(of: token, in: lines[lineIndex]) else {
            return
        }

        items.append(EditorTextInlay(line: lineIndex, column: column, text: label))
    }

    private static func resolveColorInlays(lines: [String]) -> [EditorColorInlay] {
        let palette: [(token: String, color: UInt32)] = [
            ("0xFF5B9BD5", 0xFF5B9BD5),
            ("0xFFED7D31", 0xFFED7D31),
            ("0xFF70AD47", 0xFF70AD47),
        ]

        return palette.compactMap { entry in
            guard let lineIndex = lines.firstIndex(where: { $0.contains(entry.token) }),
                  let column = column(of: entry.token, in: lines[lineIndex]) else {
                return nil
            }

            return EditorColorInlay(line: lineIndex, column: column, color: Int32(bitPattern: entry.color))
        }
    }

    private static func resolvePhantomTexts(lines: [String], blocks: [Block]) -> [EditorPhantomText] {
        blocks.prefix(12).map { block in
            EditorPhantomText(
                line: block.endLine,
                column: max(1, block.endColumn + 2),
                text: phantomLabel(for: block.openingLineText)
            )
        }
    }

    private static func phantomLabel(for line: String) -> String {
        if line.contains("class ") {
            return " // end class"
        }
        if line.contains("interface ") {
            return " // end interface"
        }
        if line.contains("enum ") {
            return " // end enum"
        }
        if line.contains("function ") || line.contains("fun ") {
            return " // end function"
        }
        return " // end block"
    }

    private static func column(of needle: String, in line: String) -> Int? {
        guard let range = line.range(of: needle) else {
            return nil
        }

        return line.distance(from: line.startIndex, to: range.lowerBound)
    }
}
