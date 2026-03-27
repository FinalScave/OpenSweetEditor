import SwiftUI
import SweetEditoriOS

struct DemoEditorContainer: UIViewRepresentable {
    let text: String
    let showsDemoDecorations: Bool
    let isDarkTheme: Bool
    let wrapMode: WrapMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SweetEditorViewiOS {
        let view = SweetEditorViewiOS(frame: .zero)
        let settings = view.settings

        settings.setEditorTextSize(16)
        settings.setFoldArrowMode(.auto)
        settings.setCurrentLineRenderMode(.border)
        settings.setMaxGutterIcons(1)
        settings.setContentStartPadding(8)

        applyState(to: view, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: SweetEditorViewiOS, context: Context) {
        applyState(to: uiView, coordinator: context.coordinator)
    }

    private func applyState(to view: SweetEditorViewiOS, coordinator: Coordinator) {
        if coordinator.lastIsDarkTheme != isDarkTheme {
            view.applyTheme(isDark: isDarkTheme)
            coordinator.lastIsDarkTheme = isDarkTheme
        }

        if coordinator.lastWrapMode != wrapMode {
            view.settings.setWrapMode(wrapMode)
            coordinator.lastWrapMode = wrapMode
        }

        let textChanged = coordinator.lastText != text
        let decorationModeChanged = coordinator.lastShowsDemoDecorations != showsDemoDecorations

        if textChanged {
            view.loadDocument(text: text)
            coordinator.lastText = text
        }

        if textChanged || decorationModeChanged {
            if showsDemoDecorations {
                view.applyDecorations(DemoDecorationResolver.resolve(lines: text.components(separatedBy: "\n")))
            } else {
                view.applyDecorations(.empty)
            }
            coordinator.lastShowsDemoDecorations = showsDemoDecorations
        }
    }

    final class Coordinator {
        var lastText: String?
        var lastShowsDemoDecorations: Bool?
        var lastIsDarkTheme: Bool?
        var lastWrapMode: WrapMode?
    }
}
