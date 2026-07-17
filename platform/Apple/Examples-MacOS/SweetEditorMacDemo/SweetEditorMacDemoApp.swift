import AppKit
import SweetEditorMacOS
import SweetEditorDemoSupport

func demoWindowAppearance(isDark: Bool) -> NSAppearance? {
    NSAppearance(named: isDark ? .darkAqua : .aqua)
}

func demoChromeBackgroundColor(isDark: Bool) -> NSColor {
    if isDark {
        return NSColor(srgbRed: 0x1E / 255.0, green: 0x1E / 255.0, blue: 0x1E / 255.0, alpha: 1.0)
    }
    return .windowBackgroundColor
}

@main
final class SweetEditorMacDemoApp: NSObject, NSApplicationDelegate {
    private var window: KeyForwardingWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = SweetEditorMacDemoApp()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = DemoRootView(frame: NSRect(x: 0, y: 0, width: 980, height: 620))

        let window = KeyForwardingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SweetEditor macOS Demo"
        window.minSize = NSSize(width: 980, height: 620)
        window.contentView = contentView
        window.initialFirstResponder = contentView.editorView
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(contentView.editorView)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private final class KeyForwardingWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown,
           let rootView = contentView as? DemoRootView,
           rootView.handleSearchKeyDown(event) {
            return
        }

        if event.type == .keyDown,
           let editor = SweetEditorViewMacOS.activeEditor,
           editor.window === self,
           !event.modifierFlags.contains(.command) {
            editor.handleForwardedKeyDown(event)
            return
        }
        super.sendEvent(event)
    }
}

private final class DemoRootView: NSView, NSTextFieldDelegate {
    let editorView = SweetEditorViewMacOS(frame: .zero)
    private let demoCompletionProvider = DemoCompletionProvider()
    private lazy var demoDecorationProvider: DemoDecorationProvider = {
        DemoDecorationProvider(documentLinesProvider: { [weak self] in
            self?.editorView.documentLines() ?? []
        })
    }()

    private let headerView = NSView(frame: .zero)
    private let titleLabel = NSTextField(labelWithString: "SweetEditorMacOS")
    private let themeLabel = NSTextField(labelWithString: "Dark Theme")
    private let themeSwitch = NSSwitch(frame: .zero)
    private let divider = NSBox(frame: .zero)
    private let toolbarScrollView = NSScrollView(frame: .zero)
    private let toolbarStack = NSStackView(frame: .zero)
    private let statusLabel = NSTextField(labelWithString: "Ready")
    private let fileLabel = NSTextField(labelWithString: "File")
    private let filePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let searchPanel = NSStackView(frame: .zero)
    private let searchRow = NSStackView(frame: .zero)
    private let replaceRow = NSStackView(frame: .zero)
    private let searchField = NSTextField(frame: .zero)
    private let replaceField = NSTextField(frame: .zero)
    private let searchCounterLabel = NSTextField(labelWithString: "")
    private let matchCaseButton = NSButton(checkboxWithTitle: "Aa", target: nil, action: nil)
    private let wholeWordButton = NSButton(checkboxWithTitle: "Word", target: nil, action: nil)
    private let regexButton = NSButton(checkboxWithTitle: ".*", target: nil, action: nil)

    private var wrapModePreset = 0
    private var isDarkTheme = true
    private var searchPanelHeightConstraint: NSLayoutConstraint?
    private var searchState = SearchState()
    private var decorationFeatureByIdentifier: [NSUserInterfaceItemIdentifier: DemoDecorationFeature] = [:]
    private var fileSelectionController = DemoFileSelectionController(
        sampleFiles: DemoSampleSupport.availableSampleFiles()
    )

    private let decorationFeatureItems: [(title: String, feature: DemoDecorationFeature)] = [
        ("Inlay", .inlayHints),
        ("Phantom", .phantomTexts),
        ("Diagnostic", .diagnostics),
        ("Fold", .foldRegions),
        ("Guides", .structureGuides),
    ]

    private static let wrapModeTitles = [
        "WrapMode: NONE",
        "WrapMode: CHAR_BREAK",
        "WrapMode: WORD_BREAK"
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViewHierarchy()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViewHierarchy()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyChromeTheme(isDark: isDarkTheme)
    }

    private func setupViewHierarchy() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        editorView.showsPerformanceOverlay = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        themeLabel.translatesAutoresizingMaskIntoConstraints = false
        themeSwitch.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        toolbarScrollView.translatesAutoresizingMaskIntoConstraints = false
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        fileLabel.translatesAutoresizingMaskIntoConstraints = false
        filePicker.translatesAutoresizingMaskIntoConstraints = false
        searchPanel.translatesAutoresizingMaskIntoConstraints = false
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        replaceRow.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        replaceField.translatesAutoresizingMaskIntoConstraints = false
        searchCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        editorView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.textColor = .secondaryLabelColor
        divider.boxType = .custom
        divider.borderColor = .separatorColor
        divider.borderWidth = 1
        divider.fillColor = .separatorColor

        themeSwitch.target = self
        themeSwitch.action = #selector(themeChanged(_:))

        toolbarScrollView.drawsBackground = false
        toolbarScrollView.borderType = .noBorder
        toolbarScrollView.hasVerticalScroller = false
        toolbarScrollView.hasHorizontalScroller = true
        toolbarScrollView.autohidesScrollers = true

        toolbarStack.orientation = .horizontal
        toolbarStack.alignment = .centerY
        toolbarStack.spacing = 8
        toolbarStack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        let toolbarContentView = NSView(frame: .zero)
        toolbarContentView.translatesAutoresizingMaskIntoConstraints = false
        toolbarContentView.addSubview(toolbarStack)
        NSLayoutConstraint.activate([
            toolbarStack.leadingAnchor.constraint(equalTo: toolbarContentView.leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: toolbarContentView.trailingAnchor),
            toolbarStack.topAnchor.constraint(equalTo: toolbarContentView.topAnchor),
            toolbarStack.bottomAnchor.constraint(equalTo: toolbarContentView.bottomAnchor)
        ])
        toolbarScrollView.documentView = toolbarContentView

        let minWidth = toolbarContentView.widthAnchor.constraint(greaterThanOrEqualTo: toolbarScrollView.widthAnchor)
        minWidth.priority = .defaultLow
        minWidth.isActive = true
        toolbarContentView.heightAnchor.constraint(equalTo: toolbarScrollView.heightAnchor).isActive = true

        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail

        fileLabel.font = .systemFont(ofSize: 12)
        fileLabel.textColor = .secondaryLabelColor

        filePicker.font = .systemFont(ofSize: 12)
        filePicker.target = self
        filePicker.action = #selector(fileSelectionChanged(_:))
        filePicker.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        configureSearchPanel()

        addSubview(headerView)
        addSubview(divider)
        addSubview(toolbarScrollView)
        addSubview(searchPanel)
        addSubview(statusLabel)
        addSubview(editorView)

        headerView.addSubview(themeLabel)
        headerView.addSubview(themeSwitch)
        headerView.addSubview(titleLabel)

        configureToolbarButtons()

        NSLayoutConstraint.activate([
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            themeLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            themeLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            themeSwitch.leadingAnchor.constraint(equalTo: themeLabel.trailingAnchor, constant: 12),
            themeSwitch.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            toolbarScrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarScrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarScrollView.topAnchor.constraint(equalTo: divider.bottomAnchor),
            toolbarScrollView.heightAnchor.constraint(equalToConstant: 44),

            searchPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchPanel.topAnchor.constraint(equalTo: toolbarScrollView.bottomAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: searchPanel.bottomAnchor),

            editorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            editorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        searchPanelHeightConstraint = searchPanel.heightAnchor.constraint(equalToConstant: 0)
        searchPanelHeightConstraint?.isActive = true

        themeSwitch.state = .on
        updateThemeLabel(isDark: true)
        applyChromeTheme(isDark: true)
        editorView.applyTheme(isDark: true)
        editorView.attachCompletionProvider(demoCompletionProvider)
        editorView.attachDecorationProvider(demoDecorationProvider)
        configureFilePicker()
        loadSelectedFileIntoEditor(showStatus: false)
        applyAllDecorations(showStatus: false)
        updateStatus(fileSelectionController?.statusText ?? "Ready")
    }

    @objc
    private func fileSelectionChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        _ = fileSelectionController?.selectFile(named: title)
        loadSelectedFileIntoEditor(showStatus: true)
        applyAllDecorations(showStatus: false)
    }

    @objc
    private func themeChanged(_ sender: NSSwitch) {
        let isDark = sender.state == .on
        guard isDarkTheme != isDark else { return }
        isDarkTheme = isDark
        applyChromeTheme(isDark: isDark)
        editorView.applyTheme(isDark: isDark)
        updateThemeLabel(isDark: isDark)
        updateStatus(isDark ? "Switched to dark theme" : "Switched to light theme")
    }

    private func applyChromeTheme(isDark: Bool) {
        window?.appearance = demoWindowAppearance(isDark: isDark)
        layer?.backgroundColor = resolvedCGColor(demoChromeBackgroundColor(isDark: isDark))
        searchPanel.layer?.backgroundColor = resolvedCGColor(demoChromeBackgroundColor(isDark: isDark))
    }

    private func resolvedCGColor(_ color: NSColor) -> CGColor {
        var resolved: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.cgColor
        }
        return resolved ?? color.cgColor
    }

    private func configureSearchPanel() {
        searchPanel.orientation = .vertical
        searchPanel.alignment = .leading
        searchPanel.spacing = 6
        searchPanel.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        searchPanel.isHidden = true
        searchPanel.wantsLayer = true

        searchRow.orientation = .horizontal
        searchRow.alignment = .centerY
        searchRow.spacing = 6
        replaceRow.orientation = .horizontal
        replaceRow.alignment = .centerY
        replaceRow.spacing = 6
        replaceRow.isHidden = true

        searchField.placeholderString = "Find"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldSubmitted(_:))
        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        replaceField.placeholderString = "Replace"
        replaceField.target = self
        replaceField.action = #selector(replaceFieldSubmitted(_:))
        replaceField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true

        [matchCaseButton, wholeWordButton, regexButton].forEach { button in
            button.target = self
            button.action = #selector(searchOptionChanged(_:))
            button.font = .systemFont(ofSize: 11)
        }

        searchCounterLabel.font = .systemFont(ofSize: 11)
        searchCounterLabel.textColor = .secondaryLabelColor
        searchCounterLabel.alignment = .center
        searchCounterLabel.widthAnchor.constraint(equalToConstant: 58).isActive = true

        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(makeSearchButton(title: "\\n", action: #selector(insertSearchNewlineToken(_:))))
        searchRow.addArrangedSubview(searchCounterLabel)
        searchRow.addArrangedSubview(matchCaseButton)
        searchRow.addArrangedSubview(wholeWordButton)
        searchRow.addArrangedSubview(regexButton)
        searchRow.addArrangedSubview(makeSearchButton(title: "↑", action: #selector(previousSearchMatch(_:))))
        searchRow.addArrangedSubview(makeSearchButton(title: "↓", action: #selector(nextSearchMatch(_:))))
        searchRow.addArrangedSubview(makeSearchButton(title: "×", action: #selector(closeSearchButtonPressed(_:))))

        replaceRow.addArrangedSubview(replaceField)
        replaceRow.addArrangedSubview(makeSearchButton(title: "\\n", action: #selector(insertReplaceNewlineToken(_:))))
        replaceRow.addArrangedSubview(makeSearchButton(title: "Replace", action: #selector(replaceCurrentButtonPressed(_:)), width: 66))
        replaceRow.addArrangedSubview(makeSearchButton(title: "All", action: #selector(replaceAllButtonPressed(_:)), width: 44))

        searchPanel.addArrangedSubview(searchRow)
        searchPanel.addArrangedSubview(replaceRow)
    }

    private func makeSearchButton(title: String, action: Selector, width: CGFloat = 30) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: title.count > 2 ? 11 : 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 26).isActive = true
        return button
    }

    private func configureToolbarButtons() {
        let buttons: [(String, () -> Void)] = [
            ("Undo", { [weak self] in self?.triggerUndo() }),
            ("Redo", { [weak self] in self?.triggerRedo() }),
            ("Find", { [weak self] in self?.openSearchPanel(replaceMode: false) }),
            ("Replace", { [weak self] in self?.openSearchPanel(replaceMode: true) }),
            ("Select All", { [weak self] in self?.triggerSelectAll() }),
            ("Get Selection", { [weak self] in self?.showSelectionPreview() }),
            ("Load Decorations", { [weak self] in self?.applyAllDecorations() }),
            ("Clear Decorations", { [weak self] in self?.clearAllDecorations() }),
            ("WrapMode", { [weak self] in self?.cycleWrapMode() })
        ]

        buttons.forEach { title, handler in
            toolbarStack.addArrangedSubview(makeToolbarButton(title: title, handler: handler))
        }

        toolbarStack.addArrangedSubview(makeToolbarSeparator())
        toolbarStack.addArrangedSubview(fileLabel)
        toolbarStack.addArrangedSubview(filePicker)
        toolbarStack.addArrangedSubview(makeToolbarSeparator())

        for item in decorationFeatureItems {
            toolbarStack.addArrangedSubview(makeDecorationFeatureCheckbox(title: item.title, feature: item.feature))
        }
    }

    private func makeToolbarSeparator() -> NSView {
        let separator = NSBox(frame: .zero)
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 8).isActive = true
        return separator
    }

    private func makeToolbarButton(title: String, handler: @escaping () -> Void) -> NSButton {
        let button = ToolbarButton()
        button.title = title
        button.target = self
        button.action = #selector(toolbarButtonPressed(_:))
        button.handler = handler
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    private func makeDecorationFeatureCheckbox(title: String, feature: DemoDecorationFeature) -> NSButton {
        let checkbox = NSButton(checkboxWithTitle: title, target: self, action: #selector(decorationFeatureCheckboxChanged(_:)))
        checkbox.font = .systemFont(ofSize: 12)
        checkbox.state = demoDecorationProvider.isFeatureEnabled(feature) ? .on : .off
        let identifier = NSUserInterfaceItemIdentifier("decoration-feature-\(feature.rawValue)")
        checkbox.identifier = identifier
        decorationFeatureByIdentifier[identifier] = feature
        return checkbox
    }

    @objc
    private func toolbarButtonPressed(_ sender: NSButton) {
        (sender as? ToolbarButton)?.handler?()
    }

    @objc
    private func decorationFeatureCheckboxChanged(_ sender: NSButton) {
        guard let identifier = sender.identifier,
              let feature = decorationFeatureByIdentifier[identifier] else {
            return
        }

        let enabled = sender.state == .on
        demoDecorationProvider.setFeatureEnabled(feature, enabled: enabled)
        focusEditor()
        editorView.requestDecorationRefresh()
        updateStatus(enabled ? "Enabled \(sender.title) decorations" : "Disabled \(sender.title) decorations")
    }

    func handleSearchKeyDown(_ event: NSEvent) -> Bool {
        let primary = event.modifierFlags.contains(.command)
        let key = event.charactersIgnoringModifiers?.lowercased()
        if primary && key == "f" {
            openSearchPanel(replaceMode: false)
            return true
        }

        if primary && key == "h" {
            openSearchPanel(replaceMode: true)
            return true
        }

        if !searchPanel.isHidden && event.keyCode == 53 {
            closeSearchPanel()
            return true
        }

        if !searchPanel.isHidden && event.keyCode == 36 && event.modifierFlags.contains(.shift) {
            findPreviousSearchMatch()
            return true
        }

        return false
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, field === searchField else {
            return
        }
        performSearch()
    }

    @objc
    private func searchFieldSubmitted(_ sender: NSTextField) {
        findNextSearchMatch()
    }

    @objc
    private func replaceFieldSubmitted(_ sender: NSTextField) {
        replaceCurrentSearchMatch()
    }

    @objc
    private func searchOptionChanged(_ sender: NSButton) {
        performSearch()
    }

    @objc
    private func insertSearchNewlineToken(_ sender: NSButton) {
        insertNewlineToken(into: searchField)
    }

    @objc
    private func insertReplaceNewlineToken(_ sender: NSButton) {
        insertNewlineToken(into: replaceField)
    }

    @objc
    private func previousSearchMatch(_ sender: NSButton) {
        findPreviousSearchMatch()
    }

    @objc
    private func nextSearchMatch(_ sender: NSButton) {
        findNextSearchMatch()
    }

    @objc
    private func closeSearchButtonPressed(_ sender: NSButton) {
        closeSearchPanel()
    }

    @objc
    private func replaceCurrentButtonPressed(_ sender: NSButton) {
        replaceCurrentSearchMatch()
    }

    @objc
    private func replaceAllButtonPressed(_ sender: NSButton) {
        replaceAllSearchMatches()
    }

    private func openSearchPanel(replaceMode: Bool) {
        searchPanel.isHidden = false
        replaceRow.isHidden = !replaceMode
        searchPanelHeightConstraint?.constant = replaceMode ? 74 : 38
        layoutSubtreeIfNeeded()
        window?.makeFirstResponder(searchField)
        searchField.selectText(nil)
        performSearch()
    }

    private func closeSearchPanel() {
        clearSearchState()
        searchPanel.isHidden = true
        replaceRow.isHidden = true
        searchPanelHeightConstraint?.constant = 0
        focusEditor()
        updateStatus("Search closed")
    }

    private func clearSearchState() {
        editorView.clearSearch()
        searchState = SearchState()
        refreshSearchCounter()
    }

    private func performSearch() {
        guard !searchPanel.isHidden else { return }
        let pattern = decodeNewlineTokens(searchField.stringValue)
        if pattern.isEmpty {
            clearSearchState()
            return
        }

        editorView.search(
            SearchRequest(
                pattern: pattern,
                options: SearchOptions(
                    case_sensitive: matchCaseButton.state == .on,
                    whole_word: wholeWordButton.state == .on,
                    use_regex: regexButton.state == .on
                )
            )
        )
        refreshSearchState()
        if searchState.status == .FAILED {
            updateStatus(searchState.error_message.isEmpty ? "Search failed" : searchState.error_message)
        }
    }

    private func findNextSearchMatch() {
        guard !searchPanel.isHidden else {
            openSearchPanel(replaceMode: false)
            return
        }
        editorView.findNextSearchMatch()
        refreshSearchState()
    }

    private func findPreviousSearchMatch() {
        guard !searchPanel.isHidden else {
            openSearchPanel(replaceMode: false)
            return
        }
        editorView.findPreviousSearchMatch()
        refreshSearchState()
    }

    private func replaceCurrentSearchMatch() {
        guard !searchPanel.isHidden else { return }
        let state = editorView.getSearchState()
        guard !searchField.stringValue.isEmpty, state.status != .FAILED, state.has_current_match else { return }
        editorView.replaceCurrentSearchMatch(decodeNewlineTokens(replaceField.stringValue))
        performSearch()
        updateStatus("Replace")
    }

    private func replaceAllSearchMatches() {
        guard !searchPanel.isHidden else { return }
        let state = editorView.getSearchState()
        guard !searchField.stringValue.isEmpty, state.status != .FAILED, state.match_count > 0 else { return }
        let count = state.match_count
        editorView.replaceAllSearchMatches(decodeNewlineTokens(replaceField.stringValue))
        performSearch()
        updateStatus("Replaced \(count) matches")
    }

    private func refreshSearchState() {
        searchState = editorView.getSearchState()
        refreshSearchCounter()
    }

    private func refreshSearchCounter() {
        guard !searchPanel.isHidden, !searchField.stringValue.isEmpty else {
            searchCounterLabel.stringValue = ""
            return
        }

        if searchState.status == .FAILED {
            searchCounterLabel.stringValue = "Error"
            return
        }

        if searchState.match_count <= 0 {
            searchCounterLabel.stringValue = "0/0"
            return
        }

        let index = searchState.has_current_match ? searchState.current_index + 1 : 0
        searchCounterLabel.stringValue = "\(index)/\(searchState.match_count)"
    }

    private func insertNewlineToken(into field: NSTextField) {
        if let editor = field.currentEditor() {
            editor.replaceCharacters(in: editor.selectedRange, with: "\\n")
        } else {
            field.stringValue += "\\n"
        }
        if field === searchField {
            performSearch()
        }
    }

    private func decodeNewlineTokens(_ text: String) -> String {
        var decoded = ""
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == "\\" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex {
                    let next = text[nextIndex]
                    if next == "n" {
                        decoded.append("\n")
                        index = text.index(after: nextIndex)
                        continue
                    }
                    if next == "\\" {
                        decoded.append("\\")
                        index = text.index(after: nextIndex)
                        continue
                    }
                }
            }
            decoded.append(ch)
            index = text.index(after: index)
        }
        return decoded
    }

    private func triggerUndo() {
        focusEditor()
        NotificationCenter.default.post(name: .editorUndo, object: nil)
        updateStatus("Undo")
    }

    private func triggerRedo() {
        focusEditor()
        NotificationCenter.default.post(name: .editorRedo, object: nil)
        updateStatus("Redo")
    }

    private func triggerSelectAll() {
        focusEditor()
        NotificationCenter.default.post(name: .editorSelectAll, object: nil)
        updateStatus("Selected all")
    }

    private func showSelectionPreview() {
        focusEditor()
        NotificationCenter.default.post(name: .editorGetSelection, object: nil)
        if let preview = editorView.selectedTextPreview(maxLength: 100) {
            let sanitized = preview.replacingOccurrences(of: "\n", with: "↵")
            updateStatus("Selection: \(sanitized)")
        } else {
            updateStatus("No selection")
        }
    }

    private func applyAllDecorations(showStatus: Bool = true) {
        focusEditor()
        editorView.requestDecorationRefresh()
        if showStatus {
            updateStatus("Decorations refreshed")
        }
    }

    private func clearAllDecorations() {
        focusEditor()
        editorView.clearAllDecorations()
        updateStatus("Cleared all decorations")
    }

    private func cycleWrapMode() {
        wrapModePreset = (wrapModePreset + 1) % DemoRootView.wrapModeTitles.count
        editorView.setWrapMode(wrapModePreset)
        updateStatus(DemoRootView.wrapModeTitles[wrapModePreset])
    }

    private func focusEditor() {
        window?.makeFirstResponder(editorView)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    private func updateThemeLabel(isDark: Bool) {
        themeLabel.stringValue = isDark ? "Dark Theme" : "Light Theme"
    }

    private func configureFilePicker() {
        filePicker.removeAllItems()
        let titles = fileSelectionController?.fileTitles ?? []
        filePicker.addItems(withTitles: titles)
        if let selectedTitle = fileSelectionController?.selectedFile.fileName {
            filePicker.selectItem(withTitle: selectedTitle)
        }
        filePicker.isEnabled = !titles.isEmpty
    }

    private func loadSelectedFileIntoEditor(showStatus: Bool) {
        guard let selectedFile = fileSelectionController?.selectedFile else { return }
        clearSearchState()
        editorView.setMetadata(fileSelectionController?.currentMetadata)
        editorView.loadDocument(text: selectedFile.text)
        if showStatus {
            updateStatus(fileSelectionController?.statusText ?? "Ready")
        }
    }

    private final class ToolbarButton: NSButton {
        var handler: (() -> Void)?
    }
}
