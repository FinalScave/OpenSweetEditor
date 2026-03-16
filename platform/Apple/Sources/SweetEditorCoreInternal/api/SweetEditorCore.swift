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

    private final class ProtocolDecoder {
        unowned let owner: SweetEditorCore

        init(owner: SweetEditorCore) {
            self.owner = owner
        }

        func decodeTextEditResultLite(_ data: Data?) -> TextEditResultLite? {
            owner.parseTextEditResultLite(data)
        }

        func decodeKeyEventResult(_ data: Data?) -> KeyEventResultData? {
            owner.parseKeyEventResult(data)
        }

        func decodeGestureResult(_ data: Data?) -> GestureResultData? {
            owner.parseGestureResult(data)
        }

        func decodeRenderModel(_ data: Data) -> EditorRenderModel? {
            owner.readEditorRenderModel(data)
        }

        func decodeLayoutMetrics(_ data: Data?) -> LayoutMetrics? {
            guard let payload = data else { return nil }
            return owner.readLayoutMetrics(payload)
        }

        func decodeScrollMetrics(_ data: Data?) -> ScrollMetrics {
            guard let payload = data else { return owner.defaultScrollMetrics() }
            var reader = BinaryReader(data: payload)
            guard let scale = reader.readFloat(),
                  let scrollX = reader.readFloat(),
                  let scrollY = reader.readFloat(),
                  let maxScrollX = reader.readFloat(),
                  let maxScrollY = reader.readFloat(),
                  let contentWidth = reader.readFloat(),
                  let contentHeight = reader.readFloat(),
                  let viewportWidth = reader.readFloat(),
                  let viewportHeight = reader.readFloat(),
                  let textAreaX = reader.readFloat(),
                  let textAreaWidth = reader.readFloat(),
                  let canScrollX = reader.readInt32(),
                  let canScrollY = reader.readInt32() else {
                return owner.defaultScrollMetrics()
            }
            return ScrollMetrics(
                scale: CGFloat(scale),
                scrollX: CGFloat(scrollX),
                scrollY: CGFloat(scrollY),
                maxScrollX: CGFloat(maxScrollX),
                maxScrollY: CGFloat(maxScrollY),
                contentWidth: CGFloat(contentWidth),
                contentHeight: CGFloat(contentHeight),
                viewportWidth: CGFloat(viewportWidth),
                viewportHeight: CGFloat(viewportHeight),
                textAreaX: CGFloat(textAreaX),
                textAreaWidth: CGFloat(textAreaWidth),
                canScrollX: canScrollX != 0,
                canScrollY: canScrollY != 0
            )
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

        handle = performCoreCall {
            create_editor(
                10.0,   // touch_slop
                300,    // double_tap_timeout
                se_text_measurer_t(
                    measure_text_width: SweetEditorCore.measureTextWidthCallback,
                    measure_inlay_hint_width: SweetEditorCore.measureInlayHintWidthCallback,
                    measure_icon_width: SweetEditorCore.measureIconWidthCallback,
                    get_font_metrics: SweetEditorCore.getFontMetricsCallback
                )
            )
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

    private func appendI32(_ value: Int32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private func withPayload(_ payload: Data, _ block: (UnsafePointer<UInt8>?, Int) -> Void) {
        payload.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress
            block(ptr, payload.count)
        }
    }

    private struct BinaryReader {
        let data: Data
        var offset: Int = 0

        mutating func readUInt32() -> UInt32? {
            guard offset + 4 <= data.count else { return nil }
            let b0 = UInt32(data[offset])
            let b1 = UInt32(data[offset + 1]) << 8
            let b2 = UInt32(data[offset + 2]) << 16
            let b3 = UInt32(data[offset + 3]) << 24
            offset += 4
            return b0 | b1 | b2 | b3
        }

        mutating func readInt32() -> Int32? {
            guard let raw = readUInt32() else { return nil }
            return Int32(bitPattern: raw)
        }

        mutating func readFloat() -> Float? {
            guard let raw = readUInt32() else { return nil }
            return Float(bitPattern: raw)
        }

        mutating func readString() -> String? {
            guard let lenI32 = readInt32(), lenI32 >= 0 else { return nil }
            let len = Int(lenI32)
            guard offset + len <= data.count else { return nil }
            defer { offset += len }
            if len == 0 { return "" }
            let slice = data.subdata(in: offset..<(offset + len))
            return String(data: slice, encoding: .utf8) ?? ""
        }
    }

    private func copyBinaryPayloadAndFree(_ ptr: UnsafePointer<UInt8>?, size: Int) -> Data? {
        guard let ptr = ptr else { return nil }
        defer { free_binary_data(Int(bitPattern: ptr)) }
        guard size > 0 else { return nil }
        return Data(bytes: ptr, count: size)
    }

    private func gestureType(from value: Int32) -> GestureType {
        switch value {
        case 1: return .TAP
        case 2: return .DOUBLE_TAP
        case 3: return .LONG_PRESS
        case 4: return .SCALE
        case 5: return .SCROLL
        case 6: return .FAST_SCROLL
        case 7: return .DRAG_SELECT
        case 8: return .CONTEXT_MENU
        default: return .UNDEFINED
        }
    }

    private func hitTargetType(from value: Int32) -> HitTargetType {
        switch value {
        case 1: return .INLAY_HINT_TEXT
        case 2: return .INLAY_HINT_ICON
        case 3: return .GUTTER_ICON
        case 4: return .FOLD_PLACEHOLDER
        case 5: return .FOLD_GUTTER
        case 6: return .INLAY_HINT_COLOR
        default: return .NONE
        }
    }

    private func parseTextChange(_ reader: inout BinaryReader) -> TextChangeData? {
        guard let startLine = reader.readInt32(),
              let startColumn = reader.readInt32(),
              let endLine = reader.readInt32(),
              let endColumn = reader.readInt32(),
              let newText = reader.readString() else {
            return nil
        }
        let range = TextRangeData(
            start: TextPositionData(line: Int(startLine), column: Int(startColumn)),
            end: TextPositionData(line: Int(endLine), column: Int(endColumn))
        )
        return TextChangeData(range: range, new_text: newText)
    }

    private func parseTextEditResultLite(_ data: Data?) -> TextEditResultLite? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let changed = reader.readInt32(), changed != 0,
              let count = reader.readInt32(), count > 0 else {
            return nil
        }
        var changes: [TextChangeData] = []
        let changeCount = Int(count)
        changes.reserveCapacity(changeCount)
        for _ in 0..<changeCount {
            guard let change = parseTextChange(&reader) else { break }
            changes.append(change)
        }
        guard !changes.isEmpty else { return nil }
        return TextEditResultLite(changes: changes)
    }

    private func parseKeyEventResult(_ data: Data?) -> KeyEventResultData? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let handled = reader.readInt32(),
              let contentChanged = reader.readInt32(),
              let cursorChanged = reader.readInt32(),
              let selectionChanged = reader.readInt32(),
              let hasEdit = reader.readInt32() else {
            return nil
        }

        var editChanges: [TextChangeData] = []
        if hasEdit != 0, let count = reader.readInt32(), count > 0 {
            let changeCount = Int(count)
            editChanges.reserveCapacity(changeCount)
            for _ in 0..<changeCount {
                guard let change = parseTextChange(&reader) else { break }
                editChanges.append(change)
            }
        }
        let zeroPos = TextPositionData(line: 0, column: 0)
        let edit = TextEditResultData(
            changed: !editChanges.isEmpty,
            changes: editChanges,
            cursor_before: zeroPos,
            cursor_after: zeroPos
        )
        return KeyEventResultData(
            handled: handled != 0,
            content_changed: contentChanged != 0,
            cursor_changed: cursorChanged != 0,
            selection_changed: selectionChanged != 0,
            edit_result: edit
        )
    }

    private func parseGestureResult(_ data: Data?) -> GestureResultData? {
        guard let data = data else { return nil }
        var reader = BinaryReader(data: data)
        guard let typeValue = reader.readInt32() else { return nil }
        let type = gestureType(from: typeValue)
        var tapPoint = PointData(x: 0, y: 0)
        if type == .TAP || type == .DOUBLE_TAP || type == .LONG_PRESS || type == .DRAG_SELECT || type == .CONTEXT_MENU {
            guard let x = reader.readFloat(), let y = reader.readFloat() else { return nil }
            tapPoint = PointData(x: x, y: y)
        }

        guard let cursorLine = reader.readInt32(),
              let cursorColumn = reader.readInt32(),
              let hasSelectionI32 = reader.readInt32(),
              let selStartLine = reader.readInt32(),
              let selStartColumn = reader.readInt32(),
              let selEndLine = reader.readInt32(),
              let selEndColumn = reader.readInt32(),
              let viewScrollX = reader.readFloat(),
              let viewScrollY = reader.readFloat(),
              let viewScale = reader.readFloat() else {
            return nil
        }

        var hitTarget = HitTargetData(type: .NONE, line: 0, column: 0, icon_id: 0, color_value: 0)
        if let hitType = reader.readInt32(),
           let hitLine = reader.readInt32(),
           let hitColumn = reader.readInt32(),
           let hitIcon = reader.readInt32(),
           let hitColor = reader.readInt32() {
            hitTarget = HitTargetData(
                type: hitTargetType(from: hitType),
                line: Int(hitLine),
                column: Int(hitColumn),
                icon_id: Int32(hitIcon),
                color_value: Int32(hitColor)
            )
        }

        let cursor = TextPositionData(line: Int(cursorLine), column: Int(cursorColumn))
        let selection = TextRangeData(
            start: TextPositionData(line: Int(selStartLine), column: Int(selStartColumn)),
            end: TextPositionData(line: Int(selEndLine), column: Int(selEndColumn))
        )
        return GestureResultData(
            type: type,
            tap_point: tapPoint,
            modifiers: 0,
            scale: 1,
            scroll_x: 0,
            scroll_y: 0,
            cursor_position: cursor,
            has_selection: hasSelectionI32 != 0,
            selection: selection,
            view_scroll_x: viewScrollX,
            view_scroll_y: viewScrollY,
            view_scale: viewScale,
            hit_target: hitTarget
        )
    }

    private func visualRunType(from value: Int32) -> VisualRunType {
        switch value {
        case 1: return .WHITESPACE
        case 2: return .NEWLINE
        case 3: return .INLAY_HINT
        case 4: return .PHANTOM_TEXT
        case 5: return .FOLD_PLACEHOLDER
        default: return .TEXT
        }
    }

    private func foldState(from value: Int32) -> FoldState {
        switch value {
        case 1: return .EXPANDED
        case 2: return .COLLAPSED
        default: return .NONE
        }
    }

    private func guideDirection(from value: Int32) -> GuideDirection {
        switch value {
        case 1: return .VERTICAL
        default: return .HORIZONTAL
        }
    }

    private func guideType(from value: Int32) -> GuideType {
        switch value {
        case 1: return .BRACKET
        case 2: return .FLOW
        case 3: return .SEPARATOR
        default: return .INDENT
        }
    }

    private func guideStyle(from value: Int32) -> GuideStyle {
        switch value {
        case 1: return .DASHED
        case 2: return .DOUBLE
        default: return .SOLID
        }
    }

    private func foldArrowModeName(from value: Int32) -> String {
        switch value {
        case 1: return "ALWAYS"
        case 2: return "HIDDEN"
        default: return "AUTO"
        }
    }

    private func readPointData(_ reader: inout BinaryReader) -> PointData? {
        guard let x = reader.readFloat(), let y = reader.readFloat() else { return nil }
        return PointData(x: x, y: y)
    }

    private func readTextPositionData(_ reader: inout BinaryReader) -> TextPositionData? {
        guard let line = reader.readInt32(), let column = reader.readInt32() else { return nil }
        return TextPositionData(line: Int(line), column: Int(column))
    }

    private func readInlineStyle(_ reader: inout BinaryReader) -> InlineStyle? {
        guard let color = reader.readInt32(),
              let backgroundColor = reader.readInt32(),
              let fontStyle = reader.readInt32() else {
            return nil
        }
        return InlineStyle(font_style: fontStyle, color: color, background_color: backgroundColor)
    }

    private func readVisualRun(_ reader: inout BinaryReader) -> VisualRun? {
        guard let typeValue = reader.readInt32(),
              let x = reader.readFloat(),
              let y = reader.readFloat(),
              let text = reader.readString(),
              let style = readInlineStyle(&reader),
              let iconId = reader.readInt32(),
              let colorValue = reader.readInt32(),
              let width = reader.readFloat(),
              let padding = reader.readFloat(),
              let margin = reader.readFloat() else {
            return nil
        }
        return VisualRun(
            type: visualRunType(from: typeValue),
            x: x,
            y: y,
            text: text,
            style: style,
            icon_id: iconId,
            color_value: colorValue,
            width: width,
            padding: padding,
            margin: margin
        )
    }

    private func readVisualLine(_ reader: inout BinaryReader) -> VisualLine? {
        guard let logicalLine = reader.readInt32(),
              let wrapIndex = reader.readInt32(),
              let lineNumberPosition = readPointData(&reader),
              let isPhantomLine = reader.readInt32(),
              let foldStateValue = reader.readInt32(),
              let gutterIconCount = reader.readInt32(),
              gutterIconCount >= 0 else {
            return nil
        }
        var gutterIconIds: [Int32] = []
        gutterIconIds.reserveCapacity(Int(gutterIconCount))
        for _ in 0..<Int(gutterIconCount) {
            guard let iconId = reader.readInt32() else { return nil }
            gutterIconIds.append(iconId)
        }
        guard let runCount = reader.readInt32(), runCount >= 0 else { return nil }
        var runs: [VisualRun] = []
        runs.reserveCapacity(Int(runCount))
        for _ in 0..<Int(runCount) {
            guard let run = readVisualRun(&reader) else { return nil }
            runs.append(run)
        }
        return VisualLine(
            logical_line: Int(logicalLine),
            wrap_index: Int(wrapIndex),
            line_number_position: lineNumberPosition,
            runs: runs,
            is_phantom_line: isPhantomLine != 0,
            gutter_icon_ids: gutterIconIds,
            fold_state: foldState(from: foldStateValue)
        )
    }

    private func readCursorRender(_ reader: inout BinaryReader) -> Cursor? {
        guard let textPosition = readTextPositionData(&reader),
              let position = readPointData(&reader),
              let height = reader.readFloat(),
              let visible = reader.readInt32(),
              let showDragger = reader.readInt32() else {
            return nil
        }
        return Cursor(
            text_position: textPosition,
            position: position,
            height: height,
            visible: visible != 0,
            show_dragger: showDragger != 0
        )
    }

    private func readSelectionRect(_ reader: inout BinaryReader) -> SelectionRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return SelectionRect(origin: origin, width: width, height: height)
    }

    private func readSelectionHandle(_ reader: inout BinaryReader) -> SelectionHandle? {
        guard let position = readPointData(&reader),
              let height = reader.readFloat(),
              let visible = reader.readInt32() else {
            return nil
        }
        return SelectionHandle(position: position, height: height, visible: visible != 0)
    }

    private func readCompositionDecoration(_ reader: inout BinaryReader) -> CompositionDecoration? {
        guard let active = reader.readInt32(),
              let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return CompositionDecoration(active: active != 0, origin: origin, width: width, height: height)
    }

    private func readGuideSegment(_ reader: inout BinaryReader) -> GuideSegment? {
        guard let directionValue = reader.readInt32(),
              let typeValue = reader.readInt32(),
              let styleValue = reader.readInt32(),
              let start = readPointData(&reader),
              let end = readPointData(&reader),
              let arrowEnd = reader.readInt32() else {
            return nil
        }
        return GuideSegment(
            direction: guideDirection(from: directionValue),
            type: guideType(from: typeValue),
            style: guideStyle(from: styleValue),
            start: start,
            end: end,
            arrow_end: arrowEnd != 0
        )
    }

    private func readDiagnosticDecoration(_ reader: inout BinaryReader) -> DiagnosticDecoration? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat(),
              let severity = reader.readInt32(),
              let color = reader.readInt32() else {
            return nil
        }
        return DiagnosticDecoration(origin: origin, width: width, height: height, severity: severity, color: color)
    }

    private func readLinkedEditingRect(_ reader: inout BinaryReader) -> LinkedEditingRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat(),
              let isActive = reader.readInt32() else {
            return nil
        }
        return LinkedEditingRect(origin: origin, width: width, height: height, is_active: isActive != 0)
    }

    private func readBracketHighlightRect(_ reader: inout BinaryReader) -> BracketHighlightRect? {
        guard let origin = readPointData(&reader),
              let width = reader.readFloat(),
              let height = reader.readFloat() else {
            return nil
        }
        return BracketHighlightRect(origin: origin, width: width, height: height)
    }

    private func readEditorRenderModel(_ data: Data) -> EditorRenderModel? {
        var reader = BinaryReader(data: data)
        guard let splitX = reader.readFloat(),
              let scrollX = reader.readFloat(),
              let scrollY = reader.readFloat(),
              let viewportWidth = reader.readFloat(),
              let viewportHeight = reader.readFloat(),
              let currentLine = readPointData(&reader),
              let lineCount = reader.readInt32(),
              lineCount >= 0 else {
            return nil
        }

        var lines: [VisualLine] = []
        lines.reserveCapacity(Int(lineCount))
        for _ in 0..<Int(lineCount) {
            guard let line = readVisualLine(&reader) else { return nil }
            lines.append(line)
        }

        guard let cursor = readCursorRender(&reader),
              let selectionRectCount = reader.readInt32(),
              selectionRectCount >= 0 else {
            return nil
        }
        var selectionRects: [SelectionRect] = []
        selectionRects.reserveCapacity(Int(selectionRectCount))
        for _ in 0..<Int(selectionRectCount) {
            guard let rect = readSelectionRect(&reader) else { return nil }
            selectionRects.append(rect)
        }

        guard let selectionStartHandle = readSelectionHandle(&reader),
              let selectionEndHandle = readSelectionHandle(&reader),
              let compositionDecoration = readCompositionDecoration(&reader),
              let guideCount = reader.readInt32(),
              guideCount >= 0 else {
            return nil
        }
        var guideSegments: [GuideSegment] = []
        guideSegments.reserveCapacity(Int(guideCount))
        for _ in 0..<Int(guideCount) {
            guard let segment = readGuideSegment(&reader) else { return nil }
            guideSegments.append(segment)
        }

        guard let diagnosticCount = reader.readInt32(), diagnosticCount >= 0 else { return nil }
        var diagnosticDecorations: [DiagnosticDecoration] = []
        diagnosticDecorations.reserveCapacity(Int(diagnosticCount))
        for _ in 0..<Int(diagnosticCount) {
            guard let decoration = readDiagnosticDecoration(&reader) else { return nil }
            diagnosticDecorations.append(decoration)
        }

        guard let maxGutterIcons = reader.readInt32(),
              let foldArrowX = reader.readFloat(),
              let linkedEditingRectCount = reader.readInt32(),
              linkedEditingRectCount >= 0 else {
            return nil
        }
        var linkedEditingRects: [LinkedEditingRect] = []
        linkedEditingRects.reserveCapacity(Int(linkedEditingRectCount))
        for _ in 0..<Int(linkedEditingRectCount) {
            guard let rect = readLinkedEditingRect(&reader) else { return nil }
            linkedEditingRects.append(rect)
        }

        guard let bracketHighlightRectCount = reader.readInt32(), bracketHighlightRectCount >= 0 else {
            return nil
        }
        var bracketHighlightRects: [BracketHighlightRect] = []
        bracketHighlightRects.reserveCapacity(Int(bracketHighlightRectCount))
        for _ in 0..<Int(bracketHighlightRectCount) {
            guard let rect = readBracketHighlightRect(&reader) else { return nil }
            bracketHighlightRects.append(rect)
        }

        return EditorRenderModel(
            split_x: splitX,
            scroll_x: scrollX,
            scroll_y: scrollY,
            viewport_width: viewportWidth,
            viewport_height: viewportHeight,
            current_line: currentLine,
            lines: lines,
            cursor: cursor,
            selection_rects: selectionRects,
            selection_start_handle: selectionStartHandle,
            selection_end_handle: selectionEndHandle,
            composition_decoration: compositionDecoration,
            guide_segments: guideSegments,
            diagnostic_decorations: diagnosticDecorations,
            max_gutter_icons: UInt32(bitPattern: maxGutterIcons),
            fold_arrow_x: foldArrowX,
            linked_editing_rects: linkedEditingRects,
            bracket_highlight_rects: bracketHighlightRects
        )
    }

    private func readLayoutMetrics(_ data: Data) -> LayoutMetrics? {
        var reader = BinaryReader(data: data)
        guard let fontHeight = reader.readFloat(),
              let fontAscent = reader.readFloat(),
              let lineSpacingAdd = reader.readFloat(),
              let lineSpacingMult = reader.readFloat(),
              let lineNumberMargin = reader.readFloat(),
              let lineNumberWidth = reader.readFloat(),
              let maxGutterIcons = reader.readInt32(),
              let inlayHintPadding = reader.readFloat(),
              let inlayHintMargin = reader.readFloat(),
              let foldArrowMode = reader.readInt32(),
              let hasFoldRegions = reader.readInt32() else {
            return nil
        }

        return LayoutMetrics(
            font_height: fontHeight,
            font_ascent: fontAscent,
            line_spacing_add: lineSpacingAdd,
            line_spacing_mult: lineSpacingMult,
            line_number_margin: lineNumberMargin,
            line_number_width: lineNumberWidth,
            max_gutter_icons: UInt32(bitPattern: maxGutterIcons),
            inlay_hint_padding: inlayHintPadding,
            inlay_hint_margin: inlayHintMargin,
            fold_arrow_mode: foldArrowModeName(from: foldArrowMode),
            has_fold_regions: hasFoldRegions != 0
        )
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

    private func defaultScrollMetrics() -> ScrollMetrics {
        ScrollMetrics(
            scale: 1.0,
            scrollX: 0.0,
            scrollY: 0.0,
            maxScrollX: 0.0,
            maxScrollY: 0.0,
            contentWidth: 0.0,
            contentHeight: 0.0,
            viewportWidth: 0.0,
            viewportHeight: 0.0,
            textAreaX: 0.0,
            textAreaWidth: 0.0,
            canScrollX: false,
            canScrollY: false
        )
    }

    func scrollToLine(line: Int, behavior: UInt8) {
        performCoreCall {
            editor_scroll_to_line(handle, line, behavior)
        }
    }

    func gotoPosition(line: Int, column: Int) {
        performCoreCall {
            editor_goto_position(handle, line, column)
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

    func resetMeasurer() {
        performCoreCall {
            reset_editor_text_measurer(handle)
        }
    }

    // MARK: - Style / Highlight

    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) {
        performCoreCall {
            editor_register_style(handle, styleId, color, 0, fontStyle)
        }
    }

    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) {
        performCoreCall {
            editor_register_style(handle, styleId, color, backgroundColor, fontStyle)
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

    /// Syncs platform-side font/measurer to the latest scale from the core.
    func syncPlatformScale(_ scale: Float) {
        guard scale > 0 else { return }
        rebuildFontsForScale(CGFloat(scale))
        performCoreCall {
            reset_editor_text_measurer(handle)
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

/// Measure string width using CoreText CTLine
func measureStringWidth(_ string: String, font: CTFont) -> CGFloat {
    if string.isEmpty { return 0 }
    let attrStr = CFAttributedStringCreateMutable(nil, 0)!
    CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), string as CFString)
    CFAttributedStringSetAttribute(attrStr, CFRange(location: 0, length: string.utf16.count),
                                   kCTFontAttributeName, font)
    let line = CTLineCreateWithAttributedString(attrStr)
    let width = CTLineGetTypographicBounds(line, nil, nil, nil)
    return width
}
