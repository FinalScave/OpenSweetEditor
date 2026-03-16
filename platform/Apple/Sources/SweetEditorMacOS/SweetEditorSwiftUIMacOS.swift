#if os(macOS)
import AppKit
import SwiftUI
import SweetEditorCoreInternal

public struct SweetEditorSwiftUIMacOS: NSViewRepresentable {
    public let isDarkTheme: Bool
    public let showsPerformanceOverlay: Bool
    public let onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)?
    public let onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)?
    public let onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)?

    public init(
        isDarkTheme: Bool = false,
        showsPerformanceOverlay: Bool = false,
        onFoldToggle: ((SweetEditorFoldToggleEvent) -> Void)? = nil,
        onInlayHintClick: ((SweetEditorInlayHintClickEvent) -> Void)? = nil,
        onGutterIconClick: ((SweetEditorGutterIconClickEvent) -> Void)? = nil
    ) {
        self.isDarkTheme = isDarkTheme
        self.showsPerformanceOverlay = showsPerformanceOverlay
        self.onFoldToggle = onFoldToggle
        self.onInlayHintClick = onInlayHintClick
        self.onGutterIconClick = onGutterIconClick
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public func makeNSView(context: Context) -> SweetEditorViewMacOS {
        let view = SweetEditorViewMacOS(frame: .zero)
        view.showsPerformanceOverlay = showsPerformanceOverlay
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        return view
    }

    public func updateNSView(_ nsView: SweetEditorViewMacOS, context: Context) {
        nsView.applyTheme(isDark: isDarkTheme)
        nsView.showsPerformanceOverlay = showsPerformanceOverlay
        nsView.onFoldToggle = onFoldToggle
        nsView.onInlayHintClick = onInlayHintClick
        nsView.onGutterIconClick = onGutterIconClick
        requestInitialFocusIfNeeded(view: nsView, coordinator: context.coordinator)
    }

    private func requestInitialFocusIfNeeded(view: SweetEditorViewMacOS, coordinator: Coordinator) {
        guard !coordinator.didSetInitialFocus else { return }
        guard let window = view.window else {
            DispatchQueue.main.async {
                requestInitialFocusIfNeeded(view: view, coordinator: coordinator)
            }
            return
        }
        coordinator.didSetInitialFocus = true
        DispatchQueue.main.async { [weak view, weak window] in
            guard let view = view else { return }
            let resolvedWindow = window ?? view.window
            guard let window = resolvedWindow else { return }
            window.initialFirstResponder = view
            window.makeFirstResponder(view)
            SweetEditorViewMacOS.activeEditor = view
        }
    }

    public final class Coordinator {
        var didSetInitialFocus = false
    }
}
#endif
