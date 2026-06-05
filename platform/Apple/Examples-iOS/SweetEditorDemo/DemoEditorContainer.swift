import SwiftUI
import SweetEditoriOS

@MainActor
final class DemoEditorHandle: ObservableObject {
    weak var view: SweetEditorViewiOS?

    func bind(_ view: SweetEditorViewiOS) {
        self.view = view
    }

    func search(_ request: SearchRequest) {
        view?.search(request)
    }

    func findNextSearchMatch() {
        view?.findNextSearchMatch()
    }

    func findPreviousSearchMatch() {
        view?.findPreviousSearchMatch()
    }

    func replaceCurrentSearchMatch(_ replacement: String) {
        view?.replaceCurrentSearchMatch(replacement)
    }

    func replaceAllSearchMatches(_ replacement: String) {
        view?.replaceAllSearchMatches(replacement)
    }

    func clearSearch() {
        view?.clearSearch()
    }

    func getSearchState() -> SearchState {
        view?.getSearchState() ?? SearchState()
    }
}

struct DemoEditorContainer: UIViewRepresentable {
    let text: String
    let reloadToken: Int
    let showsDemoDecorations: Bool
    let isDarkTheme: Bool
    let wrapMode: WrapMode
    let editorHandle: DemoEditorHandle
    let onTextChanged: (String) -> Void

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
        view.onDocumentTextChanged = onTextChanged
        editorHandle.bind(view)

        applyState(to: view, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: SweetEditorViewiOS, context: Context) {
        editorHandle.bind(uiView)
        applyState(to: uiView, coordinator: context.coordinator)
    }

    private func applyState(to view: SweetEditorViewiOS, coordinator: Coordinator) {
        view.onDocumentTextChanged = onTextChanged

        if coordinator.lastIsDarkTheme != isDarkTheme {
            view.applyTheme(isDark: isDarkTheme)
            coordinator.lastIsDarkTheme = isDarkTheme
        }

        if coordinator.lastWrapMode != wrapMode {
            view.settings.setWrapMode(wrapMode)
            coordinator.lastWrapMode = wrapMode
        }

        let reloadTokenChanged = coordinator.lastReloadToken != reloadToken
        let decorationModeChanged = coordinator.lastShowsDemoDecorations != showsDemoDecorations

        if reloadTokenChanged {
            view.loadDocument(text: text)
            coordinator.lastText = text
            coordinator.lastReloadToken = reloadToken
        }

        if reloadTokenChanged || decorationModeChanged {
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
        var lastReloadToken: Int?
        var lastShowsDemoDecorations: Bool?
        var lastIsDarkTheme: Bool?
        var lastWrapMode: WrapMode?
    }
}
