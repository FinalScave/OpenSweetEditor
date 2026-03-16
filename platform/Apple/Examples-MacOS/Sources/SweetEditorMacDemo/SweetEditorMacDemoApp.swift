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
           let editor = SweetEditorViewMacOS.activeEditor,
           editor.window === self,
           !event.modifierFlags.contains(.command) {
            editor.handleForwardedKeyDown(event)
            return
        }
        super.sendEvent(event)
    }
}

private final class DemoRootView: NSView {
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

    private var wrapModePreset = 0
    private var isDarkTheme = true
    private var decorationFeatureByIdentifier: [NSUserInterfaceItemIdentifier: DemoDecorationFeature] = [:]

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

        addSubview(headerView)
        addSubview(divider)
        addSubview(toolbarScrollView)
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

            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: toolbarScrollView.bottomAnchor),

            editorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            editorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            editorView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            editorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        themeSwitch.state = .on
        updateThemeLabel(isDark: true)
        applyChromeTheme(isDark: true)
        editorView.applyTheme(isDark: true)
        editorView.addCompletionProvider(demoCompletionProvider)
        editorView.addDecorationProvider(demoDecorationProvider)
        let sampleText = DemoSampleSupport.loadSampleText()
        editorView.loadDocument(text: sampleText)
        applyAllDecorations(showStatus: false)
        updateStatus("Ready")
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
    }

    private func resolvedCGColor(_ color: NSColor) -> CGColor {
        var resolved: CGColor?
        effectiveAppearance.performAsCurrentDrawingAppearance {
            resolved = color.cgColor
        }
        return resolved ?? color.cgColor
    }

    private func configureToolbarButtons() {
        let buttons: [(String, () -> Void)] = [
            ("Undo", { [weak self] in self?.triggerUndo() }),
            ("Redo", { [weak self] in self?.triggerRedo() }),
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

    private final class ToolbarButton: NSButton {
        var handler: (() -> Void)?
    }
}
