#if os(iOS)
import UIKit
import SwiftUI
import SweetEditorCoreInternal

public final class SweetEditorViewiOS: UIView {
    private let editorView = IOSEditorView(frame: .zero)
    public var onDocumentTextChanged: ((String) -> Void)?
    public var selectionMenuItemProvider: SweetEditorSelectionMenuItemProvider? {
        didSet {
            guard selectionMenuItemProvider != nil else {
                editorView.selectionMenuItemsProvider = nil
                return
            }
            editorView.selectionMenuItemsProvider = { [weak self] in
                guard let self, let provider = self.selectionMenuItemProvider else { return [] }
                return provider.provideSelectionMenuItems(for: self)
            }
        }
    }

    public var settings: EditorSettings {
        editorView.settings
    }

    public var onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)? {
        get { editorView.onFoldToggle }
        set { editorView.onFoldToggle = newValue }
    }

    public var onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)? {
        get { editorView.onInlayHintClick }
        set { editorView.onInlayHintClick = newValue }
    }

    public var onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)? {
        get { editorView.onGutterIconClick }
        set { editorView.onGutterIconClick = newValue }
    }

    public var onCodeLensClick: ((SweetEditorCodeLensClickEvent) -> Void)? {
        get { editorView.onCodeLensClick }
        set { editorView.onCodeLensClick = newValue }
    }

    public var onLinkClick: ((SweetEditorLinkClickEvent) -> Void)? {
        get { editorView.onLinkClick }
        set { editorView.onLinkClick = newValue }
    }

    public var onSelectionMenuItemClick: ((SweetEditorSelectionMenuItem) -> Void)? {
        get { editorView.onSelectionMenuItemClick }
        set { editorView.onSelectionMenuItemClick = newValue }
    }

    public var editorIconProvider: EditorIconProvider? {
        get { editorView.editorIconProvider }
        set { editorView.editorIconProvider = newValue }
    }

    public func setEditorIconProvider(_ provider: EditorIconProvider?) {
        editorView.editorIconProvider = provider
    }

    public func setSelectionMenuItemProvider(_ provider: SweetEditorSelectionMenuItemProvider?) {
        selectionMenuItemProvider = provider
    }

    public func dismissSelectionMenu() {
        editorView.dismissSelectionMenu()
    }

    public var isSelectionMenuShowing: Bool {
        editorView.isSelectionMenuShowing
    }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViewHierarchy()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewHierarchy()
    }

    public func applyTheme(isDark: Bool) {
        editorView.applyTheme(isDark ? .dark() : .light())
    }

    public func loadDocument(text: String) {
        editorView.loadDocument(text: text)
    }

    public func search(_ request: SearchRequest) {
        editorView.search(request)
    }

    public func findNextSearchMatch() {
        editorView.findNextSearchMatch()
    }

    public func findPreviousSearchMatch() {
        editorView.findPreviousSearchMatch()
    }

    public func replaceCurrentSearchMatch(_ replacement: String) {
        editorView.replaceCurrentSearchMatch(replacement)
    }

    public func replaceAllSearchMatches(_ replacement: String) {
        editorView.replaceAllSearchMatches(replacement)
    }

    public func undo() {
        editorView.undo()
    }

    public func redo() {
        editorView.redo()
    }

    public func canUndo() -> Bool {
        editorView.canUndo()
    }

    public func canRedo() -> Bool {
        editorView.canRedo()
    }

    public func clearSearch() {
        editorView.clearSearch()
    }

    public func getSearchState() -> SearchState {
        editorView.getSearchState()
    }

    public func insertText(_ text: String) {
        editorView.insertText(text)
    }

    /// Inserts text at the specified document position.
    public func insertText(at position: TextPosition, text: String) {
        editorView.insertText(at: position, text: text)
    }

    /// Applies multiple text edits as one undoable operation.
    public func applyTextEdits(_ edits: [TextEdit]) {
        editorView.applyTextEdits(edits)
    }

    public func applyDecorations(_ decorations: EditorResolvedDecorations, clearExisting: Bool = true) {
        editorView.applyDecorations(decorations, clearExisting: clearExisting)
    }

    public func clearAllDecorations() {
        editorView.clearAllDecorations()
    }

    public func registerStyle(styleId: UInt32, color: Int32, fontStyle: Int32) {
        editorView.registerStyle(styleId: styleId, color: color, fontStyle: fontStyle)
    }

    public func registerStyle(styleId: UInt32, color: Int32, backgroundColor: Int32, fontStyle: Int32) {
        editorView.registerStyle(styleId: styleId, color: color, backgroundColor: backgroundColor, fontStyle: fontStyle)
    }

    public func setLineSpans(line: Int, layer: SpanLayer, spans: [StyleSpan]) {
        editorView.setLineSpans(line: line, layer: layer, spans: spans)
    }

    public func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [StyleSpan]]) {
        editorView.setBatchLineSpans(layer: layer, spansByLine: spansByLine)
    }

    public func setLineInlayHints(line: Int, hints: [InlayHint]) {
        editorView.setLineInlayHints(line: line, hints: hints)
    }

    public func setBatchLineInlayHints(_ hintsByLine: [Int: [InlayHint]]) {
        editorView.setBatchLineInlayHints(hintsByLine)
    }

    public func setLinePhantomTexts(line: Int, phantoms: [PhantomText]) {
        editorView.setLinePhantomTexts(line: line, phantoms: phantoms)
    }

    public func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [PhantomText]]) {
        editorView.setBatchLinePhantomTexts(phantomsByLine)
    }

    public func setLineGutterIcons(line: Int, icons: [GutterIcon]) {
        editorView.setLineGutterIcons(line: line, icons: icons)
    }

    public func setBatchLineGutterIcons(_ iconsByLine: [Int: [GutterIcon]]) {
        editorView.setBatchLineGutterIcons(iconsByLine)
    }

    public func setLineCodeLens(line: Int, items: [CodeLensItem]) {
        editorView.setLineCodeLens(line: line, items: items)
    }

    public func setBatchLineCodeLens(_ itemsByLine: [Int: [CodeLensItem]]) {
        editorView.setBatchLineCodeLens(itemsByLine)
    }

    public func setLineLinks(line: Int, links: [LinkSpan]) {
        editorView.setLineLinks(line: line, links: links)
    }

    public func setBatchLineLinks(_ linksByLine: [Int: [LinkSpan]]) {
        editorView.setBatchLineLinks(linksByLine)
    }

    public func getLinkTargetAt(line: Int, column: Int) -> String {
        editorView.getLinkTargetAt(line: line, column: column)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setMaxGutterIcons(_ count: UInt32) {
        editorView.setMaxGutterIcons(count)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setFoldArrowMode(_ mode: FoldArrowMode) {
        editorView.setFoldArrowMode(mode)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setLineSpacing(add: Float, mult: Float) {
        editorView.setLineSpacing(add: add, mult: mult)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setContentStartPadding(_ padding: Float) {
        editorView.setContentStartPadding(padding)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setShowSplitLine(_ show: Bool) {
        editorView.setShowSplitLine(show)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setCurrentLineRenderMode(_ mode: CurrentLineRenderMode) {
        editorView.setCurrentLineRenderMode(mode)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setRenderWhitespace(_ mode: WhitespaceRenderMode) {
        editorView.setRenderWhitespace(mode)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setRenderLineBreaks(_ enabled: Bool) {
        editorView.setRenderLineBreaks(enabled)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setReadOnly(_ readOnly: Bool) {
        editorView.setReadOnly(readOnly)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setWrapMode(_ mode: Int) {
        editorView.setWrapMode(mode)
    }

    /// Compatibility wrapper for callers not yet migrated to `settings`.
    public func setScale(_ scale: Float) {
        editorView.setScale(scale)
    }

    public func setLineDiagnostics(line: Int, items: [Diagnostic]) {
        editorView.setLineDiagnostics(line: line, items: items)
    }

    public func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [Diagnostic]]) {
        editorView.setBatchLineDiagnostics(diagnosticsByLine)
    }

    public func setLineDocumentHighlights(line: Int, items: [DocumentHighlight]) {
        editorView.setLineDocumentHighlights(line: line, items: items)
    }

    public func setBatchLineDocumentHighlights(_ highlightsByLine: [Int: [DocumentHighlight]]) {
        editorView.setBatchLineDocumentHighlights(highlightsByLine)
    }

    public func setIndentGuides(_ guides: [IndentGuide]) {
        editorView.setIndentGuides(guides)
    }

    public func setBracketGuides(_ guides: [BracketGuide]) {
        editorView.setBracketGuides(guides)
    }

    public func setFlowGuides(_ guides: [FlowGuide]) {
        editorView.setFlowGuides(guides)
    }

    public func setSeparatorGuides(_ guides: [SeparatorGuide]) {
        editorView.setSeparatorGuides(guides)
    }

    public func setFoldRegions(_ regions: [FoldRegion]) {
        editorView.setFoldRegions(regions)
    }

    public func clearHighlights() {
        editorView.clearHighlights()
    }

    public func clearHighlights(layer: SpanLayer) {
        editorView.clearHighlights(layer: layer)
    }

    public func clearInlayHints() {
        editorView.clearInlayHints()
    }

    public func clearPhantomTexts() {
        editorView.clearPhantomTexts()
    }

    public func clearGutterIcons() {
        editorView.clearGutterIcons()
    }

    public func clearCodeLens() {
        editorView.clearCodeLens()
    }

    public func clearLinks() {
        editorView.clearLinks()
    }

    public func clearGuides() {
        editorView.clearGuides()
    }

    public func clearDiagnostics() {
        editorView.clearDiagnostics()
    }

    public func clearDocumentHighlights() {
        editorView.clearDocumentHighlights()
    }

    public func documentLines() -> [String] {
        editorView.documentLines()
    }

    public func attachDecorationProvider(_ provider: DecorationProvider) {
        editorView.attachDecorationProvider(provider)
    }

    public func detachDecorationProvider(_ provider: DecorationProvider) {
        editorView.detachDecorationProvider(provider)
    }

    public func requestDecorationRefresh() {
        editorView.requestDecorationRefresh()
    }

    // MARK: - Completion Providers

    public func attachCompletionProvider(_ provider: CompletionProvider) {
        editorView.attachCompletionProvider(provider)
    }

    public func detachCompletionProvider(_ provider: CompletionProvider) {
        editorView.detachCompletionProvider(provider)
    }

    public func triggerCompletion() {
        editorView.triggerCompletion()
    }

    public func showCompletionItems(_ items: [CompletionItem]) {
        editorView.showCompletionItems(items)
    }

    public func dismissCompletion() {
        editorView.dismissCompletion()
    }

    private func setupViewHierarchy() {
        editorView.onDocumentTextChanged = { [weak self] text in
            self?.onDocumentTextChanged?(text)
        }
        editorView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(editorView)
        NSLayoutConstraint.activate([
            editorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorView.topAnchor.constraint(equalTo: topAnchor),
            editorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

public struct SweetEditorSwiftUIViewiOS: UIViewRepresentable {
    public let isDarkTheme: Bool
    public let onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    public let onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    public let onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?
    public let onCodeLensClick: ((SweetEditorCodeLensClickEvent) -> Void)?
    public let onLinkClick: ((SweetEditorLinkClickEvent) -> Void)?

    public init(
        isDarkTheme: Bool = false,
        onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)? = nil,
        onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)? = nil,
        onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)? = nil,
        onCodeLensClick: ((SweetEditorCodeLensClickEvent) -> Void)? = nil,
        onLinkClick: ((SweetEditorLinkClickEvent) -> Void)? = nil
    ) {
        self.isDarkTheme = isDarkTheme
        self.onFoldToggle = onFoldToggle
        self.onInlayHintClick = onInlayHintClick
        self.onGutterIconClick = onGutterIconClick
        self.onCodeLensClick = onCodeLensClick
        self.onLinkClick = onLinkClick
    }

    public func makeUIView(context: Context) -> SweetEditorViewiOS {
        let view = SweetEditorViewiOS(frame: .zero)
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        view.onCodeLensClick = onCodeLensClick
        view.onLinkClick = onLinkClick
        return view
    }

    public func updateUIView(_ uiView: SweetEditorViewiOS, context: Context) {
        uiView.applyTheme(isDark: isDarkTheme)
        uiView.onFoldToggle = onFoldToggle
        uiView.onInlayHintClick = onInlayHintClick
        uiView.onGutterIconClick = onGutterIconClick
        uiView.onCodeLensClick = onCodeLensClick
        uiView.onLinkClick = onLinkClick
    }
}
#endif
