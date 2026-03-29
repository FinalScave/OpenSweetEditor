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
enum SEEventType: UInt8 {
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
        let color: Int32
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
        let color: Int32

        init(column: Int32, length: Int32, severity: Int32, color: Int32) {
            self.column = column
            self.length = length
            self.severity = severity
            self.color = color
        }
    }

    struct GutterIcon {
        let iconId: Int32

        init(iconId: Int32) {
            self.iconId = iconId
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

        func packLineDiagnostics(line: Int, diagnostics: [(column: Int32, length: Int32, severity: Int32, color: Int32)]) -> Data {
            var payload = Data()
            payload.reserveCapacity(8 + diagnostics.count * 16)
            appendU32(UInt32(line), to: &payload)
            appendU32(UInt32(diagnostics.count), to: &payload)
            for diagnostic in diagnostics {
                appendI32(diagnostic.column, to: &payload)
                appendI32(diagnostic.length, to: &payload)
                appendI32(diagnostic.severity, to: &payload)
                appendI32(diagnostic.color, to: &payload)
            }
            return payload
        }

        func packLineDiagnostics(line: Int, items: [DiagnosticItem]) -> Data {
            let diagnostics = items.map { (column: $0.column, length: $0.length, severity: $0.severity, color: $0.color) }
            return packLineDiagnostics(line: line, diagnostics: diagnostics)
        }

        func packBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticPayload]]) -> Data {
            let lines = diagnosticsByLine.keys.sorted()
            var payload = Data()
            payload.reserveCapacity(4 + lines.reduce(0) {
                $0 + 8 + (diagnosticsByLine[$1]?.count ?? 0) * 16
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
                    appendI32(diagnostic.color, to: &payload)
                }
            }
            return payload
        }

        func packBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticItem]]) -> Data {
            let payloads = diagnosticsByLine.mapValues { items in
                items.map {
                    DiagnosticPayload(column: $0.column, length: $0.length, severity: $0.severity, color: $0.color)
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

        let optionsPayload = SweetEditorCore.makeEditorOptionsPayload(
            touchSlop: 10.0,
            doubleTapTimeout: 300,
            longPressMs: 500,
            maxUndoStackSize: 512
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

    private static func makeEditorOptionsPayload(
        touchSlop: Float,
        doubleTapTimeout: Int64,
        longPressMs: Int64,
        maxUndoStackSize: UInt64
    ) -> Data {
        var data = Data()
        appendF32(touchSlop, to: &data)
        appendI64(doubleTapTimeout, to: &data)
        appendI64(longPressMs, to: &data)
        appendU64(maxUndoStackSize, to: &data)
        return data
    }

    private func withPayload(_ payload: Data, _ block: (UnsafePointer<UInt8>?, Int) -> Void) {
        payload.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress
            block(ptr, payload.count)
        }
    }

    private func copyBinaryPayloadAndFree(_ ptr: UnsafePointer<UInt8>?, size: Int) -> Data? {
        guard let ptr = ptr else { return nil }
        defer { free_binary_data(Int(bitPattern: ptr)) }
        guard size > 0 else { return nil }
        return Data(bytes: ptr, count: size)
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

    func setViewport(width: Int, height: Int) {
        performCoreCall {
            set_editor_viewport(handle, Int16(width), Int16(height))
        }
    }

    private(set) var document: SweetDocument?

    func setDocument(_ document: SweetDocument) {
        self.document = document
        performCoreCall {
            set_editor_document(handle, document.handle)
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
                            directScale: Float = 1) -> GestureResultData? {
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
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeGestureResult(payload)
        }
    }

    func handleKeyEvent(keyCode: SEKeyCode, text: String? = nil, modifiers: SEModifier = []) -> KeyEventResultData? {
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
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeKeyEventResult(payload)
        }
    }

    func insertText(_ text: String) -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString { cStr in
                let ptr = editor_insert_text(handle, cStr, &size)
                return ptr
            }
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    /// Replaces text in a target range atomically and returns TextEditResultLite.
    func replaceText(startLine: Int, startColumn: Int,
                     endLine: Int, endColumn: Int,
                     newText: String) -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = newText.withCString { cStr in
                editor_replace_text(handle,
                                    startLine, startColumn,
                                    endLine, endColumn, cStr, &size)
            }
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    /// Deletes text in a target range atomically and returns TextEditResultLite.
    func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_text(handle,
                                         startLine, startColumn,
                                         endLine, endColumn, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    // MARK: - Line operations

    func moveLineUp() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_up(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func moveLineDown() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_down(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func copyLineUp() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_up(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func copyLineDown() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_down(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func deleteLine() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_line(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func insertLineAbove() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_above(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func insertLineBelow() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_below(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
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
    func gotoPosition(line: Int, column: Int) {
        performCoreCall {
            editor_goto_position(handle, line, column)
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
    func setSelectionRange(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) {
        performCoreCall {
            editor_set_selection(handle, startLine, startColumn, endLine, endColumn)
        }
    }

    // MARK: - IME Composition

    func compositionStart() {
        performCoreCall {
            editor_composition_start(handle)
        }
    }

    func compositionUpdate(_ text: String) {
        performCoreCall {
            text.withCString { cStr in
                editor_composition_update(handle, cStr)
            }
        }
    }

    func compositionEnd(_ committedText: String?) -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            if let text = committedText {
                let ptr = text.withCString { cStr in
                    let ptr = editor_composition_end(handle, cStr, &size)
                    return ptr
                }
                let payload = copyBinaryPayloadAndFree(ptr, size: size)
                return protocolDecoder.decodeTextEditResultLite(payload)
            } else {
                let ptr = editor_composition_end(handle, nil, &size)
                let payload = copyBinaryPayloadAndFree(ptr, size: size)
                return protocolDecoder.decodeTextEditResultLite(payload)
            }
        }
    }

    func compositionCancel() {
        performCoreCall {
            editor_composition_cancel(handle)
        }
    }

    func isComposing() -> Bool {
        return performCoreCall {
            editor_is_composing(handle) != 0
        }
    }

    func setCompositionEnabled(_ enabled: Bool) {
        performCoreCall {
            editor_set_composition_enabled(handle, enabled ? 1 : 0)
        }
    }

    func isCompositionEnabled() -> Bool {
        return performCoreCall {
            editor_is_composition_enabled(handle) != 0
        }
    }

    // MARK: - ReadOnly

    func setReadOnly(_ readOnly: Bool) {
        performCoreCall {
            editor_set_read_only(handle, readOnly ? 1 : 0)
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
    func setAutoIndentMode(_ mode: AutoIndentMode) {
        performCoreCall {
            editor_set_auto_indent_mode(handle, mode.rawValue)
        }
    }

    /// Returns the current auto-indentation mode.
    func getAutoIndentMode() -> AutoIndentMode {
        return performCoreCall {
            AutoIndentMode(rawValue: editor_get_auto_indent_mode(handle)) ?? .keepIndent
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

    func setScrollbarConfig(_ config: ScrollbarConfig) {
        scrollbarConfig = config
        performCoreCall {
            editor_set_scrollbar_config(
                handle,
                config.thickness,
                config.minThumb,
                config.thumbHitPadding,
                config.mode.rawValue,
                config.thumbDraggable ? 1 : 0,
                config.trackTapMode.rawValue,
                config.fadeDelayMs,
                config.fadeDurationMs
            )
        }
    }

    func scrollToLine(line: Int, behavior: UInt8) {
        performCoreCall {
            editor_scroll_to_line(handle, line, behavior)
        }
    }

    func setScroll(scrollX: Float, scrollY: Float) {
        performCoreCall {
            editor_set_scroll(handle, scrollX, scrollY)
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

    func onFontMetricsChanged() {
        performCoreCall {
            editor_on_font_metrics_changed(handle)
        }
    }

    // MARK: - Style / Highlight

    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) {
        performCoreCall {
            editor_register_text_style(handle, styleId, color, 0, fontStyle)
        }
    }

    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) {
        performCoreCall {
            editor_register_text_style(handle, styleId, color, backgroundColor, fontStyle)
        }
    }

    func registerBatchStyles(_ stylesById: [UInt32: (color: Int32, backgroundColor: Int32, fontStyle: Int32)]) {
        if stylesById.isEmpty { return }
        let payload = protocolEncoder.packBatchTextStyles(stylesById)
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_register_batch_text_styles(handle, ptr, size)
            }
        }
    }

    /// Clears all highlight layers.
    func clearHighlights() {
        performCoreCall {
            editor_clear_highlights(handle)
        }
    }

    /// Clears a specific highlight layer (0=SYNTAX, 1=SEMANTIC).
    func clearHighlights(layer: UInt8) {
        performCoreCall {
            editor_clear_highlights_layer(handle, layer)
        }
    }

    func setLineSpans(line: Int, layer: UInt8 = 0, spans: [StyleSpan]) {
        let payload = protocolEncoder.packLineSpans(line: line, layer: Int(layer), spans: spans)
        setLineSpans(payload: payload)
    }

    @available(*, deprecated, message: "Use setLineSpans(line:layer:spans:) with StyleSpan model")
    func setLineSpans(line: Int, spans: [(column: UInt32, length: UInt32, styleId: UInt32)], layer: UInt8 = 0) {
        let mapped = spans.map { StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
        setLineSpans(line: line, layer: layer, spans: mapped)
    }

    func setLineSpans(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_line_spans(handle, ptr, size)
            }
        }
    }

    func setBatchLineSpans(layer: UInt8, spansByLine: [Int: [StyleSpan]]) {
        if spansByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLineSpans(layer: Int(layer), spansByLine: spansByLine)
        setBatchLineSpans(payload: payload)
    }

    @available(*, deprecated, message: "Use setBatchLineSpans(layer:spansByLine:) with StyleSpan model")
    func setBatchLineSpans(layer: UInt8, spansByLine: [Int: [(column: UInt32, length: UInt32, styleId: UInt32)]]) {
        let mapped = spansByLine.mapValues { spans in
            spans.map { StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
        }
        setBatchLineSpans(layer: layer, spansByLine: mapped)
    }

    func setBatchLineSpans(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_batch_line_spans(handle, ptr, size)
            }
        }
    }

    // MARK: - Diagnostic (diagnostic decorations)

    /// Sets diagnostic decorations for a specific line (wavy/underline).
    /// - Parameters:
    ///   - line: Line number (0-based).
    ///   - diagnostics: Array of diagnostic ranges, each as `(column, length, severity, color)`.
    ///     severity: 0=ERROR, 1=WARNING, 2=INFO, 3=HINT
    ///     color: ARGB color value; use 0 to apply severity default color.
    func setLineDiagnostics(line: Int, items: [DiagnosticItem]) {
        let payload = protocolEncoder.packLineDiagnostics(line: line, items: items)
        setLineDiagnostics(payload: payload)
    }

    @available(*, deprecated, message: "Use setLineDiagnostics(line:items:) with DiagnosticItem model")
    func setLineDiagnostics(line: Int, diagnostics: [(column: Int32, length: Int32, severity: Int32, color: Int32)]) {
        let mapped = diagnostics.map {
            DiagnosticItem(column: $0.column, length: $0.length, severity: $0.severity, color: $0.color)
        }
        setLineDiagnostics(line: line, items: mapped)
    }

    func setLineDiagnostics(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_line_diagnostics(handle, ptr, size)
            }
        }
    }

    /// Sets diagnostic decorations for multiple lines.
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticItem]]) {
        if diagnosticsByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLineDiagnostics(diagnosticsByLine)
        setBatchLineDiagnostics(payload: payload)
    }

    /// Sets diagnostic decorations for multiple lines.
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [DiagnosticPayload]]) {
        if diagnosticsByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLineDiagnostics(diagnosticsByLine)
        setBatchLineDiagnostics(payload: payload)
    }

    func setBatchLineDiagnostics(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_batch_line_diagnostics(handle, ptr, size)
            }
        }
    }

    /// Clears all diagnostic decorations.
    func clearDiagnostics() {
        performCoreCall {
            editor_clear_diagnostics(handle)
        }
    }

    // MARK: - Inlay Hints & Phantom Text

    /// Replaces all inlay hints on a specific line.
    func setLineInlayHints(line: Int, hints: [InlayHintPayload]) {
        let payload = protocolEncoder.packLineInlayHints(line: line, hints: hints)
        setLineInlayHints(payload: payload)
    }

    func setLineInlayHints(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_line_inlay_hints(handle, ptr, size)
            }
        }
    }

    /// Replaces inlay hints for multiple lines in one call.
    func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHintPayload]]) {
        if hintsByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLineInlayHints(hintsByLine)
        setBatchLineInlayHints(payload: payload)
    }

    func setBatchLineInlayHints(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_batch_line_inlay_hints(handle, ptr, size)
            }
        }
    }

    /// Clears all inlay hints.
    func clearInlayHints() {
        performCoreCall {
            editor_clear_inlay_hints(handle)
        }
    }

    /// Replaces phantom texts on a specific line.
    func setLinePhantomTexts(line: Int, phantoms: [PhantomTextPayload]) {
        let payload = protocolEncoder.packLinePhantomTexts(line: line, phantoms: phantoms)
        setLinePhantomTexts(payload: payload)
    }

    func setLinePhantomTexts(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_line_phantom_texts(handle, ptr, size)
            }
        }
    }

    /// Replaces phantom texts for multiple lines in one call.
    func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomTextPayload]]) {
        if phantomsByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLinePhantomTexts(phantomsByLine)
        setBatchLinePhantomTexts(payload: payload)
    }

    func setBatchLinePhantomTexts(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_batch_line_phantom_texts(handle, ptr, size)
            }
        }
    }

    /// Clears all phantom texts.
    func clearPhantomTexts() {
        performCoreCall {
            editor_clear_phantom_texts(handle)
        }
    }

    /// Clears all decorations (highlight/inlay/phantom/gutter/guides/diagnostics).
    func clearAllDecorations() {
        performCoreCall {
            editor_clear_all_decorations(handle)
            editor_clear_diagnostics(handle)
        }
    }

    // MARK: - Gutter Icons

    func setLineGutterIcons(line: Int, icons: [GutterIcon]) {
        let payload = protocolEncoder.packLineGutterIcons(line: line, icons: icons)
        setLineGutterIcons(payload: payload)
    }

    @available(*, deprecated, message: "Use setLineGutterIcons(line:icons:) with GutterIcon model")
    func setLineGutterIcons(line: Int, iconIds: [Int32]) {
        let mapped = iconIds.map { GutterIcon(iconId: $0) }
        setLineGutterIcons(line: line, icons: mapped)
    }

    func setLineGutterIcons(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_line_gutter_icons(handle, ptr, size)
            }
        }
    }

    func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) {
        if iconsByLine.isEmpty { return }
        let payload = protocolEncoder.packBatchLineGutterIcons(iconsByLine)
        setBatchLineGutterIcons(payload: payload)
    }

    @available(*, deprecated, message: "Use setBatchLineGutterIcons(_:) with GutterIcon model")
    func setBatchLineGutterIcons(_ iconIdsByLine: [Int: [Int32]]) {
        let mapped = iconIdsByLine.mapValues { ids in
            ids.map { GutterIcon(iconId: $0) }
        }
        setBatchLineGutterIcons(mapped)
    }

    func setBatchLineGutterIcons(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_batch_line_gutter_icons(handle, ptr, size)
            }
        }
    }

    func clearGutterIcons() {
        performCoreCall {
            editor_clear_gutter_icons(handle)
        }
    }

    func setMaxGutterIcons(_ count: UInt32) {
        performCoreCall {
            editor_set_max_gutter_icons(handle, count)
        }
    }

    // MARK: - Guides

    func setIndentGuides(_ guides: [IndentGuidePayload]) {
        let payload = protocolEncoder.packIndentGuides(guides)
        setIndentGuides(payload: payload)
    }

    func setIndentGuides(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_indent_guides(handle, ptr, size)
            }
        }
    }

    func setBracketGuides(_ guides: [BracketGuidePayload]) {
        let payload = protocolEncoder.packBracketGuides(guides)
        setBracketGuides(payload: payload)
    }

    func setBracketGuides(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_bracket_guides(handle, ptr, size)
            }
        }
    }

    func setFlowGuides(_ guides: [FlowGuidePayload]) {
        let payload = protocolEncoder.packFlowGuides(guides)
        setFlowGuides(payload: payload)
    }

    func setFlowGuides(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_flow_guides(handle, ptr, size)
            }
        }
    }

    func setSeparatorGuides(_ guides: [SeparatorGuidePayload]) {
        let payload = protocolEncoder.packSeparatorGuides(guides)
        setSeparatorGuides(payload: payload)
    }

    func setSeparatorGuides(payload: Data) {
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_separator_guides(handle, ptr, size)
            }
        }
    }

    func clearGuides() {
        performCoreCall {
            editor_clear_guides(handle)
        }
    }

    // MARK: - Undo/Redo

    func undo() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_undo(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    func redo() -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_redo(handle, &size)
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }
    func canUndo() -> Bool { performCoreCall { editor_can_undo(handle) != 0 } }
    func canRedo() -> Bool { performCoreCall { editor_can_redo(handle) != 0 } }

    // MARK: - Fold (code folding)

    func setFoldRegions(_ regions: [FoldRegion]) {
        let payload = protocolEncoder.packFoldRegions(regions)
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_set_fold_regions(handle, ptr, size)
            }
        }
    }

    @available(*, deprecated, message: "Use setFoldRegions(_:) with FoldRegion model")
    func setFoldRegions(startLines: [Int], endLines: [Int], collapsed: [Bool]) {
        let count = min(startLines.count, min(endLines.count, collapsed.count))
        var regions: [FoldRegion] = []
        regions.reserveCapacity(count)
        for i in 0..<count {
            regions.append(FoldRegion(startLine: startLines[i], endLine: endLines[i], collapsed: collapsed[i]))
        }
        setFoldRegions(regions)
    }

    func toggleFold(line: Int) -> Bool {
        return performCoreCall {
            editor_toggle_fold(handle, line) != 0
        }
    }

    func foldAt(line: Int) -> Bool {
        return performCoreCall {
            editor_fold_at(handle, line) != 0
        }
    }

    func unfoldAt(line: Int) -> Bool {
        return performCoreCall {
            editor_unfold_at(handle, line) != 0
        }
    }

    func foldAll() {
        performCoreCall {
            editor_fold_all(handle)
        }
    }

    func unfoldAll() {
        performCoreCall {
            editor_unfold_all(handle)
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
    func setFoldArrowMode(_ mode: FoldArrowMode) {
        performCoreCall {
            editor_set_fold_arrow_mode(handle, mode.rawValue)
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
    func setWrapMode(_ mode: WrapMode) {
        performCoreCall {
            editor_set_wrap_mode(handle, mode.rawValue)
        }
    }

    /// Sets editor scale in the C++ core.
    /// Use `syncPlatformScale(_:)` to update platform-side fonts and measurer.
    func setScale(_ scale: Float) {
        performCoreCall {
            editor_set_scale(handle, scale)
        }
    }

    func setContentStartPadding(_ padding: Float) {
        performCoreCall {
            editor_set_content_start_padding(handle, padding)
        }
    }

    func setShowSplitLine(_ show: Bool) {
        performCoreCall {
            editor_set_show_split_line(handle, show ? 1 : 0)
        }
    }

    func setCurrentLineRenderMode(_ mode: Int32) {
        performCoreCall {
            editor_set_current_line_render_mode(handle, mode)
        }
    }

    /// Syncs platform-side font/measurer to the latest scale from the core.
    func syncPlatformScale(_ scale: Float) {
        guard scale > 0 else { return }
        rebuildFontsForScale(CGFloat(scale))
        performCoreCall {
            editor_on_font_metrics_changed(handle)
        }
    }

    /// Sets line-spacing parameters (`line_height = font_height * mult + add`).
    /// - Parameters:
    ///   - add: Extra line-spacing pixels (default 0).
    ///   - mult: Line-spacing multiplier (default 1.0).
    func setLineSpacing(add: Float, mult: Float) {
        performCoreCall {
            editor_set_line_spacing(handle, add, mult)
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
    func insertSnippet(_ template: String) -> TextEditResultLite? {
        return performCoreCall {
            var size: Int = 0
            let ptr = template.withCString { cStr in
                editor_insert_snippet(handle, cStr, &size)
            }
            let payload = copyBinaryPayloadAndFree(ptr, size: size)
            return protocolDecoder.decodeTextEditResultLite(payload)
        }
    }

    /// Starts linked-editing mode with a generic LinkedEditingModel.
    func startLinkedEditing(model: LinkedEditingModel) {
        let payload = protocolEncoder.packLinkedEditing(model: model)
        performCoreCall {
            withPayload(payload) { ptr, size in
                editor_start_linked_editing(handle, ptr, size)
            }
        }
    }

    /// Whether linked-editing mode is active.
    func isInLinkedEditing() -> Bool {
        return performCoreCall {
            editor_is_in_linked_editing(handle) != 0
        }
    }

    /// Linked editing: jump to the next tab stop.
    func linkedEditingNext() -> Bool {
        return performCoreCall {
            editor_linked_editing_next(handle) != 0
        }
    }

    /// Linked editing: jump to the previous tab stop.
    func linkedEditingPrev() -> Bool {
        return performCoreCall {
            editor_linked_editing_prev(handle) != 0
        }
    }

    /// Cancels linked-editing mode.
    func cancelLinkedEditing() {
        performCoreCall {
            editor_cancel_linked_editing(handle)
        }
    }

    // MARK: - Bracket Highlight

    /// Sets custom bracket pairs.
    func setBracketPairs(openChars: [Int32], closeChars: [Int32]) {
        assert(openChars.count == closeChars.count, "open/close arrays must have same length")
        var opens = openChars.map(UInt32.init(bitPattern:))
        var closes = closeChars.map(UInt32.init(bitPattern:))
        performCoreCall {
            editor_set_bracket_pairs(handle, &opens, &closes, opens.count)
        }
    }

    /// Sets externally computed exact bracket-match positions (higher priority than built-in scan).
    func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int) {
        performCoreCall {
            editor_set_matched_brackets(handle, openLine, openColumn, closeLine, closeColumn)
        }
    }

    /// Clears externally provided bracket-match results (falls back to built-in scan).
    func clearMatchedBrackets() {
        performCoreCall {
            editor_clear_matched_brackets(handle)
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
