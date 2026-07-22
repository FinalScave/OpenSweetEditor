#if os(macOS)
import AppKit
import SwiftUI
import SweetEditorShared

public struct SweetEditor: NSViewRepresentable {
    public let theme: EditorTheme
    public let showsPerformanceOverlay: Bool
    public let onFoldToggle: ((FoldToggleEvent) -> Void)?
    public let onInlayHintClick: ((InlayHintClickEvent) -> Void)?
    public let onGutterIconClick: ((GutterIconClickEvent) -> Void)?
    public let onCodeLensClick: ((CodeLensClickEvent) -> Void)?
    public let onLinkClick: ((LinkClickEvent) -> Void)?

    public init(
        theme: EditorTheme = .xcodeDark(),
        showsPerformanceOverlay: Bool = false,
        onFoldToggle: ((FoldToggleEvent) -> Void)? = nil,
        onInlayHintClick: ((InlayHintClickEvent) -> Void)? = nil,
        onGutterIconClick: ((GutterIconClickEvent) -> Void)? = nil,
        onCodeLensClick: ((CodeLensClickEvent) -> Void)? = nil,
        onLinkClick: ((LinkClickEvent) -> Void)? = nil
    ) {
        self.theme = theme
        self.showsPerformanceOverlay = showsPerformanceOverlay
        self.onFoldToggle = onFoldToggle
        self.onInlayHintClick = onInlayHintClick
        self.onGutterIconClick = onGutterIconClick
        self.onCodeLensClick = onCodeLensClick
        self.onLinkClick = onLinkClick
    }

    public func makeNSView(context: Context) -> SweetEditorView {
        let view = SweetEditorView(frame: .zero)
        view.applyTheme(theme)
        view.showsPerformanceOverlay = showsPerformanceOverlay
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        view.onCodeLensClick = onCodeLensClick
        view.onLinkClick = onLinkClick
        return view
    }

    public func updateNSView(_ nsView: SweetEditorView, context: Context) {
        nsView.applyTheme(theme)
        nsView.showsPerformanceOverlay = showsPerformanceOverlay
        nsView.onFoldToggle = onFoldToggle
        nsView.onInlayHintClick = onInlayHintClick
        nsView.onGutterIconClick = onGutterIconClick
        nsView.onCodeLensClick = onCodeLensClick
        nsView.onLinkClick = onLinkClick
    }
}
#endif
