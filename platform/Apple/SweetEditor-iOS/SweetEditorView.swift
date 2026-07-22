#if os(iOS)
import UIKit
@_exported import SweetEditorShared

public class SweetEditorView: UIView, UIKeyInput, UITextInput, UITextInputTraits, UIPointerInteractionDelegate, CompletionEditorAccessor {
    static let textMatrixForTopOriginDrawing = CGAffineTransform(scaleX: 1.0, y: -1.0)

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
    public var onSelectionMenuItemClick: ((SelectionMenuItem) -> Void)?
    public weak var selectionMenuItemProvider: SelectionMenuItemProvider?
    public private(set) var theme = EditorTheme.xcodeDark()
    public var editorIconProvider: EditorIconProvider? {
        didSet { rebuildAndRedraw() }
    }
    public private(set) lazy var settings = EditorSettings(
        editorTextSize: 28.0 / Float(UIScreen.main.scale),
        gutterSticky: false,
        onChange: { [weak self] change in self?.applyEditorSetting(change) }
    )

    package var editorCore: EditorCore!
    private var document: Document? { editorCore?.getDocument() }
    private var renderModel: EditorRenderModel?
    private var decorationProviderManager: DecorationProviderManager?
    private var completionProviderManager: CompletionProviderManager?
    private var completionPopupController: CompletionPopupController?
    private var selectionMenuController: SelectionMenuController?
    private let newLineActionProviderManager = NewLineActionProviderManager()
    private var pointerInteraction: UIPointerInteraction?
    private var activeTouches: [UITouch] = []
    private var cursorBlinkTimer: Timer?
    private var animationTimer: Timer?
    private var isCursorBlinkVisible = true
    private lazy var textInputConnection = InputConnection(owner: self)

    /// Current language configuration.
    public private(set) var languageConfiguration: LanguageConfiguration?

    /// Extensible metadata supplied by external callers (cast to concrete type when used).
    public var metadata: EditorMetadata?

    // UIKeyInput
    public var hasText: Bool { (document?.editingUTF16Length ?? 0) > 0 }
    public override var canBecomeFirstResponder: Bool { true }

    public override func becomeFirstResponder() -> Bool {
        guard textInputConnection.beginSession() else { return false }
        if super.becomeFirstResponder() {
            resetCursorBlink()
            return true
        }
        dispatchEditorActionResult(textInputConnection.endSession(), notifyInputDelegate: false)
        return false
    }

    public override func resignFirstResponder() -> Bool {
        dispatchEditorActionResult(textInputConnection.endSession(), notifyInputDelegate: false)
        let resigned = super.resignFirstResponder()
        if resigned {
            stopCursorBlink(hideCursor: true)
        }
        return resigned
    }

    // UITextInputTraits
    public var autocorrectionType: UITextAutocorrectionType = .no
    public var autocapitalizationType: UITextAutocapitalizationType = .none
    public var spellCheckingType: UITextSpellCheckingType = .no
    public var smartQuotesType: UITextSmartQuotesType = .no
    public var smartDashesType: UITextSmartDashesType = .no
    public var smartInsertDeleteType: UITextSmartInsertDeleteType = .no

    // UITextInput
    public var selectedTextRange: UITextRange? {
        get { textInputConnection.selectedTextRange }
        set { textInputConnection.selectedTextRange = newValue }
    }

    public var markedTextRange: UITextRange? { textInputConnection.markedTextRange }
    public var markedTextStyle: [NSAttributedString.Key: Any]?
    public var beginningOfDocument: UITextPosition { textInputConnection.beginningOfDocument() }
    public var endOfDocument: UITextPosition { textInputConnection.endOfDocument() }
    public var tokenizer: UITextInputTokenizer { textInputConnection.tokenizer }
    public weak var inputDelegate: UITextInputDelegate? {
        get { textInputConnection.inputDelegate }
        set { textInputConnection.inputDelegate = newValue }
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = UIColor(cgColor: theme.backgroundColor)
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        editorCore = EditorCore(fontSize: CGFloat(settings.editorTextSize), fontName: "Menlo")
        editorCore.setHandleConfig(EditorRenderer.selectionHandleConfig())
        editorCore.setScrollbarConfig(ScrollbarConfig(
            thickness: 5.0,
            minThumb: 48.0,
            thumbHitPadding: 16.0,
            mode: .TRANSIENT,
            thumbDraggable: true,
            trackTapMode: .DISABLED,
            fadeDelayMs: 700,
            fadeDurationMs: 300
        ))
        EditorRenderer.applyTheme(theme, core: editorCore)
        selectionMenuController = SelectionMenuController(editor: self, theme: theme)
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

        configurePointerSupport()

        let initialDocument = Document(text: "")
        _ = editorCore.loadDocument(initialDocument)
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

    public func replaceText(in range: TextRange, with text: String) {
        dispatchEditorActionResult(editorCore.replaceText(
            startLine: Int(range.start.line),
            startColumn: Int(range.start.column),
            endLine: Int(range.end.line),
            endColumn: Int(range.end.column),
            newText: text
        ))
    }

    public func deleteText(in range: TextRange) {
        dispatchEditorActionResult(editorCore.deleteText(
            startLine: Int(range.start.line),
            startColumn: Int(range.start.column),
            endLine: Int(range.end.line),
            endColumn: Int(range.end.column)
        ))
    }

    public func getSelectedText() -> String {
        editorCore.getSelectedText()
    }

    public func setSelection(_ range: TextRange) {
        dispatchEditorActionResult(editorCore.setSelection(range))
    }

    public func setKeyMap(_ bindings: [KeyBinding]) {
        dispatchEditorActionResult(editorCore.setKeyMap(bindings))
    }

    public func getSelection() -> TextRange? {
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

    public func getWordRangeAtCursor() -> TextRange {
        editorCore.getWordRangeAtCursor()
    }

    public func getWordAtCursor() -> String {
        return editorCore.getWordAtCursor()
    }

    // MARK: - LanguageConfiguration

    /// Sets language configuration and syncs bracket pairs to the Core layer.
    public func setLanguageConfiguration(_ config: LanguageConfiguration?) {
        self.languageConfiguration = config
        guard let config = config else { return }

        if let brackets = config.brackets {
            let opens = brackets.map { Int32(($0.open.unicodeScalars.first?.value ?? 0)) }
            let closes = brackets.map { Int32(($0.close.unicodeScalars.first?.value ?? 0)) }
            dispatchEditorActionResult(editorCore.setBracketPairs(openChars: opens, closeChars: closes))
        }
        if let acPairs = config.autoClosingPairs {
            let acOpens = acPairs.map { Int32(($0.open.unicodeScalars.first?.value ?? 0)) }
            let acCloses = acPairs.map { Int32(($0.close.unicodeScalars.first?.value ?? 0)) }
            dispatchEditorActionResult(editorCore.setAutoClosingPairs(openChars: acOpens, closeChars: acCloses))
        }
        if let tabSize = config.tabSize, tabSize > 0 {
            dispatchEditorActionResult(editorCore.setTabSize(tabSize))
        }
        if let insertSpaces = config.insertSpaces {
            dispatchEditorActionResult(editorCore.setInsertSpaces(insertSpaces))
        }
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

    var selectionMenuHasSelection: Bool {
        editorCore.getSelection() != nil
    }

    func selectionMenuItems() -> [SelectionMenuItem] {
        if let selectionMenuItemProvider {
            return selectionMenuItemProvider.provideSelectionMenuItems(for: self)
        }
        let hasSelection = selectionMenuHasSelection
        return [
            SelectionMenuItem(
                id: SelectionMenuItem.actionCut,
                label: "Cut",
                isEnabled: hasSelection
            ),
            SelectionMenuItem(
                id: SelectionMenuItem.actionCopy,
                label: "Copy",
                isEnabled: hasSelection
            ),
            SelectionMenuItem(
                id: SelectionMenuItem.actionPaste,
                label: "Paste"
            ),
            SelectionMenuItem(
                id: SelectionMenuItem.actionSelectAll,
                label: "Select All"
            ),
        ]
    }

    func selectionMenuAnchorRect() -> CGRect? {
        guard let selection = editorCore.getSelection() else { return nil }
        let startRect = editorCore.getPositionRect(
            line: Int(selection.start.line),
            column: Int(selection.start.column)
        )
        let endRect = editorCore.getPositionRect(
            line: Int(selection.end.line),
            column: Int(selection.end.column)
        )
        let minX = min(CGFloat(startRect.x), CGFloat(endRect.x))
        let maxX = max(CGFloat(startRect.x), CGFloat(endRect.x))
        let minY = min(CGFloat(startRect.y), CGFloat(endRect.y))
        let maxY = max(
            CGFloat(startRect.y + startRect.height),
            CGFloat(endRect.y + endRect.height)
        )
        let rawRect = CGRect(
            x: minX,
            y: minY,
            width: max(1, maxX - minX),
            height: max(1, maxY - minY)
        )
        let visibleRect = rawRect.intersection(bounds)
        return visibleRect.isNull || visibleRect.isEmpty ? nil : visibleRect
    }

    func selectionMenuCut() {
        _ = cutToClipboard()
    }

    func selectionMenuCopy() {
        _ = copyToClipboard()
    }

    func selectionMenuPaste() {
        pasteFromClipboard()
    }

    func selectionMenuSelectAll() {
        selectAll()
    }

    @discardableResult
    public func copyToClipboard() -> Bool {
        let selectedText = editorCore.getSelectedText()
        guard !selectedText.isEmpty else { return false }
        UIPasteboard.general.string = selectedText
        return true
    }

    @discardableResult
    public func cutToClipboard() -> Bool {
        guard let selection = editorCore.getSelection(), copyToClipboard() else { return false }
        deleteText(in: selection)
        return true
    }

    public func pasteFromClipboard() {
        guard let text = UIPasteboard.general.string else { return }
        dispatchEditorActionResult(editorCore.insertText(text))
    }

    public func dismissSelectionMenu() {
        selectionMenuController?.dismiss()
    }

    public var isSelectionMenuShowing: Bool {
        selectionMenuController?.isShowing == true
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let size = bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        let result = editorCore.setViewport(width: Int(size.width), height: Int(size.height))
        dispatchEditorActionResult(result)
        selectionMenuController?.updatePosition()
    }

    private func rebuildAndRedraw() {
        renderModel = editorCore.buildRenderModel()
        completionPopupController?.updatePosition()
        selectionMenuController?.updatePosition()
        setNeedsDisplay()
    }

    package func dispatchEditorActionResult(
        _ result: EditorActionResult?,
        notifyInputDelegate: Bool = true
    ) {
        guard let result else { return }
        if result.scale_changed {
            dispatchEditorActionResult(
                editorCore.syncPlatformScale(result.scale_after),
                notifyInputDelegate: notifyInputDelegate
            )
        }
        if result.hit_target.type == .NONE {
            switch result.gesture_type {
            case .TAP, .DOUBLE_TAP, .LONG_PRESS:
                becomeFirstResponder()
            default:
                break
            }
        }
        if result.gesture_type == .TAP {
            fireGestureEvents(result)
            if completionPopupController?.isShowing == true {
                completionProviderManager?.dismiss()
            }
        }
        selectionMenuController?.onEditorActionResult(result)
        updateAnimationSchedule(result)
        dispatchGestureEvents(result)
        dispatchStateEvents(result, notifyInputDelegate: notifyInputDelegate)
        if result.pointer_cursor_changed {
            pointerInteraction?.invalidate()
        }
        if result.needs_redraw {
            rebuildAndRedraw()
        }
    }

    private func dispatchStateEvents(
        _ result: EditorActionResult,
        notifyInputDelegate: Bool
    ) {
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
        if result.content_changed || !changes.isEmpty {
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
        textInputConnection.syncEditorActionResult(result)
        completionProviderManager?.update(
            for: result,
            isLinkedEditing: editorCore.isInLinkedEditing()
        )
        if notifyInputDelegate {
            if result.content_changed || !changes.isEmpty {
                inputDelegate?.textDidChange(self)
            }
            if result.cursor_changed || result.selection_changed {
                inputDelegate?.selectionDidChange(self)
            }
        }
    }

    deinit {
        _ = textInputConnection.endSession()
        completionProviderManager?.dismiss()
        selectionMenuController?.dismiss()
        cursorBlinkTimer?.invalidate()
        animationTimer?.invalidate()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            dispatchEditorActionResult(
                textInputConnection.endSession(),
                notifyInputDelegate: false
            )
            completionProviderManager?.dismiss()
            activeTouches.removeAll()
            stopCursorBlink(hideCursor: true)
            animationTimer?.invalidate()
            animationTimer = nil
            selectionMenuController?.dismiss()
        }
    }

    /// Switches the editor theme.
    public func applyTheme(_ theme: EditorTheme) {
        self.theme = theme
        EditorRenderer.applyTheme(theme, core: editorCore)
        backgroundColor = UIColor(cgColor: theme.backgroundColor)
        selectionMenuController?.applyTheme(theme)
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

    // MARK: - Drawing

    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
              let model = renderModel else { return }

        context.saveGState()
        context.textMatrix = Self.textMatrixForTopOriginDrawing

        EditorRenderer.draw(context: context,
                            model: model,
                            core: editorCore,
                            theme: theme,
                            iconProvider: editorIconProvider,
                            isCursorBlinkVisible: isCursorBlinkVisible && isFirstResponder,
                            showsSelectionHandles: isFirstResponder)

        context.restoreGState()
    }

    private func startCursorBlinkTimerIfNeeded() {
        guard cursorBlinkTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isFirstResponder else { return }
            self.isCursorBlinkVisible.toggle()
            self.setNeedsDisplay()
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
        setNeedsDisplay()
    }

    private func resetCursorBlink() {
        isCursorBlinkVisible = true
        setNeedsDisplay()
        guard isFirstResponder else {
            stopCursorBlink(hideCursor: false)
            return
        }
        cursorBlinkTimer?.invalidate()
        cursorBlinkTimer = nil
        startCursorBlinkTimerIfNeeded()
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

    // MARK: - Touch Events

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let previousCount = activeTouches.count
        for touch in touches where !activeTouches.contains(where: { $0 === touch }) {
            activeTouches.append(touch)
        }
        guard let firstTouch = activeTouches.first else { return }

        if previousCount == 0 {
            let point = firstTouch.location(in: self)
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .TOUCH_DOWN,
                points: [(Float(point.x), Float(point.y))]
            ))
        }
        if activeTouches.count > 1 {
            dispatchEditorActionResult(editorCore.handleGestureEvent(
                type: .TOUCH_POINTER_DOWN,
                points: activeTouchPoints()
            ))
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let result = editorCore.handleGestureEvent(
            type: .TOUCH_MOVE,
            points: activeTouchPoints()
        )
        dispatchEditorActionResult(result)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let endingPoint = touches.first?.location(in: self) ?? .zero
        activeTouches.removeAll { activeTouch in
            touches.contains { $0 === activeTouch }
        }

        if activeTouches.isEmpty {
            let result = editorCore.handleGestureEvent(
                type: .TOUCH_UP,
                points: [(Float(endingPoint.x), Float(endingPoint.y))]
            )
            dispatchEditorActionResult(result)
        } else {
            let result = editorCore.handleGestureEvent(
                type: .TOUCH_POINTER_UP,
                points: activeTouchPoints()
            )
            dispatchEditorActionResult(result)
            if activeTouches.count > 1 {
                dispatchEditorActionResult(editorCore.handleGestureEvent(
                    type: .TOUCH_POINTER_DOWN,
                    points: activeTouchPoints()
                ))
            }
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        let point = touches.first?.location(in: self) ?? .zero
        activeTouches.removeAll()
        let result = editorCore.handleGestureEvent(
            type: .TOUCH_CANCEL,
            points: [(Float(point.x), Float(point.y))]
        )
        dispatchEditorActionResult(result)
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

    private func activeTouchPoints() -> [(Float, Float)] {
        activeTouches.map { touch in
            let point = touch.location(in: self)
            return (Float(point.x), Float(point.y))
        }
    }

    // MARK: - iPad Pointer / Trackpad Support

    @objc private func handleHover(_ recognizer: UIHoverGestureRecognizer) {
        let point = recognizer.location(in: self)
        let floatPoint = [(Float(point.x), Float(point.y))]

        switch recognizer.state {
        case .began, .changed:
            let result = editorCore.handleGestureEvent(
                type: .MOUSE_MOVE,
                points: floatPoint
            )
            dispatchEditorActionResult(result)
        case .ended, .cancelled:
            let result = editorCore.handleGestureEvent(
                type: .MOUSE_MOVE,
                points: [(-1, -1)]
            )
            dispatchEditorActionResult(result)
        default:
            break
        }
    }

    private func configurePointerSupport() {
        let hoverRecognizer = UIHoverGestureRecognizer(target: self, action: #selector(handleHover(_:)))
        addGestureRecognizer(hoverRecognizer)

        let interaction = UIPointerInteraction(delegate: self)
        pointerInteraction = interaction
        addInteraction(interaction)
    }

    public func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
        guard renderModel?.pointer_cursor_type == .TEXT else { return nil }
        let beamLength = CGFloat(renderModel?.cursor.height ?? 20)
        return UIPointerStyle(shape: .verticalBeam(length: beamLength))
    }

    // MARK: - UIKeyInput

    public func insertText(_ text: String) {
        var committedText = text
        if text == "\n" || text == "\r" {
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
                committedText = action.text
            }
        }
        let editResult = textInputConnection.isSessionActive
            ? textInputConnection.commitText(committedText)
            : editorCore.insertText(committedText)
        dispatchEditorActionResult(editResult, notifyInputDelegate: false)
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

    public func deleteBackward() {
        let keyResult = editorCore.handleKeyEvent(keyCode: KeyCode.BACKSPACE)
        dispatchEditorActionResult(keyResult, notifyInputDelegate: false)
    }

    public func text(in range: UITextRange) -> String? {
        textInputConnection.text(in: range)
    }

    public func replace(_ range: UITextRange, withText text: String) {
        textInputConnection.replace(range, withText: text)
    }

    public func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        textInputConnection.setMarkedText(markedText, selectedRange: selectedRange)
    }

    public func unmarkText() {
        textInputConnection.unmarkText()
    }

    public func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        textInputConnection.textRange(from: fromPosition, to: toPosition)
    }

    public func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        textInputConnection.position(from: position, offset: offset)
    }

    public func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        textInputConnection.offset(from: from, to: toPosition)
    }

    public func caretRect(for position: UITextPosition) -> CGRect {
        textInputConnection.caretRect(for: position)
    }

    public func firstRect(for range: UITextRange) -> CGRect {
        textInputConnection.firstRect(for: range)
    }

    public func closestPosition(to point: CGPoint) -> UITextPosition? {
        TextInputPosition(offset: currentTextOffset())
    }

    public func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let closest = closestPosition(to: point) as? TextInputPosition,
              let nsRange = nsRange(from: range) else { return range.start }
        let clampedOffset = min(max(closest.offset, nsRange.location), nsRange.location + nsRange.length)
        return TextInputPosition(offset: clampedOffset)
    }

    public func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let lhs = position as? TextInputPosition,
              let rhs = other as? TextInputPosition else { return .orderedSame }
        if lhs.offset < rhs.offset { return .orderedAscending }
        if lhs.offset > rhs.offset { return .orderedDescending }
        return .orderedSame
    }

    public func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        switch direction {
        case .left, .up:
            return range.start
        case .right, .down:
            return range.end
        @unknown default:
            return range.end
        }
    }

    public func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let position = position as? TextInputPosition else { return nil }

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

        let start = TextInputPosition(offset: startOffset)
        let end = TextInputPosition(offset: endOffset)
        return textRange(from: start, to: end)
    }

    public func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .leftToRight
    }

    public func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}

    public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }

    public func characterRange(at point: CGPoint) -> UITextRange? {
        guard let position = closestPosition(to: point) else { return selectedTextRange }
        return textRange(from: position, to: position)
    }

    // MARK: - Physical Keyboard Support (iPad)

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            guard let key = press.key else { continue }

            // Completion popup keyboard interception (Enter/Escape/Up/Down).
            if !textInputConnection.hasComposition,
               let popup = completionPopupController,
               popup.isShowing {
                let keyCode = mapUIKeyToKeyCode(key)
                if popup.handleKeyCode(keyCode) {
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
                    selectAll()
                    handled = true
                case .keyboardC:
                    handled = copyToClipboard()
                case .keyboardV:
                    if UIPasteboard.general.string != nil {
                        pasteFromClipboard()
                        handled = true
                    }
                case .keyboardX:
                    handled = cutToClipboard()
                case .keyboardZ:
                    let editResult: EditorActionResult?
                    if key.modifierFlags.contains(.shift) {
                        editResult = editorCore.redo()
                    } else {
                        editResult = editorCore.undo()
                    }
                    dispatchEditorActionResult(editResult)
                    handled = true
                default:
                    break
                }
                continue
            }

            // Non-shortcut keys
            let keyCode = mapUIKeyToKeyCode(key)
            if keyCode != KeyCode.NONE {
                let mods = modifiersFromUIKey(key)
                let result = editorCore.handleKeyEvent(keyCode: keyCode, modifiers: mods)
                dispatchEditorActionResult(result)
                if result.handled {
                    handled = true
                }
            }
        }

        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
    }

    // MARK: - Helpers

    private func mapUIKeyToKeyCode(_ key: UIKey) -> Int32 {
        switch key.keyCode {
        case .keyboardDeleteOrBackspace: return KeyCode.BACKSPACE
        case .keyboardTab: return KeyCode.TAB
        case .keyboardReturnOrEnter: return KeyCode.ENTER
        case .keyboardEscape: return KeyCode.ESCAPE
        case .keyboardDeleteForward: return KeyCode.DELETE_KEY
        case .keyboardLeftArrow: return KeyCode.LEFT
        case .keyboardUpArrow: return KeyCode.UP
        case .keyboardRightArrow: return KeyCode.RIGHT
        case .keyboardDownArrow: return KeyCode.DOWN
        case .keyboardHome: return KeyCode.HOME
        case .keyboardEnd: return KeyCode.END
        case .keyboardPageUp: return KeyCode.PAGE_UP
        case .keyboardPageDown: return KeyCode.PAGE_DOWN
        default: return KeyCode.NONE
        }
    }

    private func modifiersFromUIKey(_ key: UIKey) -> Int32 {
        var mods = KeyModifier.NONE
        if key.modifierFlags.contains(.shift) { mods |= KeyModifier.SHIFT }
        if key.modifierFlags.contains(.control) { mods |= KeyModifier.CTRL }
        if key.modifierFlags.contains(.alternate) { mods |= KeyModifier.ALT }
        if key.modifierFlags.contains(.command) { mods |= KeyModifier.META }
        return mods
    }

    private func textChanges(from result: EditorActionResult?) -> [TextChange] {
        guard let result, result.content_changed || !result.changes.isEmpty else { return [] }
        return textChanges(from: result.changes)
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

    func documentLength() -> Int {
        document?.editingUTF16Length ?? 0
    }

    package func uiTextRange(from nsRange: NSRange) -> UITextRange? {
        guard nsRange.location != NSNotFound else { return nil }
        let start = TextInputPosition(offset: nsRange.location)
        let end = TextInputPosition(offset: nsRange.location + nsRange.length)
        return TextInputRange(start: start, end: end)
    }

    package func nsRange(from textRange: UITextRange?) -> NSRange? {
        guard let textRange,
              let start = textRange.start as? TextInputPosition,
              let end = textRange.end as? TextInputPosition else { return nil }
        let lower = min(start.offset, end.offset)
        let upper = max(start.offset, end.offset)
        return NSRange(location: lower, length: upper - lower)
    }

    package func locationForOffset(_ offset: Int) -> (line: Int, column: Int)? {
        document?.editingLocation(forUTF16Offset: offset) ?? (0, 0)
    }

    private func currentTextOffset() -> Int {
        guard let document else { return 0 }
        let cursor = editorCore.getCursorPosition()
        return document.editingUTF16Offset(
            line: Int(cursor.line),
            column: Int(cursor.column)
        )
    }

    public func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
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

    public var selectionAffinity: UITextStorageDirection {
        get { textInputConnection.selectionAffinity }
        set { textInputConnection.selectionAffinity = newValue }
    }

}

#endif
