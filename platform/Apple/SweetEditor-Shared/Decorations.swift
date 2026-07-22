import CoreGraphics
import Foundation

public protocol EditorIconProvider: AnyObject {
    func iconImage(for iconId: Int32) -> CGImage?
}

public struct DecorationContext {
    public let visibleLineRange: IntRange
    public let totalLineCount: Int
    /// All text changes accumulated during the current refresh debounce window.
    public let textChanges: [TextChange]
    /// Current language configuration (from LanguageConfiguration).
    public let languageConfiguration: LanguageConfiguration?
    /// Host-defined metadata attached to the editor.
    public let editorMetadata: EditorMetadata?

    public init(
        visibleLineRange: IntRange,
        totalLineCount: Int,
        textChanges: [TextChange],
        languageConfiguration: LanguageConfiguration?,
        editorMetadata: EditorMetadata?
    ) {
        self.visibleLineRange = visibleLineRange
        self.totalLineCount = totalLineCount
        self.textChanges = textChanges
        self.languageConfiguration = languageConfiguration
        self.editorMetadata = editorMetadata
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
    public var syntaxSpans: [Int: [StyleSpan]]?
    public var semanticSpans: [Int: [StyleSpan]]?
    public var overlaySpans: [Int: [StyleSpan]]?
    public var inlayHints: [Int: [InlayHint]]?
    public var diagnostics: [Int: [Diagnostic]]?
    public var documentHighlights: [Int: [DocumentHighlight]]?
    public var indentGuides: [IndentGuide]?
    public var bracketGuides: [BracketGuide]?
    public var flowGuides: [FlowGuide]?
    public var separatorGuides: [SeparatorGuide]?
    public var foldRegions: [FoldRegion]?
    public var gutterIcons: [Int: [GutterIcon]]?
    public var phantomTexts: [Int: [PhantomText]]?
    public var codeLensItems: [Int: [CodeLensItem]]?
    public var links: [Int: [LinkSpan]]?
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
        syntaxSpans: [Int: [StyleSpan]]? = nil,
        semanticSpans: [Int: [StyleSpan]]? = nil,
        overlaySpans: [Int: [StyleSpan]]? = nil,
        inlayHints: [Int: [InlayHint]]? = nil,
        diagnostics: [Int: [Diagnostic]]? = nil,
        documentHighlights: [Int: [DocumentHighlight]]? = nil,
        indentGuides: [IndentGuide]? = nil,
        bracketGuides: [BracketGuide]? = nil,
        flowGuides: [FlowGuide]? = nil,
        separatorGuides: [SeparatorGuide]? = nil,
        foldRegions: [FoldRegion]? = nil,
        gutterIcons: [Int: [GutterIcon]]? = nil,
        phantomTexts: [Int: [PhantomText]]? = nil,
        codeLensItems: [Int: [CodeLensItem]]? = nil,
        links: [Int: [LinkSpan]]? = nil,
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

package final class DecorationProviderManager {
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

    private let core: EditorCore
    private let visibleLineRangeProvider: () -> IntRange
    private let totalLineCountProvider: () -> Int
    private let languageConfigurationProvider: () -> LanguageConfiguration?
    private let editorMetadataProvider: () -> EditorMetadata?
    private let scrollRefreshMinIntervalMsProvider: () -> Int64
    private let overscanViewportMultiplierProvider: () -> Float
    private let onApplied: () -> Void

    private var providers: [DecorationProvider] = []
    private var states: [ObjectIdentifier: ProviderState] = [:]
    private var pendingTextChanges: [TextChange] = []
    private var pendingRefreshReason: RefreshReason?
    private var lastObservedVisibleRange: IntRange?
    private var lastRefreshedVisibleRange: IntRange?
    private var lastScrollRefreshTimestamp: TimeInterval = 0
    private var debounceItem: DispatchWorkItem?
    private var applyScheduled = false
    private var forceFullDecorationApply = false
    private var generation = 0
    private var appliedIndentGuides: [IndentGuide] = []
    private var appliedBracketGuides: [BracketGuide] = []
    private var appliedFlowGuides: [FlowGuide] = []
    private var appliedSeparatorGuides: [SeparatorGuide] = []
    private var appliedFoldRegions: [FoldRegion] = []

    package init(core: EditorCore,
         visibleLineRangeProvider: @escaping () -> IntRange,
         totalLineCountProvider: @escaping () -> Int,
         languageConfigurationProvider: @escaping () -> LanguageConfiguration?,
         editorMetadataProvider: @escaping () -> EditorMetadata?,
         scrollRefreshMinIntervalMsProvider: @escaping () -> Int64,
         overscanViewportMultiplierProvider: @escaping () -> Float,
         onApplied: @escaping () -> Void) {
        self.core = core
        self.visibleLineRangeProvider = visibleLineRangeProvider
        self.totalLineCountProvider = totalLineCountProvider
        self.languageConfigurationProvider = languageConfigurationProvider
        self.editorMetadataProvider = editorMetadataProvider
        self.scrollRefreshMinIntervalMsProvider = scrollRefreshMinIntervalMsProvider
        self.overscanViewportMultiplierProvider = overscanViewportMultiplierProvider
        self.onApplied = onApplied
    }

    package func addProvider(_ provider: DecorationProvider) {
        if providers.contains(where: { ObjectIdentifier($0) == ObjectIdentifier(provider) }) { return }
        providers.append(provider)
        states[ObjectIdentifier(provider)] = ProviderState()
        requestRefresh()
    }

    package func removeProvider(_ provider: DecorationProvider) {
        providers.removeAll { ObjectIdentifier($0) == ObjectIdentifier(provider) }
        let key = ObjectIdentifier(provider)
        states[key]?.receiver?.cancel()
        states.removeValue(forKey: key)
        forceFullDecorationApply = true
        scheduleApply()
    }

    package func requestRefresh() { scheduleRefresh(delay: 0, changes: nil, reason: .manual) }
    package func onDocumentLoaded() { scheduleRefresh(delay: 0, changes: nil, reason: .documentLoaded) }
    package func onTextChanged(changes: [TextChange]) { scheduleRefresh(delay: 0.05, changes: changes, reason: .textChanged) }
    package func onScrollChanged() {
        let interval = TimeInterval(max(0, scrollRefreshMinIntervalMsProvider())) / 1000
        let elapsed = ProcessInfo.processInfo.systemUptime - lastScrollRefreshTimestamp
        scheduleRefresh(delay: max(0, interval - elapsed), changes: nil, reason: .scrollChanged)
    }

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

        let observedVisible = visibleLineRangeProvider()
        let totalLineCount = totalLineCountProvider()
        let visible = expandedVisibleRange(observedVisible, totalLineCount: totalLineCount)
        let textChanges = pendingTextChanges
        pendingTextChanges.removeAll(keepingCapacity: true)

        if reason == .scrollChanged,
           textChanges.isEmpty,
           let lastVisible = lastObservedVisibleRange,
           lastVisible == observedVisible {
            return
        }

        generation += 1
        let currentGeneration = generation
        lastObservedVisibleRange = observedVisible
        lastRefreshedVisibleRange = visible
        if reason == .scrollChanged {
            lastScrollRefreshTimestamp = ProcessInfo.processInfo.systemUptime
        }
        let context = DecorationContext(
            visibleLineRange: visible,
            totalLineCount: totalLineCount,
            textChanges: textChanges,
            languageConfiguration: languageConfigurationProvider(),
            editorMetadata: editorMetadataProvider()
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

    private func expandedVisibleRange(_ visible: IntRange, totalLineCount: Int) -> IntRange {
        guard totalLineCount > 0, visible.end >= visible.start else { return visible }
        let visibleLineCount = Int(visible.end - visible.start + 1)
        let multiplier = max(0, overscanViewportMultiplierProvider())
        let overscan = Int(ceil(Float(visibleLineCount) * multiplier))
        return IntRange(
            start: max(0, Int(visible.start) - overscan),
            end: min(totalLineCount - 1, Int(visible.end) + overscan)
        )
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

        var syntaxSpans: [Int: [StyleSpan]] = [:]
        var semanticSpans: [Int: [StyleSpan]] = [:]
        var overlaySpans: [Int: [StyleSpan]] = [:]
        var inlayHints: [Int: [InlayHint]] = [:]
        var diagnostics: [Int: [Diagnostic]] = [:]
        var documentHighlights: [Int: [DocumentHighlight]] = [:]
        var indentGuides: [IndentGuide]?
        var bracketGuides: [BracketGuide]?
        var flowGuides: [FlowGuide]?
        var separatorGuides: [SeparatorGuide]?
        var foldRegions: [FoldRegion]?
        var gutterIcons: [Int: [GutterIcon]] = [:]
        var phantomTexts: [Int: [PhantomText]] = [:]
        var codeLensItems: [Int: [CodeLensItem]] = [:]
        var links: [Int: [LinkSpan]] = [:]
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

        applySpanMode(layer: .syntax, mode: syntaxMode)
        if !syntaxSpans.isEmpty {
            core.setBatchLineSpans(layer: .syntax, spansByLine: syntaxSpans)
        }
        applySpanMode(layer: .semantic, mode: semanticMode)
        if !semanticSpans.isEmpty {
            core.setBatchLineSpans(layer: .semantic, spansByLine: semanticSpans)
        }
        applySpanMode(layer: .overlay, mode: overlayMode)
        if !overlaySpans.isEmpty {
            core.setBatchLineSpans(layer: .overlay, spansByLine: overlaySpans)
        }

        applyInlayMode(inlayMode)
        if !inlayHints.isEmpty {
            core.setBatchLineInlayHints(inlayHints)
        }

        applyDiagnosticMode(diagnosticMode)
        if !diagnostics.isEmpty {
            core.setBatchLineDiagnostics(diagnostics)
        }

        applyDocumentHighlightMode(documentHighlightMode)
        if !documentHighlights.isEmpty {
            core.setBatchLineDocumentHighlights(documentHighlights)
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
        core.setIndentGuides(nextIndentGuides)

        let nextBracketGuides = resolveRangeAppliedList(
            previous: appliedBracketGuides,
            incoming: bracketGuides,
            mode: bracketMode,
            range: activeRange,
            overlapsRange: bracketGuideOverlapsRange
        )
        appliedBracketGuides = nextBracketGuides
        core.setBracketGuides(nextBracketGuides)

        let nextFlowGuides = resolveRangeAppliedList(
            previous: appliedFlowGuides,
            incoming: flowGuides,
            mode: flowMode,
            range: activeRange,
            overlapsRange: flowGuideOverlapsRange
        )
        appliedFlowGuides = nextFlowGuides
        core.setFlowGuides(nextFlowGuides)

        let nextSeparatorGuides = resolveRangeAppliedList(
            previous: appliedSeparatorGuides,
            incoming: separatorGuides,
            mode: separatorMode,
            range: activeRange,
            overlapsRange: separatorGuideOverlapsRange
        )
        appliedSeparatorGuides = nextSeparatorGuides
        core.setSeparatorGuides(nextSeparatorGuides)

        let nextFoldRegions = resolveRangeAppliedList(
            previous: appliedFoldRegions,
            incoming: foldRegions,
            mode: foldMode,
            range: activeRange,
            overlapsRange: foldRegionOverlapsRange
        )
        appliedFoldRegions = nextFoldRegions
        core.setFoldRegions(nextFoldRegions)

        applyGutterMode(gutterMode)
        if !gutterIcons.isEmpty {
            core.setBatchLineGutterIcons(gutterIcons)
        }

        applyPhantomMode(phantomMode)
        if !phantomTexts.isEmpty {
            core.setBatchLinePhantomTexts(phantomTexts)
        }

        applyCodeLensMode(codeLensMode)
        if !codeLensItems.isEmpty {
            core.setBatchLineCodeLens(codeLensItems)
        }

        applyLinksMode(linksMode)
        if !links.isEmpty {
            core.setBatchLineLinks(links)
        }

        onApplied()
    }

    private func applySpanMode(layer: SpanLayer, mode: DecorationApplyMode) {
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

    private func clearSpanRange(layer: SpanLayer, startLine: Int, endLine: Int) {
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

    private func indentGuideOverlapsRange(_ guide: IndentGuide, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(startLine: Int(guide.start.line), endLine: Int(guide.end.line), range: range)
    }

    private func bracketGuideOverlapsRange(_ guide: BracketGuide, _ range: IntRange) -> Bool {
        let childEndLine = guide.children.map { Int($0.line) }.max() ?? Int(guide.end.line)
        return positionRangeOverlapsRange(
            startLine: Int(guide.parent.line),
            endLine: max(Int(guide.end.line), childEndLine),
            range: range
        )
    }

    private func flowGuideOverlapsRange(_ guide: FlowGuide, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(startLine: Int(guide.start.line), endLine: Int(guide.end.line), range: range)
    }

    private func separatorGuideOverlapsRange(_ guide: SeparatorGuide, _ range: IntRange) -> Bool {
        lineOverlapsRange(Int(guide.line), range)
    }

    private func foldRegionOverlapsRange(_ region: FoldRegion, _ range: IntRange) -> Bool {
        positionRangeOverlapsRange(
            startLine: Int(region.start_line),
            endLine: Int(region.end_line),
            range: range
        )
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
