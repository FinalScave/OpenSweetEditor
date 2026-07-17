import Foundation

public struct DecorationContext {
    public let visibleLineRange: IntRange
    public let totalLineCount: Int
    /// All text changes accumulated during the current refresh debounce window.
    public let textChanges: [TextChange]
    /// Current language configuration (from LanguageConfiguration).
    public let languageConfiguration: LanguageConfiguration?

    public init(
        visibleLineRange: IntRange,
        totalLineCount: Int,
        textChanges: [TextChange],
        languageConfiguration: LanguageConfiguration?
    ) {
        self.visibleLineRange = visibleLineRange
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
    public static let overlayHighlight = DecorationType(rawValue: 1 << 2)
    public static let inlayHint = DecorationType(rawValue: 1 << 3)
    public static let diagnostic = DecorationType(rawValue: 1 << 4)
    public static let foldRegion = DecorationType(rawValue: 1 << 5)
    public static let indentGuide = DecorationType(rawValue: 1 << 6)
    public static let bracketGuide = DecorationType(rawValue: 1 << 7)
    public static let flowGuide = DecorationType(rawValue: 1 << 8)
    public static let separatorGuide = DecorationType(rawValue: 1 << 9)
    public static let gutterIcon = DecorationType(rawValue: 1 << 10)
    public static let phantomText = DecorationType(rawValue: 1 << 11)
    public static let codeLens = DecorationType(rawValue: 1 << 12)
    public static let link = DecorationType(rawValue: 1 << 13)
    public static let documentHighlight = DecorationType(rawValue: 1 << 14)
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

public enum DecorationApplyMode {
    case merge
    case replaceAll
    case replaceRange
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

        public init(column: Int32, length: Int32, severity: Int32) {
            self.column = column
            self.length = length
            self.severity = severity
        }
    }

    public struct DocumentHighlightItem {
        public let column: Int32
        public let length: Int32
        public let kind: DocumentHighlightKind

        public init(column: Int32, length: Int32, kind: DocumentHighlightKind = .TEXT) {
            self.column = column
            self.length = length
            self.kind = kind
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

    public struct CodeLensItem {
        public let column: Int
        public let text: String
        public let commandId: Int32

        public init(column: Int, text: String, commandId: Int32) {
            self.column = column
            self.text = text
            self.commandId = commandId
        }
    }

    public struct LinkSpanItem {
        public let column: Int
        public let length: Int
        public let target: String

        public init(column: Int, length: Int, target: String) {
            self.column = column
            self.length = length
            self.target = target
        }
    }

    public var syntaxSpans: [Int: [SpanItem]]?
    public var semanticSpans: [Int: [SpanItem]]?
    public var overlaySpans: [Int: [SpanItem]]?
    public var inlayHints: [Int: [InlayHintItem]]?
    public var diagnostics: [Int: [DiagnosticItem]]?
    public var documentHighlights: [Int: [DocumentHighlightItem]]?
    public var indentGuides: [IndentGuideItem]?
    public var bracketGuides: [BracketGuideItem]?
    public var flowGuides: [FlowGuideItem]?
    public var separatorGuides: [SeparatorGuideItem]?
    public var foldRegions: [FoldRegionItem]?
    public var gutterIcons: [Int: [Int32]]?
    public var phantomTexts: [Int: [PhantomTextItem]]?
    public var codeLensItems: [Int: [CodeLensItem]]?
    public var links: [Int: [LinkSpanItem]]?
    public var syntaxSpansMode: DecorationApplyMode
    public var semanticSpansMode: DecorationApplyMode
    public var overlaySpansMode: DecorationApplyMode
    public var inlayHintsMode: DecorationApplyMode
    public var diagnosticsMode: DecorationApplyMode
    public var documentHighlightsMode: DecorationApplyMode
    public var indentGuidesMode: DecorationApplyMode
    public var bracketGuidesMode: DecorationApplyMode
    public var flowGuidesMode: DecorationApplyMode
    public var separatorGuidesMode: DecorationApplyMode
    public var foldRegionsMode: DecorationApplyMode
    public var gutterIconsMode: DecorationApplyMode
    public var phantomTextsMode: DecorationApplyMode
    public var codeLensItemsMode: DecorationApplyMode
    public var linksMode: DecorationApplyMode

    public init(
        syntaxSpans: [Int: [SpanItem]]? = nil,
        semanticSpans: [Int: [SpanItem]]? = nil,
        overlaySpans: [Int: [SpanItem]]? = nil,
        inlayHints: [Int: [InlayHintItem]]? = nil,
        diagnostics: [Int: [DiagnosticItem]]? = nil,
        documentHighlights: [Int: [DocumentHighlightItem]]? = nil,
        indentGuides: [IndentGuideItem]? = nil,
        bracketGuides: [BracketGuideItem]? = nil,
        flowGuides: [FlowGuideItem]? = nil,
        separatorGuides: [SeparatorGuideItem]? = nil,
        foldRegions: [FoldRegionItem]? = nil,
        gutterIcons: [Int: [Int32]]? = nil,
        phantomTexts: [Int: [PhantomTextItem]]? = nil,
        codeLensItems: [Int: [CodeLensItem]]? = nil,
        links: [Int: [LinkSpanItem]]? = nil,
        syntaxSpansMode: DecorationApplyMode = .merge,
        semanticSpansMode: DecorationApplyMode = .merge,
        overlaySpansMode: DecorationApplyMode = .merge,
        inlayHintsMode: DecorationApplyMode = .merge,
        diagnosticsMode: DecorationApplyMode = .merge,
        documentHighlightsMode: DecorationApplyMode = .merge,
        indentGuidesMode: DecorationApplyMode = .merge,
        bracketGuidesMode: DecorationApplyMode = .merge,
        flowGuidesMode: DecorationApplyMode = .merge,
        separatorGuidesMode: DecorationApplyMode = .merge,
        foldRegionsMode: DecorationApplyMode = .merge,
        gutterIconsMode: DecorationApplyMode = .merge,
        phantomTextsMode: DecorationApplyMode = .merge,
        codeLensItemsMode: DecorationApplyMode = .merge,
        linksMode: DecorationApplyMode = .merge
    ) {
        self.syntaxSpans = syntaxSpans
        self.semanticSpans = semanticSpans
        self.overlaySpans = overlaySpans
        self.inlayHints = inlayHints
        self.diagnostics = diagnostics
        self.documentHighlights = documentHighlights
        self.indentGuides = indentGuides
        self.bracketGuides = bracketGuides
        self.flowGuides = flowGuides
        self.separatorGuides = separatorGuides
        self.foldRegions = foldRegions
        self.gutterIcons = gutterIcons
        self.phantomTexts = phantomTexts
        self.codeLensItems = codeLensItems
        self.links = links
        self.syntaxSpansMode = syntaxSpansMode
        self.semanticSpansMode = semanticSpansMode
        self.overlaySpansMode = overlaySpansMode
        self.inlayHintsMode = inlayHintsMode
        self.diagnosticsMode = diagnosticsMode
        self.documentHighlightsMode = documentHighlightsMode
        self.indentGuidesMode = indentGuidesMode
        self.bracketGuidesMode = bracketGuidesMode
        self.flowGuidesMode = flowGuidesMode
        self.separatorGuidesMode = separatorGuidesMode
        self.foldRegionsMode = foldRegionsMode
        self.gutterIconsMode = gutterIconsMode
        self.phantomTextsMode = phantomTextsMode
        self.codeLensItemsMode = codeLensItemsMode
        self.linksMode = linksMode
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
    private let visibleLineRangeProvider: () -> IntRange
    private let totalLineCountProvider: () -> Int
    private let languageConfigurationProvider: () -> LanguageConfiguration?
    private let onApplied: () -> Void

    private var providers: [DecorationProvider] = []
    private var states: [ObjectIdentifier: ProviderState] = [:]
    private var pendingTextChanges: [TextChange] = []
    private var pendingRefreshReason: RefreshReason?
    private var lastRefreshedVisibleRange: IntRange?
    private var debounceItem: DispatchWorkItem?
    private var applyScheduled = false
    private var forceFullDecorationApply = false
    private var generation = 0
    private var appliedIndentGuides: [DecorationResult.IndentGuideItem] = []
    private var appliedBracketGuides: [DecorationResult.BracketGuideItem] = []
    private var appliedFlowGuides: [DecorationResult.FlowGuideItem] = []
    private var appliedSeparatorGuides: [DecorationResult.SeparatorGuideItem] = []
    private var appliedFoldRegions: [DecorationResult.FoldRegionItem] = []

    init(core: SweetEditorCore,
         visibleLineRangeProvider: @escaping () -> IntRange,
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
        forceFullDecorationApply = true
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
           lastVisible == visible {
            return
        }

        generation += 1
        let currentGeneration = generation
        lastRefreshedVisibleRange = visible
        let context = DecorationContext(
            visibleLineRange: visible,
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
        let forceFullApply = forceFullDecorationApply
        forceFullDecorationApply = false

        var syntaxSpans: [Int: [DecorationResult.SpanItem]] = [:]
        var semanticSpans: [Int: [DecorationResult.SpanItem]] = [:]
        var overlaySpans: [Int: [DecorationResult.SpanItem]] = [:]
        var inlayHints: [Int: [DecorationResult.InlayHintItem]] = [:]
        var diagnostics: [Int: [DecorationResult.DiagnosticItem]] = [:]
        var documentHighlights: [Int: [DecorationResult.DocumentHighlightItem]] = [:]
        var indentGuides: [DecorationResult.IndentGuideItem]?
        var bracketGuides: [DecorationResult.BracketGuideItem]?
        var flowGuides: [DecorationResult.FlowGuideItem]?
        var separatorGuides: [DecorationResult.SeparatorGuideItem]?
        var foldRegions: [DecorationResult.FoldRegionItem]?
        var gutterIcons: [Int: [Int32]] = [:]
        var phantomTexts: [Int: [DecorationResult.PhantomTextItem]] = [:]
        var codeLensItems: [Int: [DecorationResult.CodeLensItem]] = [:]
        var links: [Int: [DecorationResult.LinkSpanItem]] = [:]
        var syntaxMode: DecorationApplyMode = .merge
        var semanticMode: DecorationApplyMode = .merge
        var overlayMode: DecorationApplyMode = .merge
        var inlayMode: DecorationApplyMode = .merge
        var diagnosticMode: DecorationApplyMode = .merge
        var documentHighlightMode: DecorationApplyMode = .merge
        var indentMode: DecorationApplyMode = .merge
        var bracketMode: DecorationApplyMode = .merge
        var flowMode: DecorationApplyMode = .merge
        var separatorMode: DecorationApplyMode = .merge
        var foldMode: DecorationApplyMode = .merge
        var gutterMode: DecorationApplyMode = .merge
        var phantomMode: DecorationApplyMode = .merge
        var codeLensMode: DecorationApplyMode = .merge
        var linksMode: DecorationApplyMode = .merge

        for provider in providers {
            guard let snapshot = states[ObjectIdentifier(provider)]?.snapshot else { continue }
            syntaxMode = mergeMode(syntaxMode, snapshot.syntaxSpansMode)
            if let value = snapshot.syntaxSpans { appendMap(&syntaxSpans, value) }
            semanticMode = mergeMode(semanticMode, snapshot.semanticSpansMode)
            if let value = snapshot.semanticSpans { appendMap(&semanticSpans, value) }
            overlayMode = mergeMode(overlayMode, snapshot.overlaySpansMode)
            if let value = snapshot.overlaySpans { appendMap(&overlaySpans, value) }
            inlayMode = mergeMode(inlayMode, snapshot.inlayHintsMode)
            if let value = snapshot.inlayHints { appendMap(&inlayHints, value) }
            diagnosticMode = mergeMode(diagnosticMode, snapshot.diagnosticsMode)
            if let value = snapshot.diagnostics { appendMap(&diagnostics, value) }
            documentHighlightMode = mergeMode(documentHighlightMode, snapshot.documentHighlightsMode)
            if let value = snapshot.documentHighlights { appendMap(&documentHighlights, value) }
            gutterMode = mergeMode(gutterMode, snapshot.gutterIconsMode)
            if let value = snapshot.gutterIcons { appendMap(&gutterIcons, value) }
            phantomMode = mergeMode(phantomMode, snapshot.phantomTextsMode)
            if let value = snapshot.phantomTexts { appendMap(&phantomTexts, value) }
            codeLensMode = mergeMode(codeLensMode, snapshot.codeLensItemsMode)
            if let value = snapshot.codeLensItems { appendMap(&codeLensItems, value) }
            linksMode = mergeMode(linksMode, snapshot.linksMode)
            if let value = snapshot.links { appendMap(&links, value) }

            indentMode = mergeMode(indentMode, snapshot.indentGuidesMode)
            if let value = snapshot.indentGuides { appendList(&indentGuides, value) }
            bracketMode = mergeMode(bracketMode, snapshot.bracketGuidesMode)
            if let value = snapshot.bracketGuides { appendList(&bracketGuides, value) }
            flowMode = mergeMode(flowMode, snapshot.flowGuidesMode)
            if let value = snapshot.flowGuides { appendList(&flowGuides, value) }
            separatorMode = mergeMode(separatorMode, snapshot.separatorGuidesMode)
            if let value = snapshot.separatorGuides { appendList(&separatorGuides, value) }
            foldMode = mergeMode(foldMode, snapshot.foldRegionsMode)
            if let value = snapshot.foldRegions { appendList(&foldRegions, value) }
        }

        if forceFullApply {
            syntaxMode = .replaceAll
            semanticMode = .replaceAll
            overlayMode = .replaceAll
            inlayMode = .replaceAll
            diagnosticMode = .replaceAll
            documentHighlightMode = .replaceAll
            indentMode = .replaceAll
            bracketMode = .replaceAll
            flowMode = .replaceAll
            separatorMode = .replaceAll
            foldMode = .replaceAll
            gutterMode = .replaceAll
            phantomMode = .replaceAll
            codeLensMode = .replaceAll
            linksMode = .replaceAll
            appliedIndentGuides.removeAll(keepingCapacity: true)
            appliedBracketGuides.removeAll(keepingCapacity: true)
            appliedFlowGuides.removeAll(keepingCapacity: true)
            appliedSeparatorGuides.removeAll(keepingCapacity: true)
            appliedFoldRegions.removeAll(keepingCapacity: true)
        }

        applySpanMode(layer: 0, mode: syntaxMode)
        if !syntaxSpans.isEmpty {
            let converted = syntaxSpans.mapValues {
                $0.map { StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            core.setBatchLineSpans(layer: 0, spansByLine: converted)
        }
        applySpanMode(layer: 1, mode: semanticMode)
        if !semanticSpans.isEmpty {
            let converted = semanticSpans.mapValues {
                $0.map { StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            core.setBatchLineSpans(layer: 1, spansByLine: converted)
        }
        applySpanMode(layer: 2, mode: overlayMode)
        if !overlaySpans.isEmpty {
            let converted = overlaySpans.mapValues {
                $0.map { StyleSpan(column: $0.column, length: $0.length, styleId: $0.styleId) }
            }
            core.setBatchLineSpans(layer: 2, spansByLine: converted)
        }

        applyInlayMode(inlayMode)
        if !inlayHints.isEmpty {
            let converted = inlayHints.mapValues { items in
                items.map { item in
                    switch item.kind {
                    case .text(let text):
                        return InlayHint.text(column: item.column, text: text)
                    case .icon(let iconId):
                        return InlayHint.icon(column: item.column, iconId: iconId)
                    case .color(let color):
                        return InlayHint.color(column: item.column, color: color)
                    }
                }
            }
            core.setBatchLineInlayHints(converted)
        }

        applyDiagnosticMode(diagnosticMode)
        if !diagnostics.isEmpty {
            let converted = diagnostics.mapValues { items in
                items.map {
                    Diagnostic(
                        column: $0.column,
                        length: $0.length,
                        severity: $0.severity
                    )
                }
            }
            core.setBatchLineDiagnostics(converted)
        }

        applyDocumentHighlightMode(documentHighlightMode)
        if !documentHighlights.isEmpty {
            let converted = documentHighlights.mapValues { items in
                items.map {
                    DocumentHighlight(column: $0.column, length: $0.length, kind: $0.kind)
                }
            }
            core.setBatchLineDocumentHighlights(converted)
        }

        let activeRange = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
        let nextIndentGuides = resolveRangeAppliedList(
            previous: appliedIndentGuides,
            incoming: indentGuides,
            mode: indentMode,
            range: activeRange,
            overlapsRange: indentGuideOverlapsRange
        )
        appliedIndentGuides = nextIndentGuides
        core.setIndentGuides(nextIndentGuides.map {
            IndentGuide(
                startLine: Int($0.start.line),
                startColumn: Int($0.start.column),
                endLine: Int($0.end.line),
                endColumn: Int($0.end.column)
            )
        })

        let nextBracketGuides = resolveRangeAppliedList(
            previous: appliedBracketGuides,
            incoming: bracketGuides,
            mode: bracketMode,
            range: activeRange,
            overlapsRange: bracketGuideOverlapsRange
        )
        appliedBracketGuides = nextBracketGuides
        core.setBracketGuides(nextBracketGuides.map { item in
            BracketGuide(
                parentLine: Int(item.parent.line),
                parentColumn: Int(item.parent.column),
                endLine: Int(item.end.line),
                endColumn: Int(item.end.column),
                children: (item.children ?? []).map { (line: Int($0.line), column: Int($0.column)) }
            )
        })

        let nextFlowGuides = resolveRangeAppliedList(
            previous: appliedFlowGuides,
            incoming: flowGuides,
            mode: flowMode,
            range: activeRange,
            overlapsRange: flowGuideOverlapsRange
        )
        appliedFlowGuides = nextFlowGuides
        core.setFlowGuides(nextFlowGuides.map {
            FlowGuide(
                startLine: Int($0.start.line),
                startColumn: Int($0.start.column),
                endLine: Int($0.end.line),
                endColumn: Int($0.end.column)
            )
        })

        let nextSeparatorGuides = resolveRangeAppliedList(
            previous: appliedSeparatorGuides,
            incoming: separatorGuides,
            mode: separatorMode,
            range: activeRange,
            overlapsRange: separatorGuideOverlapsRange
        )
        appliedSeparatorGuides = nextSeparatorGuides
        core.setSeparatorGuides(nextSeparatorGuides.map {
            SeparatorGuide(
                line: Int32($0.line),
                style: SeparatorStyle.fromValue($0.style),
                count: $0.count,
                textEndColumn: $0.textEndColumn
            )
        })

        let nextFoldRegions = resolveRangeAppliedList(
            previous: appliedFoldRegions,
            incoming: foldRegions,
            mode: foldMode,
            range: activeRange,
            overlapsRange: foldRegionOverlapsRange
        )
        appliedFoldRegions = nextFoldRegions
        core.setFoldRegions(
            nextFoldRegions.map {
                FoldRegion(startLine: $0.startLine, endLine: $0.endLine, collapsed: $0.collapsed)
            }
        )

        applyGutterMode(gutterMode)
        if !gutterIcons.isEmpty {
            let converted = gutterIcons.mapValues { iconIds in
                iconIds.map { GutterIcon(iconId: $0) }
            }
            core.setBatchLineGutterIcons(converted)
        }

        applyPhantomMode(phantomMode)
        if !phantomTexts.isEmpty {
            let converted = phantomTexts.mapValues { items in
                items.map { PhantomText(column: $0.column, text: $0.text) }
            }
            core.setBatchLinePhantomTexts(converted)
        }

        applyCodeLensMode(codeLensMode)
        if !codeLensItems.isEmpty {
            let converted = codeLensItems.mapValues { items in
                items.map { CodeLensItem(column: Int32($0.column), text: $0.text, commandId: $0.commandId) }
            }
            core.setBatchLineCodeLens(converted)
        }

        applyLinksMode(linksMode)
        if !links.isEmpty {
            let converted = links.mapValues { items in
                items.map { LinkSpan(column: $0.column, length: $0.length, target: $0.target) }
            }
            core.setBatchLineLinks(converted)
        }

        onApplied()
    }

    private func applySpanMode(layer: Int32, mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearHighlights(layer: layer)
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearSpanRange(layer: layer, startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyInlayMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearInlayHints()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearInlayRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyDiagnosticMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearDiagnostics()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearDiagnosticRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyDocumentHighlightMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearDocumentHighlights()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearDocumentHighlightRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyGutterMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearGutterIcons()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearGutterRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyPhantomMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearPhantomTexts()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearPhantomRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyCodeLensMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearCodeLens()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearCodeLensRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func applyLinksMode(_ mode: DecorationApplyMode) {
        if mode == .replaceAll {
            core.clearLinks()
        } else if mode == .replaceRange {
            let range = lastRefreshedVisibleRange ?? visibleLineRangeProvider()
            clearLinksRange(startLine: Int(range.start), endLine: Int(range.end))
        }
    }

    private func clearSpanRange(layer: Int32, startLine: Int, endLine: Int) {
        let empty: [Int: [StyleSpan]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineSpans(layer: layer, spansByLine: empty)
        }
    }

    private func clearInlayRange(startLine: Int, endLine: Int) {
        let empty: [Int: [InlayHint]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineInlayHints(empty)
        }
    }

    private func clearDiagnosticRange(startLine: Int, endLine: Int) {
        let empty: [Int: [Diagnostic]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineDiagnostics(empty)
        }
    }

    private func clearDocumentHighlightRange(startLine: Int, endLine: Int) {
        let empty: [Int: [DocumentHighlight]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineDocumentHighlights(empty)
        }
    }

    private func clearGutterRange(startLine: Int, endLine: Int) {
        let empty: [Int: [GutterIcon]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineGutterIcons(empty)
        }
    }

    private func clearPhantomRange(startLine: Int, endLine: Int) {
        let empty: [Int: [PhantomText]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLinePhantomTexts(empty)
        }
    }

    private func clearCodeLensRange(startLine: Int, endLine: Int) {
        let empty: [Int: [CodeLensItem]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineCodeLens(empty)
        }
    }

    private func clearLinksRange(startLine: Int, endLine: Int) {
        let empty: [Int: [LinkSpan]] = buildEmptyRangeMap(startLine: startLine, endLine: endLine)
        if !empty.isEmpty {
            core.setBatchLineLinks(empty)
        }
    }

    private func resolveRangeAppliedList<T>(
        previous: [T],
        incoming: [T]?,
        mode: DecorationApplyMode,
        range: IntRange,
        overlapsRange: (T, IntRange) -> Bool
    ) -> [T] {
        switch mode {
        case .merge, .replaceAll:
            return incoming ?? []
        case .replaceRange:
            var next = previous.filter { !overlapsRange($0, range) }
            if let incoming {
                next.append(contentsOf: incoming)
            }
            return next
        }
    }

    private func buildEmptyRangeMap<T>(startLine: Int, endLine: Int) -> [Int: [T]] {
        if endLine < startLine { return [:] }
        var out: [Int: [T]] = [:]
        for line in startLine...endLine {
            out[line] = []
        }
        return out
    }

    private func mergeMode(_ current: DecorationApplyMode, _ next: DecorationApplyMode) -> DecorationApplyMode {
        priority(next) > priority(current) ? next : current
    }

    private func priority(_ mode: DecorationApplyMode) -> Int {
        switch mode {
        case .merge:
            return 0
        case .replaceRange:
            return 1
        case .replaceAll:
            return 2
        }
    }

    private func indentGuideOverlapsRange(_ guide: DecorationResult.IndentGuideItem, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(startLine: Int(guide.start.line), endLine: Int(guide.end.line), range: range)
    }

    private func bracketGuideOverlapsRange(_ guide: DecorationResult.BracketGuideItem, _ range: IntRange) -> Bool {
        let childEndLine = (guide.children ?? []).map { Int($0.line) }.max() ?? Int(guide.end.line)
        return positionRangeOverlapsRange(
            startLine: Int(guide.parent.line),
            endLine: max(Int(guide.end.line), childEndLine),
            range: range
        )
    }

    private func flowGuideOverlapsRange(_ guide: DecorationResult.FlowGuideItem, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(startLine: Int(guide.start.line), endLine: Int(guide.end.line), range: range)
    }

    private func separatorGuideOverlapsRange(_ guide: DecorationResult.SeparatorGuideItem, _ range: IntRange) -> Bool {
        lineOverlapsRange(guide.line, range)
    }

    private func foldRegionOverlapsRange(_ region: DecorationResult.FoldRegionItem, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(startLine: region.startLine, endLine: region.endLine, range: range)
    }

    private func positionRangeOverlapsRange(startLine: Int, endLine: Int, range: IntRange) -> Bool {
        if range.isEmpty { return false }
        return max(startLine, Int(range.start)) <= min(endLine, Int(range.end))
    }

    private func lineOverlapsRange(_ line: Int, _ range: IntRange) -> Bool {
        !range.isEmpty && line >= Int(range.start) && line <= Int(range.end)
    }

    private func mergePatch(into target: inout DecorationResult, patch: DecorationResult) {
        if let value = patch.syntaxSpans {
            target.syntaxSpans = value
            target.syntaxSpansMode = patch.syntaxSpansMode
        } else if patch.syntaxSpansMode != .merge {
            target.syntaxSpans = nil
            target.syntaxSpansMode = patch.syntaxSpansMode
        }
        if let value = patch.semanticSpans {
            target.semanticSpans = value
            target.semanticSpansMode = patch.semanticSpansMode
        } else if patch.semanticSpansMode != .merge {
            target.semanticSpans = nil
            target.semanticSpansMode = patch.semanticSpansMode
        }
        if let value = patch.overlaySpans {
            target.overlaySpans = value
            target.overlaySpansMode = patch.overlaySpansMode
        } else if patch.overlaySpansMode != .merge {
            target.overlaySpans = nil
            target.overlaySpansMode = patch.overlaySpansMode
        }
        if let value = patch.inlayHints {
            target.inlayHints = value
            target.inlayHintsMode = patch.inlayHintsMode
        } else if patch.inlayHintsMode != .merge {
            target.inlayHints = nil
            target.inlayHintsMode = patch.inlayHintsMode
        }
        if let value = patch.diagnostics {
            target.diagnostics = value
            target.diagnosticsMode = patch.diagnosticsMode
        } else if patch.diagnosticsMode != .merge {
            target.diagnostics = nil
            target.diagnosticsMode = patch.diagnosticsMode
        }
        if let value = patch.documentHighlights {
            target.documentHighlights = value
            target.documentHighlightsMode = patch.documentHighlightsMode
        } else if patch.documentHighlightsMode != .merge {
            target.documentHighlights = nil
            target.documentHighlightsMode = patch.documentHighlightsMode
        }
        if let value = patch.indentGuides {
            target.indentGuides = value
            target.indentGuidesMode = patch.indentGuidesMode
        } else if patch.indentGuidesMode != .merge {
            target.indentGuides = nil
            target.indentGuidesMode = patch.indentGuidesMode
        }
        if let value = patch.bracketGuides {
            target.bracketGuides = value
            target.bracketGuidesMode = patch.bracketGuidesMode
        } else if patch.bracketGuidesMode != .merge {
            target.bracketGuides = nil
            target.bracketGuidesMode = patch.bracketGuidesMode
        }
        if let value = patch.flowGuides {
            target.flowGuides = value
            target.flowGuidesMode = patch.flowGuidesMode
        } else if patch.flowGuidesMode != .merge {
            target.flowGuides = nil
            target.flowGuidesMode = patch.flowGuidesMode
        }
        if let value = patch.separatorGuides {
            target.separatorGuides = value
            target.separatorGuidesMode = patch.separatorGuidesMode
        } else if patch.separatorGuidesMode != .merge {
            target.separatorGuides = nil
            target.separatorGuidesMode = patch.separatorGuidesMode
        }
        if let value = patch.foldRegions {
            target.foldRegions = value
            target.foldRegionsMode = patch.foldRegionsMode
        } else if patch.foldRegionsMode != .merge {
            target.foldRegions = nil
            target.foldRegionsMode = patch.foldRegionsMode
        }
        if let value = patch.gutterIcons {
            target.gutterIcons = value
            target.gutterIconsMode = patch.gutterIconsMode
        } else if patch.gutterIconsMode != .merge {
            target.gutterIcons = nil
            target.gutterIconsMode = patch.gutterIconsMode
        }
        if let value = patch.phantomTexts {
            target.phantomTexts = value
            target.phantomTextsMode = patch.phantomTextsMode
        } else if patch.phantomTextsMode != .merge {
            target.phantomTexts = nil
            target.phantomTextsMode = patch.phantomTextsMode
        }
        if let value = patch.codeLensItems {
            target.codeLensItems = value
            target.codeLensItemsMode = patch.codeLensItemsMode
        } else if patch.codeLensItemsMode != .merge {
            target.codeLensItems = nil
            target.codeLensItemsMode = patch.codeLensItemsMode
        }
        if let value = patch.links {
            target.links = value
            target.linksMode = patch.linksMode
        } else if patch.linksMode != .merge {
            target.links = nil
            target.linksMode = patch.linksMode
        }
    }

    private func appendMap<T>(_ target: inout [Int: [T]], _ patch: [Int: [T]]) {
        for (line, values) in patch {
            var arr = target[line] ?? []
            arr.append(contentsOf: values)
            target[line] = arr
        }
    }

    private func appendList<T>(_ target: inout [T]?, _ patch: [T]) {
        if target == nil {
            target = []
        }
        target?.append(contentsOf: patch)
    }
}
