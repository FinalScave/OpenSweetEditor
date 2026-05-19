import Foundation
import CoreText
import CoreGraphics
import SweetEditorBridge

// MARK: - Font style constants (matches C++ FontStyle enum)
let FONT_STYLE_NORMAL: Int32        = 0
let FONT_STYLE_BOLD: Int32          = 1       // 1 << 0
let FONT_STYLE_ITALIC: Int32        = 1 << 1  // 2
let FONT_STYLE_STRIKETHROUGH: Int32 = 1 << 2  // 4

// MARK: - KeyCode enum (matches C++ KeyCode in editor_core.h)
enum SEKeyCode: UInt16 {
    case none       = 0
    case backspace  = 8
    case tab        = 9
    case enter      = 13
    case escape     = 27
    case deleteKey  = 46
    case left       = 37
    case up         = 38
    case right      = 39
    case down       = 40
    case home       = 36
    case end        = 35
    case pageUp     = 33
    case pageDown   = 34
    case a          = 65
    case c          = 67
    case v          = 86
    case x          = 88
    case z          = 90
    case y          = 89
}

// MARK: - Modifier flags (matches C++ Modifier in gesture.h)
struct SEModifier: OptionSet {
    let rawValue: UInt8
    static let shift = SEModifier(rawValue: 1 << 0)
    static let ctrl  = SEModifier(rawValue: 1 << 1)
    static let alt   = SEModifier(rawValue: 1 << 2)
    static let meta  = SEModifier(rawValue: 1 << 3)
}

// MARK: - EventType (matches C++ EventType in gesture.h)
enum SEEventType: UInt8, Codable {
    case undefined         = 0
    case touchDown         = 1
    case touchPointerDown  = 2
    case touchMove         = 3
    case touchPointerUp    = 4
    case touchUp           = 5
    case touchCancel       = 6
    case mouseDown         = 7
    case mouseMove         = 8
    case mouseUp           = 9
    case mouseWheel        = 10
    case mouseRightDown    = 11
    case directScale       = 12
    case directScroll      = 13
}

// MARK: - SweetEditorCore

class SweetEditorCore {
    private(set) var handle: Int = 0
    private lazy var protocolDecoder = ProtocolDecoder(owner: self)
    private lazy var protocolEncoder = ProtocolEncoder(owner: self)
    private(set) var scrollbarConfig = ScrollbarConfig()
    private var compositionEnabled = true

    struct InlayHintPayload {
        enum Kind {
            case text(String)
            case icon(Int32)
            case color(Int32)
        }

        let column: Int
        let kind: Kind

        static func text(column: Int, text: String) -> InlayHintPayload {
            InlayHintPayload(column: column, kind: .text(text))
        }

        static func icon(column: Int, iconId: Int32) -> InlayHintPayload {
            InlayHintPayload(column: column, kind: .icon(iconId))
        }

        static func color(column: Int, color: Int32) -> InlayHintPayload {
            InlayHintPayload(column: column, kind: .color(color))
        }
    }

    struct PhantomTextPayload {
        let column: Int
        let text: String
    }

    struct DiagnosticPayload {
        let column: Int32
        let length: Int32
        let severity: Int32
    }

    struct IndentGuidePayload {
        let startLine: Int
        let startColumn: Int
        let endLine: Int
        let endColumn: Int
    }

    struct BracketGuidePayload {
        let parentLine: Int
        let parentColumn: Int
        let endLine: Int
        let endColumn: Int
        let children: [(line: Int, column: Int)]
    }

    struct FlowGuidePayload {
        let startLine: Int
        let startColumn: Int
        let endLine: Int
        let endColumn: Int
    }

    struct SeparatorGuidePayload {
        let line: Int32
        let style: Int32
        let count: Int32
        let textEndColumn: UInt32
    }

    struct StyleSpan {
        let column: UInt32
        let length: UInt32
        let styleId: UInt32

        init(column: UInt32, length: UInt32, styleId: UInt32) {
            self.column = column
            self.length = length
            self.styleId = styleId
        }
    }

    struct DiagnosticItem {
        let column: Int32
        let length: Int32
        let severity: Int32

        init(column: Int32, length: Int32, severity: Int32) {
            self.column = column
            self.length = length
            self.severity = severity
        }
    }

    struct GutterIcon {
        let iconId: Int32

        init(iconId: Int32) {
            self.iconId = iconId
        }
    }

    struct CodeLensPayload {
        let column: Int32
        let text: String
        let commandId: Int32

        init(column: Int32, text: String, commandId: Int32) {
            self.column = column
            self.text = text
            self.commandId = commandId
        }
    }

    struct LinkSpan {
        let column: Int
        let length: Int
        let target: String

        init(column: Int, length: Int, target: String) {
            self.column = column
            self.length = length
            self.target = target
        }
    }

    struct FoldRegion {
        let startLine: Int
        let endLine: Int
        let collapsed: Bool

        init(startLine: Int, endLine: Int, collapsed: Bool) {
            self.startLine = startLine
            self.endLine = endLine
            self.collapsed = collapsed
        }
    }

    private static let threadDictionaryKey = NSString(string: "SweetEditorCore.currentStack")

    private final class ThreadCoreStack: NSObject {
        private var stack: [WeakCoreBox] = []

        func push(_ core: SweetEditorCore) {
            stack.append(WeakCoreBox(core: core))
        }

        func pop() {
            if !stack.isEmpty {
                stack.removeLast()
            }
        }

        func current() -> SweetEditorCore? {
            while let last = stack.last, last.core == nil {
                stack.removeLast()
            }
            return stack.last?.core
        }

        var isEmpty: Bool { stack.isEmpty }
    }

    private final class WeakCoreBox {
        weak var core: SweetEditorCore?

        init(core: SweetEditorCore) {
            self.core = core
        }
    }

    private final class ProtocolEncoder {
        unowned let owner: SweetEditorCore

        init(owner: SweetEditorCore) {
            self.owner = owner
        }

        func packLineSpans(line: Int, layer: Int, spans: [(column: UInt32, length: UInt32, styleId: UInt32)]) -> Data {
            var payload = Data()
            payload.reserveCapacity(12 + spans.count * 12)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(layer), to: &payload)
            appendU32(UInt32(spans.count), to: &payload)
            for span in spans {
                appendU32(span.column, to: &payload)
                appendU32(span.length, to: &payload)
                appendU32(span.styleId, to: &payload)
            }
            return payload
        }

        func packLineSpans(line: Int, layer: Int, spans: [StyleSpan]) -> Data {
            let tuples = spans.map { (column: $0.column, length: $0.length, styleId: $0.styleId) }
            return packLineSpans(line: line, layer: layer, spans: tuples)
        }

        func packBatchLineSpans(layer: Int,
                                spansByLine: [Int: [(column: UInt32, length: UInt32, styleId: UInt32)]]) -> Data {
            let lines = spansByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(8 + lines.reduce(0) {
                $0 + 8 + (spansByLine[$1]?.count ?? 0) * 12
            })
            appendU32(UInt32(layer), to: &payload)
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let spans = spansByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(spans.count), to: &payload)
                for span in spans {
                    appendU32(span.column, to: &payload)
                    appendU32(span.length, to: &payload)
                    appendU32(span.styleId, to: &payload)
                }
            }
            return payload
        }

        func packBatchLineSpans(layer: Int, spansByLine: [Int: [StyleSpan]]) -> Data {
            let tuples = spansByLine.mapValues { spans in
                spans.map { (column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            return packBatchLineSpans(layer: layer, spansByLine: tuples)
        }

        func packBatchTextStyles(_ stylesById: [UInt32: (color: Int32, backgroundColor: Int32, fontStyle: Int32)]) -> Data {
            let styleIds = stylesById.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + styleIds.count * 16)
            appendU32(UInt32(styleIds.count), to: &payload)
            for styleId in styleIds {
                let style = stylesById[styleId] ?? (0, 0, 0)
                appendU32(styleId, to: &payload)
                appendI32(style.color, to: &payload)
                appendI32(style.backgroundColor, to: &payload)
                appendI32(style.fontStyle, to: &payload)
            }
            return payload
        }

        func packLineInlayHints(line: Int, hints: [InlayHintPayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + hints.count * 24)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(hints.count), to: &payload)
            for hint in hints {
                appendInlayHint(hint, to: &payload)
            }
            return payload
        }

        func packBatchLineInlayHints(_ hintsByLine: [Int: [InlayHintPayload]]) -> Data {
            let lines = hintsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (hintsByLine[$1]?.count ?? 0) * 24
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let hints = hintsByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(hints.count), to: &payload)
                for hint in hints {
                    appendInlayHint(hint, to: &payload)
                }
            }
            return payload
        }

        func packLinePhantomTexts(line: Int, phantoms: [PhantomTextPayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + phantoms.count * 16)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(phantoms.count), to: &payload)
            for phantom in phantoms {
                appendU32(UInt32(phantom.column), to: &payload)
                appendUTF8(phantom.text, to: &payload)
            }
            return payload
        }

        func packBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomTextPayload]]) -> Data {
            let lines = phantomsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (phantomsByLine[$1]?.count ?? 0) * 16
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let phantoms = phantomsByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(phantoms.count), to: &payload)
                for phantom in phantoms {
                    appendU32(UInt32(phantom.column), to: &payload)
                    appendUTF8(phantom.text, to: &payload)
                }
            }
            return payload
        }

        func packLineGutterIcons(line: Int, iconIds: [Int32]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + iconIds.count * 4)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(iconIds.count), to: &payload)
            for iconId in iconIds {
                appendI32(iconId, to: &payload)
            }
            return payload
        }

        func packLineGutterIcons(line: Int, icons: [GutterIcon]) -> Data {
            let iconIds = icons.map(\.iconId)
            return packLineGutterIcons(line: line, iconIds: iconIds)
        }

        func packBatchLineGutterIcons(_ iconIdsByLine: [Int: [Int32]]) -> Data {
            let lines = iconIdsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (iconIdsByLine[$1]?.count ?? 0) * 4
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let iconIds = iconIdsByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(iconIds.count), to: &payload)
                for iconId in iconIds {
                    appendI32(iconId, to: &payload)
                }
            }
            return payload
        }

        func packBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) -> Data {
            let iconIdsByLine = iconsByLine.mapValues { icons in
                icons.map(\.iconId)
            }
            return packBatchLineGutterIcons(iconIdsByLine)
        }

        func packLineCodeLens(line: Int, items: [CodeLensPayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + items.count * 20)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(items.count), to: &payload)
            for item in items {
                appendI32(item.column, to: &payload)
                appendI32(item.commandId, to: &payload)
                appendUTF8(item.text, to: &payload)
            }
            return payload
        }

        func packBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensPayload]]) -> Data {
            let lines = itemsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (itemsByLine[$1]?.count ?? 0) * 20
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let items = itemsByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(items.count), to: &payload)
                for item in items {
                    appendI32(item.column, to: &payload)
                    appendI32(item.commandId, to: &payload)
                    appendUTF8(item.text, to: &payload)
                }
            }
            return payload
        }

        func packLineLinks(line: Int, links: [LinkSpan]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + links.reduce(0) { $0 + 12 + ($1.target.lengthOfBytes(using: .utf8)) })
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(links.count), to: &payload)
            for link in links {
                appendU32(UInt32(link.column), to: &payload)
                appendU32(UInt32(link.length), to: &payload)
                appendUTF8(link.target, to: &payload)
            }
            return payload
        }

        func packBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) -> Data {
            let lines = linksByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) { partial, line in
                let links = linksByLine[line] ?? []
                return partial + 8 + links.reduce(0) { $0 + 12 + ($1.target.lengthOfBytes(using: .utf8)) }
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let links = linksByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(links.count), to: &payload)
                for link in links {
                    appendU32(UInt32(link.column), to: &payload)
                    appendU32(UInt32(link.length), to: &payload)
                    appendUTF8(link.target, to: &payload)
                }
            }
            return payload
        }

        func packLineDiagnostics(line: Int, diagnostics: [(column: Int32, length: Int32, severity: Int32)]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + diagnostics.count * 12)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(diagnostics.count), to: &payload)
            for diagnostic in diagnostics {
                appendI32(diagnostic.column, to: &payload)
                appendI32(diagnostic.length, to: &payload)
                appendI32(diagnostic.severity, to: &payload)
            }
            return payload
        }

        func packLineDiagnostics(line: Int, items: [DiagnosticItem]) -> Data {
            let diagnostics = items.map { (column: $0.column, length: $0.length, severity: $0.severity) }
            return packLineDiagnostics(line: line, diagnostics: diagnostics)
        }

        func packBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticPayload]]) -> Data {
            let lines = diagnosticsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (diagnosticsByLine[$1]?.count ?? 0) * 12
            })
            appendU32(UInt32(lines.count), to: &payload)
            for line in lines {
                let diagnostics = diagnosticsByLine[line] ?? []
                appendU32(UInt32(line), to: &payload)
                appendU32(UInt32(diagnostics.count), to: &payload)
                for diagnostic in diagnostics {
                    appendI32(diagnostic.column, to: &payload)
                    appendI32(diagnostic.length, to: &payload)
                    appendI32(diagnostic.severity, to: &payload)
                }
            }
            return payload
        }

        func packBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticItem]]) -> Data {
            let payloads = diagnosticsByLine.mapValues { items in
                items.map {
                    DiagnosticPayload(column: $0.column, length: $0.length, severity: $0.severity)
                }
            }
            return packBatchLineDiagnostics(payloads)
        }

        func packIndentGuides(_ guides: [IndentGuidePayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(4 + guides.count * 16)
            appendU32(UInt32(guides.count), to: &payload)
            for guide in guides {
                appendU32(UInt32(guide.startLine), to: &payload)
                appendU32(UInt32(guide.startColumn), to: &payload)
                appendU32(UInt32(guide.endLine), to: &payload)
                appendU32(UInt32(guide.endColumn), to: &payload)
            }
            return payload
        }

        func packBracketGuides(_ guides: [BracketGuidePayload]) -> Data {
            let fixedCapacity = 20
            let childCapacity = guides.reduce(0) { $0 + ($1.children.count * 8) }
            var payload = Data()
            payload.reserveCapacity(4 + guides.count * fixedCapacity + childCapacity)
            appendU32(UInt32(guides.count), to: &payload)
            for guide in guides {
                appendU32(UInt32(guide.parentLine), to: &payload)
                appendU32(UInt32(guide.parentColumn), to: &payload)
                appendU32(UInt32(guide.endLine), to: &payload)
                appendU32(UInt32(guide.endColumn), to: &payload)
                appendU32(UInt32(guide.children.count), to: &payload)
                for child in guide.children {
                    appendU32(UInt32(child.line), to: &payload)
                    appendU32(UInt32(child.column), to: &payload)
                }
            }
            return payload
        }

        func packFlowGuides(_ guides: [FlowGuidePayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(4 + guides.count * 16)
            appendU32(UInt32(guides.count), to: &payload)
            for guide in guides {
                appendU32(UInt32(guide.startLine), to: &payload)
                appendU32(UInt32(guide.startColumn), to: &payload)
                appendU32(UInt32(guide.endLine), to: &payload)
                appendU32(UInt32(guide.endColumn), to: &payload)
            }
            return payload
        }

        func packSeparatorGuides(_ guides: [SeparatorGuidePayload]) -> Data {
            var payload = Data()
            payload.reserveCapacity(4 + guides.count * 16)
            appendU32(UInt32(guides.count), to: &payload)
            for guide in guides {
                appendI32(guide.line, to: &payload)
                appendI32(guide.style, to: &payload)
                appendI32(guide.count, to: &payload)
                appendU32(guide.textEndColumn, to: &payload)
            }
            return payload
        }

        func packFoldRegions(startLines: [Int], endLines: [Int], collapsed: [Bool]) -> Data {
            let count = min(startLines.count, min(endLines.count, collapsed.count))
            var payload = Data()
            payload.reserveCapacity(4 + count * 12)
            appendU32(UInt32(count), to: &payload)
            for i in 0..<count {
                appendU32(UInt32(startLines[i]), to: &payload)
                appendU32(UInt32(endLines[i]), to: &payload)
                appendU32(collapsed[i] ? 1 : 0, to: &payload)
            }
            return payload
        }

        func packFoldRegions(_ regions: [FoldRegion]) -> Data {
            return packFoldRegions(
                startLines: regions.map(\.startLine),
                endLines: regions.map(\.endLine),
                collapsed: regions.map(\.collapsed)
            )
        }

        func packLinkedEditing(model: LinkedEditingModel) -> Data {
            let groups = model.groups
            let groupCount = groups.count
            var rangeCount = 0
            var textBlobSize = 0
            var groupTextBytes: [Data?] = Array(repeating: nil, count: groupCount)
            for i in 0..<groupCount {
                let group = groups[i]
                rangeCount += group.ranges.count
                if let text = group.defaultText {
                    let bytes = text.data(using: .utf8) ?? Data()
                    groupTextBytes[i] = bytes
                    textBlobSize += bytes.count
                }
            }

            var payload = Data()
            payload.reserveCapacity(12 + groupCount * 12 + rangeCount * 20 + textBlobSize)
            appendU32(UInt32(groupCount), to: &payload)
            appendU32(UInt32(rangeCount), to: &payload)
            appendU32(UInt32(textBlobSize), to: &payload)

            var textOffset = 0
            for i in 0..<groupCount {
                let group = groups[i]
                appendU32(UInt32(group.index), to: &payload)
                if let bytes = groupTextBytes[i] {
                    appendU32(UInt32(textOffset), to: &payload)
                    appendU32(UInt32(bytes.count), to: &payload)
                    textOffset += bytes.count
                } else {
                    appendU32(0xFFFFFFFF, to: &payload)
                    appendU32(0, to: &payload)
                }
            }

            for groupOrdinal in 0..<groupCount {
                let group = groups[groupOrdinal]
                for range in group.ranges {
                    appendU32(UInt32(groupOrdinal), to: &payload)
                    appendU32(UInt32(range.startLine), to: &payload)
                    appendU32(UInt32(range.startColumn), to: &payload)
                    appendU32(UInt32(range.endLine), to: &payload)
                    appendU32(UInt32(range.endColumn), to: &payload)
                }
            }

            for bytes in groupTextBytes {
                guard let bytes, !bytes.isEmpty else { continue }
                payload.append(bytes)
            }
            return payload
        }

        private func appendU32(_ value: UInt32, to data: inout Data) {
            owner.appendU32(value, to: &data)
        }

        private func appendI32(_ value: Int32, to data: inout Data) {
            owner.appendI32(value, to: &data)
        }

        private func appendUTF8(_ text: String, to data: inout Data) {
            let bytes = text.data(using: .utf8) ?? Data()
            appendU32(UInt32(bytes.count), to: &data)
            data.append(bytes)
        }

        private func appendInlayHint(_ hint: InlayHintPayload, to payload: inout Data) {
            let type: UInt32
            let intValue: Int32
            let text: String
            switch hint.kind {
            case .text(let value):
                type = 0
                intValue = 0
                text = value
            case .icon(let value):
                type = 1
                intValue = value
                text = ""
            case .color(let value):
                type = 2
                intValue = value
                text = ""
            }
            appendU32(type, to: &payload)
            appendU32(UInt32(hint.column), to: &payload)
            appendI32(intValue, to: &payload)
            appendUTF8(text, to: &payload)
        }
    }

    // Font references kept alive for CoreText measurement
    var regularFont: CTFont
    var boldFont: CTFont
    var italicFont: CTFont
    var boldItalicFont: CTFont
    var inlayHintFont: CTFont
    private let baseFontName: String
    private let baseFontSize: CGFloat
    private let baseInlayHintFontName: String
    private let baseInlayHintFontSize: CGFloat

    private static func getCurrent() -> SweetEditorCore? {
        guard let stack = Thread.current.threadDictionary[threadDictionaryKey] as? ThreadCoreStack else { return nil }
        return stack.current()
    }

    private static func withActiveCore<T>(_ core: SweetEditorCore, execute block: () -> T) -> T {
        let dict = Thread.current.threadDictionary
        let key = threadDictionaryKey
        let stack: ThreadCoreStack
        if let existing = dict[key] as? ThreadCoreStack {
            stack = existing
        } else {
            let newStack = ThreadCoreStack()
            dict[key] = newStack
            stack = newStack
        }
        stack.push(core)
        defer {
            stack.pop()
            if stack.isEmpty {
                dict.removeObject(forKey: key)
            }
        }
        return block()
    }

    @discardableResult
    private func performCoreCall<T>(_ block: () -> T) -> T {
        return SweetEditorCore.withActiveCore(self, execute: block)
    }

    init(fontSize: CGFloat = 14.0, fontName: String = "Menlo") {
        baseFontName = fontName
        baseFontSize = fontSize
        baseInlayHintFontName = "Helvetica"
        baseInlayHintFontSize = fontSize * 0.85

        regularFont = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        boldFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, .boldTrait, .boldTrait)
            ?? CTFontCreateWithName(fontName as CFString, fontSize, nil)
        italicFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, .italicTrait, .italicTrait)
            ?? CTFontCreateWithName(fontName as CFString, fontSize, nil)
        boldItalicFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, [.boldTrait, .italicTrait], [.boldTrait, .italicTrait])
            ?? CTFontCreateWithName(fontName as CFString, fontSize, nil)
        inlayHintFont = CTFontCreateWithName(baseInlayHintFontName as CFString, baseInlayHintFontSize, nil)

        #if os(iOS)
        let revealSelectionEndOnSelectAll = true
        #else
        let revealSelectionEndOnSelectAll = false
        #endif

        let optionsPayload = SweetEditorCore.makeEditorOptionsPayload(
            touchSlop: 10.0,
            doubleTapTimeout: 300,
            longPressMs: 500,
            flingFriction: 3.5,
            flingMinVelocity: 50.0,
            flingMaxVelocity: 8000.0,
            maxUndoStackSize: 512,
            keyChordTimeoutMs: 2000,
            revealSelectionEndOnSelectAll: revealSelectionEndOnSelectAll
        )

        handle = performCoreCall {
            var editorHandle: Int = 0
            optionsPayload.withUnsafeBytes { raw in
                let ptr = raw.bindMemory(to: UInt8.self).baseAddress
                editorHandle = create_editor(
                    se_text_measurer_t(
                        measure_text_width: SweetEditorCore.measureTextWidthCallback,
                        measure_inlay_hint_width: SweetEditorCore.measureInlayHintWidthCallback,
                        measure_icon_width: SweetEditorCore.measureIconWidthCallback,
                        get_font_metrics: SweetEditorCore.getFontMetricsCallback
                    ),
                    ptr,
                    optionsPayload.count
                )
            }
            return editorHandle
        }
    }

    private func rebuildFontsForScale(_ scale: CGFloat) {
        let textSize = max(1.0, baseFontSize * scale)
        regularFont = CTFontCreateWithName(baseFontName as CFString, textSize, nil)
        boldFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, .boldTrait, .boldTrait)
            ?? CTFontCreateWithName(baseFontName as CFString, textSize, nil)
        italicFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, .italicTrait, .italicTrait)
            ?? CTFontCreateWithName(baseFontName as CFString, textSize, nil)
        boldItalicFont = CTFontCreateCopyWithSymbolicTraits(regularFont, 0, nil, [.boldTrait, .italicTrait], [.boldTrait, .italicTrait])
            ?? CTFontCreateWithName(baseFontName as CFString, textSize, nil)

        let inlaySize = max(1.0, baseInlayHintFontSize * scale)
        inlayHintFont = CTFontCreateWithName(baseInlayHintFontName as CFString, inlaySize, nil)
    }

    deinit {
        if handle != 0 {
            performCoreCall {
                free_editor(handle)
            }
        }
    }

    private func appendU32(_ value: UInt32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendF32(_ value: Float, to data: inout Data) {
        var le = value.bitPattern.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private func appendI32(_ value: Int32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendI64(_ value: Int64, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendU64(_ value: UInt64, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendU8(_ value: UInt8, to data: inout Data) {
        data.append(value)
    }

    private static func makeEditorOptionsPayload(
        touchSlop: Float,
        doubleTapTimeout: Int64,
        longPressMs: Int64,
        flingFriction: Float,
        flingMinVelocity: Float,
        flingMaxVelocity: Float,
        maxUndoStackSize: UInt64,
        keyChordTimeoutMs: Int64,
        revealSelectionEndOnSelectAll: Bool
    ) -> Data {
        var data = Data()
        appendF32(touchSlop, to: &data)
        appendI64(doubleTapTimeout, to: &data)
        appendI64(longPressMs, to: &data)
        appendF32(flingFriction, to: &data)
        appendF32(flingMinVelocity, to: &data)
        appendF32(flingMaxVelocity, to: &data)
        appendU64(maxUndoStackSize, to: &data)
        appendI64(keyChordTimeoutMs, to: &data)
        appendU8(revealSelectionEndOnSelectAll ? 1 : 0, to: &data)
        return data
    }

    private func withPayload<T>(_ payload: Data, _ block: (UnsafePointer<UInt8>?, Int) -> T) -> T {
        return payload.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress
            return block(ptr, payload.count)
        }
    }

    private func copyBinaryPayloadAndFree(_ ptr: UnsafePointer<UInt8>?, size: Int) -> Data? {
        guard let ptr = ptr else { return nil }
        defer { free_binary_data(Int(bitPattern: ptr)) }
        guard size > 0 else { return nil }
        return Data(bytes: ptr, count: size)
    }

    private func decodeEditorActionPayload(_ ptr: UnsafePointer<UInt8>?, size: Int) -> EditorActionResultData? {
        let payload = copyBinaryPayloadAndFree(ptr, size: size)
        return protocolDecoder.decodeEditorActionResult(payload)
    }

    private func performPayloadEditorAction(
        _ payload: Data,
        _ block: (UnsafePointer<UInt8>?, Int, inout Int) -> UnsafePointer<UInt8>?
    ) -> EditorActionResultData? {
        return performCoreCall {
            var outSize: Int = 0
            let ptr = withPayload(payload) { ptr, size in
                block(ptr, size, &outSize)
            }
            return decodeEditorActionPayload(ptr, size: outSize)
        }
    }

    // MARK: - C Callbacks (static, @convention(c))

    private static let measureTextWidthCallback: @convention(c) (UnsafePointer<UInt16>?, Int32) -> Float = { textPtr, fontStyle in
        guard let textPtr = textPtr, let core = SweetEditorCore.getCurrent() else { return 0 }
        let str = stringFromU16Ptr(textPtr)
        let font = core.fontForStyle(fontStyle)
        return Float(measureStringWidth(str, font: font))
    }

    private static let measureInlayHintWidthCallback: @convention(c) (UnsafePointer<UInt16>?) -> Float = { textPtr in
        guard let textPtr = textPtr, let core = SweetEditorCore.getCurrent() else { return 0 }
        let str = stringFromU16Ptr(textPtr)
        return Float(measureStringWidth(str, font: core.inlayHintFont))
    }

    private static let measureIconWidthCallback: @convention(c) (Int32) -> Float = { _ in
        guard let core = SweetEditorCore.getCurrent() else { return 0 }
        return Float(CTFontGetSize(core.regularFont))
    }

    private static let getFontMetricsCallback: @convention(c) (UnsafeMutablePointer<Float>?, Int) -> Void = { arrPtr, length in
        guard let arrPtr = arrPtr, length >= 2, let core = SweetEditorCore.getCurrent() else { return }
        let ascent = CTFontGetAscent(core.regularFont)
        let descent = CTFontGetDescent(core.regularFont)
        arrPtr[0] = Float(-ascent)  // negative ascent (baseline to top)
        arrPtr[1] = Float(descent)
    }

    // MARK: - Font Selection

    func fontForStyle(_ fontStyle: Int32) -> CTFont {
        let isBold = (fontStyle & FONT_STYLE_BOLD) != 0
        let isItalic = (fontStyle & FONT_STYLE_ITALIC) != 0
        if isBold && isItalic { return boldItalicFont }
        if isBold { return boldFont }
        if isItalic { return italicFont }
        return regularFont
    }

    // MARK: - Editor Operations

    @discardableResult
    func setViewport(width: Int, height: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = set_editor_viewport(handle, Int16(width), Int16(height), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    private(set) var document: SweetDocument?

    @discardableResult
    func setDocument(_ document: SweetDocument) -> EditorActionResultData? {
        self.document = document
        return performCoreCall {
            var size: Int = 0
            let ptr = set_editor_document(handle, document.handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func buildRenderModel() -> EditorRenderModel? {
        return performCoreCall {
            var size: Int = 0
            let ptr = build_editor_render_model(handle, &size)
            guard let payload = copyBinaryPayloadAndFree(ptr, size: size) else { return nil }
            return protocolDecoder.decodeRenderModel(payload)
        }
    }

    func getLayoutMetrics() -> LayoutMetrics? {
        return performCoreCall {
            var size: Int = 0
            let ptr = get_layout_metrics(handle, &size)
            guard let payload = copyBinaryPayloadAndFree(ptr, size: size) else { return nil }
            return protocolDecoder.decodeLayoutMetrics(payload)
        }
    }

    func handleGestureEvent(type: SEEventType, points: [(Float, Float)],
                            modifiers: SEModifier = [],
                            wheelDeltaX: Float = 0, wheelDeltaY: Float = 0,
                            directScale: Float = 1) -> EditorActionResultData? {
        return performCoreCall {
            var pointsArr: [Float] = []
            for p in points {
                pointsArr.append(p.0)
                pointsArr.append(p.1)
            }
            var size: Int = 0
            let ptr = pointsArr.withUnsafeMutableBufferPointer { buf in
                handle_editor_gesture_event_ex(
                    handle, type.rawValue,
                    UInt8(points.count),
                    buf.baseAddress,
                    modifiers.rawValue,
                    wheelDeltaX, wheelDeltaY, directScale,
                    &size
                )
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func handleKeyEvent(keyCode: SEKeyCode, text: String? = nil, modifiers: SEModifier = []) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr: UnsafePointer<UInt8>?
            if let text = text {
                ptr = text.withCString { cStr in
                    handle_editor_key_event(handle, keyCode.rawValue, cStr, modifiers.rawValue, &size)
                }
            } else {
                ptr = handle_editor_key_event(handle, keyCode.rawValue, nil, modifiers.rawValue, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertText(_ text: String) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString { cStr in
                let ptr = editor_insert_text(handle, cStr, &size)
                return ptr
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Replaces text in a target range atomically.
    func replaceText(startLine: Int, startColumn: Int,
                     endLine: Int, endColumn: Int,
                     newText: String) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = newText.withCString { cStr in
                editor_replace_text(handle,
                                    startLine, startColumn,
                                    endLine, endColumn, cStr, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Deletes text in a target range atomically.
    func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_text(handle,
                                         startLine, startColumn,
                                         endLine, endColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Line operations

    func moveLineUp() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func moveLineDown() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func copyLineUp() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func copyLineDown() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func deleteLine() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_line(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertLineAbove() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_above(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertLineBelow() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_below(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func getSelectedText() -> String {
        return performCoreCall {
            guard let ptr = editor_get_selected_text(handle) else { return "" }
            return String(cString: ptr)
        }
    }

    /// Returns caret position (line, column), both 0-based.
    func getCursorPosition() -> (line: Int, column: Int)? {
        return performCoreCall {
            var line: Int = 0
            var column: Int = 0
            editor_get_cursor_position(handle, &line, &column)
            return (line: line, column: column)
        }
    }

    /// Moves caret to the given document position.
    @discardableResult
    func gotoPosition(line: Int, column: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_goto_position(handle, line, column, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Returns the text range of the word at the caret.
    func getWordRangeAtCursor() -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        return performCoreCall {
            var sl: Int = 0, sc: Int = 0, el: Int = 0, ec: Int = 0
            editor_get_word_range_at_cursor(handle, &sl, &sc, &el, &ec)
            return (startLine: sl, startColumn: sc, endLine: el, endColumn: ec)
        }
    }

    /// Returns the word text at the caret.
    func getWordAtCursor() -> String {
        return performCoreCall {
            guard let ptr = editor_get_word_at_cursor(handle) else { return "" }
            return String(cString: ptr)
        }
    }

    /// Returns current selection range if one exists.
    func getSelectionRange() -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)? {
        return performCoreCall {
            var sl: Int = 0, sc: Int = 0, el: Int = 0, ec: Int = 0
            let hasSelection = editor_get_selection(handle, &sl, &sc, &el, &ec)
            if hasSelection == 0 {
                return nil
            }
            return (startLine: sl, startColumn: sc, endLine: el, endColumn: ec)
        }
    }

    /// Sets selection range in document coordinates.
    @discardableResult
    func setSelectionRange(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_selection(handle, startLine, startColumn, endLine, endColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - IME Composition

    @discardableResult
    func updateImePreedit(_ text: String) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString {
                editor_ime_update_preedit(handle, $0, 0, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setImeComposingTextSelection(_ text: String,
                                      selectionStartOffset: Int,
                                      selectionEndOffset: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let safeStart = max(0, selectionStartOffset)
            let safeEnd = max(0, selectionEndOffset)
            let ptr = text.withCString {
                editor_ime_set_composing_text_selection(handle, $0, safeStart, safeEnd, 0, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func commitImeText(_ text: String?) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let call: (UnsafePointer<CChar>?) -> UnsafePointer<UInt8>? = { cStr in
                editor_ime_commit_text(handle, cStr, 0, &size)
            }
            let ptr: UnsafePointer<UInt8>?
            if let value = text {
                ptr = value.withCString { call($0) }
            } else {
                ptr = call(nil)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func finishImePreedit() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_finish_preedit(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func cancelImePreedit() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_cancel_preedit(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func markImeDocumentRange(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_mark_document_range(handle,
                                                     startLine,
                                                     startColumn,
                                                     endLine,
                                                      endColumn,
                                                      0,
                                                      &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func markImeDocumentRange(startOffset: Int, endOffset: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_mark_document_range_by_offset(handle,
                                                               startOffset,
                                                                endOffset,
                                                                0,
                                                                &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func updateImeInputStateText(contextId: Int64,
                                 documentStartOffset: Int,
                                 text: String,
                                 selectionStartOffset: Int,
                                 selectionEndOffset: Int,
                                 composingStartOffset: Int,
                                 composingEndOffset: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString {
                editor_ime_update_input_state_text(handle,
                                                   UInt64(max(0, contextId)),
                                                   Int32(max(0, documentStartOffset)),
                                                   $0,
                                                   Int32(selectionStartOffset),
                                                   Int32(selectionEndOffset),
                                                   Int32(composingStartOffset),
                                                   Int32(composingEndOffset),
                                                   0,
                                                   &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func updateImeInputStateSelection(contextId: Int64,
                                      documentStartOffset: Int,
                                      selectionStartOffset: Int,
                                      selectionEndOffset: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_update_input_state_selection(handle,
                                                              UInt64(max(0, contextId)),
                                                              Int32(max(0, documentStartOffset)),
                                                              Int32(selectionStartOffset),
                                                              Int32(selectionEndOffset),
                                                              &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func replaceImeInputStateText(contextId: Int64,
                                  documentStartOffset: Int,
                                  startOffset: Int,
                                  endOffset: Int,
                                  text: String,
                                  cursorOffset: Int = 1) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString {
                editor_ime_replace_input_state_text(handle,
                                                    UInt64(max(0, contextId)),
                                                    Int32(max(0, documentStartOffset)),
                                                    max(0, startOffset),
                                                    max(0, endOffset),
                                                    $0,
                                                    Int32(cursorOffset),
                                                    0,
                                                    &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func isComposing() -> Bool {
        return performCoreCall {
            editor_is_composing(handle) != 0
        }
    }

    @discardableResult
    func setCompositionEnabled(_ enabled: Bool) -> EditorActionResultData? {
        compositionEnabled = enabled
        if !enabled {
            return cancelImePreedit()
        }
        return nil
    }

    func isCompositionEnabled() -> Bool {
        return compositionEnabled
    }

    // MARK: - ReadOnly

    @discardableResult
    func setReadOnly(_ readOnly: Bool) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_read_only(handle, readOnly ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func isReadOnly() -> Bool {
        return performCoreCall {
            editor_is_read_only(handle) != 0
        }
    }

    // MARK: - AutoIndent

    /// Auto-indentation mode.
    enum AutoIndentMode: Int32 {
        /// No auto-indentation; a new line starts at column 0.
        case none = 0
        /// Keep previous line indentation (copy leading whitespace).
        case keepIndent = 1
    }

    /// Sets the auto-indentation mode.
    @discardableResult
    func setAutoIndentMode(_ mode: AutoIndentMode) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_auto_indent_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Returns the current auto-indentation mode.
    func getAutoIndentMode() -> AutoIndentMode {
        return performCoreCall {
            AutoIndentMode(rawValue: editor_get_auto_indent_mode(handle)) ?? .keepIndent
        }
    }

    /// Sets backspace unindent behavior.
    @discardableResult
    func setBackspaceUnindent(_ enabled: Bool) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_backspace_unindent(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets whether Tab inserts spaces instead of a tab character.
    @discardableResult
    func setInsertSpaces(_ enabled: Bool) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_insert_spaces(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    struct ScrollbarConfig {
        enum ScrollbarMode: Int32 {
            case ALWAYS = 0
            case TRANSIENT = 1
            case NEVER = 2
        }

        enum ScrollbarTrackTapMode: Int32 {
            case JUMP = 0
            case DISABLED = 1
        }

        let thickness: Float
        let minThumb: Float
        let thumbHitPadding: Float
        let mode: ScrollbarMode
        let thumbDraggable: Bool
        let trackTapMode: ScrollbarTrackTapMode
        let fadeDelayMs: Int32
        let fadeDurationMs: Int32

        init(thickness: Float = 10.0,
             minThumb: Float = 24.0,
             thumbHitPadding: Float = 0.0,
             mode: ScrollbarMode = .ALWAYS,
             thumbDraggable: Bool = true,
             trackTapMode: ScrollbarTrackTapMode = .JUMP,
             fadeDelayMs: Int32 = 700,
             fadeDurationMs: Int32 = 300) {
            self.thickness = thickness
            self.minThumb = minThumb
            self.thumbHitPadding = thumbHitPadding
            self.mode = mode
            self.thumbDraggable = thumbDraggable
            self.trackTapMode = trackTapMode
            self.fadeDelayMs = fadeDelayMs
            self.fadeDurationMs = fadeDurationMs
        }
    }

    // MARK: - Position Rect

    /// Screen-space rectangle for a caret/text position (used for floating panel placement).
    struct CursorRect {
        /// X coordinate relative to the editor view's top-left corner.
        let x: CGFloat
        /// Y coordinate relative to the editor view's top-left corner (line top).
        let y: CGFloat
        /// Line height (same as caret height).
        let height: CGFloat
    }

    /// Returns the screen-space rectangle for any text position (for floating panel placement).
    func getPositionRect(line: Int, column: Int) -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_position_rect(handle, line, column, &x, &y, &h)
            return CursorRect(x: CGFloat(x), y: CGFloat(y), height: CGFloat(h))
        }
    }

    /// Returns the screen-space rectangle for current caret position (convenience).
    func getCursorRect() -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_cursor_rect(handle, &x, &y, &h)
            return CursorRect(x: CGFloat(x), y: CGFloat(y), height: CGFloat(h))
        }
    }

    // MARK: - Scroll / Navigation

    struct ScrollMetrics {
        let scale: CGFloat
        let scrollX: CGFloat
        let scrollY: CGFloat
        let maxScrollX: CGFloat
        let maxScrollY: CGFloat
        let contentWidth: CGFloat
        let contentHeight: CGFloat
        let viewportWidth: CGFloat
        let viewportHeight: CGFloat
        let textAreaX: CGFloat
        let textAreaWidth: CGFloat
        let canScrollX: Bool
        let canScrollY: Bool
    }

    @discardableResult
    func setScrollbarConfig(_ config: ScrollbarConfig) -> EditorActionResultData? {
        scrollbarConfig = config
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scrollbar_config(
                handle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.rawValue,
                config.thumbDraggable ? 1 : 0,
                config.trackTapMode.rawValue,
                config.fadeDelayMs,
                config.fadeDurationMs,
                &size
            )
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func scrollToLine(line: Int, behavior: UInt8) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_scroll_to_line(handle, line, behavior, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setScroll(scrollX: Float, scrollY: Float) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scroll(handle, scrollX, scrollY, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func getScrollMetrics() -> ScrollMetrics {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_scroll_metrics(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeScrollMetrics(payload)
        }
    }

    func getVisibleLineRange() -> IntRange {
        return performCoreCall {
            var startLine: Int32 = 0
            var endLine: Int32 = -1
            editor_get_visible_line_range(handle, &startLine, &endLine)
            return IntRange(start: Int(startLine), end: Int(endLine))
        }
    }

    @discardableResult
    func onFontMetricsChanged() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_on_font_metrics_changed(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Style / Highlight

    @discardableResult
    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) -> EditorActionResultData? {
        registerStyle(styleId: styleId, color: color, backgroundColor: 0, fontStyle: fontStyle)
    }

    @discardableResult
    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_register_text_style(handle, styleId, color, backgroundColor, fontStyle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func registerBatchStyles(_ stylesById: [UInt32: (color: Int32, backgroundColor: Int32, fontStyle: Int32)]) -> EditorActionResultData? {
        if stylesById.isEmpty { return nil }
        let payload = protocolEncoder.packBatchTextStyles(stylesById)
        return performCoreCall {
            var outSize: Int = 0
            let ptr = withPayload(payload) { ptr, size in
                editor_register_batch_text_styles(handle, ptr, size, &outSize)
            }
            return decodeEditorActionPayload(ptr, size: outSize)
        }
    }

    /// Clears all highlight layers.
    @discardableResult
    func clearHighlights() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears a specific highlight layer (0=SYNTAX, 1=SEMANTIC).
    @discardableResult
    func clearHighlights(layer: UInt8) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights_layer(handle, layer, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setLineSpans(line: Int, layer: UInt8 = 0, spans: [StyleSpan]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineSpans(line: line, layer: Int(layer), spans: spans)
        return setLineSpans(payload: payload)
    }

    @discardableResult
    func setLineSpans(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_spans(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineSpans(layer: UInt8, spansByLine: [Int: [StyleSpan]]) -> EditorActionResultData? {
        if spansByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineSpans(layer: Int(layer), spansByLine: spansByLine)
        return setBatchLineSpans(payload: payload)
    }

    @discardableResult
    func setBatchLineSpans(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_spans(handle, ptr, size, &outSize)
        }
    }

    // MARK: - Diagnostic (diagnostic decorations)

    /// Sets diagnostic decorations for a specific line (wavy/underline).
    /// - Parameters:
    ///   - line: Line number (0-based).
    @discardableResult
    func setLineDiagnostics(line: Int, items: [DiagnosticItem]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineDiagnostics(line: line, items: items)
        return setLineDiagnostics(payload: payload)
    }

    @discardableResult
    func setLineDiagnostics(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Sets diagnostic decorations for multiple lines.
    @discardableResult
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticItem]]) -> EditorActionResultData? {
        if diagnosticsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineDiagnostics(diagnosticsByLine)
        return setBatchLineDiagnostics(payload: payload)
    }

    /// Sets diagnostic decorations for multiple lines.
    @discardableResult
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticPayload]]) -> EditorActionResultData? {
        if diagnosticsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineDiagnostics(diagnosticsByLine)
        return setBatchLineDiagnostics(payload: payload)
    }

    @discardableResult
    func setBatchLineDiagnostics(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Clears all diagnostic decorations.
    @discardableResult
    func clearDiagnostics() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_diagnostics(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Inlay Hints & Phantom Text

    /// Replaces all inlay hints on a specific line.
    @discardableResult
    func setLineInlayHints(line: Int, hints: [InlayHintPayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineInlayHints(line: line, hints: hints)
        return setLineInlayHints(payload: payload)
    }

    @discardableResult
    func setLineInlayHints(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Replaces inlay hints for multiple lines in one call.
    @discardableResult
    func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHintPayload]]) -> EditorActionResultData? {
        if hintsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineInlayHints(hintsByLine)
        return setBatchLineInlayHints(payload: payload)
    }

    @discardableResult
    func setBatchLineInlayHints(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Clears all inlay hints.
    @discardableResult
    func clearInlayHints() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_inlay_hints(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Replaces phantom texts on a specific line.
    @discardableResult
    func setLinePhantomTexts(line: Int, phantoms: [PhantomTextPayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLinePhantomTexts(line: line, phantoms: phantoms)
        return setLinePhantomTexts(payload: payload)
    }

    @discardableResult
    func setLinePhantomTexts(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Replaces phantom texts for multiple lines in one call.
    @discardableResult
    func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomTextPayload]]) -> EditorActionResultData? {
        if phantomsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLinePhantomTexts(phantomsByLine)
        return setBatchLinePhantomTexts(payload: payload)
    }

    @discardableResult
    func setBatchLinePhantomTexts(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Clears all phantom texts.
    @discardableResult
    func clearPhantomTexts() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_phantom_texts(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears all decorations (highlight/inlay/phantom/gutter/guides/diagnostics).
    @discardableResult
    func clearAllDecorations() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_all_decorations(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Gutter Icons

    @discardableResult
    func setLineGutterIcons(line: Int, icons: [GutterIcon]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineGutterIcons(line: line, icons: icons)
        return setLineGutterIcons(payload: payload)
    }

    @discardableResult
    func setLineGutterIcons(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) -> EditorActionResultData? {
        if iconsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineGutterIcons(iconsByLine)
        return setBatchLineGutterIcons(payload: payload)
    }

    @discardableResult
    func setBatchLineGutterIcons(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearGutterIcons() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_gutter_icons(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setMaxGutterIcons(_ count: UInt32) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_max_gutter_icons(handle, count, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - CodeLens

    @discardableResult
    func setLineCodeLens(line: Int, items: [CodeLensPayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineCodeLens(line: line, items: items)
        return setLineCodeLens(payload: payload)
    }

    @discardableResult
    func setLineCodeLens(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensPayload]]) -> EditorActionResultData? {
        if itemsByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineCodeLens(itemsByLine)
        return setBatchLineCodeLens(payload: payload)
    }

    @discardableResult
    func setBatchLineCodeLens(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearCodeLens() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_codelens(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Links

    @discardableResult
    func setLineLinks(line: Int, links: [LinkSpan]) -> EditorActionResultData? {
        let payload = protocolEncoder.packLineLinks(line: line, links: links)
        return setLineLinks(payload: payload)
    }

    @discardableResult
    func setLineLinks(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) -> EditorActionResultData? {
        if linksByLine.isEmpty { return nil }
        let payload = protocolEncoder.packBatchLineLinks(linksByLine)
        return setBatchLineLinks(payload: payload)
    }

    @discardableResult
    func setBatchLineLinks(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearLinks() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_links(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func getLinkTargetAt(line: Int, column: Int) -> String {
        return performCoreCall {
            guard let ptr = editor_get_link_target_at(handle, line, column) else { return "" }
            defer { free_u8_string(Int(bitPattern: ptr)) }
            return String(cString: ptr)
        }
    }

    // MARK: - Guides

    @discardableResult
    func setIndentGuides(_ guides: [IndentGuidePayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packIndentGuides(guides)
        return setIndentGuides(payload: payload)
    }

    @discardableResult
    func setIndentGuides(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_indent_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBracketGuides(_ guides: [BracketGuidePayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packBracketGuides(guides)
        return setBracketGuides(payload: payload)
    }

    @discardableResult
    func setBracketGuides(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_bracket_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setFlowGuides(_ guides: [FlowGuidePayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packFlowGuides(guides)
        return setFlowGuides(payload: payload)
    }

    @discardableResult
    func setFlowGuides(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_flow_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setSeparatorGuides(_ guides: [SeparatorGuidePayload]) -> EditorActionResultData? {
        let payload = protocolEncoder.packSeparatorGuides(guides)
        return setSeparatorGuides(payload: payload)
    }

    @discardableResult
    func setSeparatorGuides(payload: Data) -> EditorActionResultData? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_separator_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearGuides() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_guides(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Undo/Redo

    func undo() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_undo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func redo() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_redo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }
    func canUndo() -> Bool { performCoreCall { editor_can_undo(handle) != 0 } }
    func canRedo() -> Bool { performCoreCall { editor_can_redo(handle) != 0 } }

    // MARK: - Fold (code folding)

    @discardableResult
    func setFoldRegions(_ regions: [FoldRegion]) -> EditorActionResultData? {
        let payload = protocolEncoder.packFoldRegions(regions)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_fold_regions(handle, ptr, size, &outSize)
        }
    }

    func toggleFold(line: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_toggle_fold(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func foldAt(line: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func unfoldAt(line: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_unfold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func foldAll() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func unfoldAll() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_unfold_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func isLineVisible(line: Int) -> Bool {
        return performCoreCall {
            editor_is_line_visible(handle, line) != 0
        }
    }

    /// Fold-arrow visibility mode.
    enum FoldArrowMode: Int32 {
        /// Auto: shown when fold regions exist, hidden otherwise.
        case auto = 0
        /// Always visible (reserves gutter width to avoid layout jumps).
        case always = 1
        /// Always hidden (no reserved space even if fold regions exist).
        case hidden = 2
    }

    /// Sets fold-arrow visibility mode (affects reserved gutter width).
    @discardableResult
    func setFoldArrowMode(_ mode: FoldArrowMode) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_fold_arrow_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Wrap mode.
    enum WrapMode: Int32 {
        /// No wrapping.
        case none = 0
        /// Character-level wrapping.
        case charBreak = 1
        /// Word-level wrapping.
        case wordBreak = 2
    }

    /// Sets wrap mode.
    @discardableResult
    func setWrapMode(_ mode: WrapMode) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_wrap_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets editor scale in the C++ core.
    /// Use `syncPlatformScale(_:)` to update platform-side fonts and measurer.
    @discardableResult
    func setScale(_ scale: Float) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scale(handle, scale, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setContentStartPadding(_ padding: Float) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_content_start_padding(handle, padding, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setShowSplitLine(_ show: Bool) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_show_split_line(handle, show ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setCurrentLineRenderMode(_ mode: Int32) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_current_line_render_mode(handle, mode, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Syncs platform-side font/measurer to the latest scale from the core.
    @discardableResult
    func syncPlatformScale(_ scale: Float) -> EditorActionResultData? {
        guard scale > 0 else { return nil }
        rebuildFontsForScale(CGFloat(scale))
        return onFontMetricsChanged()
    }

    /// Sets line-spacing parameters (`line_height = font_height * mult + add`).
    /// - Parameters:
    ///   - add: Extra line-spacing pixels (default 0).
    ///   - mult: Line-spacing multiplier (default 1.0).
    @discardableResult
    func setLineSpacing(add: Float, mult: Float) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_line_spacing(handle, add, mult, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - LinkedEditing

    /// Linked-editing model (pure data structure).
    struct LinkedEditingModel {
        struct TabStopGroup {
            let index: Int
            let defaultText: String?
            let ranges: [(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)]
        }
        let groups: [TabStopGroup]
    }

    /// Inserts a VSCode snippet template and enters linked-editing mode.
    func insertSnippet(_ template: String) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = template.withCString { cStr in
                editor_insert_snippet(handle, cStr, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Starts linked-editing mode with a generic LinkedEditingModel.
    @discardableResult
    func startLinkedEditing(model: LinkedEditingModel) -> EditorActionResultData? {
        let payload = protocolEncoder.packLinkedEditing(model: model)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_start_linked_editing(handle, ptr, size, &outSize)
        }
    }

    /// Whether linked-editing mode is active.
    func isInLinkedEditing() -> Bool {
        return performCoreCall {
            editor_is_in_linked_editing(handle) != 0
        }
    }

    /// Linked editing: jump to the next tab stop.
    func linkedEditingNext() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_next(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Linked editing: jump to the previous tab stop.
    func linkedEditingPrev() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_prev(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Cancels linked-editing mode.
    @discardableResult
    func cancelLinkedEditing() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_cancel_linked_editing(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Bracket Highlight

    /// Sets custom bracket pairs.
    @discardableResult
    func setBracketPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResultData? {
        assert(openChars.count == closeChars.count, "open/close arrays must have same length")
        var opens = openChars.map(UInt32.init(bitPattern:))
        var closes = closeChars.map(UInt32.init(bitPattern:))
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_bracket_pairs(handle, &opens, &closes, opens.count, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets auto-closing pairs for automatic bracket completion.
    @discardableResult
    func setAutoClosingPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResultData? {
        assert(openChars.count == closeChars.count, "open/close arrays must have same length")
        var opens = openChars.map(UInt32.init(bitPattern:))
        var closes = closeChars.map(UInt32.init(bitPattern:))
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_auto_closing_pairs(handle, &opens, &closes, opens.count, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets tab size (number of spaces per tab stop).
    @discardableResult
    func setTabSize(_ tabSize: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_tab_size(handle, Int32(tabSize), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets externally computed exact bracket-match positions (higher priority than built-in scan).
    @discardableResult
    func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int) -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_matched_brackets(handle, openLine, openColumn, closeLine, closeColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears externally provided bracket-match results (falls back to built-in scan).
    @discardableResult
    func clearMatchedBrackets() -> EditorActionResultData? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_matched_brackets(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }
}

// MARK: - UTF-16 Helpers

/// Convert a null-terminated UTF-16 pointer to Swift String
func stringFromU16Ptr(_ ptr: UnsafePointer<UInt16>) -> String {
    var length = 0
    while ptr[length] != 0 { length += 1 }
    let buffer = UnsafeBufferPointer(start: ptr, count: length)
    return String(utf16CodeUnits: Array(buffer), count: length)
}

func makeRenderedAttributedString(_ string: String,
                                  font: CTFont,
                                  color: CGColor? = nil) -> CFAttributedString {
    let attrStr = CFAttributedStringCreateMutable(nil, 0)!
    CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), string as CFString)
    let range = CFRange(location: 0, length: string.utf16.count)
    CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
    if let color {
        CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, color)
    }

    return attrStr
}

/// Measure string width using CoreText CTLine
func measureStringWidth(_ string: String, font: CTFont) -> CGFloat {
    if string.isEmpty { return 0 }
    let attrStr = makeRenderedAttributedString(string, font: font)
    let line = CTLineCreateWithAttributedString(attrStr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    return width
}
