#if os(iOS)
import UIKit
import SweetEditorCoreInternal

public struct SweetEditorSelectionMenuItem: Hashable {
    public static let actionCut = "cut"
    public static let actionCopy = "copy"
    public static let actionPaste = "paste"
    public static let actionSelectAll = "select_all"

    public let id: String
    public let label: String
    public let isEnabled: Bool

    public init(id: String, label: String, isEnabled: Bool = true) {
        self.id = id
        self.label = label
        self.isEnabled = isEnabled
    }
}

public protocol SweetEditorSelectionMenuItemProvider: AnyObject {
    func provideSelectionMenuItems(for editor: SweetEditorViewiOS) -> [SweetEditorSelectionMenuItem]
}

final class IOSSelectionMenuController {
    private final class MenuButton: UIButton {
        var menuItem: SweetEditorSelectionMenuItem?
    }

    private enum LifecycleState {
        case hidden
        case pendingShow
        case visible
        case suspended
    }

    private static let showDelay: TimeInterval = 0.1
    private static let menuHeight: CGFloat = 36
    private static let menuMargin: CGFloat = 8
    private static let itemHorizontalPadding: CGFloat = 12

    private weak var editor: IOSEditorView?
    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var lifecycleState: LifecycleState = .hidden
    private var latestHasSelection = false
    private var coreBlocked = false
    private var pendingShow: DispatchWorkItem?
    private var menuTextColor = UIColor.label
    private var menuDividerColor = UIColor.separator

    var isShowing: Bool {
        lifecycleState == .visible
    }

    init(editor: IOSEditorView, theme: EditorTheme) {
        self.editor = editor
        configureViews()
        applyTheme(theme)
    }

    func onEditorActionResult(_ result: EditorActionResult) {
        latestHasSelection = result.has_selection_after
        coreBlocked = result.hasActiveInteraction || result.needsViewportMotion

        if result.content_changed || !latestHasSelection {
            dismiss()
            return
        }

        if coreBlocked {
            if result.selection_changed || lifecycleState != .hidden {
                suspend()
            }
            return
        }

        if result.selection_changed || lifecycleState == .suspended {
            scheduleShow()
        } else if lifecycleState == .visible {
            updatePosition()
        }
    }

    func updatePosition() {
        guard lifecycleState == .visible, let editor else {
            return
        }
        guard let anchor = editor.selectionMenuAnchorRect() else {
            dismiss()
            return
        }

        let maxWidth = max(0, editor.bounds.width - Self.menuMargin * 2)
        let menuWidth = min(stackView.frame.width + Self.menuMargin * 2, maxWidth)
        guard menuWidth > 0 else { return }

        var x = anchor.midX - menuWidth / 2
        x = min(max(x, Self.menuMargin), editor.bounds.width - menuWidth - Self.menuMargin)

        var y = anchor.minY - Self.menuHeight - Self.menuMargin
        if y < Self.menuMargin {
            y = anchor.maxY + Self.menuMargin
        }
        let maxY = max(0, editor.bounds.height - Self.menuHeight)
        y = min(max(y, 0), maxY)

        containerView.frame = CGRect(x: x, y: y, width: menuWidth, height: Self.menuHeight)
        scrollView.frame = containerView.bounds
    }

    func dismiss() {
        cancelPendingShow()
        hideMenu()
        lifecycleState = .hidden
    }

    func applyTheme(_ theme: EditorTheme) {
        containerView.backgroundColor = UIColor(cgColor: theme.selectionMenuBgColor)
        menuTextColor = UIColor(cgColor: theme.selectionMenuTextColor)
        menuDividerColor = UIColor(cgColor: theme.selectionMenuDividerColor)
        if lifecycleState == .visible {
            for view in stackView.arrangedSubviews {
                if let button = view as? MenuButton {
                    button.setTitleColor(menuTextColor, for: .normal)
                    button.setTitleColor(menuTextColor.withAlphaComponent(0.4), for: .disabled)
                } else {
                    view.backgroundColor = menuDividerColor
                }
            }
            updatePosition()
        }
    }

    private func configureViews() {
        guard let editor else { return }

        containerView.layer.cornerRadius = 7
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.22
        containerView.layer.shadowRadius = 5
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.clipsToBounds = false
        containerView.isHidden = true

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.layer.cornerRadius = 7
        scrollView.clipsToBounds = true

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0

        scrollView.addSubview(stackView)
        containerView.addSubview(scrollView)
        editor.addSubview(containerView)
    }

    private func scheduleShow() {
        cancelPendingShow()
        hideMenu()
        lifecycleState = .pendingShow

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.lifecycleState == .pendingShow,
                  self.latestHasSelection,
                  !self.coreBlocked,
                  self.editor?.selectionMenuHasSelection == true else {
                self?.dismiss()
                return
            }
            self.showNow()
        }
        pendingShow = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.showDelay, execute: workItem)
    }

    private func showNow() {
        guard let editor, editor.selectionMenuAnchorRect() != nil else {
            dismiss()
            return
        }

        let items = editor.selectionMenuItems()
        guard !items.isEmpty else {
            dismiss()
            return
        }

        rebuildItems(items)
        lifecycleState = .visible
        containerView.isHidden = false
        updatePosition()
        editor.bringSubviewToFront(containerView)
    }

    private func rebuildItems(_ items: [SweetEditorSelectionMenuItem]) {
        for view in stackView.arrangedSubviews {
            stackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        var width: CGFloat = 0
        for (index, item) in items.enumerated() {
            if index > 0 {
                let divider = UIView()
                divider.backgroundColor = menuDividerColor
                divider.widthAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale).isActive = true
                stackView.addArrangedSubview(divider)
                width += 1 / UIScreen.main.scale
            }
            let button = MenuButton(type: .system)
            button.menuItem = item
            button.setTitle(item.label, for: .normal)
            button.setTitleColor(menuTextColor, for: .normal)
            button.setTitleColor(menuTextColor.withAlphaComponent(0.4), for: .disabled)
            button.isEnabled = item.isEnabled
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
            button.accessibilityIdentifier = item.id
            button.addTarget(self, action: #selector(onMenuButtonTapped(_:)), for: .touchUpInside)
            button.sizeToFit()
            let buttonWidth = max(44, button.bounds.width + Self.itemHorizontalPadding * 2)
            button.frame = CGRect(x: 0, y: 0, width: buttonWidth, height: Self.menuHeight)
            button.widthAnchor.constraint(equalToConstant: buttonWidth).isActive = true
            stackView.addArrangedSubview(button)
            width += buttonWidth
        }

        stackView.frame = CGRect(x: Self.menuMargin, y: 0, width: width, height: Self.menuHeight)
        scrollView.contentSize = CGSize(width: width + Self.menuMargin * 2, height: Self.menuHeight)
    }

    @objc private func onMenuButtonTapped(_ sender: MenuButton) {
        guard let item = sender.menuItem else { return }
        onItemSelected(item)
    }

    private func onItemSelected(_ item: SweetEditorSelectionMenuItem) {
        guard item.isEnabled, let editor else { return }

        switch item.id {
        case SweetEditorSelectionMenuItem.actionCut:
            editor.selectionMenuCut()
        case SweetEditorSelectionMenuItem.actionCopy:
            editor.selectionMenuCopy()
        case SweetEditorSelectionMenuItem.actionPaste:
            editor.selectionMenuPaste()
        case SweetEditorSelectionMenuItem.actionSelectAll:
            editor.selectionMenuSelectAll()
            return
        default:
            editor.onSelectionMenuItemClick?(item)
        }
        dismiss()
    }

    private func suspend() {
        cancelPendingShow()
        hideMenu()
        lifecycleState = .suspended
    }

    private func hideMenu() {
        containerView.isHidden = true
    }

    private func cancelPendingShow() {
        pendingShow?.cancel()
        pendingShow = nil
    }
}
#endif
