#if os(iOS)
import UIKit
import SwiftUI
import SweetEditorCoreInternal

public final class SweetEditorViewiOS: UIView {
    private let editorView = IOSEditorView(frame: .zero)

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

    public var editorIconProvider: EditorIconProvider? {
        get { editorView.editorIconProvider }
        set { editorView.editorIconProvider = newValue }
    }

    public func setEditorIconProvider(_ provider: EditorIconProvider?) {
        editorView.editorIconProvider = provider
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

    public func setLineSpans(line: Int, layer: SpanLayer, spans: [SweetEditorCore.StyleSpan]) {
        editorView.setLineSpans(line: line, layer: layer, spans: spans)
    }

    public func setBatchLineSpans(layer: SpanLayer, spansByLine: [Int: [SweetEditorCore.StyleSpan]]) {
        editorView.setBatchLineSpans(layer: layer, spansByLine: spansByLine)
    }

    public func setLineInlayHints(line: Int, hints: [SweetEditorCore.InlayHintPayload]) {
        editorView.setLineInlayHints(line: line, hints: hints)
    }

    public func setBatchLineInlayHints(_ hintsByLine: [Int: [SweetEditorCore.InlayHintPayload]]) {
        editorView.setBatchLineInlayHints(hintsByLine)
    }

    public func setLinePhantomTexts(line: Int, phantoms: [SweetEditorCore.PhantomTextPayload]) {
        editorView.setLinePhantomTexts(line: line, phantoms: phantoms)
    }

    public func setBatchLinePhantomTexts(_ phantomsByLine: [Int: [SweetEditorCore.PhantomTextPayload]]) {
        editorView.setBatchLinePhantomTexts(phantomsByLine)
    }

    public func setLineGutterIcons(line: Int, icons: [SweetEditorCore.GutterIcon]) {
        editorView.setLineGutterIcons(line: line, icons: icons)
    }

    public func setBatchLineGutterIcons(_ iconsByLine: [Int: [SweetEditorCore.GutterIcon]]) {
        editorView.setBatchLineGutterIcons(iconsByLine)
    }

    public func setMaxGutterIcons(_ count: UInt32) {
        editorView.setMaxGutterIcons(count)
    }

    public func setScale(_ scale: Float) {
        editorView.setScale(scale)
    }

    public func setLineDiagnostics(line: Int, items: [SweetEditorCore.DiagnosticItem]) {
        editorView.setLineDiagnostics(line: line, items: items)
    }

    public func setBatchLineDiagnostics(_ diagnosticsByLine: [Int: [SweetEditorCore.DiagnosticItem]]) {
        editorView.setBatchLineDiagnostics(diagnosticsByLine)
    }

    public func setIndentGuides(_ guides: [SweetEditorCore.IndentGuidePayload]) {
        editorView.setIndentGuides(guides)
    }

    public func setBracketGuides(_ guides: [SweetEditorCore.BracketGuidePayload]) {
        editorView.setBracketGuides(guides)
    }

    public func setFlowGuides(_ guides: [SweetEditorCore.FlowGuidePayload]) {
        editorView.setFlowGuides(guides)
    }

    public func setSeparatorGuides(_ guides: [SweetEditorCore.SeparatorGuidePayload]) {
        editorView.setSeparatorGuides(guides)
    }

    public func setFoldRegions(_ regions: [SweetEditorCore.FoldRegion]) {
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

    public func clearGuides() {
        editorView.clearGuides()
    }

    public func clearDiagnostics() {
        editorView.clearDiagnostics()
    }

    public func documentLines() -> [String] {
        editorView.documentLines()
    }

    public func addDecorationProvider(_ provider: DecorationProvider) {
        editorView.addDecorationProvider(provider)
    }

    public func removeDecorationProvider(_ provider: DecorationProvider) {
        editorView.removeDecorationProvider(provider)
    }

    public func requestDecorationRefresh() {
        editorView.requestDecorationRefresh()
    }

    // MARK: - Completion Providers

    public func addCompletionProvider(_ provider: CompletionProvider) {
        editorView.addCompletionProvider(provider)
    }

    public func removeCompletionProvider(_ provider: CompletionProvider) {
        editorView.removeCompletionProvider(provider)
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

    public init(
        isDarkTheme: Bool = false,
        onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)? = nil,
        onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)? = nil,
        onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)? = nil
    ) {
        self.isDarkTheme = isDarkTheme
        self.onFoldToggle = onFoldToggle
        self.onInlayHintClick = onInlayHintClick
        self.onGutterIconClick = onGutterIconClick
    }

    public func makeUIView(context: Context) -> SweetEditorViewiOS {
        let view = SweetEditorViewiOS(frame: .zero)
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        return view
    }

    public func updateUIView(_ uiView: SweetEditorViewiOS, context: Context) {
        uiView.applyTheme(isDark: isDarkTheme)
        uiView.onFoldToggle = onFoldToggle
        uiView.onInlayHintClick = onInlayHintClick
        uiView.onGutterIconClick = onGutterIconClick
    }
}
#endif
