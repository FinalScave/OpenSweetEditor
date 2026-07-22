#if os(iOS)
import SwiftUI
import SweetEditorShared

public struct SweetEditor: UIViewRepresentable {
    public let theme: EditorTheme
    public let onFoldToggle: ((FoldToggleEvent) -> Void)?
    public let onInlayHintClick: ((InlayHintClickEvent) -> Void)?
    public let onGutterIconClick: ((GutterIconClickEvent) -> Void)?
    public let onCodeLensClick: ((CodeLensClickEvent) -> Void)?
    public let onLinkClick: ((LinkClickEvent) -> Void)?

    public init(
        theme: EditorTheme = .xcodeDark(),
        onFoldToggle: ((FoldToggleEvent) -> Void)? = nil,
        onInlayHintClick: ((InlayHintClickEvent) -> Void)? = nil,
        onGutterIconClick: ((GutterIconClickEvent) -> Void)? = nil,
        onCodeLensClick: ((CodeLensClickEvent) -> Void)? = nil,
        onLinkClick: ((LinkClickEvent) -> Void)? = nil
    ) {
        self.theme = theme
        self.onFoldToggle = onFoldToggle
        self.onInlayHintClick = onInlayHintClick
        self.onGutterIconClick = onGutterIconClick
        self.onCodeLensClick = onCodeLensClick
        self.onLinkClick = onLinkClick
    }

    public func makeUIView(context: Context) -> SweetEditorView {
        let view = SweetEditorView(frame: .zero)
        view.applyTheme(theme)
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        view.onCodeLensClick = onCodeLensClick
        view.onLinkClick = onLinkClick
        return view
    }

    public func updateUIView(_ view: SweetEditorView, context: Context) {
        view.applyTheme(theme)
        view.onFoldToggle = onFoldToggle
        view.onInlayHintClick = onInlayHintClick
        view.onGutterIconClick = onGutterIconClick
        view.onCodeLensClick = onCodeLensClick
        view.onLinkClick = onLinkClick
    }
}
#endif
