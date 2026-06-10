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
    private(set) var scrollbarConfig = ScrollbarConfig()
    private var compositionEnabled = true

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

        let optionsPayload = CoreProtocol.encodeEditorOptions(
            EditorOptions(
                touch_slop: 10.0,
                double_tap_timeout: 300,
                long_press_ms: 500,
                fling_friction: 3.5,
                fling_min_velocity: 50.0,
                fling_max_velocity: 8000.0,
                max_undo_stack_size: 512,
                key_chord_timeout_ms: 2000,
                reveal_selection_end_on_select_all: revealSelectionEndOnSelectAll
            )
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

    private func withPayload<T>(_ payload: Data, _ block: (UnsafePointer<UInt8>?, Int) -> T) -> T {
        return payload.withUnsafeBytes { raw in
            let ptr = raw.bindMemory(to: UInt8.self).baseAddress
            return block(ptr, payload.count)
        }
    }

    private func int32Keyed<T>(_ values: [Int: T]) -> [Int32: T] {
        Dictionary(uniqueKeysWithValues: values.map { (Int32($0.key), $0.value) })
    }

    private func spanLayer(from rawValue: Int32) -> SpanLayer {
        SpanLayer.fromValue(rawValue)
    }

    private func decodeNativePayload<T>(
        _ ptr: UnsafePointer<UInt8>?,
        size: Int,
        decode: (UnsafeRawBufferPointer) -> T?
    ) -> T? {
        guard let ptr = ptr else { return nil }
        defer { free_binary_data(Int(bitPattern: ptr)) }
        guard size > 0 else { return nil }
        let buffer = UnsafeRawBufferPointer(start: ptr, count: size)
        return decode(buffer)
    }

    private func decodeEditorActionPayload(_ ptr: UnsafePointer<UInt8>?, size: Int) -> EditorActionResult? {
        decodeNativePayload(ptr, size: size) { CoreProtocol.decodeEditorActionResult($0) }
    }

    private func performPayloadEditorAction(
        _ payload: Data,
        _ block: (UnsafePointer<UInt8>?, Int, inout Int) -> UnsafePointer<UInt8>?
    ) -> EditorActionResult? {
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
    func setViewport(width: Int, height: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_viewport(handle, Int16(width), Int16(height), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    private(set) var document: SweetDocument?

    @discardableResult
    func setDocument(_ document: SweetDocument) -> EditorActionResult? {
        self.document = document
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_document(handle, document.handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func buildRenderModel() -> EditorRenderModel? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_build_render_model(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeEditorRenderModel($0) }
        }
    }

    func getLayoutMetrics() -> LayoutMetrics? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_layout_metrics(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeLayoutMetrics($0) }
        }
    }

    func handleGestureEvent(type: SEEventType, points: [(Float, Float)],
                            modifiers: SEModifier = [],
                            wheelDeltaX: Float = 0, wheelDeltaY: Float = 0,
                            directScale: Float = 1) -> EditorActionResult? {
        let event = GestureEvent(
            type: EventType.fromValue(Int32(type.rawValue)),
            points: points.map { PointF(x: $0.0, y: $0.1) },
            modifiers: Int32(modifiers.rawValue),
            wheel_delta_x: wheelDeltaX,
            wheel_delta_y: wheelDeltaY,
            direct_scale: directScale
        )
        let payload = CoreProtocol.encodeGestureEvent(event)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_handle_gesture_event(handle, ptr, size, &outSize)
        }
    }

    func updatePointerModifiers(_ modifiers: SEModifier) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_update_pointer_modifiers(handle, modifiers.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func handleKeyEvent(keyCode: SEKeyCode, text: String? = nil, modifiers: SEModifier = []) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr: UnsafePointer<UInt8>?
            if let text = text {
                ptr = text.withCString { cStr in
                    editor_handle_key_event(handle, keyCode.rawValue, cStr, modifiers.rawValue, &size)
                }
            } else {
                ptr = editor_handle_key_event(handle, keyCode.rawValue, nil, modifiers.rawValue, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertText(_ text: String) -> EditorActionResult? {
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
                     newText: String) -> EditorActionResult? {
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
                    endLine: Int, endColumn: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_text(handle,
                                         startLine, startColumn,
                                         endLine, endColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Applies multiple text edits as one undoable operation.
    func applyTextEdits(_ edits: [TextEdit]) -> EditorActionResult? {
        return performCoreCall {
            let payload = CoreProtocol.encodeApplyTextEditsPayload(edits: edits)
            var size: Int = 0
            let ptr = payload.withUnsafeBytes { bytes -> UnsafePointer<UInt8>? in
                guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                return editor_apply_text_edits(handle, base, payload.count, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Line operations

    func moveLineUp() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func moveLineDown() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func copyLineUp() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func copyLineDown() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func deleteLine() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_line(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertLineAbove() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_above(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func insertLineBelow() -> EditorActionResult? {
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
    func gotoPosition(line: Int, column: Int) -> EditorActionResult? {
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
    func setSelectionRange(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_selection(handle, startLine, startColumn, endLine, endColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - IME Composition

    @discardableResult
    func updateImePreedit(_ text: String) -> EditorActionResult? {
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
                                      selectionEndOffset: Int) -> EditorActionResult? {
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
    func commitImeText(_ text: String?) -> EditorActionResult? {
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
    func finishImePreedit() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_finish_preedit(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func cancelImePreedit() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_cancel_preedit(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func markImeDocumentRange(startLine: Int, startColumn: Int, endLine: Int, endColumn: Int) -> EditorActionResult? {
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
    func markImeDocumentRange(startOffset: Int, endOffset: Int) -> EditorActionResult? {
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
    func updateImeTextModelState(_ state: ImeTextModelState) -> EditorActionResult? {
        return performCoreCall {
            let payload = CoreProtocol.encodeImeTextModelState(state)
            var size: Int = 0
            let ptr = payload.withUnsafeBytes { raw in
                let data = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
                editor_ime_update_text_model_state(handle,
                                                   data,
                                                   payload.count,
                                                   &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func updateImeInputStateSelection(contextId: Int64,
                                      documentStartOffset: Int,
                                      selectionStartOffset: Int,
                                      selectionEndOffset: Int) -> EditorActionResult? {
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
    func replaceImeInputStateText(_ replacement: ImeInputStateTextReplacement) -> EditorActionResult? {
        return performCoreCall {
            let payload = CoreProtocol.encodeImeInputStateTextReplacement(replacement)
            var size: Int = 0
            let ptr = payload.withUnsafeBytes { raw in
                let data = raw.baseAddress?.assumingMemoryBound(to: UInt8.self)
                editor_ime_replace_input_state_text(handle,
                                                    data,
                                                    payload.count,
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
    func setCompositionEnabled(_ enabled: Bool) -> EditorActionResult? {
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
    func setReadOnly(_ readOnly: Bool) -> EditorActionResult? {
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

    /// Sets the auto-indentation mode.
    @discardableResult
    func setAutoIndentMode(_ mode: AutoIndentMode) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_auto_indent_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Returns the current auto-indentation mode.
    func getAutoIndentMode() -> AutoIndentMode {
        return performCoreCall {
            AutoIndentMode(rawValue: editor_get_auto_indent_mode(handle)) ?? .KEEP_INDENT
        }
    }

    /// Sets backspace unindent behavior.
    @discardableResult
    func setBackspaceUnindent(_ enabled: Bool) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_backspace_unindent(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets whether Tab inserts spaces instead of a tab character.
    @discardableResult
    func setInsertSpaces(_ enabled: Bool) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_insert_spaces(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Position Rect

    /// Returns the screen-space rectangle for any text position (for floating panel placement).
    func getPositionRect(line: Int, column: Int) -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_position_rect(handle, line, column, &x, &y, &h)
            return CursorRect(x: x, y: y, height: h)
        }
    }

    /// Returns the screen-space rectangle for current caret position (convenience).
    func getCursorRect() -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_cursor_rect(handle, &x, &y, &h)
            return CursorRect(x: x, y: y, height: h)
        }
    }

    // MARK: - Scroll / Navigation

    @discardableResult
    func setScrollbarConfig(_ config: ScrollbarConfig) -> EditorActionResult? {
        scrollbarConfig = config
        let payload = CoreProtocol.encodeScrollbarConfig(config)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_scrollbar_config(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setEditorRenderColors(_ colors: EditorRenderColors) -> EditorActionResult? {
        let payload = CoreProtocol.encodeEditorRenderColors(colors)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_editor_render_colors(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setEditorRangeEffectStyles(_ styles: EditorRangeEffectStyles) -> EditorActionResult? {
        let payload = CoreProtocol.encodeEditorRangeEffectStyles(styles)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_editor_range_effect_styles(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func scrollToLine(line: Int, behavior: UInt8) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_scroll_to_line(handle, line, behavior, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setScroll(scrollX: Float, scrollY: Float) -> EditorActionResult? {
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
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeScrollMetrics($0) } ?? defaultScrollMetrics()
        }
    }

    private func defaultScrollMetrics() -> ScrollMetrics {
        ScrollMetrics()
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
    func onFontMetricsChanged() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_on_font_metrics_changed(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Style / Highlight

    @discardableResult
    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) -> EditorActionResult? {
        registerStyle(styleId: styleId, color: color, backgroundColor: 0, fontStyle: fontStyle)
    }

    @discardableResult
    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_register_text_style(handle, styleId, color, backgroundColor, fontStyle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func registerBatchStyles(_ stylesById: [UInt32: (color: Int32, backgroundColor: Int32, fontStyle: Int32)]) -> EditorActionResult? {
        if stylesById.isEmpty { return nil }
        let styles = Dictionary(uniqueKeysWithValues: stylesById.map {
            (
                Int32(bitPattern: $0.key),
                TextStyle(
                    color: $0.value.color,
                    background_color: $0.value.backgroundColor,
                    font_style: $0.value.fontStyle
                )
            )
        })
        let payload = CoreProtocol.encodeRegisterBatchTextStylesPayload(styleByStyleId: styles)
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
    func clearHighlights() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears a specific highlight layer (0=SYNTAX, 1=SEMANTIC).
    @discardableResult
    func clearHighlights(layer: Int32) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights_layer(handle, UInt8(clamping: layer), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setLineSpans(line: Int, layer: Int32 = 0, spans: [StyleSpan]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineSpansPayload(
            line: Int32(line),
            layer: spanLayer(from: layer),
            spans: spans
        )
        return setLineSpans(payload: payload)
    }

    @discardableResult
    func setLineSpans(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_spans(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineSpans(layer: Int32, spansByLine: [Int: [StyleSpan]]) -> EditorActionResult? {
        if spansByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineSpansPayload(
            layer: spanLayer(from: layer),
            spansByLine: int32Keyed(spansByLine)
        )
        return setBatchLineSpans(payload: payload)
    }

    @discardableResult
    func setBatchLineSpans(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_spans(handle, ptr, size, &outSize)
        }
    }

    // MARK: - Diagnostic (diagnostic decorations)

    /// Sets diagnostic decorations for a specific line (wavy/underline).
    /// - Parameters:
    ///   - line: Line number (0-based).
    @discardableResult
    func setLineDiagnostics(line: Int, items: [Diagnostic]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineDiagnosticsPayload(line: Int32(line), diagnostics: items)
        return setLineDiagnostics(payload: payload)
    }

    @discardableResult
    func setLineDiagnostics(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Sets diagnostic decorations for multiple lines.
    @discardableResult
    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]]) -> EditorActionResult? {
        if diagnosticsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineDiagnosticsPayload(diagnosticsByLine: int32Keyed(diagnosticsByLine))
        return setBatchLineDiagnostics(payload: payload)
    }

    @discardableResult
    func setBatchLineDiagnostics(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Clears all diagnostic decorations.
    @discardableResult
    func clearDiagnostics() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_diagnostics(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Document Highlight

    @discardableResult
    func setLineDocumentHighlights(line: Int, items: [DocumentHighlight]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineDocumentHighlightsPayload(line: Int32(line), highlights: items)
        return setLineDocumentHighlights(payload: payload)
    }

    @discardableResult
    func setLineDocumentHighlights(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_document_highlights(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineDocumentHighlights(_ highlightsByLine: [Int: [DocumentHighlight]]) -> EditorActionResult? {
        if highlightsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineDocumentHighlightsPayload(highlightsByLine: int32Keyed(highlightsByLine))
        return setBatchLineDocumentHighlights(payload: payload)
    }

    @discardableResult
    func setBatchLineDocumentHighlights(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_document_highlights(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearDocumentHighlights() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_document_highlights(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Inlay Hints & Phantom Text

    /// Replaces all inlay hints on a specific line.
    @discardableResult
    func setLineInlayHints(line: Int, hints: [InlayHint]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineInlayHintsPayload(line: Int32(line), hints: hints)
        return setLineInlayHints(payload: payload)
    }

    @discardableResult
    func setLineInlayHints(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Replaces inlay hints for multiple lines in one call.
    @discardableResult
    func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHint]]) -> EditorActionResult? {
        if hintsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineInlayHintsPayload(hintsByLine: int32Keyed(hintsByLine))
        return setBatchLineInlayHints(payload: payload)
    }

    @discardableResult
    func setBatchLineInlayHints(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Clears all inlay hints.
    @discardableResult
    func clearInlayHints() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_inlay_hints(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Replaces phantom texts on a specific line.
    @discardableResult
    func setLinePhantomTexts(line: Int, phantoms: [PhantomText]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLinePhantomTextsPayload(line: Int32(line), phantoms: phantoms)
        return setLinePhantomTexts(payload: payload)
    }

    @discardableResult
    func setLinePhantomTexts(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Replaces phantom texts for multiple lines in one call.
    @discardableResult
    func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomText]]) -> EditorActionResult? {
        if phantomsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLinePhantomTextsPayload(phantomsByLine: int32Keyed(phantomsByLine))
        return setBatchLinePhantomTexts(payload: payload)
    }

    @discardableResult
    func setBatchLinePhantomTexts(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Clears all phantom texts.
    @discardableResult
    func clearPhantomTexts() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_phantom_texts(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears all decorations (highlight/inlay/phantom/gutter/guides/diagnostics).
    @discardableResult
    func clearAllDecorations() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_all_decorations(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Gutter Icons

    @discardableResult
    func setLineGutterIcons(line: Int, icons: [GutterIcon]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineGutterIconsPayload(line: Int32(line), icons: icons)
        return setLineGutterIcons(payload: payload)
    }

    @discardableResult
    func setLineGutterIcons(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) -> EditorActionResult? {
        if iconsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineGutterIconsPayload(iconsByLine: int32Keyed(iconsByLine))
        return setBatchLineGutterIcons(payload: payload)
    }

    @discardableResult
    func setBatchLineGutterIcons(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearGutterIcons() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_gutter_icons(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setMaxGutterIcons(_ count: UInt32) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_max_gutter_icons(handle, count, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - CodeLens

    @discardableResult
    func setLineCodeLens(line: Int, items: [CodeLensItem]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineCodeLensPayload(line: Int32(line), items: items)
        return setLineCodeLens(payload: payload)
    }

    @discardableResult
    func setLineCodeLens(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensItem]]) -> EditorActionResult? {
        if itemsByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineCodeLensPayload(itemsByLine: int32Keyed(itemsByLine))
        return setBatchLineCodeLens(payload: payload)
    }

    @discardableResult
    func setBatchLineCodeLens(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearCodeLens() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_codelens(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Links

    @discardableResult
    func setLineLinks(line: Int, links: [LinkSpan]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetLineLinksPayload(line: Int32(line), links: links)
        return setLineLinks(payload: payload)
    }

    @discardableResult
    func setLineLinks(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) -> EditorActionResult? {
        if linksByLine.isEmpty { return nil }
        let payload = CoreProtocol.encodeSetBatchLineLinksPayload(linksByLine: int32Keyed(linksByLine))
        return setBatchLineLinks(payload: payload)
    }

    @discardableResult
    func setBatchLineLinks(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearLinks() -> EditorActionResult? {
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
    func setIndentGuides(_ guides: [IndentGuide]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetIndentGuidesPayload(guides: guides)
        return setIndentGuides(payload: payload)
    }

    @discardableResult
    func setIndentGuides(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_indent_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setBracketGuides(_ guides: [BracketGuide]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetBracketGuidesPayload(guides: guides)
        return setBracketGuides(payload: payload)
    }

    @discardableResult
    func setBracketGuides(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_bracket_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setFlowGuides(_ guides: [FlowGuide]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetFlowGuidesPayload(guides: guides)
        return setFlowGuides(payload: payload)
    }

    @discardableResult
    func setFlowGuides(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_flow_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func setSeparatorGuides(_ guides: [SeparatorGuide]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetSeparatorGuidesPayload(guides: guides)
        return setSeparatorGuides(payload: payload)
    }

    @discardableResult
    func setSeparatorGuides(payload: Data) -> EditorActionResult? {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_separator_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearGuides() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_guides(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Undo/Redo

    func undo() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_undo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func redo() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_redo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }
    func canUndo() -> Bool { performCoreCall { editor_can_undo(handle) != 0 } }
    func canRedo() -> Bool { performCoreCall { editor_can_redo(handle) != 0 } }

    // MARK: - Search

    @discardableResult
    func search(_ request: SearchRequest) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSearchRequest(request)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_search(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func findNextSearchMatch() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_find_next_search_match(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func findPreviousSearchMatch() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_find_previous_search_match(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func replaceCurrentSearchMatch(_ replacement: String) -> EditorActionResult? {
        let payload = CoreProtocol.encodeUtf8String(replacement)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_replace_current_search_match(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func replaceAllSearchMatches(_ replacement: String) -> EditorActionResult? {
        let payload = CoreProtocol.encodeUtf8String(replacement)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_replace_all_search_matches(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    func clearSearch() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_search(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func getSearchState() -> SearchState {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_search_state(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeSearchState($0) } ?? SearchState()
        }
    }

    // MARK: - Fold (code folding)

    @discardableResult
    func setFoldRegions(_ regions: [FoldRegion]) -> EditorActionResult? {
        let payload = CoreProtocol.encodeSetFoldRegionsPayload(regions: regions)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_fold_regions(handle, ptr, size, &outSize)
        }
    }

    func toggleFold(line: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_toggle_fold(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func foldAt(line: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    func unfoldAt(line: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_unfold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func foldAll() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func unfoldAll() -> EditorActionResult? {
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

    /// Sets fold-arrow visibility mode (affects reserved gutter width).
    @discardableResult
    func setFoldArrowMode(_ mode: FoldArrowMode) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_fold_arrow_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets wrap mode.
    @discardableResult
    func setWrapMode(_ mode: WrapMode) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_wrap_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets editor scale in the C++ core.
    /// Use `syncPlatformScale(_:)` to update platform-side fonts and measurer.
    @discardableResult
    func setScale(_ scale: Float) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scale(handle, scale, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setContentStartPadding(_ padding: Float) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_content_start_padding(handle, padding, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setShowSplitLine(_ show: Bool) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_show_split_line(handle, show ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    func setCurrentLineRenderMode(_ mode: Int32) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_current_line_render_mode(handle, mode, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Syncs platform-side font/measurer to the latest scale from the core.
    @discardableResult
    func syncPlatformScale(_ scale: Float) -> EditorActionResult? {
        guard scale > 0 else { return nil }
        rebuildFontsForScale(CGFloat(scale))
        return onFontMetricsChanged()
    }

    /// Sets line-spacing parameters (`line_height = font_height * mult + add`).
    /// - Parameters:
    ///   - add: Extra line-spacing pixels (default 0).
    ///   - mult: Line-spacing multiplier (default 1.0).
    @discardableResult
    func setLineSpacing(add: Float, mult: Float) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_line_spacing(handle, add, mult, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - LinkedEditing

    /// Inserts a VSCode snippet template and enters linked-editing mode.
    func insertSnippet(_ template: String) -> EditorActionResult? {
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
    func startLinkedEditing(model: LinkedEditingModel) -> EditorActionResult? {
        let payload = CoreProtocol.encodeStartLinkedEditingPayload(model: model)
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
    func linkedEditingNext() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_next(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Linked editing: jump to the previous tab stop.
    func linkedEditingPrev() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_prev(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Cancels linked-editing mode.
    @discardableResult
    func cancelLinkedEditing() -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_cancel_linked_editing(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Bracket Highlight

    /// Sets custom bracket pairs.
    @discardableResult
    func setBracketPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResult? {
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
    func setAutoClosingPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResult? {
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
    func setTabSize(_ tabSize: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_tab_size(handle, Int32(tabSize), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets externally computed exact bracket-match positions (higher priority than built-in scan).
    @discardableResult
    func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int) -> EditorActionResult? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_matched_brackets(handle, openLine, openColumn, closeLine, closeColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears externally provided bracket-match results (falls back to built-in scan).
    @discardableResult
    func clearMatchedBrackets() -> EditorActionResult? {
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
