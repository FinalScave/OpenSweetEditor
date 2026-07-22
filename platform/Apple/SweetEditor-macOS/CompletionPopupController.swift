#if os(macOS)
import AppKit
import SweetEditorShared

final class CompletionPopupController {
    private weak var editor: SweetEditorView?
    private var items: [CompletionItem] = []
    private var selectedIndex = 0
    private(set) var isShowing = false

    private let maxVisibleItems = 6
    private let itemHeight: CGFloat = 24
    private let popupWidth: CGFloat = 280
    private let gap: CGFloat = 4
    private var panel: NSPanel?
    private var tableView: NSTableView?
    private var tableDelegate: TableDelegate?
    private var theme: EditorTheme

    init(editor: SweetEditorView) {
        self.editor = editor
        theme = editor.theme
    }

    func updateItems(_ newItems: [CompletionItem]) {
        items = newItems
        selectedIndex = 0
        if items.isEmpty {
            dismiss()
        } else {
            show()
            reloadList()
            updatePosition()
        }
    }

    func dismiss() {
        isShowing = false
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
    }

    func applyTheme(_ theme: EditorTheme) {
        self.theme = theme
        panel?.backgroundColor = color(theme.completionBgColor)
        tableView?.backgroundColor = color(theme.completionBgColor)
        panel?.contentView?.layer?.borderColor = theme.completionBorderColor
        reloadList()
    }

    func handleKeyCode(_ keyCode: Int32) -> Bool {
        switch keyCode {
        case KeyCode.ENTER:
            guard isShowing, !items.isEmpty else { return false }
            confirmSelected()
            return true
        case KeyCode.ESCAPE:
            guard isShowing else { return false }
            editor?.dismissCompletion()
            return true
        case KeyCode.UP:
            guard isShowing, !items.isEmpty else { return false }
            moveSelection(-1)
            return true
        case KeyCode.DOWN:
            guard isShowing, !items.isEmpty else { return false }
            moveSelection(1)
            return true
        default:
            return false
        }
    }

    func updatePosition() {
        guard isShowing, let editor, let window = editor.window, let panel else { return }
        let cursor = editor.getCursorRect()
        let cursorX = CGFloat(cursor.x)
        let cursorY = CGFloat(cursor.y)
        let cursorHeight = CGFloat(cursor.height)
        let localPoint = NSPoint(x: cursorX, y: cursorY + cursorHeight + gap)
        let windowPoint = editor.convert(localPoint, to: nil)
        var screenPoint = window.convertPoint(toScreen: windowPoint)
        screenPoint.y -= panel.frame.height
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        if screenPoint.x + popupWidth > visibleFrame.maxX {
            screenPoint.x = max(visibleFrame.minX, visibleFrame.maxX - popupWidth)
        }
        if screenPoint.x < visibleFrame.minX {
            screenPoint.x = visibleFrame.minX
        }
        if screenPoint.y < visibleFrame.minY {
            let pointAbove = editor.convert(NSPoint(x: cursorX, y: cursorY - gap), to: nil)
            screenPoint.y = min(window.convertPoint(toScreen: pointAbove).y, visibleFrame.maxY) + gap
        }
        if screenPoint.y + panel.frame.height > visibleFrame.maxY {
            screenPoint.y = visibleFrame.maxY - panel.frame.height
        }
        panel.setFrameOrigin(screenPoint)
    }

    private func show() {
        if panel == nil { setupPopup() }
        guard let editor, let window = editor.window, let panel else { return }
        let height = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        panel.setContentSize(NSSize(width: popupWidth, height: height))
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        if !panel.isVisible {
            panel.orderFront(nil)
        }
        isShowing = true
    }

    private func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        let oldIndex = selectedIndex
        selectedIndex = max(0, min(items.count - 1, selectedIndex + delta))
        if oldIndex != selectedIndex { reloadList() }
    }

    private func confirmSelected() {
        guard selectedIndex >= 0, selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        dismiss()
        editor?.applyCompletionItem(item)
    }

    private func reloadList() {
        tableView?.reloadData()
        if selectedIndex < items.count {
            tableView?.scrollRowToVisible(selectedIndex)
        }
    }

    private func setupPopup() {
        let height = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        let contentRect = NSRect(x: 0, y: 0, width: popupWidth, height: height)
        let popup = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        popup.isFloatingPanel = true
        popup.level = .floating
        popup.hasShadow = true
        popup.backgroundColor = color(theme.completionBgColor)
        popup.hidesOnDeactivate = true
        popup.becomesKeyOnlyIfNeeded = true
        popup.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]

        let scrollView = NSScrollView(frame: contentRect)
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = color(theme.completionBgColor)
        scrollView.wantsLayer = true
        scrollView.layer?.borderWidth = 1
        scrollView.layer?.borderColor = theme.completionBorderColor
        scrollView.autoresizingMask = [.width, .height]

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = itemHeight
        tableView.backgroundColor = color(theme.completionBgColor)
        tableView.selectionHighlightStyle = .none
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
        column.width = popupWidth
        tableView.addTableColumn(column)
        let delegate = TableDelegate(controller: self)
        tableView.delegate = delegate
        tableView.dataSource = delegate

        scrollView.documentView = tableView
        popup.contentView = scrollView
        panel = popup
        self.tableView = tableView
        tableDelegate = delegate
    }

    private func color(_ value: CGColor) -> NSColor {
        NSColor(cgColor: value) ?? .clear
    }

    private final class TableDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private weak var controller: CompletionPopupController?

        init(controller: CompletionPopupController) {
            self.controller = controller
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            controller?.items.count ?? 0
        }

        func tableView(_ tableView: NSTableView,
                       viewFor tableColumn: NSTableColumn?,
                       row: Int) -> NSView? {
            guard let controller, row < controller.items.count else { return nil }
            let item = controller.items[row]
            let isSelected = row == controller.selectedIndex
            let cell = NSView()
            cell.wantsLayer = true
            cell.layer?.backgroundColor = isSelected
                ? controller.theme.completionSelectedBgColor
                : NSColor.clear.cgColor

            let label = NSTextField(labelWithString: item.label)
            label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            label.textColor = controller.color(controller.theme.completionLabelColor)
            label.lineBreakMode = .byTruncatingTail
            label.frame = NSRect(x: 8, y: 3, width: 166, height: 18)
            cell.addSubview(label)

            if let detail = item.detail {
                let detailLabel = NSTextField(labelWithString: detail)
                detailLabel.font = NSFont.systemFont(ofSize: 11)
                detailLabel.textColor = controller.color(controller.theme.completionDetailColor)
                detailLabel.alignment = .right
                detailLabel.lineBreakMode = .byTruncatingTail
                detailLabel.frame = NSRect(x: 180, y: 4, width: 92, height: 16)
                cell.addSubview(detailLabel)
            }
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView = notification.object as? NSTableView, let controller else { return }
            let row = tableView.selectedRow
            if row >= 0 && row < controller.items.count {
                controller.selectedIndex = row
                controller.confirmSelected()
            }
        }
    }
}
#endif
