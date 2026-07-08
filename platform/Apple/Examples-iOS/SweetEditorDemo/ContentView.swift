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
    @StateObject private var editorHandle = DemoEditorHandle()
    @State private var isSearchVisible = false
    @State private var isReplaceVisible = false
    @State private var searchText = ""
    @State private var replaceText = ""
    @State private var searchCaseSensitive = false
    @State private var searchWholeWord = false
    @State private var searchUseRegex = false
    @State private var searchState = SearchState()
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            searchPanel
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
                editorHandle: editorHandle,
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

            Button(action: handleUndo) {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(primaryForegroundColor)

            Button(action: handleRedo) {
                Image(systemName: "arrow.uturn.forward")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(primaryForegroundColor)

            Menu {
                Button(action: { openSearch(replaceMode: false) }) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)

                Button(action: { openSearch(replaceMode: true) }) {
                    Label("Replace", systemImage: "arrow.left.arrow.right")
                }
                .keyboardShortcut("h", modifiers: .command)

                Button(action: model.cycleWrapMode) {
                    Label(DemoWrapModeCycle.title(for: model.wrapMode), systemImage: "text.alignleft")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(primaryForegroundColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(chromeBackground)
    }

    @ViewBuilder
    private var searchPanel: some View {
        if isSearchVisible {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Find", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .focused($searchFocused)
                        .onChange(of: searchText) { _ in performSearch() }
                        .onSubmit(findNextSearchMatch)

                    Button("\\n") {
                        searchText += "\\n"
                        performSearch()
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(primaryForegroundColor)

                    Text(searchCounterText)
                        .font(.caption)
                        .foregroundStyle(secondaryForegroundColor)
                        .frame(width: 54)

                    searchToggle("Aa", isOn: $searchCaseSensitive)
                    searchToggle("Word", isOn: $searchWholeWord)
                    searchToggle(".*", isOn: $searchUseRegex)

                    Button(action: findPreviousSearchMatch) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(primaryForegroundColor)

                    Button(action: findNextSearchMatch) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(primaryForegroundColor)

                    Button(action: closeSearch) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(primaryForegroundColor)
                    .keyboardShortcut(.escape, modifiers: [])
                }

                if isReplaceVisible {
                    HStack(spacing: 6) {
                        TextField("Replace", text: $replaceText)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(replaceCurrentSearchMatch)

                        Button("\\n") {
                            replaceText += "\\n"
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(primaryForegroundColor)

                        Button("Replace", action: replaceCurrentSearchMatch)
                            .buttonStyle(.borderless)
                            .foregroundStyle(primaryForegroundColor)

                        Button("All", action: replaceAllSearchMatches)
                            .buttonStyle(.borderless)
                            .foregroundStyle(primaryForegroundColor)
                    }
                }
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(chromeBackground)
        }
    }

    private func searchToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button(title) {
            isOn.wrappedValue.toggle()
            performSearch()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(isOn.wrappedValue ? primaryForegroundColor : secondaryForegroundColor)
    }

    private func handleUndo() {
        guard editorHandle.canUndo() else {
            model.updateStatus("Nothing to undo")
            return
        }
        editorHandle.undo()
        model.updateStatus("Undo")
    }

    private func handleRedo() {
        guard editorHandle.canRedo() else {
            model.updateStatus("Nothing to redo")
            return
        }
        editorHandle.redo()
        model.updateStatus("Redo")
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
            set: {
                clearSearchState()
                model.selectFile(named: $0)
            }
        )
    }

    private var searchCounterText: String {
        guard isSearchVisible, !searchText.isEmpty else {
            return ""
        }
        if searchState.status == .FAILED {
            return "Error"
        }
        if searchState.match_count <= 0 {
            return "0/0"
        }
        let index = searchState.has_current_match ? searchState.current_index + 1 : 0
        return "\(index)/\(searchState.match_count)"
    }

    private func openSearch(replaceMode: Bool) {
        isSearchVisible = true
        isReplaceVisible = replaceMode
        searchFocused = true
        performSearch()
    }

    private func closeSearch() {
        clearSearchState()
        isSearchVisible = false
        isReplaceVisible = false
        model.updateStatus("Search closed")
    }

    private func clearSearchState() {
        editorHandle.clearSearch()
        searchState = SearchState()
    }

    private func performSearch() {
        guard isSearchVisible else { return }
        let pattern = decodeNewlineTokens(searchText)
        if pattern.isEmpty {
            clearSearchState()
            return
        }

        editorHandle.search(
            SearchRequest(
                pattern: pattern,
                options: SearchOptions(
                    case_sensitive: searchCaseSensitive,
                    whole_word: searchWholeWord,
                    use_regex: searchUseRegex
                )
            )
        )
        refreshSearchState()
        if searchState.status == .FAILED {
            model.updateStatus(searchState.error_message.isEmpty ? "Search failed" : searchState.error_message)
        }
    }

    private func findNextSearchMatch() {
        guard isSearchVisible else {
            openSearch(replaceMode: false)
            return
        }
        editorHandle.findNextSearchMatch()
        refreshSearchState()
    }

    private func findPreviousSearchMatch() {
        guard isSearchVisible else {
            openSearch(replaceMode: false)
            return
        }
        editorHandle.findPreviousSearchMatch()
        refreshSearchState()
    }

    private func replaceCurrentSearchMatch() {
        guard isSearchVisible else { return }
        let state = editorHandle.getSearchState()
        guard !searchText.isEmpty, state.status != .FAILED, state.has_current_match else { return }
        editorHandle.replaceCurrentSearchMatch(decodeNewlineTokens(replaceText))
        performSearch()
        model.updateStatus("Replace")
    }

    private func replaceAllSearchMatches() {
        guard isSearchVisible else { return }
        let state = editorHandle.getSearchState()
        guard !searchText.isEmpty, state.status != .FAILED, state.match_count > 0 else { return }
        let count = state.match_count
        editorHandle.replaceAllSearchMatches(decodeNewlineTokens(replaceText))
        performSearch()
        model.updateStatus("Replaced \(count) matches")
    }

    private func refreshSearchState() {
        searchState = editorHandle.getSearchState()
    }

    private func decodeNewlineTokens(_ text: String) -> String {
        var decoded = ""
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == "\\" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex {
                    let next = text[nextIndex]
                    if next == "n" {
                        decoded.append("\n")
                        index = text.index(after: nextIndex)
                        continue
                    }
                    if next == "\\" {
                        decoded.append("\\")
                        index = text.index(after: nextIndex)
                        continue
                    }
                }
            }
            decoded.append(ch)
            index = text.index(after: index)
        }
        return decoded
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
