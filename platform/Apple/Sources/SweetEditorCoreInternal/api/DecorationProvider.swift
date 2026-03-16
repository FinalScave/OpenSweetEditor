import Foundation

public struct DecorationContext {
    public let visibleStartLine: Int
    public let visibleEndLine: Int
    public let totalLineCount: Int
    /// All text changes accumulated during the current refresh debounce window.
    public let textChanges: [TextChange]
    /// Current language configuration (from LanguageConfiguration).
    public let languageConfiguration: LanguageConfiguration?

    public init(
        visibleStartLine: Int,
        visibleEndLine: Int,
        totalLineCount: Int,
        textChanges: [TextChange],
        languageConfiguration: LanguageConfiguration?
    ) {
        self.visibleStartLine = visibleStartLine
        self.visibleEndLine = visibleEndLine
        self.totalLineCount = totalLineCount
        self.textChanges = textChanges
        self.languageConfiguration = languageConfiguration
    }
}

public struct DecorationType: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let syntaxHighlight = DecorationType(rawValue: 1 << 0)
    public static let semanticHighlight = DecorationType(rawValue: 1 << 1)
    public static let inlayHint = DecorationType(rawValue: 1 << 2)
    public static let diagnostic = DecorationType(rawValue: 1 << 3)
    public static let foldRegion = DecorationType(rawValue: 1 << 4)
    public static let indentGuide = DecorationType(rawValue: 1 << 5)
    public static let bracketGuide = DecorationType(rawValue: 1 << 6)
    public static let flowGuide = DecorationType(rawValue: 1 << 7)
    public static let separatorGuide = DecorationType(rawValue: 1 << 8)
    public static let gutterIcon = DecorationType(rawValue: 1 << 9)
    public static let phantomText = DecorationType(rawValue: 1 << 10)
}

public protocol DecorationReceiver: AnyObject {
    @discardableResult
    func accept(_ result: DecorationResult) -> Bool
    var isCancelled: Bool { get }
}

public protocol DecorationProvider: AnyObject {
    var capabilities: DecorationType { get }
    func provideDecorations(context: DecorationContext, receiver: DecorationReceiver)
}

public struct DecorationResult {
    public struct SpanItem {
        public let column: UInt32
        public let length: UInt32
        public let styleId: UInt32

        public init(column: UInt32, length: UInt32, styleId: UInt32) {
            self.column = column
            self.length = length
            self.styleId = styleId
        }
    }

    public struct InlayHintItem {
        public enum Kind {
            case text(String)
            case icon(Int32)
            case color(Int32)
        }
        public let column: Int
        public let kind: Kind

        public init(column: Int, kind: Kind) {
            self.column = column
            self.kind = kind
        }
    }

    public struct DiagnosticItem {
        public let column: Int32
        public let length: Int32
        public let severity: Int32
        public let color: Int32

        public init(column: Int32, length: Int32, severity: Int32, color: Int32) {
            self.column = column
            self.length = length
            self.severity = severity
            self.color = color
        }
    }

    public struct FoldRegionItem {
        public let startLine: Int
        public let endLine: Int
        public let collapsed: Bool

        public init(startLine: Int, endLine: Int, collapsed: Bool) {
            self.startLine = startLine
            self.endLine = endLine
            self.collapsed = collapsed
        }
    }

    public struct IndentGuideItem {
        public let start: TextPosition
        public let end: TextPosition

        public init(start: TextPosition, end: TextPosition) {
            self.start = start
            self.end = end
        }
    }

    public struct BracketGuideItem {
        public let parent: TextPosition
        public let end: TextPosition
        public let children: [TextPosition]?

        public init(parent: TextPosition, end: TextPosition, children: [TextPosition]?) {
            self.parent = parent
            self.end = end
            self.children = children
        }
    }

    public struct FlowGuideItem {
        public let start: TextPosition
        public let end: TextPosition

        public init(start: TextPosition, end: TextPosition) {
            self.start = start
            self.end = end
        }
    }

    public struct SeparatorGuideItem {
        public let line: Int
        public let style: Int32
        public let count: Int32
        public let textEndColumn: UInt32

        public init(line: Int, style: Int32, count: Int32, textEndColumn: UInt32) {
            self.line = line
            self.style = style
            self.count = count
            self.textEndColumn = textEndColumn
        }
    }

    public struct PhantomTextItem {
        public let column: Int
        public let text: String

        public init(column: Int, text: String) {
            self.column = column
            self.text = text
        }
    }

    public var syntaxSpans: [Int: [SpanItem]]?
    public var semanticSpans: [Int: [SpanItem]]?
    public var inlayHints: [Int: [InlayHintItem]]?
    public var diagnostics: [Int: [DiagnosticItem]]?
    public var indentGuides: [IndentGuideItem]?
    public var bracketGuides: [BracketGuideItem]?
    public var flowGuides: [FlowGuideItem]?
    public var separatorGuides: [SeparatorGuideItem]?
    public var foldRegions: [FoldRegionItem]?
    public var gutterIcons: [Int: [Int32]]?
    public var phantomTexts: [Int: [PhantomTextItem]]?

    public init(
        syntaxSpans: [Int: [SpanItem]]? = nil,
        semanticSpans: [Int: [SpanItem]]? = nil,
        inlayHints: [Int: [InlayHintItem]]? = nil,
        diagnostics: [Int: [DiagnosticItem]]? = nil,
        indentGuides: [IndentGuideItem]? = nil,
        bracketGuides: [BracketGuideItem]? = nil,
        flowGuides: [FlowGuideItem]? = nil,
        separatorGuides: [SeparatorGuideItem]? = nil,
        foldRegions: [FoldRegionItem]? = nil,
        gutterIcons: [Int: [Int32]]? = nil,
        phantomTexts: [Int: [PhantomTextItem]]? = nil
    ) {
        self.syntaxSpans = syntaxSpans
        self.semanticSpans = semanticSpans
        self.inlayHints = inlayHints
        self.diagnostics = diagnostics
        self.indentGuides = indentGuides
        self.bracketGuides = bracketGuides
        self.flowGuides = flowGuides
        self.separatorGuides = separatorGuides
        self.foldRegions = foldRegions
        self.gutterIcons = gutterIcons
        self.phantomTexts = phantomTexts
    }
}

final class DecorationProviderManager {
    private enum RefreshReason {
        case manual
        case documentLoaded
        case textChanged
        case scrollChanged
    }

    private struct ProviderState {
        var snapshot: DecorationResult?
        weak var receiver: ManagedReceiver?
    }

    private final class ManagedReceiver: DecorationReceiver {
        private weak var manager: DecorationProviderManager?
        private weak var provider: DecorationProvider?
        private let generation: Int
        private var cancelledValue = false

        init(manager: DecorationProviderManager, provider: DecorationProvider, generation: Int) {
            self.manager = manager
            self.provider = provider
            self.generation = generation
        }

        var isCancelled: Bool {
            cancelledValue || (manager?.generation != generation)
        }

        func cancel() {
            cancelledValue = true
        }

        @discardableResult
        func accept(_ result: DecorationResult) -> Bool {
            guard let manager, let provider, !isCancelled else { return false }
            DispatchQueue.main.async { [weak manager] in
                manager?.onReceiverAccept(provider: provider, generation: self.generation, patch: result)
            }
            return true
        }
    }

    private let core: SweetEditorCore
    private let visibleLineRangeProvider: () -> (Int, Int)
    private let totalLineCountProvider: () -> Int
    private let languageConfigurationProvider: () -> LanguageConfiguration?
    private let onApplied: () -> Void

    private var providers: [DecorationProvider] = []
    private var states: [ObjectIdentifier: ProviderState] = [:]
    private var pendingTextChanges: [TextChange] = []
    private var pendingRefreshReason: RefreshReason?
    private var lastRefreshedVisibleRange: (start: Int, end: Int)?
    private var debounceItem: DispatchWorkItem?
    private var applyScheduled = false
    private var generation = 0

    init(core: SweetEditorCore,
         visibleLineRangeProvider: @escaping () -> (Int, Int),
         totalLineCountProvider: @escaping () -> Int,
         languageConfigurationProvider: @escaping () -> LanguageConfiguration?,
         onApplied: @escaping () -> Void) {
        self.core = core
        self.visibleLineRangeProvider = visibleLineRangeProvider
        self.totalLineCountProvider = totalLineCountProvider
        self.languageConfigurationProvider = languageConfigurationProvider
        self.onApplied = onApplied
    }

    func addProvider(_ provider: DecorationProvider) {
        if providers.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(provider) }) { return }
        providers.append(provider)
        states[ObjectIdentifier(provider)] = ProviderState()
        requestRefresh()
    }

    func removeProvider(_ provider: DecorationProvider) {
        providers.removeAll { ObjectIdentifier($0) == ObjectIdentifier(provider) }
        let key = ObjectIdentifier(provider)
        states[key]?.receiver?.cancel()
        states.removeValue(forKey: key)
        scheduleApply()
    }

    func requestRefresh() { scheduleRefresh(delay: 0, changes: nil, reason: .manual) }
    func onDocumentLoaded() { scheduleRefresh(delay: 0, changes: nil, reason: .documentLoaded) }
    func onTextChanged(changes: [TextChange]) { scheduleRefresh(delay: 0.05, changes: changes, reason: .textChanged) }
    func onScrollChanged() { scheduleRefresh(delay: 0.05, changes: nil, reason: .scrollChanged) }

    private func scheduleRefresh(delay: TimeInterval, changes: [TextChange]?, reason: RefreshReason) {
        if let changes {
            pendingTextChanges.append(contentsOf: changes)
        }
        if reason != .scrollChanged || pendingRefreshReason == nil {
            pendingRefreshReason = reason
        }
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.doRefresh() }
        debounceItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func doRefresh() {
        let reason = pendingRefreshReason ?? .manual
        pendingRefreshReason = nil

        let visible = visibleLineRangeProvider()
        let textChanges = pendingTextChanges
        pendingTextChanges.removeAll(keepingCapacity: true)

        if reason == .scrollChanged,
           textChanges.isEmpty,
           let lastVisible = lastRefreshedVisibleRange,
           lastVisible.start == visible.0,
           lastVisible.end == visible.1 {
            return
        }

        generation += 1
        let currentGeneration = generation
        lastRefreshedVisibleRange = (start: visible.0, end: visible.1)
        let context = DecorationContext(
            visibleStartLine: visible.0,
            visibleEndLine: visible.1,
            totalLineCount: totalLineCountProvider(),
            textChanges: textChanges,
            languageConfiguration: languageConfigurationProvider()
        )

        for provider in providers {
            let key = ObjectIdentifier(provider)
            var state = states[key] ?? ProviderState()
            state.receiver?.cancel()
            let receiver = ManagedReceiver(manager: self, provider: provider, generation: currentGeneration)
            state.receiver = receiver
            states[key] = state
            provider.provideDecorations(context: context, receiver: receiver)
        }
    }

    private func onReceiverAccept(provider: DecorationProvider, generation: Int, patch: DecorationResult) {
        guard generation == self.generation else { return }
        let key = ObjectIdentifier(provider)
        var state = states[key] ?? ProviderState()
        if state.snapshot == nil { state.snapshot = DecorationResult() }
        mergePatch(into: &state.snapshot!, patch: patch)
        states[key] = state
        scheduleApply()
    }

    private func scheduleApply() {
        if applyScheduled { return }
        applyScheduled = true
        DispatchQueue.main.async { [weak self] in self?.applyMerged() }
    }

    private func applyMerged() {
        applyScheduled = false

        var syntaxSpans: [Int: [DecorationResult.SpanItem]] = [:]
        var semanticSpans: [Int: [DecorationResult.SpanItem]] = [:]
        var inlayHints: [Int: [DecorationResult.InlayHintItem]] = [:]
        var diagnostics: [Int: [DecorationResult.DiagnosticItem]] = [:]
        var indentGuides: [DecorationResult.IndentGuideItem]?
        var bracketGuides: [DecorationResult.BracketGuideItem]?
        var flowGuides: [DecorationResult.FlowGuideItem]?
        var separatorGuides: [DecorationResult.SeparatorGuideItem]?
        var foldRegions: [DecorationResult.FoldRegionItem] = []
        var gutterIcons: [Int: [Int32]] = [:]
        var phantomTexts: [Int: [DecorationResult.PhantomTextItem]] = [:]

        for provider in providers {
            guard let snapshot = states[ObjectIdentifier(provider)]?.snapshot else { continue }
            appendMap(&syntaxSpans, snapshot.syntaxSpans)
            appendMap(&semanticSpans, snapshot.semanticSpans)
            appendMap(&inlayHints, snapshot.inlayHints)
            appendMap(&diagnostics, snapshot.diagnostics)
            appendMap(&gutterIcons, snapshot.gutterIcons)
            appendMap(&phantomTexts, snapshot.phantomTexts)

            if let v = snapshot.indentGuides { indentGuides = v }
            if let v = snapshot.bracketGuides { bracketGuides = v }
            if let v = snapshot.flowGuides { flowGuides = v }
            if let v = snapshot.separatorGuides { separatorGuides = v }
            if let v = snapshot.foldRegions { foldRegions.append(contentsOf: v) }
        }

        core.clearHighlights(layer: 0)
        if !syntaxSpans.isEmpty {
            let converted = syntaxSpans.mapValues {
                $0.map { SweetEditorCore.StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            core.setBatchLineSpans(layer: 0, spansByLine: converted)
        }
        core.clearHighlights(layer: 1)
        if !semanticSpans.isEmpty {
            let converted = semanticSpans.mapValues {
                $0.map { SweetEditorCore.StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            core.setBatchLineSpans(layer: 1, spansByLine: converted)
        }

        core.clearInlayHints()
        if !inlayHints.isEmpty {
            let converted = inlayHints.mapValues { items in
                items.map { item in
                    switch item.kind {
                    case .text(let text):
                        return SweetEditorCore.InlayHintPayload.text(column: item.column, text: text)
                    case .icon(let iconId):
                        return SweetEditorCore.InlayHintPayload.icon(column: item.column, iconId: iconId)
                    case .color(let color):
                        return SweetEditorCore.InlayHintPayload.color(column: item.column, color: color)
                    }
                }
            }
            core.setBatchLineInlayHints(converted)
        }

        core.clearDiagnostics()
        if !diagnostics.isEmpty {
            let converted = diagnostics.mapValues { items in
                items.map {
                    SweetEditorCore.DiagnosticItem(
                        column: $0.column,
                        length: $0.length,
                        severity: $0.severity,
                        color: $0.color
                    )
                }
            }
            core.setBatchLineDiagnostics(converted)
        }

        core.clearGuides()
        if let indentGuides {
            core.setIndentGuides(indentGuides.map {
                SweetEditorCore.IndentGuidePayload(
                    startLine: $0.start.line,
                    startColumn: $0.start.column,
                    endLine: $0.end.line,
                    endColumn: $0.end.column
                )
            })
        }
        if let bracketGuides {
            core.setBracketGuides(bracketGuides.map { item in
                SweetEditorCore.BracketGuidePayload(
                    parentLine: item.parent.line,
                    parentColumn: item.parent.column,
                    endLine: item.end.line,
                    endColumn: item.end.column,
                    children: (item.children ?? []).map { (line: $0.line, column: $0.column) }
                )
            })
        }
        if let flowGuides {
            core.setFlowGuides(flowGuides.map {
                SweetEditorCore.FlowGuidePayload(
                    startLine: $0.start.line,
                    startColumn: $0.start.column,
                    endLine: $0.end.line,
                    endColumn: $0.end.column
                )
            })
        }
        if let separatorGuides {
            core.setSeparatorGuides(separatorGuides.map {
                SweetEditorCore.SeparatorGuidePayload(
                    line: Int32($0.line),
                    style: $0.style,
                    count: $0.count,
                    textEndColumn: $0.textEndColumn
                )
            })
        }

        if !foldRegions.isEmpty {
            core.setFoldRegions(
                foldRegions.map {
                    SweetEditorCore.FoldRegion(startLine: $0.startLine, endLine: $0.endLine, collapsed: $0.collapsed)
                }
            )
        }

        core.clearGutterIcons()
        if !gutterIcons.isEmpty {
            let converted = gutterIcons.mapValues { iconIds in
                iconIds.map { SweetEditorCore.GutterIcon(iconId: $0) }
            }
            core.setBatchLineGutterIcons(converted)
        }

        core.clearPhantomTexts()
        if !phantomTexts.isEmpty {
            let converted = phantomTexts.mapValues { items in
                items.map { SweetEditorCore.PhantomTextPayload(column: $0.column, text: $0.text) }
            }
            core.setBatchLinePhantomTexts(converted)
        }

        onApplied()
    }

    private func mergePatch(into target: inout DecorationResult, patch: DecorationResult) {
        if let v = patch.syntaxSpans { target.syntaxSpans = v }
        if let v = patch.semanticSpans { target.semanticSpans = v }
        if let v = patch.inlayHints { target.inlayHints = v }
        if let v = patch.diagnostics { target.diagnostics = v }
        if let v = patch.indentGuides { target.indentGuides = v }
        if let v = patch.bracketGuides { target.bracketGuides = v }
        if let v = patch.flowGuides { target.flowGuides = v }
        if let v = patch.separatorGuides { target.separatorGuides = v }
        if let v = patch.foldRegions { target.foldRegions = v }
        if let v = patch.gutterIcons { target.gutterIcons = v }
        if let v = patch.phantomTexts { target.phantomTexts = v }
    }

    private func appendMap<T>(_ target: inout [Int: [T]], _ patch: [Int: [T]]?) {
        guard let patch else { return }
        for (line, values) in patch {
            var arr = target[line] ?? []
            arr.append(contentsOf: values)
            target[line] = arr
        }
    }
}
