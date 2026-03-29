#if os(iOS)
import UIKit
import SwiftUI
import SweetEditorCoreInternal

class IOSEditorView: UIView, UIKeyInput, UITextInput, UITextInputTraits, UIPointerInteractionDelegate, CompletionEditorAccessor, EditorSettingsHost {
    static let usesFullContextFlipForRendering = false
    static let textMatrixForTopOriginDrawing = CGAffineTransform(scaleX: 1.0, y: -1.0)

    var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    var onDocumentTextChanged: ((String) -> Void)?
    var editorIconProvider: EditorIconProvider?
    let settings = EditorSettings(host: nil)

    private var editorCore: SweetEditorCore!
    private var document: SweetDocument?
    private var highlighter: SyntaxHighlighter?
    private var renderModel: EditorRenderModel?
    private var decorationProviderManager: DecorationProviderManager?
    private var completionProviderManager: CompletionProviderManager?
    private var completionPopupController: CompletionPopupController?
    private var newLineActionProviderManager: NewLineActionProviderManager?
    private var pinchRecognizer: UIPinchGestureRecognizer!
    private var transientScrollbarRefreshTimer: Timer?
    private var scrollbarPolicy = IOSScrollbarPolicy()
    private lazy var textInputConnection = SweetEditorInputConnectioniOS(owner: self)

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

    // UITextInput
    var selectedTextRange: UITextRange? {
        get { textInputConnection.selectedTextRange }
        set { textInputConnection.selectedTextRange = newValue }
    }

    var markedTextRange: UITextRange? { textInputConnection.markedTextRange }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition { textInputConnection.beginningOfDocument() }
    var endOfDocument: UITextPosition { textInputConnection.endOfDocument() }
    var tokenizer: UITextInputTokenizer { textInputConnection.tokenizer }
    weak var inputDelegate: UITextInputDelegate? {
        get { textInputConnection.inputDelegate }
        set { textInputConnection.inputDelegate = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        settings.attachHost(self)
        backgroundColor = UIColor(cgColor: EditorRenderer.theme.backgroundColor)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        editorCore = SweetEditorCore(fontSize: 14.0, fontName: "Menlo")
        editorCore.setScrollbarConfig(scrollbarPolicy.defaultConfig())
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

        if #available(iOS 13.4, *) {
            configurePointerSupportIfAvailable()
        }

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
        selectedTextRange = uiTextRange(from: NSRange(location: 0, length: 0))
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
        settings.setMaxGutterIcons(count)
    }

    func setFoldArrowMode(_ mode: FoldArrowMode) {
        settings.setFoldArrowMode(mode)
    }

    func setLineSpacing(add: Float, mult: Float) {
        settings.setLineSpacing(add: add, mult: mult)
    }

    func setContentStartPadding(_ padding: Float) {
        settings.setContentStartPadding(padding)
    }

    func setShowSplitLine(_ show: Bool) {
        settings.setShowSplitLine(show)
    }

    func setCurrentLineRenderMode(_ mode: CurrentLineRenderMode) {
        settings.setCurrentLineRenderMode(mode)
    }

    func setReadOnly(_ readOnly: Bool) {
        settings.setReadOnly(readOnly)
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

    func attachDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.addProvider(provider)
    }

    func detachDecorationProvider(_ provider: DecorationProvider) {
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

    func attachCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.addProvider(provider)
    }

    func detachCompletionProvider(_ provider: CompletionProvider) {
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

    func isCoreComposing() -> Bool {
        editorCore.isComposing()
    }

    func cancelCoreCompositionForTesting() {
        editorCore.compositionCancel()
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

    public func setMetadata<T: EditorMetadata>(_ metadata: T?) {
        self.metadata = metadata
    }

    public func getMetadata<T: EditorMetadata>() -> T? {
        return metadata as? T
    }

    func setWrapMode(_ mode: Int) {
        let wrapModes: [WrapMode] = [.none, .charBreak, .wordBreak]
        guard wrapModes.indices.contains(mode) else { return }
        settings.setWrapMode(wrapModes[mode])
    }

    /// Sets editor scale from external API and syncs platform-side fonts/measurer.
    func setScale(_ scale: Float) {
        settings.setScale(scale)
    }

    func setAutoIndentMode(_ mode: SweetEditorCore.AutoIndentMode) {
        switch mode {
        case .none:
            settings.setAutoIndentMode(.none)
        case .keepIndent:
            settings.setAutoIndentMode(.keepIndent)
        }
    }

    func getAutoIndentMode() -> SweetEditorCore.AutoIndentMode {
        SweetEditorCore.AutoIndentMode(settings.autoIndentMode)
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

    deinit {
        transientScrollbarRefreshTimer?.invalidate()
    }

    /// Switches the editor theme.
    func applyTheme(_ theme: EditorTheme) {
        let bgColor = EditorRenderer.applyTheme(theme, core: editorCore)
        backgroundColor = UIColor(cgColor: bgColor)
        rebuildAndRedraw()
    }

    func applyEditorSettings(_ settings: EditorSettings) {
        editorCore.setScale(settings.scale)
        editorCore.syncPlatformScale(settings.scale)
        editorCore.setFoldArrowMode(SweetEditorCore.FoldArrowMode(settings.foldArrowMode))
        editorCore.setWrapMode(SweetEditorCore.WrapMode(settings.wrapMode))
        editorCore.setLineSpacing(add: settings.lineSpacingAdd, mult: settings.lineSpacingMult)
        editorCore.setContentStartPadding(settings.contentStartPadding)
        editorCore.setShowSplitLine(settings.showSplitLine)
        editorCore.setCurrentLineRenderMode(settings.currentLineRenderMode.rawValue)
        editorCore.setAutoIndentMode(SweetEditorCore.AutoIndentMode(settings.autoIndentMode))
        editorCore.setReadOnly(settings.readOnly)
        editorCore.setMaxGutterIcons(settings.maxGutterIcons)
        rebuildAndRedraw()
    }

    func rehighlightAndRedraw() {
        if let doc = document {
            highlighter?.highlightAll(document: doc)
        }
        rebuildAndRedraw()
    }

    func notifyDocumentTextChanged() {
        onDocumentTextChanged?(documentLines().joined(separator: "\n"))
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let model = renderModel else { return }

        context.saveGState()
        context.textMatrix = Self.textMatrixForTopOriginDrawing

        let needsTransientRefresh = EditorRenderer.draw(context: context,
                                                        model: model,
                                                        core: editorCore,
                                                        viewHeight: bounds.height,
                                                        iconProvider: editorIconProvider)

        context.restoreGState()
        updateTransientScrollbarRefresh(needsRefresh: needsTransientRefresh)
    }

    private func updateTransientScrollbarRefresh(needsRefresh: Bool) {
        guard editorCore.scrollbarConfig.mode == .TRANSIENT else {
            transientScrollbarRefreshTimer?.invalidate()
            transientScrollbarRefreshTimer = nil
            return
        }
        guard needsRefresh else {
            transientScrollbarRefreshTimer?.invalidate()
            transientScrollbarRefreshTimer = nil
            return
        }
        ScrollbarRefreshScheduler.scheduleTransientRefreshTimer(&transientScrollbarRefreshTimer) { [weak self] in
            self?.rebuildAndRedraw()
        }
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

    @available(iOS 13.4, *)
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

    @available(iOS 13.4, *)
    private func configurePointerSupportIfAvailable() {
        let hoverRecognizer = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hoverRecognizer)

        let pointerInteraction = UIPointerInteraction(delegate: self)
        addInteraction(pointerInteraction)
    }

    @available(iOS 13.4, *)
    func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        let beamLength = CGFloat(renderModel?.cursor.height ?? 20)
        return UIPointerStyle(shape: .verticalBeam(length: beamLength))
    }

    // MARK: - UIKeyInput

    func insertText(_ text: String) {
        if textInputConnection.commitInsertTextIfNeeded(text) {
            return
        }

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
                notifyDocumentTextChanged()
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
        notifyDocumentTextChanged()
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
        notifyDocumentTextChanged()
        rehighlightAndRedraw()
    }

    /// Deletes text in a target range atomically, then refreshes decorations and redraws.
    func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) {
        let editResult = editorCore.deleteText(
            startLine: startLine, startColumn: startColumn,
            endLine: endLine, endColumn: endColumn)
        decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        notifyDocumentTextChanged()
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
        notifyDocumentTextChanged()
        rehighlightAndRedraw()
    }

    func text(in range: UITextRange) -> String? {
        textInputConnection.text(in: range)
    }

    func replace(_ range: UITextRange, withText text: String) {
        textInputConnection.replace(range, withText: text)
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        textInputConnection.setMarkedText(markedText, selectedRange: selectedRange)
    }

    func unmarkText() {
        textInputConnection.unmarkText()
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        textInputConnection.textRange(from: fromPosition, to: toPosition)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        textInputConnection.position(from: position, offset: offset)
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        textInputConnection.offset(from: from, to: toPosition)
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        textInputConnection.caretRect(for: position)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        textInputConnection.firstRect(for: range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        SweetEditorTextPosition(offset: closestTextOffset(to: point))
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let closest = closestPosition(to: point) as? SweetEditorTextPosition,
              let nsRange = nsRange(from: range) else { return range.start }
        let clampedOffset = min(max(closest.offset, nsRange.location), nsRange.location + nsRange.length)
        return SweetEditorTextPosition(offset: clampedOffset)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let lhs = position as? SweetEditorTextPosition,
              let rhs = other as? SweetEditorTextPosition else { return .orderedSame }
        if lhs.offset < rhs.offset { return .orderedAscending }
        if lhs.offset > rhs.offset { return .orderedDescending }
        return .orderedSame
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        switch direction {
        case .left, .up:
            return range.start
        case .right, .down:
            return range.end
        @unknown default:
            return range.end
        }
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let position = position as? SweetEditorTextPosition else { return nil }

        let startOffset: Int
        let endOffset: Int
        switch direction {
        case .left, .up:
            startOffset = max(position.offset - 1, 0)
            endOffset = position.offset
        case .right, .down:
            startOffset = position.offset
            endOffset = min(position.offset + 1, documentLength())
        @unknown default:
            startOffset = position.offset
            endOffset = position.offset
        }

        let start = SweetEditorTextPosition(offset: startOffset)
        let end = SweetEditorTextPosition(offset: endOffset)
        return textRange(from: start, to: end)
    }

    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .leftToRight
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let position = closestPosition(to: point) else { return selectedTextRange }
        return textRange(from: position, to: position)
    }

    var insertDictationResultPlaceholder: Any { UUID().uuidString }

    func removeDictationResultPlaceholder(_ placeholder: Any, willInsertResult: Bool) {}

    func insertDictationResult(_ dictationResult: [UIDictationPhrase]) {}

    // MARK: - Physical Keyboard Support (iPad)

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard #available(iOS 13.4, *) else {
            super.pressesBegan(presses, with: event)
            return
        }

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
            notifyDocumentTextChanged()
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

    @available(iOS 13.4, *)
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

    @available(iOS 13.4, *)
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

    func documentLength() -> Int {
        guard let doc = document else { return 0 }
        return documentUTF16Length(doc)
    }

    func uiTextRange(from nsRange: NSRange) -> UITextRange? {
        guard nsRange.location != NSNotFound else { return nil }
        let start = SweetEditorTextPosition(offset: nsRange.location)
        let end = SweetEditorTextPosition(offset: nsRange.location + nsRange.length)
        return SweetEditorTextRange(start: start, end: end)
    }

    func nsRange(from textRange: UITextRange?) -> NSRange? {
        guard let textRange,
              let start = textRange.start as? SweetEditorTextPosition,
              let end = textRange.end as? SweetEditorTextPosition else { return nil }
        let lower = min(start.offset, end.offset)
        let upper = max(start.offset, end.offset)
        return NSRange(location: lower, length: upper - lower)
    }

    func substring(for range: NSRange) -> String? {
        guard range.location != NSNotFound else { return nil }
        guard let doc = document else { return nil }
        let totalLength = documentUTF16Length(doc)
        let startLocation = min(max(range.location, 0), totalLength)
        let requestedEnd = range.location + range.length
        let endLocation = min(max(requestedEnd, startLocation), totalLength)
        return textBetweenOffsets(doc: doc, start: startLocation, end: endLocation)
    }

    func locationForOffset(_ offset: Int) -> (line: Int, column: Int)? {
        guard let doc = document else { return (0, 0) }
        return locationForOffset(offset, in: doc)
    }

    func offsetForLocation(line: Int, column: Int) -> Int {
        guard let doc = document else { return 0 }
        let totalLines = doc.getLineCount()
        guard totalLines > 0 else { return 0 }

        let clampedLine = min(max(line, 0), totalLines - 1)
        var offset = 0
        if clampedLine > 0 {
            for currentLine in 0..<clampedLine {
                offset += doc.getLineText(currentLine).utf16.count
                offset += 1
            }
        }
        let currentLineText = doc.getLineText(clampedLine)
        let clampedColumn = min(max(column, 0), currentLineText.utf16.count)
        return offset + clampedColumn
    }

    func currentSelectionNSRange() -> NSRange {
        if let selection = editorCore.getSelectionRange() {
            let startOffset = offsetForLocation(line: selection.startLine, column: selection.startColumn)
            let endOffset = offsetForLocation(line: selection.endLine, column: selection.endColumn)
            let lower = min(startOffset, endOffset)
            let upper = Swift.max(startOffset, endOffset)
            return NSRange(location: lower, length: upper - lower)
        }

        if let cursor = editorCore.getCursorPosition() {
            let offset = offsetForLocation(line: cursor.line, column: cursor.column)
            return NSRange(location: offset, length: 0)
        }

        return NSRange(location: 0, length: 0)
    }

    func closestTextOffset(to point: CGPoint) -> Int {
        guard let document else { return 0 }
        let lineCount = document.getLineCount()
        guard lineCount > 0 else { return 0 }

        var bestLine = 0
        var bestLineDistance = CGFloat.greatestFiniteMagnitude

        for line in 0..<lineCount {
            let startRect = getPositionRect(line: line, column: 0)
            let endRect = getPositionRect(line: line, column: document.getLineText(line).utf16.count)
            let minY = min(startRect.y, endRect.y)
            let maxY = max(startRect.y + startRect.height, endRect.y + endRect.height)
            let distance: CGFloat
            if point.y < minY {
                distance = minY - point.y
            } else if point.y > maxY {
                distance = point.y - maxY
            } else {
                distance = 0
            }

            if distance < bestLineDistance {
                bestLineDistance = distance
                bestLine = line
            }
        }

        let lineLength = document.getLineText(bestLine).utf16.count
        var bestColumn = 0
        var bestColumnDistance = CGFloat.greatestFiniteMagnitude

        for column in 0...lineLength {
            let rect = getPositionRect(line: bestLine, column: column)
            let distance = abs(rect.x - point.x)
            if distance < bestColumnDistance {
                bestColumnDistance = distance
                bestColumn = column
            }
        }

        return offsetForLocation(line: bestLine, column: bestColumn)
    }

    func textBeforeCursor(_ count: Int) -> String {
        let selection = currentSelectionNSRange()
        let end = selection.location
        let start = max(0, end - max(count, 0))
        return substring(for: NSRange(location: start, length: end - start)) ?? ""
    }

    func textAfterCursor(_ count: Int) -> String {
        let selection = currentSelectionNSRange()
        let start = selection.location + selection.length
        let clampedCount = max(count, 0)
        let end = min(documentLength(), start + clampedCount)
        return substring(for: NSRange(location: start, length: end - start)) ?? ""
    }

    func selectedText() -> String {
        let selection = currentSelectionNSRange()
        guard selection.length > 0 else { return "" }
        return substring(for: selection) ?? ""
    }

    func deleteSurroundingText(before: Int, after: Int) {
        let selection = currentSelectionNSRange()
        let beforeCount = max(before, 0)
        let afterCount = max(after, 0)

        let start = max(0, selection.location - beforeCount)
        let end = min(documentLength(), selection.location + selection.length + afterCount)
        let deleteRange = NSRange(location: start, length: max(0, end - start))

        replaceText(in: deleteRange, with: "")
    }

    func setSelection(from nsRange: NSRange) {
        let lower = nsRange.location
        let upper = nsRange.location + nsRange.length
        guard let start = locationForOffset(lower),
              let end = locationForOffset(upper) else { return }

        if nsRange.length == 0 {
            editorCore.gotoPosition(line: start.line, column: start.column)
        } else {
            editorCore.setSelectionRange(startLine: start.line,
                                         startColumn: start.column,
                                         endLine: end.line,
                                         endColumn: end.column)
        }
    }

    func replaceText(in range: NSRange, with text: String) {
        guard let replacementRange = textRange(for: range) else {
            insertText(text)
            return
        }
        replaceText(startLine: replacementRange.startLine,
                    startColumn: replacementRange.startColumn,
                    endLine: replacementRange.endLine,
                    endColumn: replacementRange.endColumn,
                    newText: text)
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        let signedOffset: Int
        switch direction {
        case .left, .up:
            signedOffset = -offset
        case .right, .down:
            signedOffset = offset
        @unknown default:
            signedOffset = offset
        }
        return self.position(from: position, offset: signedOffset)
    }

    func textStyling(at position: UITextPosition, in direction: UITextStorageDirection) -> [NSAttributedString.Key: Any]? {
        nil
    }

    var selectionAffinity: UITextStorageDirection {
        get { .forward }
        set {}
    }

    private func documentUTF16Length(_ doc: SweetDocument) -> Int {
        let totalLines = doc.getLineCount()
        guard totalLines > 0 else { return 0 }
        var length = 0
        for index in 0..<totalLines {
            let text = doc.getLineText(index)
            length += text.utf16.count
            if index < totalLines - 1 {
                length += 1
            }
        }
        return length
    }

    private func normalizedReplacementRange(_ range: NSRange) -> NSRange? {
        guard range.location != NSNotFound else { return nil }
        guard let doc = document else { return nil }
        let totalLength = documentUTF16Length(doc)
        let startLocation = min(max(range.location, 0), totalLength)
        let endLocation = min(max(range.location + range.length, startLocation), totalLength)
        return NSRange(location: startLocation, length: endLocation - startLocation)
    }

    private func textRange(for nsRange: NSRange) -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)? {
        guard let normalizedRange = normalizedReplacementRange(nsRange),
              let doc = document,
              let start = locationForOffset(normalizedRange.location, in: doc),
              let end = locationForOffset(normalizedRange.location + normalizedRange.length, in: doc) else {
            return nil
        }
        return (start.line, start.column, end.line, end.column)
    }

    private func locationForOffset(_ offset: Int, in doc: SweetDocument) -> (line: Int, column: Int)? {
        let totalLines = doc.getLineCount()
        guard totalLines > 0 else { return (0, 0) }

        let clampedOffset = min(max(offset, 0), documentUTF16Length(doc))
        var currentOffset = 0

        for line in 0..<totalLines {
            let text = doc.getLineText(line)
            let lineLength = text.utf16.count
            let lineEndOffset = currentOffset + lineLength

            if clampedOffset <= lineEndOffset {
                return (line, clampedOffset - currentOffset)
            }

            currentOffset = lineEndOffset
            if line < totalLines - 1 {
                currentOffset += 1
            }
        }

        let lastLine = max(totalLines - 1, 0)
        return (lastLine, doc.getLineText(lastLine).utf16.count)
    }

    private func textBetweenOffsets(doc: SweetDocument, start: Int, end: Int) -> String {
        guard end > start else { return "" }
        let totalLines = doc.getLineCount()
        if totalLines == 0 {
            return ""
        }
        var builder = String()
        var currentOffset = 0
        for line in 0..<totalLines {
            let text = doc.getLineText(line)
            let lineLength = text.utf16.count
            let lineStart = currentOffset
            let lineEnd = lineStart + lineLength
            if end <= lineStart {
                break
            }
            if start < lineEnd && end > lineStart {
                let localStart = max(start, lineStart) - lineStart
                let localEnd = min(end, lineEnd) - lineStart
                if localStart < localEnd {
                    let startIdx = String.Index(utf16Offset: localStart, in: text)
                    let endIdx = String.Index(utf16Offset: localEnd, in: text)
                    builder.append(String(text[startIdx..<endIdx]))
                }
            }
            currentOffset = lineEnd
            if line < totalLines - 1 {
                let newlineStart = currentOffset
                let newlineEnd = newlineStart + 1
                if start < newlineEnd && end > newlineStart {
                    builder.append("\n")
                }
                currentOffset = newlineEnd
            }
            if currentOffset >= end {
                break
            }
        }
        return builder
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
