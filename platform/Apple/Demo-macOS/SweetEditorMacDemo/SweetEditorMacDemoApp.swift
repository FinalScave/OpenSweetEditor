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

        super.sendEvent(event)
    }
}

private final class DemoRootView: NSView, NSTextFieldDelegate {
    let editorView = SweetEditorView(frame: .zero)
    private let demoCompletionProvider = DemoCompletionProvider()
    private lazy var sweetLineDecorationProvider: SweetLineDecorationProvider = {
        SweetLineDecorationProvider(
            editorProvider: { [weak self] in self?.editorView },
            fileNameProvider: { [weak self] in
                self?.fileSelectionController?.selectedFile.fileName ?? "sample.cpp"
            }
        )
    }()

    private let themeLabel = NSTextField(labelWithString: "Dark")
    private let themeSwitch = NSSwitch(frame: .zero)
    private let divider = NSBox(frame: .zero)
    private let toolbarStack = NSStackView(frame: .zero)
    private let filePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let wrapModePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    private let searchPanel = NSStackView(frame: .zero)
    private let searchRow = NSStackView(frame: .zero)
    private let replaceRow = NSStackView(frame: .zero)
    private let searchField = NSTextField(frame: .zero)
    private let replaceField = NSTextField(frame: .zero)
    private let searchCounterLabel = NSTextField(labelWithString: "")
    private let matchCaseButton = NSButton(checkboxWithTitle: "Aa", target: nil, action: nil)
    private let wholeWordButton = NSButton(checkboxWithTitle: "Word", target: nil, action: nil)
    private let regexButton = NSButton(checkboxWithTitle: ".*", target: nil, action: nil)

    private var isDarkTheme = true
    private var searchPanelHeightConstraint: NSLayoutConstraint?
    private var searchState = SearchState()
    private var fileSelectionController = DemoFileSelectionController(
        sampleFiles: DemoSampleSupport.availableSampleFiles()
    )

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

        themeLabel.translatesAutoresizingMaskIntoConstraints = false
        themeSwitch.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        toolbarStack.translatesAutoresizingMaskIntoConstraints = false
        filePicker.translatesAutoresizingMaskIntoConstraints = false
        wrapModePicker.translatesAutoresizingMaskIntoConstraints = false
        searchPanel.translatesAutoresizingMaskIntoConstraints = false
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        replaceRow.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        replaceField.translatesAutoresizingMaskIntoConstraints = false
        searchCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        editorView.translatesAutoresizingMaskIntoConstraints = false

        divider.boxType = .custom
        divider.borderColor = .separatorColor
        divider.borderWidth = 1
        divider.fillColor = .separatorColor

        themeSwitch.target = self
        themeSwitch.action = #selector(themeChanged(_:))
        themeLabel.font = .systemFont(ofSize: 12)
        themeLabel.textColor = .secondaryLabelColor

        toolbarStack.orientation = .horizontal
        toolbarStack.alignment = .centerY
        toolbarStack.spacing = 8
        toolbarStack.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        filePicker.font = .systemFont(ofSize: 12)
        filePicker.target = self
        filePicker.action = #selector(fileSelectionChanged(_:))
        filePicker.widthAnchor.constraint(equalToConstant: 220).isActive = true

        wrapModePicker.font = .systemFont(ofSize: 12)
        wrapModePicker.addItems(withTitles: ["No Wrap", "Character Wrap", "Word Wrap"])
        wrapModePicker.target = self
        wrapModePicker.action = #selector(wrapModeChanged(_:))
        wrapModePicker.widthAnchor.constraint(equalToConstant: 132).isActive = true
        configureSearchPanel()
        configureToolbar()

        addSubview(toolbarStack)
        addSubview(divider)
        addSubview(searchPanel)
        addSubview(editorView)

        NSLayoutConstraint.activate([
            toolbarStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarStack.topAnchor.constraint(equalTo: topAnchor),
            toolbarStack.heightAnchor.constraint(equalToConstant: 44),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.topAnchor.constraint(equalTo: toolbarStack.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            searchPanel.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchPanel.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchPanel.topAnchor.constraint(equalTo: divider.bottomAnchor),

            editorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorView.topAnchor.constraint(equalTo: searchPanel.bottomAnchor),
            editorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        searchPanelHeightConstraint = searchPanel.heightAnchor.constraint(equalToConstant: 0)
        searchPanelHeightConstraint?.isActive = true

        themeSwitch.state = .on
        applyChromeTheme(isDark: true)
        editorView.applyTheme(SweetLineDecorationProvider.makeTheme(isDark: true))
        editorView.attachCompletionProvider(demoCompletionProvider)
        editorView.attachDecorationProvider(sweetLineDecorationProvider)
        configureFilePicker()
        loadSelectedFileIntoEditor()
    }

    @objc
    private func fileSelectionChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        _ = fileSelectionController?.selectFile(named: title)
        loadSelectedFileIntoEditor()
    }

    @objc
    private func themeChanged(_ sender: NSSwitch) {
        let isDark = sender.state == .on
        guard isDarkTheme != isDark else { return }
        isDarkTheme = isDark
        applyChromeTheme(isDark: isDark)
        editorView.applyTheme(SweetLineDecorationProvider.makeTheme(isDark: isDark))
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

    private func configureToolbar() {
        toolbarStack.addArrangedSubview(filePicker)
        toolbarStack.addArrangedSubview(makeToolbarSeparator())
        toolbarStack.addArrangedSubview(makeToolbarButton(
            symbolName: "arrow.uturn.backward", label: "Undo", action: #selector(undoButtonPressed(_:))))
        toolbarStack.addArrangedSubview(makeToolbarButton(
            symbolName: "arrow.uturn.forward", label: "Redo", action: #selector(redoButtonPressed(_:))))
        toolbarStack.addArrangedSubview(makeToolbarButton(
            symbolName: "magnifyingglass", label: "Find", action: #selector(findButtonPressed(_:))))
        toolbarStack.addArrangedSubview(makeToolbarSeparator())
        toolbarStack.addArrangedSubview(wrapModePicker)

        let spacer = NSView(frame: .zero)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        spacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        toolbarStack.addArrangedSubview(spacer)
        toolbarStack.addArrangedSubview(themeLabel)
        toolbarStack.addArrangedSubview(themeSwitch)
    }

    private func makeToolbarSeparator() -> NSView {
        let separator = NSBox(frame: .zero)
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return separator
    }

    private func makeToolbarButton(symbolName: String, label: String, action: Selector) -> NSButton {
        let button = NSButton(frame: .zero)
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        button.imagePosition = .imageOnly
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.target = self
        button.action = action
        button.bezelStyle = .texturedRounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 32).isActive = true
        button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        return button
    }

    @objc
    private func undoButtonPressed(_ sender: NSButton) {
        focusEditor()
        editorView.undo()
    }

    @objc
    private func redoButtonPressed(_ sender: NSButton) {
        focusEditor()
        editorView.redo()
    }

    @objc
    private func findButtonPressed(_ sender: NSButton) {
        openSearchPanel(replaceMode: false)
    }

    @objc
    private func wrapModeChanged(_ sender: NSPopUpButton) {
        let modes: [WrapMode] = [.none, .charBreak, .wordBreak]
        guard modes.indices.contains(sender.indexOfSelectedItem) else { return }
        editorView.settings.setWrapMode(modes[sender.indexOfSelectedItem])
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
    }

    private func replaceAllSearchMatches() {
        guard !searchPanel.isHidden else { return }
        let state = editorView.getSearchState()
        guard !searchField.stringValue.isEmpty, state.status != .FAILED, state.match_count > 0 else { return }
        editorView.replaceAllSearchMatches(decodeNewlineTokens(replaceField.stringValue))
        performSearch()
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

    private func focusEditor() {
        window?.makeFirstResponder(editorView)
        NSApp.activate(ignoringOtherApps: true)
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

    private func loadSelectedFileIntoEditor() {
        guard let selectedFile = fileSelectionController?.selectedFile else { return }
        clearSearchState()
        editorView.metadata = fileSelectionController?.currentMetadata
        editorView.loadDocument(text: selectedFile.text)
    }
}
