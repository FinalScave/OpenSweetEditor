import SwiftUI
import Combine
import SweetEditorIOS

@MainActor
final class DemoEditorHandle: ObservableObject {
    weak var view: SweetEditorView?

    func bind(_ view: SweetEditorView) {
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

    func undo() {
        view?.undo()
    }

    func redo() {
        view?.redo()
    }

    func canUndo() -> Bool {
        view?.canUndo() ?? false
    }

    func canRedo() -> Bool {
        view?.canRedo() ?? false
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
    let fileName: String
    let reloadToken: Int
    let isDarkTheme: Bool
    let wrapMode: WrapMode
    let editorHandle: DemoEditorHandle
    let onTextChanged: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SweetEditorView {
        let view = SweetEditorView(frame: .zero)
        let settings = view.settings

        settings.setEditorTextSize(16)
        settings.setCurrentLineRenderMode(.border)
        view.onTextChanged = { [weak view, onTextChanged] _ in
            onTextChanged(view?.getDocument()?.getText() ?? "")
        }
        let decorationProvider = SweetLineDecorationProvider(
            editorProvider: { [weak view] in view },
            fileNameProvider: { [weak coordinator = context.coordinator] in
                coordinator?.fileName ?? "sample.cpp"
            }
        )
        context.coordinator.decorationProvider = decorationProvider
        view.attachDecorationProvider(decorationProvider)
        editorHandle.bind(view)

        applyState(to: view, coordinator: context.coordinator)

        return view
    }

    func updateUIView(_ uiView: SweetEditorView, context: Context) {
        editorHandle.bind(uiView)
        applyState(to: uiView, coordinator: context.coordinator)
    }

    private func applyState(to view: SweetEditorView, coordinator: Coordinator) {
        coordinator.fileName = fileName
        view.onTextChanged = { [weak view, onTextChanged] _ in
            onTextChanged(view?.getDocument()?.getText() ?? "")
        }

        if coordinator.lastIsDarkTheme != isDarkTheme {
            view.applyTheme(SweetLineDecorationProvider.makeTheme(isDark: isDarkTheme))
            coordinator.lastIsDarkTheme = isDarkTheme
        }

        if coordinator.lastWrapMode != wrapMode {
            view.settings.setWrapMode(wrapMode)
            coordinator.lastWrapMode = wrapMode
        }

        let reloadTokenChanged = coordinator.lastReloadToken != reloadToken

        if reloadTokenChanged {
            view.loadDocument(text: text)
            coordinator.lastReloadToken = reloadToken
        }
    }

    final class Coordinator {
        var decorationProvider: SweetLineDecorationProvider?
        var fileName: String?
        var lastReloadToken: Int?
        var lastIsDarkTheme: Bool?
        var lastWrapMode: WrapMode?
    }
}
