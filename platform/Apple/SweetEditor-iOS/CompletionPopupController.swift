#if os(iOS)
import UIKit
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
    private var containerView: UIView?
    private var scrollView: UIScrollView?
    private var contentView: UIView?
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
        containerView?.isHidden = true
    }

    func applyTheme(_ theme: EditorTheme) {
        self.theme = theme
        containerView?.backgroundColor = UIColor(cgColor: theme.completionBgColor)
        containerView?.layer.borderColor = theme.completionBorderColor
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
        guard isShowing, let containerView, let editor else { return }
        let cursor = editor.getCursorRect()
        let cursorX = CGFloat(cursor.x)
        let cursorY = CGFloat(cursor.y)
        let cursorHeight = CGFloat(cursor.height)
        let popupHeight = CGFloat(min(items.count, maxVisibleItems)) * itemHeight
        var x = cursorX
        var y = cursorY + cursorHeight + gap
        if y + popupHeight > editor.bounds.height {
            y = cursorY - popupHeight - gap
        }
        if x + popupWidth > editor.bounds.width {
            x = editor.bounds.width - popupWidth
        }
        containerView.frame = CGRect(
            x: max(0, x),
            y: y,
            width: popupWidth,
            height: popupHeight
        )
    }

    private func show() {
        if containerView == nil { setupPopup() }
        containerView?.isHidden = false
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
        guard let scrollView, let contentView else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }
        for index in items.indices {
            let cell = makeCell(
                item: items[index],
                isSelected: index == selectedIndex,
                frame: CGRect(
                    x: 0,
                    y: CGFloat(index) * itemHeight,
                    width: popupWidth,
                    height: itemHeight
                )
            )
            cell.tag = index
            cell.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:))))
            contentView.addSubview(cell)
        }
        let contentSize = CGSize(width: popupWidth, height: CGFloat(items.count) * itemHeight)
        contentView.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.contentSize = contentSize
        if selectedIndex < items.count {
            scrollView.scrollRectToVisible(
                CGRect(
                    x: 0,
                    y: CGFloat(selectedIndex) * itemHeight,
                    width: popupWidth,
                    height: itemHeight
                ),
                animated: false
            )
        }
    }

    private func setupPopup() {
        guard let editor else { return }
        let view = UIView()
        view.backgroundColor = UIColor(cgColor: theme.completionBgColor)
        view.layer.cornerRadius = 4
        view.layer.borderWidth = 1
        view.layer.borderColor = theme.completionBorderColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowRadius = 4
        view.clipsToBounds = false
        view.isHidden = true
        let scrollView = UIScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.showsVerticalScrollIndicator = true
        let contentView = UIView()
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
        editor.addSubview(view)
        containerView = view
        self.scrollView = scrollView
        self.contentView = contentView
    }

    @objc private func cellTapped(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        selectedIndex = view.tag
        confirmSelected()
    }

    private func makeCell(item: CompletionItem, isSelected: Bool, frame: CGRect) -> UIView {
        let cell = UIView(frame: frame)
        cell.backgroundColor = isSelected
            ? UIColor(cgColor: theme.completionSelectedBgColor)
            : .clear
        cell.isUserInteractionEnabled = true

        let label = UILabel(frame: CGRect(x: 8, y: 0, width: frame.width * 0.6, height: frame.height))
        label.text = item.label
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = UIColor(cgColor: theme.completionLabelColor)
        cell.addSubview(label)

        if let detail = item.detail {
            let detailLabel = UILabel(
                frame: CGRect(
                    x: frame.width * 0.6 + 8,
                    y: 0,
                    width: frame.width * 0.35,
                    height: frame.height
                )
            )
            detailLabel.text = detail
            detailLabel.font = UIFont.systemFont(ofSize: 11)
            detailLabel.textColor = UIColor(cgColor: theme.completionDetailColor)
            detailLabel.textAlignment = .right
            cell.addSubview(detailLabel)
        }
        return cell
    }
}
#endif
