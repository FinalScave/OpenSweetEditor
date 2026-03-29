//
//  ContentView.swift
//  SweetEditorDemo
//
//  Created by xiue233 on 2026/3/27.
//

import SwiftUI
import SweetEditoriOS

struct ContentView: View {
    @StateObject private var model = DemoScreenModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            editorSection
            statusBar
        }
        .background(chromeBackground)
        .task {
            model.startInitialLoadIfNeeded()
        }
    }

    @ViewBuilder
    private var editorSection: some View {
        if model.documentText.isEmpty {
            VStack(spacing: 12) {
                if model.isLoadingDocument {
                    ProgressView()
                        .tint(primaryForegroundColor)
                }
                Text(model.statusText)
                    .font(.callout)
                    .foregroundStyle(secondaryForegroundColor)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(chromeBackground)
        } else {
            DemoEditorContainer(
                text: model.documentText,
                reloadToken: model.documentReloadToken,
                showsDemoDecorations: model.shouldApplyDecorations,
                isDarkTheme: model.isDarkTheme,
                wrapMode: model.wrapMode,
                onTextChanged: model.updateDocumentText
            )
        }
    }

    private var toolbar: some View {
        HStack(spacing: 5) {
            Picker("File", selection: fileSelectionBinding) {
                ForEach(model.fileNames, id: \.self) { fileName in
                    Text(fileName).tag(fileName)
                }
            }
            .pickerStyle(.menu)

            Button(action: model.toggleTheme) {
                Image(systemName: model.isDarkTheme ? "sun.max" : "moon")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(primaryForegroundColor)

            Button(action: model.cycleWrapMode) {
                Image(systemName: "text.alignleft")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(primaryForegroundColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(chromeBackground)
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(model.statusText)
                .lineLimit(1)

            Spacer()

            Text(DemoWrapModeCycle.title(for: model.wrapMode))
        }
        .font(.caption)
        .foregroundStyle(secondaryForegroundColor)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(chromeBackground)
    }

    private var fileSelectionBinding: Binding<String> {
        Binding(
            get: { model.currentFileName },
            set: { model.selectFile(named: $0) }
        )
    }

    private var chromeBackground: Color {
        model.isDarkTheme ? Color(red: 0.11, green: 0.12, blue: 0.14) : Color(red: 0.98, green: 0.98, blue: 0.99)
    }

    private var primaryForegroundColor: Color {
        model.isDarkTheme ? .white : Color(red: 0.13, green: 0.16, blue: 0.22)
    }

    private var secondaryForegroundColor: Color {
        model.isDarkTheme ? Color.white.opacity(0.65) : Color(red: 0.42, green: 0.47, blue: 0.54)
    }

    private func foregroundColor(for role: DemoToolbarStyle.ForegroundRole) -> Color {
        switch role {
        case .primary:
            return primaryForegroundColor
        case .secondary:
            return secondaryForegroundColor
        }
    }
}

#Preview {
    ContentView()
}
