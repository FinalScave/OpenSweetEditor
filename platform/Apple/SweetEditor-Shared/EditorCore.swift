import Foundation
import CoreText
import CoreGraphics
#if os(iOS)
import SweetEditorCoreIOS
#elseif os(macOS)
import SweetEditorCoreMacOS
#endif

// MARK: - Font style constants (matches C++ FontStyle enum)
let FONT_STYLE_NORMAL: Int32        = 0
let FONT_STYLE_BOLD: Int32          = 1       // 1 << 0
let FONT_STYLE_ITALIC: Int32        = 1 << 1  // 2
let FONT_STYLE_STRIKETHROUGH: Int32 = 1 << 2  // 4

// MARK: - EditorCore

public final class EditorCore {
    private(set) var handle: Int = 0
    private var handleConfig = HandleConfig()
    private var scrollbarConfig = ScrollbarConfig()

    private static let threadDictionaryKey = NSString(string: "EditorCore.currentStack")

    private final class ThreadCoreStack: NSObject {
        private var stack: [WeakCoreBox] = []

        func push(_ core: EditorCore) {
            stack.append(WeakCoreBox(core: core))
        }

        func pop() {
            if !stack.isEmpty {
                stack.removeLast()
            }
        }

        func current() -> EditorCore? {
            while let last = stack.last, last.core == nil {
                stack.removeLast()
            }
            return stack.last?.core
        }

        var isEmpty: Bool { stack.isEmpty }
    }

    private final class WeakCoreBox {
        weak var core: EditorCore?

        init(core: EditorCore) {
            self.core = core
        }
    }

    // Font references kept alive for CoreText measurement
    package var regularFont: CTFont
    package var boldFont: CTFont
    package var italicFont: CTFont
    package var boldItalicFont: CTFont
    package var inlayHintFont: CTFont
    private var baseFontName: String
    private var baseFontSize: CGFloat
    private let baseInlayHintFontName: String
    private var baseInlayHintFontSize: CGFloat
    private var platformScale: CGFloat = 1

    private static func getCurrent() -> EditorCore? {
        guard let stack = Thread.current.threadDictionary[threadDictionaryKey] as? ThreadCoreStack else { return nil }
        return stack.current()
    }

    private static func withActiveCore<T>(_ core: EditorCore, execute block: () -> T) -> T {
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
        return EditorCore.withActiveCore(self, execute: block)
    }

    public init(
        fontSize: CGFloat = 14.0,
        fontName: String = "Menlo",
        options: EditorOptions? = nil
    ) {
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

        let defaultOptions = EditorOptions(
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
        let optionsPayload = CoreProtocol.encodeEditorOptions(options ?? defaultOptions)

        handle = performCoreCall {
            var editorHandle: Int = 0
            optionsPayload.withUnsafeBytes { raw in
                let ptr = raw.bindMemory(to: UInt8.self).baseAddress
                editorHandle = create_editor(
                    text_measurer_t(
                        measure_text_width: EditorCore.measureTextWidthCallback,
                        measure_inlay_hint_width: EditorCore.measureInlayHintWidthCallback,
                        measure_icon_width: EditorCore.measureIconWidthCallback,
                        get_font_metrics: EditorCore.getFontMetricsCallback
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

    private func decodeEditorActionPayload(_ ptr: UnsafePointer<UInt8>?, size: Int) -> EditorActionResult {
        decodeNativePayload(ptr, size: size) { CoreProtocol.decodeEditorActionResult($0) }
            ?? EditorActionResult()
    }

    private func performPayloadEditorAction(
        _ payload: Data,
        _ block: (UnsafePointer<UInt8>?, Int, inout Int) -> UnsafePointer<UInt8>?
    ) -> EditorActionResult {
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
        guard let textPtr = textPtr, let core = EditorCore.getCurrent() else { return 0 }
        let str = stringFromU16Ptr(textPtr)
        let font = core.fontForStyle(fontStyle)
        return Float(measureStringWidth(str, font: font))
    }

    private static let measureInlayHintWidthCallback: @convention(c) (UnsafePointer<UInt16>?) -> Float = { textPtr in
        guard let textPtr = textPtr, let core = EditorCore.getCurrent() else { return 0 }
        let str = stringFromU16Ptr(textPtr)
        return Float(measureStringWidth(str, font: core.inlayHintFont))
    }

    private static let measureIconWidthCallback: @convention(c) (Int32) -> Float = { _ in
        guard let core = EditorCore.getCurrent() else { return 0 }
        return Float(CTFontGetSize(core.regularFont))
    }

    private static let getFontMetricsCallback: @convention(c) (UnsafeMutablePointer<Float>?, Int) -> Void = { arrPtr, length in
        guard let arrPtr = arrPtr, length >= 2, let core = EditorCore.getCurrent() else { return }
        let ascent = CTFontGetAscent(core.regularFont)
        let descent = CTFontGetDescent(core.regularFont)
        arrPtr[0] = Float(-ascent)  // negative ascent (baseline to top)
        arrPtr[1] = Float(descent)
    }

    // MARK: - Font Selection

    package func fontForStyle(_ fontStyle: Int32) -> CTFont {
        let isBold = (fontStyle & FONT_STYLE_BOLD) != 0
        let isItalic = (fontStyle & FONT_STYLE_ITALIC) != 0
        if isBold && isItalic { return boldItalicFont }
        if isBold { return boldFont }
        if isItalic { return italicFont }
        return regularFont
    }

    // MARK: - Editor Operations

    @discardableResult
    public func setViewport(width: Int, height: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_viewport(handle, Int32(width), Int32(height), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    private var document: Document?

    @discardableResult
    public func loadDocument(_ document: Document) -> EditorActionResult {
        self.document = document
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_document(handle, document.handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func getDocument() -> Document? {
        document
    }

    public func buildRenderModel() -> EditorRenderModel? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_build_render_model(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeEditorRenderModel($0) }
        }
    }

    public func getLayoutMetrics() -> LayoutMetrics? {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_layout_metrics(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeLayoutMetrics($0) }
        }
    }

    public func handleGestureEvent(_ event: GestureEvent) -> EditorActionResult {
        let payload = CoreProtocol.encodeGestureEvent(event)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_handle_gesture_event(handle, ptr, size, &outSize)
        }
    }

    package func handleGestureEvent(type: EventType, points: [(Float, Float)],
                            modifiers: Int32 = KeyModifier.NONE,
                            wheelDeltaX: Float = 0, wheelDeltaY: Float = 0,
                            directScale: Float = 1) -> EditorActionResult {
        let event = GestureEvent(
            type: type,
            points: points.map { PointF(x: $0.0, y: $0.1) },
            modifiers: modifiers,
            wheel_delta_x: wheelDeltaX,
            wheel_delta_y: wheelDeltaY,
            direct_scale: directScale
        )
        return handleGestureEvent(event)
    }

    public func updatePointerModifiers(_ modifiers: Int32) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_update_pointer_modifiers(handle, UInt8(modifiers), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func tickAnimations() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_tick_animations(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func handleKeyEvent(
        keyCode: Int32,
        text: String? = nil,
        modifiers: Int32 = KeyModifier.NONE
    ) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr: UnsafePointer<UInt8>?
            if let text = text {
                ptr = text.withCString { cStr in
                    editor_handle_key_event(handle, UInt16(keyCode), cStr, UInt8(modifiers), &size)
                }
            } else {
                ptr = editor_handle_key_event(handle, UInt16(keyCode), nil, UInt8(modifiers), &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setKeyMap(_ bindings: [KeyBinding]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetKeyMapPayload(bindings: bindings)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_keymap(handle, ptr, size, &outSize)
        }
    }

    public func insertText(_ text: String) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = text.withCString { cStr in
                let ptr = editor_insert_text(handle, cStr, &size)
                return ptr
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func backspace() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_backspace(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func deleteForward() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_forward(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Replaces text in a target range atomically.
    public func replaceText(startLine: Int, startColumn: Int,
                     endLine: Int, endColumn: Int,
                     newText: String) -> EditorActionResult {
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
    public func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_text(handle,
                                         startLine, startColumn,
                                         endLine, endColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Applies multiple text edits as one undoable operation.
    public func applyTextEdits(_ edits: [TextEdit]) -> EditorActionResult {
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

    public func moveLineUp() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func moveLineDown() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_move_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func copyLineUp() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_up(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func copyLineDown() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_copy_line_down(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func deleteLine() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_delete_line(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func insertLineAbove() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_above(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func insertLineBelow() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_insert_line_below(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func getSelectedText() -> String {
        return performCoreCall {
            guard let ptr = editor_get_selected_text(handle) else { return "" }
            return String(cString: ptr)
        }
    }

    /// Returns the caret position in document coordinates.
    public func getCursorPosition() -> TextPosition {
        return performCoreCall {
            var line: Int = 0
            var column: Int = 0
            editor_get_cursor_position(handle, &line, &column)
            return TextPosition(line: line, column: column)
        }
    }

    @discardableResult
    public func setCursorPosition(_ position: TextPosition) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_cursor_position(handle, Int(position.line), Int(position.column), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Moves caret to the given document position.
    @discardableResult
    public func gotoPosition(line: Int, column: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_goto_position(handle, line, column, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Returns the text range of the word at the caret.
    public func getWordRangeAtCursor() -> TextRange {
        return performCoreCall {
            var sl: Int = 0, sc: Int = 0, el: Int = 0, ec: Int = 0
            editor_get_word_range_at_cursor(handle, &sl, &sc, &el, &ec)
            return TextRange(
                start: TextPosition(line: sl, column: sc),
                end: TextPosition(line: el, column: ec)
            )
        }
    }

    /// Returns the word text at the caret.
    public func getWordAtCursor() -> String {
        return performCoreCall {
            guard let ptr = editor_get_word_at_cursor(handle) else { return "" }
            return String(cString: ptr)
        }
    }

    /// Returns the current selection range if one exists.
    public func getSelection() -> TextRange? {
        return performCoreCall {
            var sl: Int = 0, sc: Int = 0, el: Int = 0, ec: Int = 0
            let hasSelection = editor_get_selection(handle, &sl, &sc, &el, &ec)
            if hasSelection == 0 {
                return nil
            }
            return TextRange(
                start: TextPosition(line: sl, column: sc),
                end: TextPosition(line: el, column: ec)
            )
        }
    }

    /// Sets the selection range in document coordinates.
    @discardableResult
    public func setSelection(_ range: TextRange) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_selection(
                handle,
                Int(range.start.line),
                Int(range.start.column),
                Int(range.end.line),
                Int(range.end.column),
                &size
            )
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func selectAll() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_select_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func moveCursorLeft(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_left, extendSelection: extendSelection)
    }

    @discardableResult
    public func moveCursorRight(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_right, extendSelection: extendSelection)
    }

    @discardableResult
    public func moveCursorUp(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_up, extendSelection: extendSelection)
    }

    @discardableResult
    public func moveCursorDown(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_down, extendSelection: extendSelection)
    }

    @discardableResult
    public func moveCursorToLineStart(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_to_line_start, extendSelection: extendSelection)
    }

    @discardableResult
    public func moveCursorToLineEnd(extendSelection: Bool = false) -> EditorActionResult {
        moveCursor(editor_move_cursor_to_line_end, extendSelection: extendSelection)
    }

    private func moveCursor(
        _ operation: (Int, Int32, UnsafeMutablePointer<Int>) -> UnsafePointer<UInt8>?,
        extendSelection: Bool
    ) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = operation(handle, extendSelection ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - IME

    public func beginImeSession(_ mutationModel: ImeMutationModel) -> ImeState? {
        performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_begin_session(handle, Int32(mutationModel.rawValue), &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeImeState($0) }
        }
    }

    public func endImeSession(_ sessionId: Int64) -> EditorActionResult {
        performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_end_session(handle, UInt64(bitPattern: sessionId), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func applyImeCommands(_ batch: ImeCommandBatch) -> EditorActionResult {
        let payload = CoreProtocol.encodeImeCommandBatch(batch)
        return performPayloadEditorAction(payload) { data, size, outSize in
            editor_ime_apply_commands(handle, data, size, &outSize)
        }
    }

    public func getImeState(_ sessionId: Int64) -> ImeState? {
        performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_get_state(handle, UInt64(bitPattern: sessionId), &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeImeState($0) }
        }
    }

    public func getImeContext(
        _ sessionId: Int64,
        source: ImeTextSource,
        startUtf16: Int64,
        lengthUtf16: Int64
    ) -> ImeTextContext? {
        performCoreCall {
            var size: Int = 0
            let ptr = editor_ime_get_context(
                handle,
                UInt64(bitPattern: sessionId),
                Int32(source.rawValue),
                startUtf16,
                lengthUtf16,
                &size
            )
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeImeTextContext($0) }
        }
    }

    // MARK: - ReadOnly

    @discardableResult
    public func setReadOnly(_ readOnly: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_read_only(handle, readOnly ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func isReadOnly() -> Bool {
        return performCoreCall {
            editor_is_read_only(handle) != 0
        }
    }

    // MARK: - AutoIndent

    /// Sets the auto-indentation mode.
    @discardableResult
    public func setAutoIndentMode(_ mode: AutoIndentMode) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_auto_indent_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Returns the current auto-indentation mode.
    public func getAutoIndentMode() -> AutoIndentMode {
        return performCoreCall {
            AutoIndentMode(rawValue: editor_get_auto_indent_mode(handle)) ?? .KEEP_INDENT
        }
    }

    /// Sets backspace unindent behavior.
    @discardableResult
    public func setBackspaceUnindent(_ enabled: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_backspace_unindent(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets whether Tab inserts spaces instead of a tab character.
    @discardableResult
    public func setInsertSpaces(_ enabled: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_insert_spaces(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Position Rect

    /// Returns the screen-space rectangle for any text position (for floating panel placement).
    public func getPositionRect(line: Int, column: Int) -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_position_rect(handle, line, column, &x, &y, &h)
            return CursorRect(x: x, y: y, height: h)
        }
    }

    /// Returns the screen-space rectangle for current caret position (convenience).
    public func getCursorRect() -> CursorRect {
        return performCoreCall {
            var x: Float = 0, y: Float = 0, h: Float = 0
            editor_get_cursor_rect(handle, &x, &y, &h)
            return CursorRect(x: x, y: y, height: h)
        }
    }

    // MARK: - Scroll / Navigation

    @discardableResult
    public func setHandleConfig(_ config: HandleConfig) -> EditorActionResult {
        handleConfig = config
        let payload = CoreProtocol.encodeHandleConfig(config)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_handle_config(handle, ptr, size, &outSize)
        }
    }

    public func getHandleConfig() -> HandleConfig {
        handleConfig
    }

    @discardableResult
    public func setScrollbarConfig(_ config: ScrollbarConfig) -> EditorActionResult {
        scrollbarConfig = config
        let payload = CoreProtocol.encodeScrollbarConfig(config)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_scrollbar_config(handle, ptr, size, &outSize)
        }
    }

    public func getScrollbarConfig() -> ScrollbarConfig {
        scrollbarConfig
    }

    @discardableResult
    public func setEditorRenderColors(_ colors: EditorRenderColors) -> EditorActionResult {
        let payload = CoreProtocol.encodeEditorRenderColors(colors)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_editor_render_colors(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setEditorRangeEffectStyles(_ styles: EditorRangeEffectStyles) -> EditorActionResult {
        let payload = CoreProtocol.encodeEditorRangeEffectStyles(styles)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_editor_range_effect_styles(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func scrollToLine(_ line: Int, behavior: ScrollBehavior) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_scroll_to_line(handle, line, UInt8(behavior.rawValue), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setScroll(scrollX: Float, scrollY: Float) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scroll(handle, scrollX, scrollY, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func getScrollMetrics() -> ScrollMetrics {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_scroll_metrics(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeScrollMetrics($0) } ?? defaultScrollMetrics()
        }
    }

    private func defaultScrollMetrics() -> ScrollMetrics {
        ScrollMetrics()
    }

    public func getVisibleLineRange() -> IntRange {
        return performCoreCall {
            var startLine: Int32 = 0
            var endLine: Int32 = -1
            editor_get_visible_line_range(handle, &startLine, &endLine)
            return IntRange(start: Int(startLine), end: Int(endLine))
        }
    }

    @discardableResult
    public func ensureCursorVisible() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_ensure_cursor_visible(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func onFontMetricsChanged() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_on_font_metrics_changed(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Style / Highlight

    @discardableResult
    public func registerTextStyle(styleId: Int32, color: Int32, fontStyle: Int32) -> EditorActionResult {
        registerTextStyle(styleId: styleId, color: color, backgroundColor: 0, fontStyle: fontStyle)
    }

    @discardableResult
    public func registerTextStyle(styleId: Int32, color: Int32, backgroundColor: Int32, fontStyle: Int32) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_register_text_style(
                handle,
                UInt32(bitPattern: styleId),
                color,
                backgroundColor,
                fontStyle,
                &size
            )
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func registerBatchTextStyles(_ stylesById: [Int32: TextStyle]) -> EditorActionResult {
        if stylesById.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeRegisterBatchTextStylesPayload(styleByStyleId: stylesById)
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
    public func clearHighlights() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears a specific highlight layer (0=SYNTAX, 1=SEMANTIC).
    @discardableResult
    public func clearHighlights(layer: SpanLayer) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_highlights_layer(handle, UInt8(clamping: layer.rawValue), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setLineSpans(line: Int, layer: SpanLayer = .SYNTAX, spans: [StyleSpan]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineSpansPayload(
            line: Int32(line),
            layer: layer,
            spans: spans
        )
        return setLineSpans(payload: payload)
    }

    @discardableResult
    public func clearLineSpans(line: Int, layer: SpanLayer = .SYNTAX) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_line_spans(handle, line, UInt8(clamping: layer.rawValue), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    private func setLineSpans(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_spans(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [StyleSpan]]) -> EditorActionResult {
        if spansByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineSpansPayload(
            layer: layer,
            spansByLine: int32Keyed(spansByLine)
        )
        return setBatchLineSpans(payload: payload)
    }

    @discardableResult
    private func setBatchLineSpans(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_spans(handle, ptr, size, &outSize)
        }
    }

    // MARK: - Diagnostic (diagnostic decorations)

    /// Sets diagnostic decorations for a specific line (wavy/underline).
    /// - Parameters:
    ///   - line: Line number (0-based).
    @discardableResult
    public func setLineDiagnostics(line: Int, items: [Diagnostic]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineDiagnosticsPayload(line: Int32(line), diagnostics: items)
        return setLineDiagnostics(payload: payload)
    }

    @discardableResult
    private func setLineDiagnostics(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Sets diagnostic decorations for multiple lines.
    @discardableResult
    public func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]]) -> EditorActionResult {
        if diagnosticsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineDiagnosticsPayload(diagnosticsByLine: int32Keyed(diagnosticsByLine))
        return setBatchLineDiagnostics(payload: payload)
    }

    @discardableResult
    private func setBatchLineDiagnostics(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_diagnostics(handle, ptr, size, &outSize)
        }
    }

    /// Clears all diagnostic decorations.
    @discardableResult
    public func clearDiagnostics() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_diagnostics(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Document Highlight

    @discardableResult
    public func setLineDocumentHighlights(line: Int, items: [DocumentHighlight]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineDocumentHighlightsPayload(line: Int32(line), highlights: items)
        return setLineDocumentHighlights(payload: payload)
    }

    @discardableResult
    private func setLineDocumentHighlights(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_document_highlights(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBatchLineDocumentHighlights(_ highlightsByLine: [Int: [DocumentHighlight]]) -> EditorActionResult {
        if highlightsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineDocumentHighlightsPayload(highlightsByLine: int32Keyed(highlightsByLine))
        return setBatchLineDocumentHighlights(payload: payload)
    }

    @discardableResult
    private func setBatchLineDocumentHighlights(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_document_highlights(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearDocumentHighlights() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_document_highlights(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Inlay Hints & Phantom Text

    /// Replaces all inlay hints on a specific line.
    @discardableResult
    public func setLineInlayHints(line: Int, hints: [InlayHint]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineInlayHintsPayload(line: Int32(line), hints: hints)
        return setLineInlayHints(payload: payload)
    }

    @discardableResult
    private func setLineInlayHints(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Replaces inlay hints for multiple lines in one call.
    @discardableResult
    public func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHint]]) -> EditorActionResult {
        if hintsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineInlayHintsPayload(hintsByLine: int32Keyed(hintsByLine))
        return setBatchLineInlayHints(payload: payload)
    }

    @discardableResult
    private func setBatchLineInlayHints(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_inlay_hints(handle, ptr, size, &outSize)
        }
    }

    /// Clears all inlay hints.
    @discardableResult
    public func clearInlayHints() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_inlay_hints(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Replaces phantom texts on a specific line.
    @discardableResult
    public func setLinePhantomTexts(line: Int, phantoms: [PhantomText]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLinePhantomTextsPayload(line: Int32(line), phantoms: phantoms)
        return setLinePhantomTexts(payload: payload)
    }

    @discardableResult
    private func setLinePhantomTexts(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Replaces phantom texts for multiple lines in one call.
    @discardableResult
    public func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomText]]) -> EditorActionResult {
        if phantomsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLinePhantomTextsPayload(phantomsByLine: int32Keyed(phantomsByLine))
        return setBatchLinePhantomTexts(payload: payload)
    }

    @discardableResult
    private func setBatchLinePhantomTexts(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_phantom_texts(handle, ptr, size, &outSize)
        }
    }

    /// Clears all phantom texts.
    @discardableResult
    public func clearPhantomTexts() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_phantom_texts(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears all decorations (highlight/inlay/phantom/gutter/guides/diagnostics).
    @discardableResult
    public func clearAllDecorations() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_all_decorations(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Gutter Icons

    @discardableResult
    public func setLineGutterIcons(line: Int, icons: [GutterIcon]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineGutterIconsPayload(line: Int32(line), icons: icons)
        return setLineGutterIcons(payload: payload)
    }

    @discardableResult
    private func setLineGutterIcons(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) -> EditorActionResult {
        if iconsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineGutterIconsPayload(iconsByLine: int32Keyed(iconsByLine))
        return setBatchLineGutterIcons(payload: payload)
    }

    @discardableResult
    private func setBatchLineGutterIcons(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_gutter_icons(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearGutterIcons() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_gutter_icons(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setMaxGutterIcons(_ count: UInt32) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_max_gutter_icons(handle, count, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - CodeLens

    @discardableResult
    public func setLineCodeLens(line: Int, items: [CodeLensItem]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineCodeLensPayload(line: Int32(line), items: items)
        return setLineCodeLens(payload: payload)
    }

    @discardableResult
    private func setLineCodeLens(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensItem]]) -> EditorActionResult {
        if itemsByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineCodeLensPayload(itemsByLine: int32Keyed(itemsByLine))
        return setBatchLineCodeLens(payload: payload)
    }

    @discardableResult
    private func setBatchLineCodeLens(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_codelens(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearCodeLens() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_codelens(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Links

    @discardableResult
    public func setLineLinks(line: Int, links: [LinkSpan]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetLineLinksPayload(line: Int32(line), links: links)
        return setLineLinks(payload: payload)
    }

    @discardableResult
    private func setLineLinks(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) -> EditorActionResult {
        if linksByLine.isEmpty { return EditorActionResult() }
        let payload = CoreProtocol.encodeSetBatchLineLinksPayload(linksByLine: int32Keyed(linksByLine))
        return setBatchLineLinks(payload: payload)
    }

    @discardableResult
    private func setBatchLineLinks(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_line_links(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearLinks() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_links(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func getLinkTargetAt(line: Int, column: Int) -> String {
        return performCoreCall {
            guard let ptr = editor_get_link_target_at(handle, line, column) else { return "" }
            defer { free_u8_string(Int(bitPattern: ptr)) }
            return String(cString: ptr)
        }
    }

    // MARK: - Guides

    @discardableResult
    public func setIndentGuides(_ guides: [IndentGuide]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetIndentGuidesPayload(guides: guides)
        return setIndentGuides(payload: payload)
    }

    @discardableResult
    private func setIndentGuides(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_indent_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setBracketGuides(_ guides: [BracketGuide]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetBracketGuidesPayload(guides: guides)
        return setBracketGuides(payload: payload)
    }

    @discardableResult
    private func setBracketGuides(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_bracket_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setFlowGuides(_ guides: [FlowGuide]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetFlowGuidesPayload(guides: guides)
        return setFlowGuides(payload: payload)
    }

    @discardableResult
    private func setFlowGuides(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_flow_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func setSeparatorGuides(_ guides: [SeparatorGuide]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetSeparatorGuidesPayload(guides: guides)
        return setSeparatorGuides(payload: payload)
    }

    @discardableResult
    private func setSeparatorGuides(payload: Data) -> EditorActionResult {
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_separator_guides(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearGuides() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_guides(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Undo/Redo

    public func undo() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_undo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func redo() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_redo(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }
    public func canUndo() -> Bool { performCoreCall { editor_can_undo(handle) != 0 } }
    public func canRedo() -> Bool { performCoreCall { editor_can_redo(handle) != 0 } }

    // MARK: - Search

    @discardableResult
    public func search(_ request: SearchRequest) -> EditorActionResult {
        let payload = CoreProtocol.encodeSearchRequest(request)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_search(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func findNextSearchMatch() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_find_next_search_match(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func findPreviousSearchMatch() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_find_previous_search_match(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func replaceCurrentSearchMatch(_ replacement: String) -> EditorActionResult {
        let payload = CoreProtocol.encodeUtf8String(replacement)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_replace_current_search_match(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func replaceAllSearchMatches(_ replacement: String) -> EditorActionResult {
        let payload = CoreProtocol.encodeUtf8String(replacement)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_replace_all_search_matches(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearSearch() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_search(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func getSearchState() -> SearchState {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_get_search_state(handle, &size)
            return decodeNativePayload(ptr, size: size) { CoreProtocol.decodeSearchState($0) } ?? SearchState()
        }
    }

    // MARK: - Fold (code folding)

    @discardableResult
    public func setFoldRegions(_ regions: [FoldRegion]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetFoldRegionsPayload(regions: regions)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_fold_regions(handle, ptr, size, &outSize)
        }
    }

    public func toggleFold(at line: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_toggle_fold(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func foldAt(line: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func unfoldAt(line: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_unfold_at(handle, line, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func foldAll() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_fold_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func unfoldAll() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_unfold_all(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    public func isLineVisible(line: Int) -> Bool {
        return performCoreCall {
            editor_is_line_visible(handle, line) != 0
        }
    }

    /// Sets fold-arrow visibility mode (affects reserved gutter width).
    @discardableResult
    public func setFoldArrowMode(_ mode: FoldArrowMode) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_fold_arrow_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets wrap mode.
    @discardableResult
    public func setWrapMode(_ mode: WrapMode) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_wrap_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets whitespace marker rendering mode.
    @discardableResult
    public func setRenderWhitespace(_ mode: WhitespaceRenderMode) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_render_whitespace(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets line-break marker visibility.
    @discardableResult
    public func setRenderLineBreaks(_ enabled: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_render_line_breaks(handle, enabled ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets editor scale in the C++ core.
    /// Use `syncPlatformScale(_:)` to update platform-side fonts and measurer.
    @discardableResult
    public func setScale(_ scale: Float) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_scale(handle, scale, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setContentStartPadding(_ padding: Float) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_content_start_padding(handle, padding, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setShowSplitLine(_ show: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_show_split_line(handle, show ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setGutterSticky(_ sticky: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_gutter_sticky(handle, sticky ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setGutterVisible(_ visible: Bool) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_gutter_visible(handle, visible ? 1 : 0, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setCurrentLineRenderMode(_ mode: CurrentLineRenderMode) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_current_line_render_mode(handle, mode.rawValue, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Syncs platform-side font/measurer to the latest scale from the core.
    @discardableResult
    package func syncPlatformScale(_ scale: Float) -> EditorActionResult {
        guard scale > 0 else { return EditorActionResult() }
        platformScale = CGFloat(scale)
        rebuildFontsForScale(platformScale)
        return onFontMetricsChanged()
    }

    @discardableResult
    package func updateFont(size: Float, name: String) -> EditorActionResult {
        guard size > 0, !name.isEmpty else { return EditorActionResult() }
        baseFontSize = CGFloat(size)
        baseFontName = name
        baseInlayHintFontSize = CGFloat(size) * 0.85
        rebuildFontsForScale(platformScale)
        return onFontMetricsChanged()
    }

    /// Sets line-spacing parameters (`line_height = font_height * mult + add`).
    /// - Parameters:
    ///   - add: Extra line-spacing pixels (default 0).
    ///   - mult: Line-spacing multiplier (default 1.0).
    @discardableResult
    public func setLineSpacing(add: Float, mult: Float) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_line_spacing(handle, add, mult, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Diff

    @discardableResult
    public func setDiffChanges(_ changes: [DiffChange]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetDiffChangesPayload(changes: changes)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_diff_changes(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func computeDiff(originalText: String) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = originalText.withCString { text in
                editor_compute_diff(handle, text, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    @discardableResult
    public func setBatchDiffLineSpans(layer: SpanLayer,
                                      spansByOriginalLine: [Int: [StyleSpan]]) -> EditorActionResult {
        let payload = CoreProtocol.encodeSetBatchDiffLineSpansPayload(
            layer: layer,
            spansByOriginalLine: int32Keyed(spansByOriginalLine)
        )
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_set_batch_diff_line_spans(handle, ptr, size, &outSize)
        }
    }

    @discardableResult
    public func clearDiff() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_clear_diff(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - LinkedEditing

    /// Inserts a VSCode snippet template and enters linked-editing mode.
    public func insertSnippet(_ template: String) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = template.withCString { cStr in
                editor_insert_snippet(handle, cStr, &size)
            }
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Starts linked-editing mode with externally built tab stop groups.
    @discardableResult
    public func startLinkedEditing(groups: [TabStopGroup]) -> EditorActionResult {
        let payload = CoreProtocol.encodeStartLinkedEditingPayload(groups: groups)
        return performPayloadEditorAction(payload) { ptr, size, outSize in
            editor_start_linked_editing(handle, ptr, size, &outSize)
        }
    }

    /// Whether linked-editing mode is active.
    public func isInLinkedEditing() -> Bool {
        return performCoreCall {
            editor_is_in_linked_editing(handle) != 0
        }
    }

    /// Linked editing: jump to the next tab stop.
    public func linkedEditingNext() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_next(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Linked editing: jump to the previous tab stop.
    public func linkedEditingPrev() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_linked_editing_prev(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Cancels linked-editing mode.
    @discardableResult
    public func cancelLinkedEditing() -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_cancel_linked_editing(handle, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    // MARK: - Bracket Highlight

    /// Sets custom bracket pairs.
    @discardableResult
    public func setBracketPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResult {
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
    public func setAutoClosingPairs(openChars: [Int32], closeChars: [Int32]) -> EditorActionResult {
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
    public func setTabSize(_ tabSize: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_tab_size(handle, Int32(tabSize), &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Sets externally computed exact bracket-match positions (higher priority than built-in scan).
    @discardableResult
    public func setMatchedBrackets(openLine: Int, openColumn: Int, closeLine: Int, closeColumn: Int) -> EditorActionResult {
        return performCoreCall {
            var size: Int = 0
            let ptr = editor_set_matched_brackets(handle, openLine, openColumn, closeLine, closeColumn, &size)
            return decodeEditorActionPayload(ptr, size: size)
        }
    }

    /// Clears externally provided bracket-match results (falls back to built-in scan).
    @discardableResult
    public func clearMatchedBrackets() -> EditorActionResult {
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
