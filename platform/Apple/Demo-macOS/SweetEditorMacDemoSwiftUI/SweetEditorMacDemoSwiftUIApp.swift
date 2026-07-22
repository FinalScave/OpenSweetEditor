import AppKit
import SwiftUI
import SweetEditorMacOS
import SweetEditorDemoSupport

@main
struct SweetEditorMacDemoSwiftUIApp: App {
    var body: some Scene {
        WindowGroup("SweetEditor SwiftUI Demo") {
            DemoContentView()
        }
        .defaultSize(width: 980, height: 620)
    }
}

private struct DemoContentView: View {
    private let samples = DemoSampleSupport.availableSampleFiles()
    @State private var selectedFileName = ""
    @State private var isDarkTheme = true

    private var selectedSample: DemoSampleSupport.DemoSampleFile {
        if let selected = samples.first(where: { $0.fileName == selectedFileName }) {
            return selected
        }
        if let first = samples.first {
            return first
        }
        return DemoSampleSupport.DemoSampleFile(
            fileName: "Untitled.cpp",
            text: "int main() {\n    return 0;\n}\n"
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("File", selection: $selectedFileName) {
                    ForEach(samples, id: \.fileName) { sample in
                        Text(sample.fileName).tag(sample.fileName)
                    }
                }
                .frame(width: 240)

                Toggle("Dark Theme", isOn: $isDarkTheme)
                    .toggleStyle(.switch)

                Spacer()

                Text("SweetEditorMacOS")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: 52)

            Divider()

            DemoEditor(
                sample: selectedSample,
                isDarkTheme: isDarkTheme
            )
        }
        .onAppear {
            if selectedFileName.isEmpty {
                selectedFileName = samples.first?.fileName ?? "Untitled.cpp"
            }
        }
    }
}

private struct DemoEditor: NSViewRepresentable {
    let sample: DemoSampleSupport.DemoSampleFile
    let isDarkTheme: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> SweetEditorView {
        let editor = SweetEditorView(frame: .zero)
        context.coordinator.editor = editor
        editor.attachCompletionProvider(context.coordinator.completionProvider)
        editor.attachDecorationProvider(context.coordinator.decorationProvider)
        editor.settings.setWrapMode(.wordBreak)
        applyState(to: editor, coordinator: context.coordinator)
        return editor
    }

    func updateNSView(_ editor: SweetEditorView, context: Context) {
        applyState(to: editor, coordinator: context.coordinator)
    }

    private func applyState(to editor: SweetEditorView, coordinator: Coordinator) {
        if coordinator.fileName != sample.fileName {
            coordinator.fileName = sample.fileName
            editor.loadDocument(text: sample.text)
        }
        if coordinator.isDarkTheme != isDarkTheme {
            coordinator.isDarkTheme = isDarkTheme
            editor.applyTheme(SweetLineDecorationProvider.makeTheme(isDark: isDarkTheme))
        }
    }

    final class Coordinator {
        let completionProvider = DemoCompletionProvider()
        weak var editor: SweetEditorView?
        var fileName: String?
        var isDarkTheme: Bool?

        lazy var decorationProvider = SweetLineDecorationProvider(
            editorProvider: { [weak self] in self?.editor },
            fileNameProvider: { [weak self] in self?.fileName ?? "sample.cpp" }
        )
    }
}
