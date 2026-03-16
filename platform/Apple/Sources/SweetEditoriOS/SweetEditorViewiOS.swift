#if os(iOS)
import UIKit
import SwiftUI
import SweetEditorCoreInternal

class IOSEditorView: UIView, UIKeyInput, UITextInputTraits, UIPointerInteractionDelegate, CompletionEditorAccessor {
    var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    var editorIconProvider: EditorIconProvider?

    private var editorCore: SweetEditorCore!
    private var document: SweetDocument?
    private var highlighter: SyntaxHighlighter?
    private var renderModel: EditorRenderModel?
    private var decorationProviderManager: DecorationProviderManager?
    private var completionProviderManager: CompletionProviderManager?
    private var completionPopupController: CompletionPopupController?
    private var newLineActionProviderManager: NewLineActionProviderManager?
    private var pinchRecognizer: UIPinchGestureRecognizer!

    /// Current language configuration.
    private(set) var languageConfiguration: LanguageConfiguration?

    /// Extensible metadata supplied by external callers (cast to concrete type when used).
    var metadata: EditorMetadata?

    // UIKeyInput
    var hasText: Bool { true }
    override var canBecomeFirstResponder: Bool { true }

    // UITextInputTraits
    var autocorrectionType: UITextAutocorrectionType = .no
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var spellCheckingType: UITextSpellCheckingType = .no
    var smartQuotesType: UITextSmartQuotesType = .no
    var smartDashesType: UITextSmartDashesType = .no
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .no

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(cgColor: EditorRenderer.theme.backgroundColor)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        editorCore = SweetEditorCore(fontSize: 14.0, fontName: "Menlo")
        EditorRenderer.applyTheme(EditorRenderer.theme, core: editorCore)
        decorationProviderManager = DecorationProviderManager(
            core: editorCore,
            visibleLineRangeProvider: { [weak self] in
                guard let self, let model = self.renderModel, !model.lines.isEmpty else { return (0, -1) }
                let lines = model.lines
                var start = Int.max
                var end = -1
                for line in lines {
                    start = min(start, line.logical_line)
                    end = max(end, line.logical_line)
                }
                return start == Int.max ? (0, -1) : (start, end)
            },
            totalLineCountProvider: { [weak self] in
                guard let self, let doc = self.document else { return -1 }
                return doc.getLineCount()
            },
            languageConfigurationProvider: { [weak self] in self?.languageConfiguration },
            onApplied: { [weak self] in self?.rebuildAndRedraw() }
        )

        // Completion manager and popup controller.
        completionProviderManager = CompletionProviderManager(editor: self)
        completionPopupController = CompletionPopupController(anchorView: self)
        completionProviderManager?.itemsUpdatedHandler = { [weak self] items in
            self?.completionPopupController?.updateItems(items)
            self?.updateCompletionPopupPosition()
        }
        completionProviderManager?.dismissedHandler = { [weak self] in
            self?.completionPopupController?.dismissPanel()
        }
        completionPopupController?.onConfirmed = { [weak self] item in
            self?.applyCompletionItem(item)
        }

        pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinchRecognizer)

        // iPad trackpad/mouse pointer support
        let hoverRecognizer = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hoverRecognizer)

        let pointerInteraction = UIPointerInteraction(delegate: self)
        addInteraction(pointerInteraction)

        loadDocument(text: "")
        applyTheme(EditorRenderer.theme)

        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: .editorUndo, object: nil, queue: .main) { [weak self] _ in
            let editResult = self?.editorCore.undo()
            self?.decorationProviderManager?.onTextChanged(changes: self?.textChanges(from: editResult) ?? [])
            self?.rehighlightAndRedraw()
        }
        NotificationCenter.default.addObserver(forName: .editorRedo, object: nil, queue: .main) { [weak self] _ in
            let editResult = self?.editorCore.redo()
            self?.decorationProviderManager?.onTextChanged(changes: self?.textChanges(from: editResult) ?? [])
            self?.rehighlightAndRedraw()
        }
        NotificationCenter.default.addObserver(forName: .editorSelectAll, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            _ = self.editorCore.handleKeyEvent(keyCode: .a, modifiers: .meta)
            self.rebuildAndRedraw()
        }
        NotificationCenter.default.addObserver(forName: .editorGetSelection, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let text = self.editorCore.getSelectedText()
            if text.isEmpty {
                print("[SweetEditor] No selection")
            } else {
                print("[SweetEditor] Selection: \(text.prefix(100))")
            }
        }
    }

    func loadDocument(text: String) {
        let doc = SweetDocument(text: text)
        document = doc
        editorCore.setDocument(doc)
        decorationProviderManager?.onDocumentLoaded()
        if highlighter == nil {
            highlighter = SyntaxHighlighter(editorCore: editorCore)
        }
        highlighter?.highlightAll(document: doc)
    }

    func applyDecorations(_ decorations: EditorResolvedDecorations, clearExisting: Bool = true) {
        if clearExisting {
            editorCore.clearAllDecorations()
        }
        if let doc = document {
            highlighter?.highlightAll(document: doc)
        }
        applyResolvedDecorations(decorations)
        rebuildAndRedraw()
    }

    func clearAllDecorations() {
        editorCore.clearAllDecorations()
        rebuildAndRedraw()
    }

    func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) {
        editorCore.registerStyle(styleId: styleId, color: color, fontStyle: fontStyle)
    }

    func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) {
        editorCore.registerStyle(styleId: styleId, color: color, backgroundColor: backgroundColor, fontStyle: fontStyle)
    }

    func setLineSpans(line: Int, layer: SpanLayer, spans: [SweetEditorCore.StyleSpan]) {
        editorCore.setLineSpans(line: line, layer: layer.rawValue, spans: spans)
        rebuildAndRedraw()
    }

    func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [SweetEditorCore.StyleSpan]]) {
        editorCore.setBatchLineSpans(layer: layer.rawValue, spansByLine: spansByLine)
        rebuildAndRedraw()
    }

    func setLineInlayHints(line: Int, hints: [SweetEditorCore.InlayHintPayload]) {
        editorCore.setLineInlayHints(line: line, hints: hints)
        rebuildAndRedraw()
    }

    func setBatchLineInlayHints(_ hintsByLine: [Int: [SweetEditorCore.InlayHintPayload]]) {
        editorCore.setBatchLineInlayHints(hintsByLine)
        rebuildAndRedraw()
    }

    func setLinePhantomTexts(line: Int, phantoms: [SweetEditorCore.PhantomTextPayload]) {
        editorCore.setLinePhantomTexts(line: line, phantoms: phantoms)
        rebuildAndRedraw()
    }

    func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [SweetEditorCore.PhantomTextPayload]]) {
        editorCore.setBatchLinePhantomTexts(phantomsByLine)
        rebuildAndRedraw()
    }

    func setLineGutterIcons(line: Int, icons: [SweetEditorCore.GutterIcon]) {
        editorCore.setLineGutterIcons(line: line, icons: icons)
        rebuildAndRedraw()
    }

    func setBatchLineGutterIcons(_ iconsByLine: [Int: [SweetEditorCore.GutterIcon]]) {
        editorCore.setBatchLineGutterIcons(iconsByLine)
        rebuildAndRedraw()
    }

    func setMaxGutterIcons(_ count: UInt32) {
        editorCore.setMaxGutterIcons(count)
        rebuildAndRedraw()
    }

    func setLineDiagnostics(line: Int, items: [SweetEditorCore.DiagnosticItem]) {
        editorCore.setLineDiagnostics(line: line, items: items)
        rebuildAndRedraw()
    }

    func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [SweetEditorCore.DiagnosticItem]]) {
        editorCore.setBatchLineDiagnostics(diagnosticsByLine)
        rebuildAndRedraw()
    }

    func setIndentGuides(_ guides: [SweetEditorCore.IndentGuidePayload]) {
        editorCore.setIndentGuides(guides)
        rebuildAndRedraw()
    }

    func setBracketGuides(_ guides: [SweetEditorCore.BracketGuidePayload]) {
        editorCore.setBracketGuides(guides)
        rebuildAndRedraw()
    }

    func setFlowGuides(_ guides: [SweetEditorCore.FlowGuidePayload]) {
        editorCore.setFlowGuides(guides)
        rebuildAndRedraw()
    }

    func setSeparatorGuides(_ guides: [SweetEditorCore.SeparatorGuidePayload]) {
        editorCore.setSeparatorGuides(guides)
        rebuildAndRedraw()
    }

    func setFoldRegions(_ regions: [SweetEditorCore.FoldRegion]) {
        editorCore.setFoldRegions(regions)
        rebuildAndRedraw()
    }

    func clearHighlights() {
        editorCore.clearHighlights()
        rebuildAndRedraw()
    }

    func clearHighlights(layer: SpanLayer) {
        editorCore.clearHighlights(layer: layer.rawValue)
        rebuildAndRedraw()
    }

    func clearInlayHints() {
        editorCore.clearInlayHints()
        rebuildAndRedraw()
    }

    func clearPhantomTexts() {
        editorCore.clearPhantomTexts()
        rebuildAndRedraw()
    }

    func clearGutterIcons() {
        editorCore.clearGutterIcons()
        rebuildAndRedraw()
    }

    func clearGuides() {
        editorCore.clearGuides()
        rebuildAndRedraw()
    }

    func clearDiagnostics() {
        editorCore.clearDiagnostics()
        rebuildAndRedraw()
    }

    func documentLines() -> [String] {
        guard let document else { return [] }
        let totalLines = document.getLineCount()
        guard totalLines > 0 else { return [] }
        return (0..<totalLines).map { document.getLineText($0) }
    }

    func addDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.addProvider(provider)
    }

    func removeDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.removeProvider(provider)
    }

    func requestDecorationRefresh() {
        decorationProviderManager?.requestRefresh()
    }

    private func applyResolvedDecorations(_ decorations: EditorResolvedDecorations) {
        if !decorations.foldRegions.isEmpty {
            editorCore.setFoldRegions(
                decorations.foldRegions.map {
                    SweetEditorCore.FoldRegion(startLine: $0.startLine, endLine: $0.endLine, collapsed: $0.collapsed)
                }
            )
        }

        if !decorations.diagnostics.isEmpty {
            var diagnosticsByLine: [Int: [SweetEditorCore.DiagnosticItem]] = [:]
            for lineDiagnostics in decorations.diagnostics {
                let mapped = lineDiagnostics.items.map {
                    SweetEditorCore.DiagnosticItem(
                        column: $0.column,
                        length: $0.length,
                        severity: $0.severity,
                        color: $0.color
                    )
                }
                diagnosticsByLine[lineDiagnostics.line, default: []].append(contentsOf: mapped)
            }
            editorCore.setBatchLineDiagnostics(diagnosticsByLine)
        }

        var inlayHintsByLine: [Int: [SweetEditorCore.InlayHintPayload]] = [:]
        for item in decorations.textInlays {
            inlayHintsByLine[item.line, default: []].append(
                .text(column: item.column, text: item.text)
            )
        }
        for item in decorations.colorInlays {
            inlayHintsByLine[item.line, default: []].append(
                .color(column: item.column, color: item.color)
            )
        }
        if !inlayHintsByLine.isEmpty {
            editorCore.setBatchLineInlayHints(inlayHintsByLine)
        }

        var phantomsByLine: [Int: [SweetEditorCore.PhantomTextPayload]] = [:]
        for item in decorations.phantomTexts {
            phantomsByLine[item.line, default: []].append(
                SweetEditorCore.PhantomTextPayload(column: item.column, text: item.text)
            )
        }
        if !phantomsByLine.isEmpty {
            editorCore.setBatchLinePhantomTexts(phantomsByLine)
        }
    }

    // MARK: - CompletionProvider API

    func addCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.addProvider(provider)
    }

    func removeCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.removeProvider(provider)
    }

    func triggerCompletion() {
        completionProviderManager?.triggerCompletion(.invoked)
    }

    func showCompletionItems(_ items: [CompletionItem]) {
        completionProviderManager?.showItems(items)
    }

    func dismissCompletion() {
        completionProviderManager?.dismiss()
    }

    // MARK: - CompletionEditorAccessor

    func getCursorPosition() -> TextPosition? {
        guard let cursor = editorCore.getCursorPosition() else { return nil }
        return TextPosition(line: cursor.line, column: cursor.column)
    }

    func getDocument() -> SweetDocument? {
        return document
    }

    func getWordRangeAtCursor() -> TextRange {
        let range = editorCore.getWordRangeAtCursor()
        return TextRange(
            start: TextPosition(line: range.startLine, column: range.startColumn),
            end: TextPosition(line: range.endLine, column: range.endColumn)
        )
    }

    func getWordAtCursor() -> String {
        return editorCore.getWordAtCursor()
    }

    // MARK: - LanguageConfiguration

    /// Sets language configuration and syncs bracket pairs to the Core layer.
    func setLanguageConfiguration(_ config: LanguageConfiguration?) {
        self.languageConfiguration = config
        if let config = config {
            let opens = config.brackets.map { Int32(($0.open.unicodeScalars.first?.value ?? 0)) }
            let closes = config.brackets.map { Int32(($0.close.unicodeScalars.first?.value ?? 0)) }
            if !opens.isEmpty {
                editorCore.setBracketPairs(openChars: opens, closeChars: closes)
            }
        }
    }

    // MARK: - EditorMetadata

    func setMetadata<T: EditorMetadata>(_ metadata: T?) {
        self.metadata = metadata
    }

    func getMetadata<T: EditorMetadata>() -> T? {
        return metadata as? T
    }

    func setWrapMode(_ mode: Int) {
        let wrapModes: [SweetEditorCore.WrapMode] = [.none, .charBreak, .wordBreak]
        editorCore.setWrapMode(wrapModes[mode])
        rebuildAndRedraw()
    }

    /// Sets editor scale from external API and syncs platform-side fonts/measurer.
    func setScale(_ scale: Float) {
        editorCore.setScale(scale)
        editorCore.syncPlatformScale(scale)
        rebuildAndRedraw()
    }

    func setAutoIndentMode(_ mode: SweetEditorCore.AutoIndentMode) {
        editorCore.setAutoIndentMode(mode)
    }

    func getAutoIndentMode() -> SweetEditorCore.AutoIndentMode {
        return editorCore.getAutoIndentMode()
    }

    func getPositionRect(line: Int, column: Int) -> SweetEditorCore.CursorRect {
        return editorCore.getPositionRect(line: line, column: column)
    }

    func getCursorRect() -> SweetEditorCore.CursorRect {
        return editorCore.getCursorRect()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        editorCore.setViewport(width: Int(size.width), height: Int(size.height))
        rebuildAndRedraw()
    }

    private func rebuildAndRedraw() {
        renderModel = editorCore.buildRenderModel()
        updateCompletionPopupPosition()
        setNeedsDisplay()
    }

    /// Switches the editor theme.
    func applyTheme(_ theme: EditorTheme) {
        let bgColor = EditorRenderer.applyTheme(theme, core: editorCore)
        backgroundColor = UIColor(cgColor: bgColor)
        rehighlightAndRedraw()
    }

    private func rehighlightAndRedraw() {
        if let doc = document {
            highlighter?.highlightAll(document: doc)
        }
        rebuildAndRedraw()
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let model = renderModel else { return }

        // UIKit has top-left origin; CoreText expects bottom-left.
        // Flip for CoreText text rendering.
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // In the flipped coordinate system, we need to adjust y coordinates
        // Since EditorRenderer draws with top-left origin (y increases downward),
        // and we've flipped, we need to re-flip the text matrix
        context.textMatrix = CGAffineTransform.identity

        EditorRenderer.draw(context: context,
                           model: model,
                           core: editorCore,
                           viewHeight: bounds.height,
                           iconProvider: editorIconProvider)

        context.restoreGState()
    }

    // MARK: - Touch Events

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        becomeFirstResponder()
        let allTouches = event?.allTouches ?? touches

        if allTouches.count == 1 {
            let point = touches.first!.location(in: self)
            let result = editorCore.handleGestureEvent(
                type: .touchDown,
                points: [(Float(point.x), Float(point.y))]
            )
            handleGestureResult(result)
        } else {
            let allPoints = allTouchPoints(event)
            let result = editorCore.handleGestureEvent(
                type: .touchPointerDown,
                points: allPoints
            )
            handleGestureResult(result)
        }
        rebuildAndRedraw()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allPoints = allTouchPoints(event)
        let result = editorCore.handleGestureEvent(
            type: .touchMove,
            points: allPoints
        )
        handleGestureResult(result)
        decorationProviderManager?.onScrollChanged()
        // Dismiss completion popup while scrolling.
        if completionPopupController?.isShowing == true {
            completionProviderManager?.dismiss()
        }
        rebuildAndRedraw()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let allTouches = event?.allTouches ?? touches
        let remaining = allTouches.subtracting(touches)

        if remaining.isEmpty {
            let point = touches.first!.location(in: self)
            let result = editorCore.handleGestureEvent(
                type: .touchUp,
                points: [(Float(point.x), Float(point.y))]
            )
            handleGestureResult(result)
            // Dismiss completion popup on tap.
            if completionPopupController?.isShowing == true {
                completionProviderManager?.dismiss()
            }
        } else {
            let allPoints = allTouchPoints(event)
            let result = editorCore.handleGestureEvent(
                type: .touchPointerUp,
                points: allPoints
            )
            handleGestureResult(result)
        }
        rebuildAndRedraw()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first?.location(in: self) ?? .zero
        let result = editorCore.handleGestureEvent(
            type: .touchCancel,
            points: [(Float(point.x), Float(point.y))]
        )
        handleGestureResult(result)
        rebuildAndRedraw()
    }

    private func handleGestureResult(_ result: GestureResultData?) {
        guard let result else { return }

        if result.type == .SCALE {
            // Core gesture handling already updated C++ scale, only sync platform-side fonts/measurer.
            editorCore.syncPlatformScale(result.view_scale)
            return
        }

        guard result.type == .TAP else { return }

        switch result.hit_target.type {
        case .INLAY_HINT_TEXT:
            onInlayHintClick?(
                SweetEditorInlayHintClickEvent(
                    line: result.hit_target.line,
                    column: result.hit_target.column,
                    kind: .text,
                    iconId: 0,
                    colorValue: 0,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .INLAY_HINT_ICON:
            onInlayHintClick?(
                SweetEditorInlayHintClickEvent(
                    line: result.hit_target.line,
                    column: result.hit_target.column,
                    kind: .icon,
                    iconId: result.hit_target.icon_id,
                    colorValue: 0,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .INLAY_HINT_COLOR:
            onInlayHintClick?(
                SweetEditorInlayHintClickEvent(
                    line: result.hit_target.line,
                    column: result.hit_target.column,
                    kind: .color,
                    iconId: 0,
                    colorValue: result.hit_target.color_value,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .GUTTER_ICON:
            onGutterIconClick?(
                SweetEditorGutterIconClickEvent(
                    line: result.hit_target.line,
                    iconId: result.hit_target.icon_id,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .FOLD_PLACEHOLDER, .FOLD_GUTTER:
            onFoldToggle?(
                SweetEditorFoldToggleEvent(
                    line: result.hit_target.line,
                    isGutter: result.hit_target.type == .FOLD_GUTTER,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        default:
            break
        }
    }

    private func updateCompletionPopupPosition() {
        guard completionPopupController?.isShowing == true else { return }
        let rect = editorCore.getCursorRect()
        completionPopupController?.updatePosition(cursorX: rect.x, cursorY: rect.y, cursorHeight: rect.height)
    }

    private func allTouchPoints(_ event: UIEvent?) -> [(Float, Float)] {
        guard let allTouches = event?.allTouches else { return [] }
        return allTouches.map { touch in
            let point = touch.location(in: self)
            return (Float(point.x), Float(point.y))
        }
    }

    // MARK: - Pinch Gesture (Zoom)

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        let center = recognizer.location(in: self)
        let result = editorCore.handleGestureEvent(
            type: .directScale,
            points: [(Float(center.x), Float(center.y))],
            directScale: Float(recognizer.scale)
        )
        handleGestureResult(result)
        recognizer.scale = 1.0
        rebuildAndRedraw()
    }

    // MARK: - iPad Pointer / Trackpad Support

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        let point = recognizer.location(in: self)
        let floatPoint = [(Float(point.x), Float(point.y))]

        switch recognizer.state {
        case .began, .changed:
            _ = editorCore.handleGestureEvent(
                type: .mouseMove,
                points: floatPoint
            )
            rebuildAndRedraw()
        default:
            break
        }
    }

    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let beamLength = CGFloat(renderModel?.cursor.height ?? 20)
        return UIPointerStyle(shape: .verticalBeam(length: beamLength))
    }

    // MARK: - UIKeyInput

    func insertText(_ text: String) {
        // Let NewLineActionProvider handle newline first (provider decides indentation).
        // If no provider handles it, fall back to Core default behavior.
        if text == "\n" || text == "\r",
           let manager = newLineActionProviderManager {
            let pos = editorCore.getCursorPosition() ?? (line: 0, column: 0)
            let lineText = document?.getLineText(pos.line) ?? ""
            let context = NewLineContext(
                lineNumber: pos.line,
                column: pos.column,
                lineText: lineText,
                languageConfiguration: languageConfiguration
            )
            if let action = manager.provideNewLineAction(context: context) {
                let editResult = editorCore.insertText(action.text)
                decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
                rehighlightAndRedraw()
                return
            }
        }
        let editResult = editorCore.insertText(text)
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        // Suppress completion triggers during linked editing to avoid Enter/Tab conflicts.
        if !editorCore.isInLinkedEditing(), text.count == 1, let manager = completionProviderManager {
            let ch = text.unicodeScalars.first!
            if manager.isTriggerCharacter(text) {
                manager.triggerCompletion(.character, triggerCharacter: text)
            } else if completionPopupController?.isShowing == true {
                manager.triggerCompletion(.retrigger)
            } else if (ch.properties.isAlphabetic || CharacterSet.decimalDigits.contains(ch) || text == "_")
                        && getWordAtCursor().count >= 2 {
                manager.triggerCompletion(.invoked)
            }
        }
        rehighlightAndRedraw()
    }

    /// Replaces text in a target range atomically, then refreshes decorations and redraws.
    func replaceText(startLine: Int, startColumn: Int,
                     endLine: Int, endColumn: Int,
                     newText: String) {
        let editResult = editorCore.replaceText(
            startLine: startLine, startColumn: startColumn,
            endLine: endLine, endColumn: endColumn,
            newText: newText)
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Deletes text in a target range atomically, then refreshes decorations and redraws.
    func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) {
        let editResult = editorCore.deleteText(
            startLine: startLine, startColumn: startColumn,
            endLine: endLine, endColumn: endColumn)
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    // MARK: - Line operations

    /// Moves the current line (or selected lines) up by one line.
    func moveLineUp() {
        let editResult = editorCore.moveLineUp()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Moves the current line (or selected lines) down by one line.
    func moveLineDown() {
        let editResult = editorCore.moveLineDown()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Copies the current line (or selected lines) upward.
    func copyLineUp() {
        let editResult = editorCore.copyLineUp()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Copies the current line (or selected lines) downward.
    func copyLineDown() {
        let editResult = editorCore.copyLineDown()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Deletes the current line (or all selected lines).
    func deleteLine() {
        let editResult = editorCore.deleteLine()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Inserts an empty line above the current line.
    func insertLineAbove() {
        let editResult = editorCore.insertLineAbove()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    /// Inserts an empty line below the current line.
    func insertLineBelow() {
        let editResult = editorCore.insertLineBelow()
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        rehighlightAndRedraw()
    }

    func deleteBackward() {
        let keyResult = editorCore.handleKeyEvent(keyCode: .backspace)
        decorationProviderManager?.onTextChanged(changes: textChanges(from: keyResult))
        rehighlightAndRedraw()
    }

    // MARK: - Physical Keyboard Support (iPad)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        var contentChanged = false
        var changedTextChanges: [TextChange] = []

        for press in presses {
            guard let key = press.key else { continue }

            // Completion popup keyboard interception (Enter/Escape/Up/Down).
            if let popup = completionPopupController, popup.isShowing {
                let seKey = mapUIKeyToSEKeyCode(key)
                if popup.handleSEKeyCode(seKey) {
                    handled = true
                    continue
                }
            }

            // Manually trigger completion via Cmd+Space.
            if key.modifierFlags.contains(.command) && key.keyCode == .keyboardSpacebar {
                triggerCompletion()
                handled = true
                continue
            }

            // Handle Cmd+key shortcuts directly
            if key.modifierFlags.contains(.command) {
                switch key.keyCode {
                case .keyboardA:
                    let result = editorCore.handleKeyEvent(keyCode: .a, modifiers: modifiersFromUIKey(key))
                    if result?.handled == true { handled = true }
                case .keyboardC:
                    let result = editorCore.handleKeyEvent(keyCode: .c, modifiers: modifiersFromUIKey(key))
                    if result?.handled == true {
                        let text = editorCore.getSelectedText()
                        if !text.isEmpty {
                            UIPasteboard.general.string = text
                        }
                        handled = true
                    }
                case .keyboardV:
                    if let text = UIPasteboard.general.string {
                        let editResult = editorCore.insertText(text)
                        changedTextChanges.append(contentsOf: textChanges(from: editResult))
                        contentChanged = true
                    }
                case .keyboardX:
                    let result = editorCore.handleKeyEvent(keyCode: .x, modifiers: modifiersFromUIKey(key))
                    if result?.handled == true {
                        let text = editorCore.getSelectedText()
                        if !text.isEmpty {
                            UIPasteboard.general.string = text
                        }
                        changedTextChanges.append(contentsOf: textChanges(from: result))
                        contentChanged = true
                    }
                case .keyboardZ:
                    let editResult: TextEditResultLite?
                    if key.modifierFlags.contains(.shift) {
                        editResult = editorCore.redo()
                    } else {
                        editResult = editorCore.undo()
                    }
                    changedTextChanges.append(contentsOf: textChanges(from: editResult))
                    contentChanged = true
                default:
                    break
                }
                continue
            }

            // Non-shortcut keys
            let keyCode = mapUIKeyToSEKeyCode(key)
            if keyCode != .none {
                let mods = modifiersFromUIKey(key)
                let result = editorCore.handleKeyEvent(keyCode: keyCode, modifiers: mods)
                if result?.handled == true {
                    handled = true
                    if result?.content_changed == true {
                        changedTextChanges.append(contentsOf: textChanges(from: result))
                        contentChanged = true
                    }
                }
            }
        }

        if contentChanged {
            decorationProviderManager?.onTextChanged(changes: changedTextChanges)
            rehighlightAndRedraw()
        } else if handled {
            rebuildAndRedraw()
        } else {
            super.pressesBegan(presses, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
    }

    // MARK: - Helpers

    private func mapUIKeyToSEKeyCode(_ key: UIKey) -> SEKeyCode {
        switch key.keyCode {
        case .keyboardDeleteOrBackspace: return .backspace
        case .keyboardTab: return .tab
        case .keyboardReturnOrEnter: return .enter
        case .keyboardEscape: return .escape
        case .keyboardDeleteForward: return .deleteKey
        case .keyboardLeftArrow: return .left
        case .keyboardUpArrow: return .up
        case .keyboardRightArrow: return .right
        case .keyboardDownArrow: return .down
        case .keyboardHome: return .home
        case .keyboardEnd: return .end
        case .keyboardPageUp: return .pageUp
        case .keyboardPageDown: return .pageDown
        default: return .none
        }
    }

    private func modifiersFromUIKey(_ key: UIKey) -> SEModifier {
        var mods = SEModifier()
        if key.modifierFlags.contains(.shift) { mods.insert(.shift) }
        if key.modifierFlags.contains(.control) { mods.insert(.ctrl) }
        if key.modifierFlags.contains(.alternate) { mods.insert(.alt) }
        if key.modifierFlags.contains(.command) { mods.insert(.meta) }
        return mods
    }

    private func textChanges(from editResult: TextEditResultLite?) -> [TextChange] {
        guard let editResult else { return [] }
        return textChanges(from: editResult.changes)
    }

    private func textChanges(from keyResult: KeyEventResultData?) -> [TextChange] {
        guard let keyResult, keyResult.content_changed else { return [] }
        return textChanges(from: keyResult.edit_result.changes)
    }

    private func textChanges(from rawChanges: [TextChangeData]) -> [TextChange] {
        rawChanges.map { change in
            TextChange(
                range: TextRange(
                    start: TextPosition(line: change.range.start.line, column: change.range.start.column),
                    end: TextPosition(line: change.range.end.line, column: change.range.end.column)
                ),
                newText: change.new_text
            )
        }
    }

    /// Completion confirm callback: prefer `textEdit` replacement, otherwise fall back to `wordRange`.
    private func applyCompletionItem(_ item: CompletionItem) {
        let isSnippet = item.insertTextFormat == CompletionItem.insertTextFormatSnippet
        var text = item.insertText ?? item.label

        // Resolve replacement range: prefer textEdit, otherwise fall back to wordRange.
        var replaceRange: (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)? = nil
        if let textEdit = item.textEdit {
            replaceRange = (
                textEdit.range.start.line,
                textEdit.range.start.column,
                textEdit.range.end.line,
                textEdit.range.end.column
            )
            text = textEdit.newText
        } else {
            let wr = getWordRangeAtCursor()
            if wr.start.line != wr.end.line || wr.start.column != wr.end.column {
                replaceRange = (wr.start.line, wr.start.column, wr.end.line, wr.end.column)
            }
        }

        // Delete replacement range (typed prefix) first, then insert new text.
        if let range = replaceRange {
            deleteText(startLine: range.startLine, startColumn: range.startColumn,
                       endLine: range.endLine, endColumn: range.endColumn)
        }
        if isSnippet {
            let editResult = editorCore.insertSnippet(text)
            decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
            rehighlightAndRedraw()
        } else {
            insertText(text)
        }
    }
}

// MARK: - SwiftUI Wrapper

struct IOSEditorViewRepresentable: UIViewRepresentable {
    @Binding var isDarkTheme: Bool
    @Binding var wrapModePreset: Int

    func makeUIView(context: Context) -> IOSEditorView {
        return IOSEditorView()
    }

    func updateUIView(_ uiView: IOSEditorView, context: Context) {
        uiView.applyTheme(isDarkTheme ? .dark() : .light())
        uiView.setWrapMode(wrapModePreset)
    }
}

extension Notification.Name {
    static let editorUndo = Notification.Name("editorUndo")
    static let editorRedo = Notification.Name("editorRedo")
    static let editorSelectAll = Notification.Name("editorSelectAll")
    static let editorGetSelection = Notification.Name("editorGetSelection")
}

#endif
