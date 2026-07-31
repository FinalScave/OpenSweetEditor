#if os(macOS)
import AppKit
import QuartzCore
@_exported import SweetEditorShared

public class SweetEditorView: NSView, NSTextInputClient, CompletionEditorAccessor {
    public private(set) lazy var settings = EditorSettings(
        editorTextSize: 28.0 / Float(NSScreen.main?.backingScaleFactor ?? 1.0),
        gutterSticky: true,
        onChange: { [weak self] change in self?.applyEditorSetting(change) }
    )
    public var onFoldToggle: ((FoldToggleEvent) -> Void)?
    public var onInlayHintClick: ((InlayHintClickEvent) -> Void)?
    public var onGutterIconClick: ((GutterIconClickEvent) -> Void)?
    public var onCodeLensClick: ((CodeLensClickEvent) -> Void)?
    public var onLinkClick: ((LinkClickEvent) -> Void)?
    public var onTextChanged: ((TextChangedEvent) -> Void)?
    public var onCursorChanged: ((CursorChangedEvent) -> Void)?
    public var onSelectionChanged: ((SelectionChangedEvent) -> Void)?
    public var onScrollChanged: ((ScrollChangedEvent) -> Void)?
    public var onScaleChanged: ((ScaleChangedEvent) -> Void)?
    public var onDocumentLoaded: ((DocumentLoadedEvent) -> Void)?
    public var onLongPress: ((LongPressEvent) -> Void)?
    public var onDoubleTap: ((DoubleTapEvent) -> Void)?
    public var onContextMenu: ((ContextMenuEvent) -> Void)?
    public private(set) var theme = EditorTheme.xcodeDark()
    public var editorIconProvider: EditorIconProvider? {
        didSet { rebuildAndRedraw() }
    }
    public var showsPerformanceOverlay = false {
        didSet {
            updatePerformanceOverlayRefreshState()
            needsDisplay = true
        }
    }

    package var editorCore: EditorCore!
    private var document: Document? { editorCore?.getDocument() }
    private var renderModel: EditorRenderModel?
    private var decorationProviderManager: DecorationProviderManager?
    private var completionProviderManager: CompletionProviderManager?
    private var completionPopupController: CompletionPopupController?
    private let newLineActionProviderManager = NewLineActionProviderManager()
    private var textInputHandledInCurrentKeyDown = false
    private lazy var textInputConnection = InputConnection(owner: self)
    private var performanceOverlayTimer: Timer?
    private var cursorBlinkTimer: Timer?
    private var animationTimer: Timer?
    private var directScrollGestureActive = false
    private var directScaleGestureActive = false
    private var hoverTrackingArea: NSTrackingArea?
    private var scrollbarPolicy = ScrollbarPolicy()
    private var isCursorBlinkVisible = true
    private var pendingFrameBuildDurationMs: Double = 0
    private var performanceWindowStartTimestamp: CFTimeInterval?
    private var performanceWindowFrameCount = 0
    private var performanceWindowAccumulatedFrameDurationMs: Double = 0
    private var displayedAverageFrameDurationMs: Double = 0
    private var displayedAverageFramesPerSecond: Double = 0

    /// Current language configuration.
    public private(set) var languageConfiguration: LanguageConfiguration?

    /// Extensible metadata supplied by external callers (cast to concrete type when used).
    public var metadata: EditorMetadata? {
        didSet {
            decorationProviderManager?.requestRefresh()
        }
    }

    public override var acceptsFirstResponder: Bool { true }
    public override var isFlipped: Bool { true }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    public override func becomeFirstResponder() -> Bool {
        guard textInputConnection.beginSession() else { return false }
        resetCursorBlink()
        return true
    }

    public override func resignFirstResponder() -> Bool {
        dispatchEditorActionResult(textInputConnection.endSession())
        stopCursorBlink(hideCursor: true)
        return true
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = theme.backgroundColor
        editorCore = EditorCore(fontSize: CGFloat(settings.editorTextSize), fontName: "Menlo")
        editorCore.setScrollbarConfig(scrollbarPolicy.defaultConfig())
        EditorRenderer.applyTheme(theme, core: editorCore)
        decorationProviderManager = DecorationProviderManager(
            core: editorCore,
            visibleLineRangeProvider: { [weak self] in
                guard let self else { return IntRange(start: 0, end: -1) }
                return self.editorCore.getVisibleLineRange()
            },
            totalLineCountProvider: { [weak self] in
                guard let self, let doc = self.document else { return -1 }
                return doc.getLineCount()
            },
            languageConfigurationProvider: { [weak self] in self?.languageConfiguration },
            editorMetadataProvider: { [weak self] in self?.metadata },
            scrollRefreshMinIntervalMsProvider: { [weak self] in
                self?.settings.decorationScrollRefreshMinIntervalMs ?? 0
            },
            overscanViewportMultiplierProvider: { [weak self] in
                self?.settings.decorationOverscanViewportMultiplier ?? 0
            },
            onApplied: { [weak self] in self?.rebuildAndRedraw() }
        )

        completionPopupController = CompletionPopupController(editor: self)
        completionProviderManager = CompletionProviderManager(
            editor: self,
            onItemsUpdated: { [weak self] items in
                self?.completionPopupController?.updateItems(items)
            },
            onDismissed: { [weak self] in
                self?.completionPopupController?.dismiss()
            }
        )

        let doc = Document(text: "")
        _ = editorCore.loadDocument(doc)
        decorationProviderManager?.onDocumentLoaded()
        settings.applyAll()
        applyTheme(theme)
    }

    public func loadDocument(text: String) {
        loadDocument(Document(text: text))
    }

    public func loadDocument(_ document: Document) {
        let result = editorCore.loadDocument(document)
        decorationProviderManager?.onDocumentLoaded()
        dispatchEditorActionResult(result)
        onDocumentLoaded?(DocumentLoadedEvent())
    }

    public func replaceText(in range: SweetEditorShared.TextRange, with text: String) {
        dispatchEditorActionResult(editorCore.replaceText(
            startLine: Int(range.start.line),
            startColumn: Int(range.start.column),
            endLine: Int(range.end.line),
            endColumn: Int(range.end.column),
            newText: text
        ))
    }

    public func deleteText(in range: SweetEditorShared.TextRange) {
        dispatchEditorActionResult(editorCore.deleteText(
            startLine: Int(range.start.line),
            startColumn: Int(range.start.column),
            endLine: Int(range.end.line),
            endColumn: Int(range.end.column)
        ))
    }

    public func insertText(_ text: String) {
        dispatchEditorActionResult(editorCore.insertText(text))
    }

    public func getSelectedText() -> String {
        editorCore.getSelectedText()
    }

    public func setSelection(_ range: SweetEditorShared.TextRange) {
        dispatchEditorActionResult(editorCore.setSelection(range))
    }

    public func setKeyMap(_ bindings: [KeyBinding]) {
        dispatchEditorActionResult(editorCore.setKeyMap(bindings))
    }

    public func getSelection() -> SweetEditorShared.TextRange? {
        editorCore.getSelection()
    }

    public func hasSelection() -> Bool {
        editorCore.getSelection() != nil
    }

    public func setCursorPosition(_ position: TextPosition) {
        dispatchEditorActionResult(editorCore.setCursorPosition(position))
    }

    public func gotoPosition(_ position: TextPosition) {
        dispatchEditorActionResult(editorCore.gotoPosition(
            line: Int(position.line),
            column: Int(position.column)
        ))
    }

    public func scrollToLine(_ line: Int, behavior: ScrollBehavior = .GOTO_CENTER) {
        dispatchEditorActionResult(editorCore.scrollToLine(line, behavior: behavior))
    }

    public func setScroll(x: Float, y: Float) {
        dispatchEditorActionResult(editorCore.setScroll(scrollX: x, scrollY: y))
    }

    public func getScrollMetrics() -> ScrollMetrics {
        editorCore.getScrollMetrics()
    }

    public func getVisibleLineRange() -> IntRange {
        editorCore.getVisibleLineRange()
    }

    public func getTotalLineCount() -> Int {
        document?.getLineCount() ?? 0
    }

    public func ensureCursorVisible() {
        dispatchEditorActionResult(editorCore.ensureCursorVisible())
    }

    public func toggleFold(at line: Int) {
        dispatchEditorActionResult(editorCore.toggleFold(at: line))
    }

    public func fold(at line: Int) {
        dispatchEditorActionResult(editorCore.foldAt(line: line))
    }

    public func unfold(at line: Int) {
        dispatchEditorActionResult(editorCore.unfoldAt(line: line))
    }

    public func foldAll() {
        dispatchEditorActionResult(editorCore.foldAll())
    }

    public func unfoldAll() {
        dispatchEditorActionResult(editorCore.unfoldAll())
    }

    public func isLineVisible(_ line: Int) -> Bool {
        editorCore.isLineVisible(line: line)
    }

    public func insertSnippet(_ template: String) {
        dispatchEditorActionResult(editorCore.insertSnippet(template))
    }

    public func startLinkedEditing(_ groups: [TabStopGroup]) {
        dispatchEditorActionResult(editorCore.startLinkedEditing(groups: groups))
    }

    public func isInLinkedEditing() -> Bool {
        editorCore.isInLinkedEditing()
    }

    public func moveToNextLinkedEditingRange() {
        dispatchEditorActionResult(editorCore.linkedEditingNext())
    }

    public func moveToPreviousLinkedEditingRange() {
        dispatchEditorActionResult(editorCore.linkedEditingPrev())
    }

    public func cancelLinkedEditing() {
        dispatchEditorActionResult(editorCore.cancelLinkedEditing())
    }

    public func search(_ request: SearchRequest) {
        dispatchEditorActionResult(editorCore.search(request))
    }

    public func findNextSearchMatch() {
        dispatchEditorActionResult(editorCore.findNextSearchMatch())
    }

    public func findPreviousSearchMatch() {
        dispatchEditorActionResult(editorCore.findPreviousSearchMatch())
    }

    public func replaceCurrentSearchMatch(_ replacement: String) {
        dispatchEditorActionResult(editorCore.replaceCurrentSearchMatch(replacement))
    }

    public func replaceAllSearchMatches(_ replacement: String) {
        dispatchEditorActionResult(editorCore.replaceAllSearchMatches(replacement))
    }

    public func undo() {
        dispatchEditorActionResult(editorCore.undo())
    }

    public func redo() {
        dispatchEditorActionResult(editorCore.redo())
    }

    public func canUndo() -> Bool {
        editorCore.canUndo()
    }

    public func canRedo() -> Bool {
        editorCore.canRedo()
    }

    public func selectAll() {
        dispatchEditorActionResult(editorCore.selectAll())
    }

    public func clearSearch() {
        dispatchEditorActionResult(editorCore.clearSearch())
    }

    public func getSearchState() -> SearchState {
        editorCore.getSearchState()
    }

    public func clearAllDecorations() {
        dispatchEditorActionResult(editorCore.clearAllDecorations())
    }

    public func registerTextStyle(styleId: Int32, color: Int32, fontStyle: Int32) {
        dispatchEditorActionResult(editorCore.registerTextStyle(styleId: styleId, color: color, fontStyle: fontStyle))
    }

    public func registerTextStyle(
        styleId: Int32,
        color: Int32,
        backgroundColor: Int32,
        fontStyle: Int32
    ) {
        dispatchEditorActionResult(editorCore.registerTextStyle(
            styleId: styleId,
            color: color,
            backgroundColor: backgroundColor,
            fontStyle: fontStyle
        ))
    }

    public func registerBatchTextStyles(_ stylesById: [Int32: TextStyle]) {
        dispatchEditorActionResult(editorCore.registerBatchTextStyles(stylesById))
    }

    public func setLineSpans(line: Int, layer: SpanLayer, spans: [StyleSpan]) {
        dispatchEditorActionResult(editorCore.setLineSpans(line: line, layer: layer, spans: spans))
    }

    public func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [StyleSpan]]) {
        dispatchEditorActionResult(editorCore.setBatchLineSpans(layer: layer, spansByLine: spansByLine))
    }

    public func setLineInlayHints(line: Int, hints: [InlayHint]) {
        dispatchEditorActionResult(editorCore.setLineInlayHints(line: line, hints: hints))
    }

    public func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHint]]) {
        dispatchEditorActionResult(editorCore.setBatchLineInlayHints(hintsByLine))
    }

    public func setLinePhantomTexts(line: Int, phantoms: [PhantomText]) {
        dispatchEditorActionResult(editorCore.setLinePhantomTexts(line: line, phantoms: phantoms))
    }

    public func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomText]]) {
        dispatchEditorActionResult(editorCore.setBatchLinePhantomTexts(phantomsByLine))
    }

    public func setLineGutterIcons(line: Int, icons: [GutterIcon]) {
        dispatchEditorActionResult(editorCore.setLineGutterIcons(line: line, icons: icons))
    }

    public func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) {
        dispatchEditorActionResult(editorCore.setBatchLineGutterIcons(iconsByLine))
    }

    public func setLineCodeLens(line: Int, items: [CodeLensItem]) {
        dispatchEditorActionResult(editorCore.setLineCodeLens(line: line, items: items))
    }

    public func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensItem]]) {
        dispatchEditorActionResult(editorCore.setBatchLineCodeLens(itemsByLine))
    }

    public func setLineLinks(line: Int, links: [LinkSpan]) {
        dispatchEditorActionResult(editorCore.setLineLinks(line: line, links: links))
    }

    public func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) {
        dispatchEditorActionResult(editorCore.setBatchLineLinks(linksByLine))
    }

    public func getLinkTargetAt(line: Int, column: Int) -> String {
        editorCore.getLinkTargetAt(line: line, column: column)
    }

    public func setLineDiagnostics(line: Int, items: [Diagnostic]) {
        dispatchEditorActionResult(editorCore.setLineDiagnostics(line: line, items: items))
    }

    public func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]]) {
        dispatchEditorActionResult(editorCore.setBatchLineDiagnostics(diagnosticsByLine))
    }

    public func setLineDocumentHighlights(line: Int, items: [DocumentHighlight]) {
        dispatchEditorActionResult(editorCore.setLineDocumentHighlights(line: line, items: items))
    }

    public func setBatchLineDocumentHighlights(_ highlightsByLine: [Int: [DocumentHighlight]]) {
        dispatchEditorActionResult(editorCore.setBatchLineDocumentHighlights(highlightsByLine))
    }

    public func setIndentGuides(_ guides: [IndentGuide]) {
        dispatchEditorActionResult(editorCore.setIndentGuides(guides))
    }

    public func setBracketGuides(_ guides: [BracketGuide]) {
        dispatchEditorActionResult(editorCore.setBracketGuides(guides))
    }

    public func setFlowGuides(_ guides: [FlowGuide]) {
        dispatchEditorActionResult(editorCore.setFlowGuides(guides))
    }

    public func setSeparatorGuides(_ guides: [SeparatorGuide]) {
        dispatchEditorActionResult(editorCore.setSeparatorGuides(guides))
    }

    public func setFoldRegions(_ regions: [FoldRegion]) {
        dispatchEditorActionResult(editorCore.setFoldRegions(regions))
    }

    public func clearHighlights() {
        dispatchEditorActionResult(editorCore.clearHighlights())
    }

    public func clearHighlights(layer: SpanLayer) {
        dispatchEditorActionResult(editorCore.clearHighlights(layer: layer))
    }

    public func clearInlayHints() {
        dispatchEditorActionResult(editorCore.clearInlayHints())
    }

    public func clearPhantomTexts() {
        dispatchEditorActionResult(editorCore.clearPhantomTexts())
    }

    public func clearGutterIcons() {
        dispatchEditorActionResult(editorCore.clearGutterIcons())
    }

    public func clearCodeLens() {
        dispatchEditorActionResult(editorCore.clearCodeLens())
    }

    public func clearLinks() {
        dispatchEditorActionResult(editorCore.clearLinks())
    }

    public func clearGuides() {
        dispatchEditorActionResult(editorCore.clearGuides())
    }

    public func clearDiagnostics() {
        dispatchEditorActionResult(editorCore.clearDiagnostics())
    }

    public func clearDocumentHighlights() {
        dispatchEditorActionResult(editorCore.clearDocumentHighlights())
    }

    public func attachDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.addProvider(provider)
    }

    public func detachDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.removeProvider(provider)
    }

    public func requestDecorationRefresh() {
        decorationProviderManager?.requestRefresh()
    }

    // MARK: - CompletionProvider API

    public func attachCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.addProvider(provider)
    }

    public func detachCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.removeProvider(provider)
    }

    public func triggerCompletion() {
        completionProviderManager?.triggerCompletion(.invoked)
    }

    public func showCompletionItems(_ items: [CompletionItem]) {
        completionProviderManager?.showItems(items)
    }

    public func dismissCompletion() {
        completionProviderManager?.dismiss()
    }

    // MARK: - NewLineActionProvider API

    public func attachNewLineActionProvider(_ provider: NewLineActionProvider) {
        newLineActionProviderManager.addProvider(provider)
    }

    public func detachNewLineActionProvider(_ provider: NewLineActionProvider) {
        newLineActionProviderManager.removeProvider(provider)
    }

    // MARK: - CompletionEditorAccessor

    public func getCursorPosition() -> TextPosition? {
        guard document != nil else { return nil }
        return editorCore.getCursorPosition()
    }

    public func getDocument() -> Document? {
        return document
    }

    public func getWordRangeAtCursor() -> SweetEditorShared.TextRange {
        editorCore.getWordRangeAtCursor()
    }

    public func getWordAtCursor() -> String {
        return editorCore.getWordAtCursor()
    }

    @discardableResult
    public func copyToClipboard() -> Bool {
        let selectedText = editorCore.getSelectedText()
        guard !selectedText.isEmpty else { return false }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
        return true
    }

    @discardableResult
    public func cutToClipboard() -> Bool {
        guard let selection = editorCore.getSelection(), copyToClipboard() else { return false }
        deleteText(in: selection)
        return true
    }

    public func pasteFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        dispatchEditorActionResult(editorCore.insertText(text))
    }

    // MARK: - LanguageConfiguration

    /// Sets language configuration and syncs bracket pairs to the Core layer.
    public func setLanguageConfiguration(_ config: LanguageConfiguration?) {
        self.languageConfiguration = config
        let brackets = config?.brackets ?? []
        let opens = brackets.map { Int32($0.open.unicodeScalars.first?.value ?? 0) }
        let closes = brackets.map { Int32($0.close.unicodeScalars.first?.value ?? 0) }
        dispatchEditorActionResult(editorCore.setBracketPairs(openChars: opens, closeChars: closes))

        let autoClosingPairs = config?.autoClosingPairs ?? []
        let autoClosingOpens = autoClosingPairs.map { Int32($0.open.unicodeScalars.first?.value ?? 0) }
        let autoClosingCloses = autoClosingPairs.map { Int32($0.close.unicodeScalars.first?.value ?? 0) }
        dispatchEditorActionResult(editorCore.setAutoClosingPairs(
            openChars: autoClosingOpens,
            closeChars: autoClosingCloses
        ))

        let tabSize = config?.tabSize ?? LanguageConfiguration.defaultTabSize
        dispatchEditorActionResult(editorCore.setTabSize(
            tabSize > 0 ? tabSize : LanguageConfiguration.defaultTabSize
        ))
        dispatchEditorActionResult(editorCore.setInsertSpaces(config?.insertSpaces ?? false))
        decorationProviderManager?.requestRefresh()
    }

    // MARK: - EditorMetadata

    func getAutoIndentMode() -> AutoIndentMode {
        settings.autoIndentMode
    }

    public func getPositionRect(line: Int, column: Int) -> CursorRect {
        return editorCore.getPositionRect(line: line, column: column)
    }

    public func getCursorRect() -> CursorRect {
        return editorCore.getCursorRect()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            endDirectGestureSessions()
            dispatchEditorActionResult(textInputConnection.endSession())
            completionProviderManager?.dismiss()
            animationTimer?.invalidate()
            animationTimer = nil
            stopCursorBlink(hideCursor: true)
            return
        }
        configurePointerTracking()
        updatePerformanceOverlayRefreshState()
        updateViewportAndRedraw()
    }

    deinit {
        endDirectGestureSessions()
        _ = textInputConnection.endSession()
        completionProviderManager?.dismiss()
        performanceOverlayTimer?.invalidate()
        cursorBlinkTimer?.invalidate()
        animationTimer?.invalidate()
        hoverTrackingArea = nil
    }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        configurePointerTracking()
    }

    private func configurePointerTracking() {
        installPointerTrackingArea()
        window?.acceptsMouseMovedEvents = true
    }

    private func installPointerTrackingArea() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateViewportAndRedraw()
    }

    private func updateViewportAndRedraw() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        let result = editorCore.setViewport(width: Int(size.width), height: Int(size.height))
        dispatchEditorActionResult(result)
    }

    private func rebuildAndRedraw() {
        let buildStart = CACurrentMediaTime()
        renderModel = editorCore.buildRenderModel()
        pendingFrameBuildDurationMs = (CACurrentMediaTime() - buildStart) * 1000
        if completionPopupController?.isShowing == true {
            completionPopupController?.updatePosition()
        }
        needsDisplay = true
    }

    private func dispatchEditorActionResult(_ result: EditorActionResult?) {
        guard let result else { return }
        if result.scale_changed {
            dispatchEditorActionResult(editorCore.syncPlatformScale(result.scale_after))
        }
        if result.gesture_type != .UNDEFINED {
            if result.gesture_type == .TAP {
                fireGestureEvents(result)
                if completionPopupController?.isShowing == true {
                    completionProviderManager?.dismiss()
                }
            }
        }
        updateAnimationSchedule(result)
        dispatchGestureEvents(result)
        dispatchStateEvents(result)
        if result.pointer_cursor_changed {
            applyPointerCursor(result.pointer_cursor_after)
        }
        if result.needs_redraw {
            rebuildAndRedraw()
        }
    }

    private func dispatchStateEvents(_ result: EditorActionResult) {
        if result.cursor_changed || result.selection_changed {
            resetCursorBlink()
        }
        if result.scroll_changed {
            decorationProviderManager?.onScrollChanged()
            if completionPopupController?.isShowing == true {
                completionProviderManager?.dismiss()
            }
        }
        let changes = textChanges(from: result)
        if !changes.isEmpty {
            decorationProviderManager?.onTextChanged(changes: changes)
            onTextChanged?(TextChangedEvent(
                changes: changes,
                kind: result.text_change_kind,
                source: result.source
            ))
        }
        if result.cursor_changed {
            onCursorChanged?(CursorChangedEvent(cursorPosition: result.cursor_after))
        }
        if result.selection_changed {
            onSelectionChanged?(SelectionChangedEvent(
                hasSelection: result.has_selection_after,
                selection: result.has_selection_after ? result.selection_after : nil,
                cursorPosition: result.cursor_after
            ))
        }
        if result.scroll_changed {
            onScrollChanged?(ScrollChangedEvent(
                scrollX: result.scroll_x_after,
                scrollY: result.scroll_y_after
            ))
        }
        if result.scale_changed {
            onScaleChanged?(ScaleChangedEvent(scale: result.scale_after))
        }
        textInputConnection.synchronize(result)
        completionProviderManager?.update(
            for: result,
            isLinkedEditing: editorCore.isInLinkedEditing()
        )
    }

    private func dispatchGestureEvents(_ result: EditorActionResult) {
        let location = CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
        switch result.gesture_type {
        case .LONG_PRESS:
            onLongPress?(LongPressEvent(
                cursorPosition: result.cursor_after,
                locationInView: location
            ))
        case .DOUBLE_TAP:
            onDoubleTap?(DoubleTapEvent(
                cursorPosition: result.cursor_after,
                hasSelection: result.has_selection_after,
                selection: result.has_selection_after ? result.selection_after : nil,
                locationInView: location
            ))
        case .CONTEXT_MENU:
            onContextMenu?(ContextMenuEvent(
                cursorPosition: result.cursor_after,
                locationInView: location
            ))
        default:
            break
        }
    }

    /// Switches the editor theme.
    public func applyTheme(_ theme: EditorTheme) {
        self.theme = theme
        EditorRenderer.applyTheme(theme, core: editorCore)
        layer?.backgroundColor = theme.backgroundColor
        completionPopupController?.applyTheme(theme)
        rebuildAndRedraw()
    }

    private func applyEditorSetting(_ change: EditorSettingChange) {
        switch change {
        case let .font(size, typeface):
            dispatchEditorActionResult(editorCore.updateFont(size: size, name: typeface))
        case let .scale(scale):
            dispatchEditorActionResult(editorCore.setScale(scale))
        case let .foldArrowMode(mode):
            dispatchEditorActionResult(editorCore.setFoldArrowMode(mode))
        case let .wrapMode(mode):
            dispatchEditorActionResult(editorCore.setWrapMode(mode))
        case let .renderWhitespace(mode):
            dispatchEditorActionResult(editorCore.setRenderWhitespace(mode))
        case let .renderLineBreaks(enabled):
            dispatchEditorActionResult(editorCore.setRenderLineBreaks(enabled))
        case let .lineSpacing(add, mult):
            dispatchEditorActionResult(editorCore.setLineSpacing(add: add, mult: mult))
        case let .contentStartPadding(padding):
            dispatchEditorActionResult(editorCore.setContentStartPadding(padding))
        case let .showSplitLine(show):
            dispatchEditorActionResult(editorCore.setShowSplitLine(show))
        case let .gutterSticky(sticky):
            dispatchEditorActionResult(editorCore.setGutterSticky(sticky))
        case let .gutterVisible(visible):
            dispatchEditorActionResult(editorCore.setGutterVisible(visible))
        case let .currentLineRenderMode(mode):
            dispatchEditorActionResult(editorCore.setCurrentLineRenderMode(mode))
        case let .autoIndentMode(mode):
            dispatchEditorActionResult(editorCore.setAutoIndentMode(mode))
        case let .backspaceUnindent(enabled):
            dispatchEditorActionResult(editorCore.setBackspaceUnindent(enabled))
        case let .readOnly(readOnly):
            dispatchEditorActionResult(editorCore.setReadOnly(readOnly))
        case let .compositionEnabled(enabled):
            dispatchEditorActionResult(textInputConnection.setCompositionEnabled(enabled))
        case let .maxGutterIcons(count):
            dispatchEditorActionResult(editorCore.setMaxGutterIcons(count))
        case .decorationOverscanViewportMultiplier:
            decorationProviderManager?.requestRefresh()
        }
    }

    private func isEditorFocused() -> Bool {
        window?.firstResponder === self
    }

    private func applyPointerCursor(_ cursor: PointerCursorType) {
        switch cursor {
        case .DEFAULT:
            NSCursor.arrow.set()
        case .TEXT:
            NSCursor.iBeam.set()
        case .HAND:
            NSCursor.pointingHand.set()
        }
    }

    private func startCursorBlinkTimerIfNeeded() {
        guard cursorBlinkTimer == nil else { return }

        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isEditorFocused() else { return }
            self.isCursorBlinkVisible.toggle()
            self.needsDisplay = true
        }
        timer.tolerance = 0.125
        RunLoop.main.add(timer, forMode: .common)
        cursorBlinkTimer = timer
    }

    private func stopCursorBlink(hideCursor: Bool) {
        cursorBlinkTimer?.invalidate()
        cursorBlinkTimer = nil
        if hideCursor {
            isCursorBlinkVisible = false
        }
        needsDisplay = true
    }

    private func resetCursorBlink() {
        isCursorBlinkVisible = true
        needsDisplay = true

        guard isEditorFocused() else {
            stopCursorBlink(hideCursor: false)
            return
        }

        cursorBlinkTimer?.invalidate()
        cursorBlinkTimer = nil
        startCursorBlinkTimerIfNeeded()
    }

    private func updatePerformanceOverlayRefreshState() {
        let shouldRefresh = showsPerformanceOverlay && window != nil

        guard shouldRefresh else {
            performanceOverlayTimer?.invalidate()
            performanceOverlayTimer = nil
            performanceWindowStartTimestamp = nil
            performanceWindowFrameCount = 0
            performanceWindowAccumulatedFrameDurationMs = 0
            displayedAverageFrameDurationMs = 0
            displayedAverageFramesPerSecond = 0
            return
        }

        guard performanceOverlayTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self,
                  self.showsPerformanceOverlay,
                  self.window != nil,
                  !self.isHiddenOrHasHiddenAncestor,
                  self.bounds.width > 0,
                  self.bounds.height > 0 else { return }
            self.needsDisplay = true
        }
        timer.tolerance = 1.0 / 120.0
        RunLoop.main.add(timer, forMode: .common)
        performanceOverlayTimer = timer
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext,
              let model = renderModel else { return }

        let frameStart = CACurrentMediaTime()
        if performanceWindowStartTimestamp == nil {
            performanceWindowStartTimestamp = frameStart
        }

        // CoreText draws text upside down in flipped views, so we need to flip the text matrix
        // while keeping the coordinate system flipped for drawing rects
        context.saveGState()

        // Set text matrix to flip text rendering (CoreText expects unflipped coordinates)
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)

        EditorRenderer.draw(context: context,
            model: model,
            core: editorCore,
            theme: theme,
            iconProvider: editorIconProvider,
                            isCursorBlinkVisible: isCursorBlinkVisible && isEditorFocused(),
                            scrollbarStyle: scrollbarPolicy.visualStyle(for: theme))

        context.restoreGState()

        let frameEnd = CACurrentMediaTime()
        let drawDurationMs = (frameEnd - frameStart) * 1000
        let frameDurationMs = pendingFrameBuildDurationMs + drawDurationMs
        pendingFrameBuildDurationMs = 0

        performanceWindowAccumulatedFrameDurationMs += frameDurationMs
        performanceWindowFrameCount += 1

        if let windowStartTimestamp = performanceWindowStartTimestamp {
            let windowElapsed = frameEnd - windowStartTimestamp
            if windowElapsed >= 1.0, performanceWindowFrameCount > 0 {
                displayedAverageFrameDurationMs =
                    performanceWindowAccumulatedFrameDurationMs / Double(performanceWindowFrameCount)
                displayedAverageFramesPerSecond = Double(performanceWindowFrameCount) / windowElapsed
                performanceWindowStartTimestamp = frameEnd
                performanceWindowFrameCount = 0
                performanceWindowAccumulatedFrameDurationMs = 0
            }
        }

        if showsPerformanceOverlay {
            drawPerformanceOverlay()
        }
    }

    private func drawPerformanceOverlay() {
        let metricsText = String(
            format: "Avg1s %.2f ms  FPS %.1f",
            displayedAverageFrameDurationMs,
            displayedAverageFramesPerSecond
        ) as NSString
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
        ]

        let textSize = metricsText.size(withAttributes: textAttributes)
        let paddingX: CGFloat = 10
        let paddingY: CGFloat = 6
        let origin = CGPoint(
            x: bounds.width - textSize.width - paddingX * 2 - 12,
            y: 12
        )
        let backgroundRect = CGRect(
            x: max(8, origin.x),
            y: origin.y,
            width: textSize.width + paddingX * 2,
            height: textSize.height + paddingY * 2
        )

        let backgroundPath = NSBezierPath(
            roundedRect: backgroundRect,
            xRadius: 8,
            yRadius: 8
        )
        NSColor.black.withAlphaComponent(0.72).setFill()
        backgroundPath.fill()

        NSColor.white.withAlphaComponent(0.12).setStroke()
        backgroundPath.lineWidth = 1
        backgroundPath.stroke()

        let textOrigin = CGPoint(
            x: backgroundRect.minX + paddingX,
            y: backgroundRect.minY + paddingY
        )
        metricsText.draw(at: textOrigin, withAttributes: textAttributes)
    }

    private func updateAnimationSchedule(_ result: EditorActionResult) {
        guard result.needsAnimation else {
            animationTimer?.invalidate()
            animationTimer = nil
            return
        }
        EditorAnimationScheduler.schedule(
            &animationTimer,
            delayMs: result.next_animation_delay_ms
        ) { [weak self] in
            guard let self else { return }
            self.dispatchEditorActionResult(self.editorCore.tickAnimations())
        }
    }

    // MARK: - Mouse Events

    public override func mouseDown(with event: NSEvent) {
        _ = window?.makeFirstResponder(self)
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_DOWN, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
    }

    public override func mouseDragged(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_MOVE, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
        applyPointerCursor(result.pointer_cursor_after)
    }

    public override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_MOVE, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
        applyPointerCursor(result.pointer_cursor_after)
    }

    public override func mouseExited(with event: NSEvent) {
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_MOVE, points: [(-1, -1)],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
        NSCursor.arrow.set()
    }

    public override func mouseUp(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_UP, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
    }

    public override func rightMouseDown(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .MOUSE_RIGHT_DOWN, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        dispatchEditorActionResult(result)
    }

    public override func scrollWheel(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)

        let result: EditorActionResult?
        if event.phase != [] || event.momentumPhase != [] {
            if !directScrollGestureActive {
                directScrollGestureActive = true
                dispatchEditorActionResult(editorCore.handleGestureEvent(
                    type: .DIRECT_GESTURE_BEGIN,
                    points: [(Float(point.x), Float(point.y))],
                    modifiers: mods
                ))
            }
            result = editorCore.handleGestureEvent(
                type: .DIRECT_SCROLL,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods,
                wheelDeltaX: Float(event.scrollingDeltaX),
                wheelDeltaY: Float(event.scrollingDeltaY)
            )
            dispatchEditorActionResult(result)
            let phaseFinished = event.phase.contains(.ended) || event.phase.contains(.cancelled)
            let momentumFinished = event.momentumPhase.contains(.ended)
                || event.momentumPhase.contains(.cancelled)
            if momentumFinished || (phaseFinished && event.momentumPhase == []) {
                directScrollGestureActive = false
                dispatchEditorActionResult(editorCore.handleGestureEvent(
                    type: .DIRECT_GESTURE_END,
                    points: [(Float(point.x), Float(point.y))],
                    modifiers: mods
                ))
            }
        } else {
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .DIRECT_GESTURE_BEGIN,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods
            ))
            result = editorCore.handleGestureEvent(
                type: .MOUSE_WHEEL,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods,
                wheelDeltaX: Float(event.scrollingDeltaX * 40),
                wheelDeltaY: Float(event.scrollingDeltaY * 40)
            )
            dispatchEditorActionResult(result)
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .DIRECT_GESTURE_END,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods
            ))
        }
    }

    public override func magnify(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let isContinuous = event.phase != []
        if !isContinuous || !directScaleGestureActive {
            if isContinuous {
                directScaleGestureActive = true
            }
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .DIRECT_GESTURE_BEGIN,
                points: [(Float(point.x), Float(point.y))]
            ))
        }
        let result = editorCore.handleGestureEvent(
            type: .DIRECT_SCALE,
            points: [(Float(point.x), Float(point.y))],
            directScale: Float(1.0 + event.magnification)
        )
        dispatchEditorActionResult(result)
        if !isContinuous {
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .DIRECT_GESTURE_END,
                points: [(Float(point.x), Float(point.y))]
            ))
        }
        if directScaleGestureActive
            && (event.phase.contains(.ended) || event.phase.contains(.cancelled)) {
            directScaleGestureActive = false
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .DIRECT_GESTURE_END,
                points: [(Float(point.x), Float(point.y))]
            ))
        }
    }

    private func endDirectGestureSessions() {
        let activeSessionCount = (directScrollGestureActive ? 1 : 0)
            + (directScaleGestureActive ? 1 : 0)
        directScrollGestureActive = false
        directScaleGestureActive = false
        for _ in 0..<activeSessionCount {
            _ = editorCore?.handleGestureEvent(type: .DIRECT_GESTURE_END, points: [])
        }
    }

    private func fireGestureEvents(_ result: EditorActionResult) {
        guard result.gesture_type == .TAP else { return }
        let hitLine = Int(result.hit_target.line)
        let hitColumn = Int(result.hit_target.column)

        switch result.hit_target.type {
        case .INLAY_HINT_TEXT:
            onInlayHintClick?(
                InlayHintClickEvent(
                    line: hitLine,
                    column: hitColumn,
                    kind: .text,
                    iconId: 0,
                    colorValue: 0,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .INLAY_HINT_ICON:
            onInlayHintClick?(
                InlayHintClickEvent(
                    line: hitLine,
                    column: hitColumn,
                    kind: .icon,
                    iconId: result.hit_target.icon_id,
                    colorValue: 0,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .INLAY_HINT_COLOR:
            onInlayHintClick?(
                InlayHintClickEvent(
                    line: hitLine,
                    column: hitColumn,
                    kind: .color,
                    iconId: 0,
                    colorValue: result.hit_target.color_value,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .GUTTER_ICON:
            onGutterIconClick?(
                GutterIconClickEvent(
                    line: hitLine,
                    iconId: result.hit_target.icon_id,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .CODELENS:
            onCodeLensClick?(
                CodeLensClickEvent(
                    line: hitLine,
                    column: hitColumn,
                    commandId: result.hit_target.icon_id,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .LINK:
            onLinkClick?(
                LinkClickEvent(
                    line: hitLine,
                    column: hitColumn,
                    target: getLinkTargetAt(line: hitLine, column: hitColumn),
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        case .FOLD_PLACEHOLDER, .FOLD_GUTTER:
            onFoldToggle?(
                FoldToggleEvent(
                    line: hitLine,
                    isGutter: result.hit_target.type == .FOLD_GUTTER,
                    locationInView: CGPoint(x: CGFloat(result.tap_point.x), y: CGFloat(result.tap_point.y))
                )
            )
        default:
            break
        }
    }

    // MARK: - Keyboard Events

    public override func keyDown(with event: NSEvent) {
        resetCursorBlink()
        textInputHandledInCurrentKeyDown = false

        interpretKeyEvents([event])
        if textInputHandledInCurrentKeyDown {
            return
        }
        if handleFallbackKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    public override func flagsChanged(with event: NSEvent) {
        dispatchEditorActionResult(editorCore.updatePointerModifiers(modifiersFromEvent(event)))
        super.flagsChanged(with: event)
    }

    // MARK: - NSResponder Standard Key Bindings (dispatched via doCommandBySelector:)

    public override func doCommand(by selector: Selector) {
        // Completion popup keyboard interception.
        if !textInputConnection.hasComposition,
           let popup = completionPopupController,
           popup.isShowing {
            switch selector {
            case #selector(insertNewline(_:)):
                if popup.handleKeyCode(KeyCode.ENTER) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(cancelOperation(_:)):
                if popup.handleKeyCode(KeyCode.ESCAPE) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(moveUp(_:)):
                if popup.handleKeyCode(KeyCode.UP) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(moveDown(_:)):
                if popup.handleKeyCode(KeyCode.DOWN) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            default:
                break
            }
        }

        let mods = currentModifiers()

        switch selector {
        case #selector(deleteBackward(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.BACKSPACE, modifiers: mods))
        case #selector(deleteForward(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.DELETE_KEY, modifiers: mods))
        case #selector(insertNewline(_:)):
            textInputHandledInCurrentKeyDown = true
            // Let NewLineActionProvider handle newline first (provider decides indentation).
            // If not handled, fall back to Core behavior (KEEP_INDENT keeps indentation, NONE disables it).
            let pos = editorCore.getCursorPosition()
            let lineText = document?.getLineText(Int(pos.line)) ?? ""
            let context = NewLineContext(
                lineNumber: Int(pos.line),
                column: Int(pos.column),
                lineText: lineText,
                languageConfiguration: languageConfiguration,
                editorMetadata: metadata
            )
            if let action = newLineActionProviderManager.provideNewLineAction(context: context) {
                dispatchEditorActionResult(editorCore.handleKeyEvent(
                    keyCode: KeyCode.NONE,
                    text: action.text,
                    modifiers: mods
                ))
                break
            }
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.ENTER, modifiers: mods))
        case #selector(insertTab(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.TAB, modifiers: mods))
        case #selector(insertBacktab(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.TAB, modifiers: shiftMods))
        case #selector(moveLeft(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.LEFT, modifiers: mods))
        case #selector(moveRight(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.RIGHT, modifiers: mods))
        case #selector(moveWordLeft(_:)), NSSelectorFromString("moveWordBackward:"):
            textInputHandledInCurrentKeyDown = true
            var wordMods = mods
            wordMods |= KeyModifier.ALT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.LEFT, modifiers: wordMods))
        case #selector(moveWordRight(_:)), NSSelectorFromString("moveWordForward:"):
            textInputHandledInCurrentKeyDown = true
            var wordMods = mods
            wordMods |= KeyModifier.ALT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.RIGHT, modifiers: wordMods))
        case #selector(moveUp(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.UP, modifiers: mods))
        case #selector(moveDown(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.DOWN, modifiers: mods))
        case #selector(moveLeftAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.LEFT, modifiers: shiftMods))
        case #selector(moveRightAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.RIGHT, modifiers: shiftMods))
        case #selector(moveWordLeftAndModifySelection(_:)), NSSelectorFromString("moveWordBackwardAndModifySelection:"):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            shiftMods |= KeyModifier.ALT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.LEFT, modifiers: shiftMods))
        case #selector(moveWordRightAndModifySelection(_:)), NSSelectorFromString("moveWordForwardAndModifySelection:"):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            shiftMods |= KeyModifier.ALT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.RIGHT, modifiers: shiftMods))
        case #selector(moveUpAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.UP, modifiers: shiftMods))
        case #selector(moveDownAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.DOWN, modifiers: shiftMods))
        case #selector(moveToBeginningOfLine(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.HOME, modifiers: mods))
        case #selector(moveToEndOfLine(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.END, modifiers: mods))
        case #selector(moveToBeginningOfLineAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.HOME, modifiers: shiftMods))
        case #selector(moveToEndOfLineAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods |= KeyModifier.SHIFT
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.END, modifiers: shiftMods))
        case #selector(pageUp(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.PAGE_UP, modifiers: mods))
        case #selector(pageDown(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.PAGE_DOWN, modifiers: mods))
        case #selector(cancelOperation(_:)):
            textInputHandledInCurrentKeyDown = true
            dispatchEditorActionResult(editorCore.handleKeyEvent(keyCode: KeyCode.ESCAPE, modifiers: mods))
        default:
            super.doCommand(by: selector)
            return
        }
    }

    public override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else { return false }
        let keyCode = mapShortcutKeyCode(event)
        guard keyCode != KeyCode.NONE else { return false }
        resetCursorBlink()

        let result = editorCore.handleKeyEvent(
            keyCode: keyCode,
            modifiers: modifiersFromEvent(event)
        )
        guard result.handled else { return false }
        dispatchEditorActionResult(result)
        performHostCommand(result.command)
        return true
    }

    // MARK: - NSTextInputClient

    public override func insertText(_ insertString: Any) {
        textInputHandledInCurrentKeyDown = true
        insertText(insertString, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    public func insertText(_ string: Any, replacementRange: NSRange) {
        resetCursorBlink()
        textInputHandledInCurrentKeyDown = true

        let text: String
        if let attrStr = string as? NSAttributedString {
            text = attrStr.string
        } else if let str = string as? String {
            text = str
        } else {
            return
        }

        if text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first {
            let keyCode = mapCharToKeyCode(scalar)
            if keyCode != KeyCode.NONE {
                let mods = currentModifiers()
                let keyResult = editorCore.handleKeyEvent(keyCode: keyCode, modifiers: mods)
                dispatchEditorActionResult(keyResult)
                return
            }
        }

        let editResult = textInputConnection.commitText(text, replacementRange: replacementRange)
        dispatchEditorActionResult(editResult)
    }

    /// Inserts text at the specified document position.
    public func insertText(at position: TextPosition, text: String) {
        replaceText(
            startLine: Int(position.line),
            startColumn: Int(position.column),
            endLine: Int(position.line),
            endColumn: Int(position.column),
            newText: text
        )
    }

    /// Replaces text in a target range atomically, then refreshes decorations and redraws.
    func replaceText(startLine: Int, startColumn: Int,
                     endLine: Int, endColumn: Int,
                     newText: String) {
        let editResult = editorCore.replaceText(
            startLine: startLine, startColumn: startColumn,
            endLine: endLine, endColumn: endColumn,
            newText: newText)
        dispatchEditorActionResult(editResult)
    }

    /// Deletes text in a target range atomically, then refreshes decorations and redraws.
    func deleteText(startLine: Int, startColumn: Int,
                    endLine: Int, endColumn: Int) {
        let editResult = editorCore.deleteText(
            startLine: startLine, startColumn: startColumn,
            endLine: endLine, endColumn: endColumn)
        dispatchEditorActionResult(editResult)
    }

    /// Applies multiple text edits as one undoable operation.
    public func applyTextEdits(_ edits: [TextEdit]) {
        let editResult = editorCore.applyTextEdits(edits)
        dispatchEditorActionResult(editResult)
    }

    // MARK: - Line operations

    /// Moves the current line (or selected lines) up by one line.
    public func moveLineUp() {
        let editResult = editorCore.moveLineUp()
        dispatchEditorActionResult(editResult)
    }

    /// Moves the current line (or selected lines) down by one line.
    public func moveLineDown() {
        let editResult = editorCore.moveLineDown()
        dispatchEditorActionResult(editResult)
    }

    /// Copies the current line (or selected lines) upward.
    public func copyLineUp() {
        let editResult = editorCore.copyLineUp()
        dispatchEditorActionResult(editResult)
    }

    /// Copies the current line (or selected lines) downward.
    public func copyLineDown() {
        let editResult = editorCore.copyLineDown()
        dispatchEditorActionResult(editResult)
    }

    /// Deletes the current line (or all selected lines).
    public func deleteLine() {
        let editResult = editorCore.deleteLine()
        dispatchEditorActionResult(editResult)
    }

    /// Inserts an empty line above the current line.
    public func insertLineAbove() {
        let editResult = editorCore.insertLineAbove()
        dispatchEditorActionResult(editResult)
    }

    /// Inserts an empty line below the current line.
    public func insertLineBelow() {
        let editResult = editorCore.insertLineBelow()
        dispatchEditorActionResult(editResult)
    }

    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        resetCursorBlink()
        textInputHandledInCurrentKeyDown = true

        let text: String
        if let attrStr = string as? NSAttributedString {
            text = attrStr.string
        } else if let str = string as? String {
            text = str
        } else {
            return
        }

        dispatchEditorActionResult(textInputConnection.setMarkedText(
            text,
            selectedRange: selectedRange,
            replacementRange: replacementRange
        ))
    }

    public func unmarkText() {
        resetCursorBlink()
        dispatchEditorActionResult(textInputConnection.unmarkText())
    }

    public func selectedRange() -> NSRange {
        textInputConnection.selectedRange
    }

    public func markedRange() -> NSRange {
        textInputConnection.markedRange
    }

    public func hasMarkedText() -> Bool {
        textInputConnection.hasComposition
    }

    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        textInputConnection.attributedSubstring(for: range, actualRange: actualRange)
    }

    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        return []
    }

    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        let requestedRange = range.location == NSNotFound ? selectedRange() : range
        actualRange?.pointee = NSRange(location: requestedRange.location, length: 0)
        guard let document,
              requestedRange.location != NSNotFound else {
            return window?.convertToScreen(frame) ?? .zero
        }
        let location = document.editingLocation(forUTF16Offset: requestedRange.location)
        let rect = editorCore.getPositionRect(line: location.line, column: location.column)
        let localRect = NSRect(
            x: CGFloat(rect.x),
            y: CGFloat(rect.y),
            width: 1,
            height: CGFloat(rect.height)
        )
        let windowRect = convert(localRect, to: nil)
        return window?.convertToScreen(windowRect) ?? windowRect
    }

    public func characterIndex(for point: NSPoint) -> Int {
        guard let document else { return NSNotFound }
        let cursor = editorCore.getCursorPosition()
        return document.editingUTF16Offset(
            line: Int(cursor.line),
            column: Int(cursor.column)
        )
    }

    // MARK: - Helpers

    private func modifiersFromEvent(_ event: NSEvent) -> Int32 {
        var mods = KeyModifier.NONE
        if event.modifierFlags.contains(.shift) { mods |= KeyModifier.SHIFT }
        if event.modifierFlags.contains(.control) { mods |= KeyModifier.CTRL }
        if event.modifierFlags.contains(.option) { mods |= KeyModifier.ALT }
        if event.modifierFlags.contains(.command) { mods |= KeyModifier.META }
        return mods
    }

    private func handleFallbackKeyDown(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            return false
        }

        let mods = modifiersFromEvent(event)
        let mappedKeyCode = mapShortcutKeyCode(event)
        if mappedKeyCode != KeyCode.NONE {
            let result = editorCore.handleKeyEvent(keyCode: mappedKeyCode, modifiers: mods)
            if result.handled {
                dispatchEditorActionResult(result)
                performHostCommand(result.command)
                return true
            }
        }

        if event.modifierFlags.contains(.control) || event.modifierFlags.contains(.option) {
            return false
        }

        guard let text = event.characters, !text.isEmpty else {
            return false
        }
        insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        return true
    }

    /// Completion confirm callback: `textEdit` is the only source of replacement range semantics.
    func applyCompletionItem(_ item: CompletionItem) {
        guard !editorCore.isInLinkedEditing() else {
            completionProviderManager?.dismiss()
            return
        }
        guard completionProviderManager?.consumeDisplayedGeneration() == true else { return }

        let isSnippet = item.insertTextFormat == CompletionItem.insertTextFormatSnippet
        var text = item.insertText ?? item.label

        if let textEdit = item.textEdit {
            text = textEdit.new_text
            var edits: [TextEdit] = []
            edits.append(isSnippet ? TextEdit(range: textEdit.range, new_text: "") : textEdit)
            edits.append(contentsOf: item.additionalTextEdits)
            applyTextEdits(edits)
            if isSnippet {
                let editResult = editorCore.insertSnippet(text)
                dispatchEditorActionResult(editResult)
            }
        } else if item.additionalTextEdits.isEmpty {
            if isSnippet {
                let editResult = editorCore.insertSnippet(text)
                dispatchEditorActionResult(editResult)
            } else {
                dispatchEditorActionResult(editorCore.insertText(text))
            }
        } else {
            let cursor = getCursorPosition() ?? TextPosition(line: 0, column: 0)
            let primaryEdit = TextEdit(
                range: TextRange(start: cursor, end: cursor),
                new_text: isSnippet ? "" : text
            )
            var edits: [TextEdit] = []
            edits.append(primaryEdit)
            edits.append(contentsOf: item.additionalTextEdits)
            applyTextEdits(edits)
            if isSnippet {
                let editResult = editorCore.insertSnippet(text)
                dispatchEditorActionResult(editResult)
            }
        }
    }

    private func textChanges(from result: EditorActionResult?) -> [TextChange] {
        guard let result, !result.text_changes.isEmpty else { return [] }
        return textChanges(from: result.text_changes)
    }

    private func textChanges(from rawChanges: [TextChange]) -> [TextChange] {
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

    private func currentModifiers() -> Int32 {
        var mods = KeyModifier.NONE
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { mods |= KeyModifier.SHIFT }
        if flags.contains(.control) { mods |= KeyModifier.CTRL }
        if flags.contains(.option) { mods |= KeyModifier.ALT }
        if flags.contains(.command) { mods |= KeyModifier.META }
        return mods
    }

    private func mapNSKeyCodeToKeyCode(_ keyCode: UInt16) -> Int32 {
        switch keyCode {
        case 51: return KeyCode.BACKSPACE
        case 48: return KeyCode.TAB
        case 36, 76: return KeyCode.ENTER
        case 53: return KeyCode.ESCAPE
        case 117: return KeyCode.DELETE_KEY
        case 123: return KeyCode.LEFT
        case 126: return KeyCode.UP
        case 124: return KeyCode.RIGHT
        case 125: return KeyCode.DOWN
        case 115: return KeyCode.HOME
        case 119: return KeyCode.END
        case 116: return KeyCode.PAGE_UP
        case 121: return KeyCode.PAGE_DOWN
        default: return KeyCode.NONE
        }
    }

    private func mapShortcutKeyCode(_ event: NSEvent) -> Int32 {
        let keyCode = mapNSKeyCodeToKeyCode(event.keyCode)
        if keyCode != KeyCode.NONE {
            return keyCode
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ": return KeyCode.SPACE
        case "a": return KeyCode.A
        case "c": return KeyCode.C
        case "d": return KeyCode.D
        case "k": return KeyCode.K
        case "v": return KeyCode.V
        case "x": return KeyCode.X
        case "y": return KeyCode.Y
        case "z": return KeyCode.Z
        default: return KeyCode.NONE
        }
    }

    private func performHostCommand(_ command: Int32) {
        switch EditorBuiltinCommand.fromValue(command) {
        case .COPY:
            _ = copyToClipboard()
        case .PASTE:
            pasteFromClipboard()
        case .CUT:
            _ = cutToClipboard()
        case .TRIGGER_COMPLETION:
            triggerCompletion()
        default:
            break
        }
    }

    private func mapCharToKeyCode(_ scalar: Unicode.Scalar) -> Int32 {
        switch scalar.value {
        case 0x08, 0x7F: return KeyCode.BACKSPACE
        case 0x09: return KeyCode.TAB
        case 0x0D, 0x0A, 0x03: return KeyCode.ENTER
        case 0x1B: return KeyCode.ESCAPE
        default: return KeyCode.NONE
        }
    }

}

#endif
