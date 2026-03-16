#if os(macOS)
import AppKit
import QuartzCore
import SwiftUI
import SweetEditorCoreInternal

public class SweetEditorViewMacOS: NSView, NSTextInputClient, CompletionEditorAccessor {
    public static weak var activeEditor: SweetEditorViewMacOS?
    public var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    public var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    public var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    public var editorIconProvider: EditorIconProvider?

    public func setEditorIconProvider(_ provider: EditorIconProvider?) {
        editorIconProvider = provider
        rebuildAndRedraw()
    }
    public var showsPerformanceOverlay = false {
        didSet {
            updatePerformanceOverlayRefreshState()
            needsDisplay = true
        }
    }

    private var editorCore: SweetEditorCore!
    private var document: SweetDocument?
    private var highlighter: SyntaxHighlighter?
    private var renderModel: EditorRenderModel?
    private var decorationProviderManager: DecorationProviderManager?
    private var completionProviderManager: CompletionProviderManager?
    private var completionPopupController: CompletionPopupController?
    private var newLineActionProviderManager: NewLineActionProviderManager?
    private var isComposing = false
    private var textInputHandledInCurrentKeyDown = false
    private var currentMarkedRange: NSRange?
    private var currentMarkedSelectionRange: NSRange?
    private var localKeyDownMonitor: Any?
    private var performanceOverlayTimer: Timer?
    private var cursorBlinkTimer: Timer?
    private var isCursorBlinkVisible = true
    private var pendingFrameBuildDurationMs: Double = 0
    private var performanceWindowStartTimestamp: CFTimeInterval?
    private var performanceWindowFrameCount = 0
    private var performanceWindowAccumulatedFrameDurationMs: Double = 0
    private var displayedAverageFrameDurationMs: Double = 0
    private var displayedAverageFramesPerSecond: Double = 0

    /// Current language configuration.
    private(set) var languageConfiguration: LanguageConfiguration?

    /// Extensible metadata supplied by external callers (cast to concrete type when used).
    var metadata: EditorMetadata?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        SweetEditorViewMacOS.activeEditor = self
        resetCursorBlink()
        return true
    }

    override func resignFirstResponder() -> Bool {
        if SweetEditorViewMacOS.activeEditor === self {
            SweetEditorViewMacOS.activeEditor = nil
        }
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
        layer?.backgroundColor = EditorRenderer.theme.backgroundColor
        editorCore = SweetEditorCore(fontSize: 14.0, fontName: "Menlo")
        editorCore.setCompositionEnabled(true)
        editorCore.setReadOnly(false)
        // Sync current theme to Core first so syntax styles are registered immediately.
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
            onApplied: { [weak self] in self?.rehighlightAndRedraw() }
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

        loadDocument(text: "")
        // Ensure initial theme (default EditorRenderer.theme) is applied to Core for syntax style sync.
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
                NSLog("[SweetEditor] No selection")
            } else {
                NSLog("[SweetEditor] Selection: \(text.prefix(100))")
            }
        }
    }

    public func loadDocument(text: String) {
        let doc = SweetDocument(text: text)
        document = doc
        editorCore.setDocument(doc)
        decorationProviderManager?.onDocumentLoaded()
        if highlighter == nil {
            highlighter = SyntaxHighlighter(editorCore: editorCore)
        }
        highlighter?.highlightAll(document: doc)
    }

    public func applyDecorations(_ decorations: EditorResolvedDecorations, clearExisting: Bool = true) {
        if clearExisting {
            editorCore.clearAllDecorations()
        }
        if let doc = document {
            highlighter?.highlightAll(document: doc)
        }
        applyResolvedDecorations(decorations)
        rehighlightAndRedraw()
    }

    public func clearAllDecorations() {
        editorCore.clearAllDecorations()
        rebuildAndRedraw()
    }

    public func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) {
        editorCore.registerStyle(styleId: styleId, color: color, fontStyle: fontStyle)
    }

    public func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) {
        editorCore.registerStyle(styleId: styleId, color: color, backgroundColor: backgroundColor, fontStyle: fontStyle)
    }

    public func setLineSpans(line: Int, layer: SpanLayer, spans: [SweetEditorCore.StyleSpan]) {
        editorCore.setLineSpans(line: line, layer: layer.rawValue, spans: spans)
        rebuildAndRedraw()
    }

    public func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [SweetEditorCore.StyleSpan]]) {
        editorCore.setBatchLineSpans(layer: layer.rawValue, spansByLine: spansByLine)
        rebuildAndRedraw()
    }

    public func setLineInlayHints(line: Int, hints: [SweetEditorCore.InlayHintPayload]) {
        editorCore.setLineInlayHints(line: line, hints: hints)
        rebuildAndRedraw()
    }

    public func setBatchLineInlayHints(_ hintsByLine: [Int: [SweetEditorCore.InlayHintPayload]]) {
        editorCore.setBatchLineInlayHints(hintsByLine)
        rebuildAndRedraw()
    }

    public func setLinePhantomTexts(line: Int, phantoms: [SweetEditorCore.PhantomTextPayload]) {
        editorCore.setLinePhantomTexts(line: line, phantoms: phantoms)
        rebuildAndRedraw()
    }

    public func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [SweetEditorCore.PhantomTextPayload]]) {
        editorCore.setBatchLinePhantomTexts(phantomsByLine)
        rebuildAndRedraw()
    }

    public func setLineGutterIcons(line: Int, icons: [SweetEditorCore.GutterIcon]) {
        editorCore.setLineGutterIcons(line: line, icons: icons)
        rebuildAndRedraw()
    }

    public func setBatchLineGutterIcons(_ iconsByLine: [Int: [SweetEditorCore.GutterIcon]]) {
        editorCore.setBatchLineGutterIcons(iconsByLine)
        rebuildAndRedraw()
    }

    public func setMaxGutterIcons(_ count: UInt32) {
        editorCore.setMaxGutterIcons(count)
        rebuildAndRedraw()
    }

    public func setLineDiagnostics(line: Int, items: [SweetEditorCore.DiagnosticItem]) {
        editorCore.setLineDiagnostics(line: line, items: items)
        rebuildAndRedraw()
    }

    public func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [SweetEditorCore.DiagnosticItem]]) {
        editorCore.setBatchLineDiagnostics(diagnosticsByLine)
        rebuildAndRedraw()
    }

    public func setIndentGuides(_ guides: [SweetEditorCore.IndentGuidePayload]) {
        editorCore.setIndentGuides(guides)
        rebuildAndRedraw()
    }

    public func setBracketGuides(_ guides: [SweetEditorCore.BracketGuidePayload]) {
        editorCore.setBracketGuides(guides)
        rebuildAndRedraw()
    }

    public func setFlowGuides(_ guides: [SweetEditorCore.FlowGuidePayload]) {
        editorCore.setFlowGuides(guides)
        rebuildAndRedraw()
    }

    public func setSeparatorGuides(_ guides: [SweetEditorCore.SeparatorGuidePayload]) {
        editorCore.setSeparatorGuides(guides)
        rebuildAndRedraw()
    }

    public func setFoldRegions(_ regions: [SweetEditorCore.FoldRegion]) {
        editorCore.setFoldRegions(regions)
        rebuildAndRedraw()
    }

    public func clearHighlights() {
        editorCore.clearHighlights()
        rebuildAndRedraw()
    }

    public func clearHighlights(layer: SpanLayer) {
        editorCore.clearHighlights(layer: layer.rawValue)
        rebuildAndRedraw()
    }

    public func clearInlayHints() {
        editorCore.clearInlayHints()
        rebuildAndRedraw()
    }

    public func clearPhantomTexts() {
        editorCore.clearPhantomTexts()
        rebuildAndRedraw()
    }

    public func clearGutterIcons() {
        editorCore.clearGutterIcons()
        rebuildAndRedraw()
    }

    public func clearGuides() {
        editorCore.clearGuides()
        rebuildAndRedraw()
    }

    public func clearDiagnostics() {
        editorCore.clearDiagnostics()
        rebuildAndRedraw()
    }

    public func documentLines() -> [String] {
        guard let document else { return [] }
        let totalLines = document.getLineCount()
        guard totalLines > 0 else { return [] }
        return (0..<totalLines).map { document.getLineText($0) }
    }

    public func addDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.addProvider(provider)
    }

    public func removeDecorationProvider(_ provider: DecorationProvider) {
        decorationProviderManager?.removeProvider(provider)
    }

    public func requestDecorationRefresh() {
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

    public func addCompletionProvider(_ provider: CompletionProvider) {
        completionProviderManager?.addProvider(provider)
    }

    public func removeCompletionProvider(_ provider: CompletionProvider) {
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

    public func addNewLineActionProvider(_ provider: NewLineActionProvider) {
        if newLineActionProviderManager == nil {
            newLineActionProviderManager = NewLineActionProviderManager()
        }
        newLineActionProviderManager?.addProvider(provider)
    }

    public func removeNewLineActionProvider(_ provider: NewLineActionProvider) {
        newLineActionProviderManager?.removeProvider(provider)
    }

    // MARK: - CompletionEditorAccessor

    func getCursorPosition() -> TextPosition? {
        guard let cursor = editorCore.getCursorPosition() else { return nil }
        return TextPosition(line: cursor.line, column: cursor.column)
    }

    func getDocument() -> SweetDocument? {
        return document
    }

    func getWordRangeAtCursor() -> SweetEditorCoreInternal.TextRange {
        let range = editorCore.getWordRangeAtCursor()
        return SweetEditorCoreInternal.TextRange(
            start: SweetEditorCoreInternal.TextPosition(line: range.startLine, column: range.startColumn),
            end: SweetEditorCoreInternal.TextPosition(line: range.endLine, column: range.endColumn)
        )
    }

    func getWordAtCursor() -> String {
        return editorCore.getWordAtCursor()
    }

    public func selectedTextPreview(maxLength: Int = 80) -> String? {
        let text = editorCore.getSelectedText()
        guard !text.isEmpty else { return nil }
        if text.count > maxLength {
            let endIndex = text.index(text.startIndex, offsetBy: maxLength)
            return String(text[text.startIndex..<endIndex]) + "…"
        }
        return text
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

    public func setWrapMode(_ mode: Int) {
        let wrapModes: [SweetEditorCore.WrapMode] = [.none, .charBreak, .wordBreak]
        editorCore.setWrapMode(wrapModes[mode])
        rebuildAndRedraw()
    }

    /// Sets editor scale from external API and syncs platform-side fonts/measurer.
    public func setScale(_ scale: Float) {
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            stopCursorBlink(hideCursor: true)
            return
        }
        installLocalKeyMonitorIfNeeded()
        updatePerformanceOverlayRefreshState()
        updateViewportAndRedraw()
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else { return }
            _ = window.makeFirstResponder(self)
            SweetEditorViewMacOS.activeEditor = self
            self.resetCursorBlink()
        }
    }

    deinit {
        performanceOverlayTimer?.invalidate()
        cursorBlinkTimer?.invalidate()
        if let localKeyDownMonitor {
            NSEvent.removeMonitor(localKeyDownMonitor)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateViewportAndRedraw()
    }

    private func updateViewportAndRedraw() {
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        editorCore.setViewport(width: Int(size.width), height: Int(size.height))
        rebuildAndRedraw()
    }

    private func rebuildAndRedraw() {
        let buildStart = CACurrentMediaTime()
        renderModel = editorCore.buildRenderModel()
        pendingFrameBuildDurationMs = (CACurrentMediaTime() - buildStart) * 1000
        if completionPopupController?.isShowing == true {
            updateCompletionPopupPosition()
        }
        needsDisplay = true
    }

    /// Switches the editor theme.
    func applyTheme(_ theme: EditorTheme) {
        let bgColor = EditorRenderer.applyTheme(theme, core: editorCore)
        layer?.backgroundColor = bgColor
        rehighlightAndRedraw()
    }

    public func applyTheme(isDark: Bool) {
        applyTheme(isDark ? .dark() : .light())
    }

    private func rehighlightAndRedraw() {
        if let doc = document {
            highlighter?.highlightAll(document: doc)
        }
        rebuildAndRedraw()
    }

    private func isEditorFocused() -> Bool {
        window?.firstResponder === self
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

    override func draw(_ dirtyRect: NSRect) {
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
                           viewHeight: bounds.height,
                           iconProvider: editorIconProvider,
                           isCursorBlinkVisible: isCursorBlinkVisible && isEditorFocused())

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

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        SweetEditorViewMacOS.activeEditor = self
        _ = window?.makeFirstResponder(self)
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .mouseDown, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        handleGestureResult(result)
        // Dismiss completion popup on click.
        if completionPopupController?.isShowing == true {
            completionProviderManager?.dismiss()
        }
        rebuildAndRedraw()
    }

    override func mouseDragged(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .mouseMove, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        handleGestureResult(result)
        rebuildAndRedraw()
    }

    override func mouseUp(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .mouseUp, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        handleGestureResult(result)
        rebuildAndRedraw()
    }

    override func rightMouseDown(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)
        let result = editorCore.handleGestureEvent(type: .mouseRightDown, points: [(Float(point.x), Float(point.y))],
                                                   modifiers: mods)
        handleGestureResult(result)
        rebuildAndRedraw()
    }

    override func scrollWheel(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let mods = modifiersFromEvent(event)

        if event.phase != [] || event.momentumPhase != [] {
            // Trackpad two-finger scroll (continuous)
            let result = editorCore.handleGestureEvent(
                type: .directScroll,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods,
                wheelDeltaX: Float(event.scrollingDeltaX),
                wheelDeltaY: Float(event.scrollingDeltaY)
            )
            handleGestureResult(result)
        } else {
            // Mouse scroll wheel (discrete)
            let result = editorCore.handleGestureEvent(
                type: .mouseWheel,
                points: [(Float(point.x), Float(point.y))],
                modifiers: mods,
                wheelDeltaX: Float(event.scrollingDeltaX * 40),
                wheelDeltaY: Float(event.scrollingDeltaY * 40)
            )
            handleGestureResult(result)
        }
        decorationProviderManager?.onScrollChanged()
        // Dismiss completion popup while scrolling.
        if completionPopupController?.isShowing == true {
            completionProviderManager?.dismiss()
        }
        rebuildAndRedraw()
    }

    override func magnify(with event: NSEvent) {
        resetCursorBlink()
        let point = convert(event.locationInWindow, from: nil)
        let result = editorCore.handleGestureEvent(
            type: .directScale,
            points: [(Float(point.x), Float(point.y))],
            directScale: Float(1.0 + event.magnification)
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

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        resetCursorBlink()
        textInputHandledInCurrentKeyDown = false

        let handledByInputContext = inputContext?.handleEvent(event) ?? false
        if handledByInputContext && textInputHandledInCurrentKeyDown {
            return
        }

        interpretKeyEvents([event])
        if textInputHandledInCurrentKeyDown {
            return
        }
        if handleFallbackKeyDown(event) {
            return
        }
        super.keyDown(with: event)
    }

    public func handleForwardedKeyDown(_ event: NSEvent) {
        keyDown(with: event)
    }

    private func updateCompletionPopupPosition() {
        let rect = getCursorRect()
        completionPopupController?.updatePosition(cursorX: rect.x, cursorY: rect.y, cursorHeight: rect.height)
    }

    // MARK: - NSResponder Standard Key Bindings (dispatched via doCommandBySelector:)

    override func doCommand(by selector: Selector) {
        // Completion popup keyboard interception.
        if let popup = completionPopupController, popup.isShowing {
            switch selector {
            case #selector(insertNewline(_:)):
                if popup.handleSEKeyCode(.enter) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(cancelOperation(_:)):
                if popup.handleSEKeyCode(.escape) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(moveUp(_:)):
                if popup.handleSEKeyCode(.up) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            case #selector(moveDown(_:)):
                if popup.handleSEKeyCode(.down) {
                    textInputHandledInCurrentKeyDown = true
                    return
                }
            default:
                break
            }
        }

        let mods = currentModifiers()
        var contentChanged = false
        var changedTextChanges: [TextChange] = []

        switch selector {
        case #selector(deleteBackward(_:)):
            textInputHandledInCurrentKeyDown = true
            let result = editorCore.handleKeyEvent(keyCode: .backspace, modifiers: mods)
            changedTextChanges.append(contentsOf: textChanges(from: result))
            contentChanged = true
        case #selector(deleteForward(_:)):
            textInputHandledInCurrentKeyDown = true
            let result = editorCore.handleKeyEvent(keyCode: .deleteKey, modifiers: mods)
            changedTextChanges.append(contentsOf: textChanges(from: result))
            contentChanged = true
        case #selector(insertNewline(_:)):
            textInputHandledInCurrentKeyDown = true
            // Let NewLineActionProvider handle newline first (provider decides indentation).
            // If not handled, fall back to Core behavior (KEEP_INDENT keeps indentation, NONE disables it).
            if let manager = newLineActionProviderManager {
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
                    changedTextChanges.append(contentsOf: textChanges(from: editResult))
                    contentChanged = true
                    break
                }
            }
            let result = editorCore.handleKeyEvent(keyCode: .enter, modifiers: mods)
            changedTextChanges.append(contentsOf: textChanges(from: result))
            contentChanged = true
        case #selector(insertTab(_:)):
            textInputHandledInCurrentKeyDown = true
            let result = editorCore.handleKeyEvent(keyCode: .tab, modifiers: mods)
            changedTextChanges.append(contentsOf: textChanges(from: result))
            contentChanged = true
        case #selector(insertBacktab(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            let result = editorCore.handleKeyEvent(keyCode: .tab, modifiers: shiftMods)
            changedTextChanges.append(contentsOf: textChanges(from: result))
            contentChanged = true
        case #selector(moveLeft(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .left, modifiers: mods)
        case #selector(moveRight(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .right, modifiers: mods)
        case #selector(moveWordLeft(_:)), NSSelectorFromString("moveWordBackward:"):
            textInputHandledInCurrentKeyDown = true
            var wordMods = mods
            wordMods.insert(.alt)
            _ = editorCore.handleKeyEvent(keyCode: .left, modifiers: wordMods)
        case #selector(moveWordRight(_:)), NSSelectorFromString("moveWordForward:"):
            textInputHandledInCurrentKeyDown = true
            var wordMods = mods
            wordMods.insert(.alt)
            _ = editorCore.handleKeyEvent(keyCode: .right, modifiers: wordMods)
        case #selector(moveUp(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .up, modifiers: mods)
        case #selector(moveDown(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .down, modifiers: mods)
        case #selector(moveLeftAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .left, modifiers: shiftMods)
        case #selector(moveRightAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .right, modifiers: shiftMods)
        case #selector(moveWordLeftAndModifySelection(_:)), NSSelectorFromString("moveWordBackwardAndModifySelection:"):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            shiftMods.insert(.alt)
            _ = editorCore.handleKeyEvent(keyCode: .left, modifiers: shiftMods)
        case #selector(moveWordRightAndModifySelection(_:)), NSSelectorFromString("moveWordForwardAndModifySelection:"):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            shiftMods.insert(.alt)
            _ = editorCore.handleKeyEvent(keyCode: .right, modifiers: shiftMods)
        case #selector(moveUpAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .up, modifiers: shiftMods)
        case #selector(moveDownAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .down, modifiers: shiftMods)
        case #selector(moveToBeginningOfLine(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .home, modifiers: mods)
        case #selector(moveToEndOfLine(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .end, modifiers: mods)
        case #selector(moveToBeginningOfLineAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .home, modifiers: shiftMods)
        case #selector(moveToEndOfLineAndModifySelection(_:)):
            textInputHandledInCurrentKeyDown = true
            var shiftMods = mods
            shiftMods.insert(.shift)
            _ = editorCore.handleKeyEvent(keyCode: .end, modifiers: shiftMods)
        case #selector(pageUp(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .pageUp, modifiers: mods)
        case #selector(pageDown(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .pageDown, modifiers: mods)
        case #selector(cancelOperation(_:)):
            textInputHandledInCurrentKeyDown = true
            _ = editorCore.handleKeyEvent(keyCode: .escape, modifiers: mods)
        default:
            super.doCommand(by: selector)
            return
        }

        if contentChanged {
            decorationProviderManager?.onTextChanged(changes: changedTextChanges)
            rehighlightAndRedraw()
        } else {
            rebuildAndRedraw()
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Handle Cmd+key shortcuts
        guard event.modifierFlags.contains(.command) else { return false }
        resetCursorBlink()

        // Manually trigger completion via Cmd+Space.
        if event.charactersIgnoringModifiers == " " {
            triggerCompletion()
            return true
        }

        let mods = modifiersFromEvent(event)

        switch event.charactersIgnoringModifiers {
        case "a":
            let result = editorCore.handleKeyEvent(keyCode: .a, modifiers: mods)
            if result?.handled == true { rebuildAndRedraw() }
            return true
        case "c":
            let result = editorCore.handleKeyEvent(keyCode: .c, modifiers: mods)
            if result?.handled == true {
                let text = editorCore.getSelectedText()
                if !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
            return true
        case "v":
            if let text = NSPasteboard.general.string(forType: .string) {
                let editResult = editorCore.insertText(text)
                decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
                rehighlightAndRedraw()
            }
            return true
        case "x":
            let result = editorCore.handleKeyEvent(keyCode: .x, modifiers: mods)
            if result?.handled == true {
                let text = editorCore.getSelectedText()
                if !text.isEmpty {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                decorationProviderManager?.onTextChanged(changes: textChanges(from: result))
                rehighlightAndRedraw()
            }
            return true
        case "z":
            let editResult: TextEditResultLite?
            if event.modifierFlags.contains(.shift) {
                editResult = editorCore.redo()
            } else {
                editResult = editorCore.undo()
            }
            decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
            rehighlightAndRedraw()
            return true
        default:
            return false
        }
    }

    // MARK: - NSTextInputClient

    override func insertText(_ insertString: Any) {
        textInputHandledInCurrentKeyDown = true
        insertText(insertString, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
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

        if isComposing {
            let editResult = editorCore.compositionEnd(text)
            isComposing = false
            currentMarkedRange = nil
            currentMarkedSelectionRange = nil
            decorationProviderManager?.onTextChanged(changes: textChanges(from: editResult))
        } else {
            if let replacementTextRange = textRange(for: replacementRange) {
                replaceText(startLine: replacementTextRange.startLine,
                            startColumn: replacementTextRange.startColumn,
                            endLine: replacementTextRange.endLine,
                            endColumn: replacementTextRange.endColumn,
                            newText: text)
                return
            }

            // Check if it's a special key (non-printable)
            if text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first {
                let keyCode = mapCharToKeyCode(scalar)
                if keyCode != .none {
                    let mods = currentModifiers()
                    let keyResult = editorCore.handleKeyEvent(keyCode: keyCode, modifiers: mods)
                    decorationProviderManager?.onTextChanged(changes: textChanges(from: keyResult))
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

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
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

        if !isComposing {
            editorCore.compositionStart()
            isComposing = true
        }

        let baseRange: NSRange
        if let replacementRange = normalizedReplacementRange(replacementRange) {
            baseRange = replacementRange
        } else if let currentMarkedRange {
            baseRange = currentMarkedRange
        } else {
            baseRange = currentSelectionRange() ?? NSRange(location: 0, length: 0)
        }

        currentMarkedRange = NSRange(location: baseRange.location, length: text.utf16.count)

        let selectedLocation = min(max(selectedRange.location, 0), text.utf16.count)
        let maxLength = max(text.utf16.count - selectedLocation, 0)
        let selectedLength = min(max(selectedRange.length, 0), maxLength)
        currentMarkedSelectionRange = NSRange(location: baseRange.location + selectedLocation,
                                              length: selectedLength)

        editorCore.compositionUpdate(text)
        rebuildAndRedraw()
    }

    func unmarkText() {
        resetCursorBlink()
        if isComposing {
            _ = editorCore.compositionEnd(nil)
            isComposing = false
            currentMarkedRange = nil
            currentMarkedSelectionRange = nil
            rebuildAndRedraw()
        }
    }

    func selectedRange() -> NSRange {
        if isComposing, let currentMarkedSelectionRange {
            return currentMarkedSelectionRange
        }
        return currentSelectionRange() ?? NSRange(location: 0, length: 0)
    }

    func markedRange() -> NSRange {
        if isComposing, let currentMarkedRange {
            return currentMarkedRange
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    func hasMarkedText() -> Bool {
        return isComposing
    }

    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        guard let (text, normalizedRange) = substringAndRange(for: range) else {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }
        actualRange?.pointee = normalizedRange
        return NSAttributedString(string: text)
    }

    func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        return []
    }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        // Return cursor position for IME candidate window placement
        actualRange?.pointee = isComposing ? (currentMarkedRange ?? range) : range
        guard let model = renderModel else {
            return window?.convertToScreen(frame) ?? .zero
        }
        let cursor = model.cursor
        let localRect = NSRect(x: CGFloat(cursor.position.x),
                               y: CGFloat(cursor.position.y),
                               width: 1,
                               height: CGFloat(cursor.height))
        let windowRect = convert(localRect, to: nil)
        return window?.convertToScreen(windowRect) ?? windowRect
    }

    func characterIndex(for point: NSPoint) -> Int {
        return NSNotFound
    }

    // MARK: - Helpers

    private func modifiersFromEvent(_ event: NSEvent) -> SEModifier {
        var mods = SEModifier()
        if event.modifierFlags.contains(.shift) { mods.insert(.shift) }
        if event.modifierFlags.contains(.control) { mods.insert(.ctrl) }
        if event.modifierFlags.contains(.option) { mods.insert(.alt) }
        if event.modifierFlags.contains(.command) { mods.insert(.meta) }
        return mods
    }

    private func handleFallbackKeyDown(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            return false
        }

        let mods = modifiersFromEvent(event)
        let mappedKeyCode = mapNSKeyCodeToSEKeyCode(event.keyCode)
        if mappedKeyCode != .none {
            let result = editorCore.handleKeyEvent(keyCode: mappedKeyCode, modifiers: mods)
            switch mappedKeyCode {
            case .backspace, .deleteKey, .enter, .tab:
                decorationProviderManager?.onTextChanged(changes: textChanges(from: result))
                rehighlightAndRedraw()
            default:
                rebuildAndRedraw()
            }
            return true
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
            insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        }
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
                range: SweetEditorCoreInternal.TextRange(
                    start: SweetEditorCoreInternal.TextPosition(line: change.range.start.line, column: change.range.start.column),
                    end: SweetEditorCoreInternal.TextPosition(line: change.range.end.line, column: change.range.end.column)
                ),
                newText: change.new_text
            )
        }
    }

    private func currentModifiers() -> SEModifier {
        var mods = SEModifier()
        let flags = NSEvent.modifierFlags
        if flags.contains(.shift) { mods.insert(.shift) }
        if flags.contains(.control) { mods.insert(.ctrl) }
        if flags.contains(.option) { mods.insert(.alt) }
        if flags.contains(.command) { mods.insert(.meta) }
        return mods
    }

    private func mapNSKeyCodeToSEKeyCode(_ keyCode: UInt16) -> SEKeyCode {
        switch keyCode {
        case 51: return .backspace      // Delete (backspace)
        case 48: return .tab
        case 36: return .enter          // Return
        case 76: return .enter          // Numpad Enter
        case 53: return .escape
        case 117: return .deleteKey     // Forward delete
        case 123: return .left
        case 126: return .up
        case 124: return .right
        case 125: return .down
        case 115: return .home
        case 119: return .end
        case 116: return .pageUp
        case 121: return .pageDown
        default: return .none
        }
    }

    private func mapCharToKeyCode(_ scalar: Unicode.Scalar) -> SEKeyCode {
        switch scalar.value {
        case 0x08, 0x7F: return .backspace
        case 0x09: return .tab
        case 0x0D, 0x0A: return .enter
        case 0x1B: return .escape
        case 0x03: return .enter       // NSEnterCharacter
        default: return .none
        }
    }

    // MARK: - Document helpers

    private func currentSelectionRange() -> NSRange? {
        if let selection = editorCore.getSelectionRange(),
           let start = textOffset(for: selection.startLine, column: selection.startColumn),
           let end = textOffset(for: selection.endLine, column: selection.endColumn) {
            let lower = min(start, end)
            return NSRange(location: lower, length: max(end - start, 0))
        }
        if let cursor = editorCore.getCursorPosition(),
           let offset = textOffset(for: cursor.line, column: cursor.column) {
            return NSRange(location: offset, length: 0)
        }
        return nil
    }

    private func textOffset(for line: Int, column: Int) -> Int? {
        guard let doc = document else { return nil }
        let totalLines = doc.getLineCount()
        if totalLines <= 0 {
            return 0
        }
        let clampedLine = max(0, min(line, totalLines - 1))
        var offset = 0
        if clampedLine > 0 {
            for index in 0..<clampedLine {
                let text = doc.getLineText(index)
                offset += text.utf16.count
                // The document uses '\n' as the internal line separator.
                offset += 1
            }
        }
        let lineText = doc.getLineText(clampedLine)
        let clampedColumn = max(0, min(column, lineText.utf16.count))
        offset += clampedColumn
        return offset
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

    private func substringAndRange(for range: NSRange) -> (String, NSRange)? {
        guard range.location != NSNotFound else { return nil }
        guard let doc = document else { return nil }
        let totalLength = documentUTF16Length(doc)
        let startLocation = min(max(range.location, 0), totalLength)
        let requestedEnd = range.location + range.length
        let endLocation = min(max(requestedEnd, startLocation), totalLength)
        let substring = textBetweenOffsets(doc: doc, start: startLocation, end: endLocation)
        return (substring, NSRange(location: startLocation, length: endLocation - startLocation))
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

    private func installLocalKeyMonitorIfNeeded() {
        guard localKeyDownMonitor == nil else { return }
        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard self.window?.firstResponder === self else { return event }
            guard !event.modifierFlags.contains(.command) else { return event }
            self.keyDown(with: event)
            return nil
        }
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

struct MacEditorViewRepresentable: NSViewRepresentable {
    @Binding var isDarkTheme: Bool
    @Binding var wrapModePreset: Int

    func makeNSView(context: Context) -> SweetEditorViewMacOS {
        let view = SweetEditorViewMacOS()
        return view
    }

    func updateNSView(_ nsView: SweetEditorViewMacOS, context: Context) {
        nsView.applyTheme(isDark: isDarkTheme)
        nsView.setWrapMode(wrapModePreset)
    }
}

public extension Notification.Name {
    static let editorUndo = Notification.Name("editorUndo")
    static let editorRedo = Notification.Name("editorRedo")
    static let editorSelectAll = Notification.Name("editorSelectAll")
    static let editorGetSelection = Notification.Name("editorGetSelection")
}

// MARK: - Load sample text

#endif
