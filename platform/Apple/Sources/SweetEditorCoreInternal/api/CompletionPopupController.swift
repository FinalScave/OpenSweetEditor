import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Completion popup controller shared by iOS/macOS.
/// Platform-specific EditorView initializes and binds it during setup.
final class CompletionPopupController {

    var onConfirmed: ((CompletionItem) -> Void)?
    var cellProvider: CompletionItemCellProvider?

    private(set) var items: [CompletionItem] = []
    private(set) var selectedIndex = 0

    private let maxVisibleItems = 6
    private let itemHeight: CGFloat = 24
    private let popupWidth: CGFloat = 280
    private let gap: CGFloat = 4

    #if os(iOS)
    private weak var anchorView: UIView?
    private var containerView: UIView?
    private var tableView: UITableView?
    #elseif os(macOS)
    private weak var anchorView: NSView?
    private var panel: NSPanel?
    private var scrollView: NSScrollView?
    private var tableView: NSTableView?
    #endif

    private var _isShowing = false
    var isShowing: Bool { _isShowing }

    // MARK: - Initialization

    #if os(iOS)
    init(anchorView: UIView) {
        self.anchorView = anchorView
    }
    #elseif os(macOS)
    init(anchorView: NSView) {
        self.anchorView = anchorView
    }
    #endif

    // MARK: - Update Items

    func updateItems(_ newItems: [CompletionItem]) {
        items = newItems
        selectedIndex = 0
        if items.isEmpty {
            dismiss()
        } else {
            show()
            reloadList()
        }
    }

    func dismissPanel() {
        dismiss()
    }

    // MARK: - Keyboard Navigation

    /// Handles raw key codes. Enter=13, Escape=27, Up=38, Down=40.
    func handleKeyCode(_ keyCode: UInt16) -> Bool {
        guard isShowing, !items.isEmpty else { return false }
        switch keyCode {
        case 13: // Enter
            confirmSelected()
            return true
        case 27: // Escape
            dismiss()
            return true
        case 38: // Up
            moveSelection(-1)
            return true
        case 40: // Down
            moveSelection(1)
            return true
        default:
            return false
        }
    }

    /// Handles SEKeyCode.
    func handleSEKeyCode(_ keyCode: SEKeyCode) -> Bool {
        switch keyCode {
        case .enter:
            guard isShowing, !items.isEmpty else { return false }
            confirmSelected()
            return true
        case .escape:
            guard isShowing else { return false }
            dismiss()
            return true
        case .up:
            guard isShowing, !items.isEmpty else { return false }
            moveSelection(-1)
            return true
        case .down:
            guard isShowing, !items.isEmpty else { return false }
            moveSelection(1)
            return true
        default:
            return false
        }
    }

    // MARK: - Position

    func updatePosition(cursorX: CGFloat, cursorY: CGFloat, cursorHeight: CGFloat) {
        guard isShowing else { return }
        // Position update is platform-specific; basic implementation
        #if os(macOS)
        guard let anchorView, let window = anchorView.window, let panel else { return }
        let localPoint = NSPoint(x: cursorX, y: cursorY + cursorHeight + gap)
        let windowPoint = anchorView.convert(localPoint, to: nil)
        var screenPoint = window.convertPoint(toScreen: windowPoint)
        screenPoint.y -= panel.frame.height // macOS screen coords go up
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        if screenPoint.x + popupWidth > visibleFrame.maxX {
            screenPoint.x = max(visibleFrame.minX, visibleFrame.maxX - popupWidth)
        }
        if screenPoint.x < visibleFrame.minX {
            screenPoint.x = visibleFrame.minX
        }
        if screenPoint.y < visibleFrame.minY {
            screenPoint.y = min(window.convertPoint(toScreen: anchorView.convert(NSPoint(x: cursorX, y: cursorY - gap), to: nil)).y,
                                visibleFrame.maxY) + gap
        }
        if screenPoint.y + panel.frame.height > visibleFrame.maxY {
            screenPoint.y = visibleFrame.maxY - panel.frame.height
        }
        panel.setFrameOrigin(screenPoint)
        #elseif os(iOS)
        guard let containerView, let anchorView else { return }
        var x = cursorX
        var y = cursorY + cursorHeight + gap
        let popupHeight = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        if y + popupHeight > anchorView.bounds.height {
            y = cursorY - popupHeight - gap
        }
        if x + popupWidth > anchorView.bounds.width {
            x = anchorView.bounds.width - popupWidth
        }
        if x < 0 { x = 0 }
        containerView.frame = CGRect(x: x, y: y, width: popupWidth, height: popupHeight)
        #endif
    }

    // MARK: - Internal

    private func show() {
        #if os(iOS)
        if containerView == nil { setupIOSPopup() }
        containerView?.isHidden = false
        _isShowing = true
        #elseif os(macOS)
        if panel == nil { setupMacOSPopup() }
        guard let anchorView, let window = anchorView.window, let panel else { return }
        let height = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        panel.setContentSize(NSSize(width: popupWidth, height: height))
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        if !panel.isVisible {
            panel.orderFront(nil)
        }
        _isShowing = true
        #endif
    }

    func dismiss() {
        _isShowing = false
        #if os(iOS)
        containerView?.isHidden = true
        #elseif os(macOS)
        if let panel {
            panel.parent?.removeChildWindow(panel)
            panel.orderOut(nil)
        }
        #endif
    }

    private func moveSelection(_ delta: Int) {
        guard !items.isEmpty else { return }
        let old = selectedIndex
        selectedIndex = max(0, min(items.count - 1, selectedIndex + delta))
        if old != selectedIndex { reloadList() }
    }

    private func confirmSelected() {
        guard selectedIndex >= 0, selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        dismiss()
        onConfirmed?(item)
    }

    private func reloadList() {
        #if os(iOS)
        // Simple reload by removing & re-adding subviews
        guard let containerView else { return }
        containerView.subviews.forEach { $0.removeFromSuperview() }
        let visibleCount = min(items.count, maxVisibleItems)
        let startIdx = max(0, min(selectedIndex - visibleCount / 2, items.count - visibleCount))
        for i in 0..<visibleCount {
            let idx = startIdx + i
            guard idx < items.count else { break }
            let item = items[idx]
            let isSelected = idx == selectedIndex
            let cell = createDefaultIOSCell(item: item, isSelected: isSelected, frame: CGRect(x: 0, y: CGFloat(i) * itemHeight, width: popupWidth, height: itemHeight))
            let tapIdx = idx
            cell.tag = tapIdx
            let tap = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
            cell.addGestureRecognizer(tap)
            containerView.addSubview(cell)
        }
        let height = CGFloat(visibleCount) * itemHeight
        containerView.frame.size.height = height
        #elseif os(macOS)
        tableView?.reloadData()
        if selectedIndex < items.count {
            tableView?.scrollRowToVisible(selectedIndex)
        }
        #endif
    }

    // MARK: - iOS Setup

    #if os(iOS)
    private func setupIOSPopup() {
        guard let anchorView else { return }
        let view = UIView()
        view.backgroundColor = UIColor.systemBackground
        view.layer.cornerRadius = 4
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        view.clipsToBounds = false
        view.isHidden = true
        anchorView.addSubview(view)
        containerView = view
    }

    @objc private func cellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        selectedIndex = view.tag
        confirmSelected()
    }

    private func createDefaultIOSCell(item: CompletionItem, isSelected: Bool, frame: CGRect) -> UIView {
        let cell = UIView(frame: frame)
        cell.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.15) : .clear
        cell.isUserInteractionEnabled = true

        let label = UILabel(frame: CGRect(x: 8, y: 0, width: frame.width * 0.6, height: frame.height))
        label.text = item.label
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .label
        cell.addSubview(label)

        if let detail = item.detail {
            let detailLabel = UILabel(frame: CGRect(x: frame.width * 0.6 + 8, y: 0, width: frame.width * 0.35, height: frame.height))
            detailLabel.text = detail
            detailLabel.font = UIFont.systemFont(ofSize: 11)
            detailLabel.textColor = .secondaryLabel
            detailLabel.textAlignment = .right
            cell.addSubview(detailLabel)
        }
        return cell
    }
    #endif

    // MARK: - macOS Setup

    #if os(macOS)
    private func setupMacOSPopup() {
        let height = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        let contentRect = NSRect(x: 0, y: 0, width: popupWidth, height: height)

        let p = NSPanel(contentRect: contentRect,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .floating
        p.hasShadow = true
        p.backgroundColor = .windowBackgroundColor
        p.hidesOnDeactivate = true
        p.becomesKeyOnlyIfNeeded = true
        p.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]

        let sv = NSScrollView(frame: contentRect)
        sv.hasVerticalScroller = true
        sv.autoresizingMask = [.width, .height]

        let tv = NSTableView()
        tv.headerView = nil
        tv.rowHeight = itemHeight
        tv.backgroundColor = .windowBackgroundColor
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("completion"))
        col.width = popupWidth
        tv.addTableColumn(col)
        tv.delegate = MacTableDelegate.shared
        tv.dataSource = MacTableDelegate.shared
        MacTableDelegate.shared.controller = self

        sv.documentView = tv
        p.contentView = sv

        panel = p
        scrollView = sv
        tableView = tv
    }

    // Simple delegate for macOS NSTableView
    private final class MacTableDelegate: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        static let shared = MacTableDelegate()
        weak var controller: CompletionPopupController?

        func numberOfRows(in tableView: NSTableView) -> Int {
            controller?.items.count ?? 0
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let controller, row < controller.items.count else { return nil }
            let item = controller.items[row]
            let isSelected = row == controller.selectedIndex

            let cell = NSTextField(labelWithString: item.label)
            cell.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.backgroundColor = isSelected ? NSColor.selectedControlColor : .clear
            cell.drawsBackground = true
            return cell
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTableView, let controller else { return }
            let row = tv.selectedRow
            if row >= 0 && row < controller.items.count {
                controller.selectedIndex = row
                controller.confirmSelected()
            }
        }
    }
    #endif
}
