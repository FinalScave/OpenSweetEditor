package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.config.WrapMode;
import com.qiplat.sweeteditor.core.search.SearchOptions;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.search.SearchStatus;
import com.qiplat.sweeteditor.event.CodeLensClickEvent;
import com.qiplat.sweeteditor.event.LinkClickEvent;

import javax.swing.AbstractAction;
import javax.swing.BorderFactory;
import javax.swing.BoxLayout;
import javax.swing.DefaultComboBoxModel;
import javax.swing.InputMap;
import javax.swing.JComponent;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JTextField;
import javax.swing.JToggleButton;
import javax.swing.KeyStroke;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;
import javax.swing.event.DocumentEvent;
import javax.swing.event.DocumentListener;
import java.awt.*;
import java.awt.event.ActionListener;
import java.awt.event.InputEvent;
import java.awt.event.KeyEvent;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

public class Main extends JFrame {
    private static final String FALLBACK_FILE_NAME = "example.cpp";
    private static final String FALLBACK_SAMPLE_CODE =
            "// SweetEditor Demo\n" +
            "int main() {\n" +
            "    return 0;\n" +
            "}\n";

    private final SweetEditor editor;
    private final JLabel statusLabel;
    private final JComboBox<String> fileComboBox;
    private final JPanel searchPanel;
    private final JPanel replaceRow;
    private final JTextField searchField;
    private final JTextField replaceField;
    private final JLabel searchCounterLabel;
    private final JToggleButton matchCaseButton;
    private final JToggleButton wholeWordButton;
    private final JToggleButton regexButton;
    private final List<Path> demoFiles = new ArrayList<>();

    private boolean isDarkTheme = true;
    private WrapMode wrapModePreset = WrapMode.NONE;
    private boolean suppressFileSelection;

    private final DemoDecorationProvider demoProvider;
    private final DemoCompletionProvider demoCompletionProvider;

    public Main() {
        super("SweetEditor - Swing Demo");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1200, 800);
        setLocationRelativeTo(null);

        editor = new SweetEditor(EditorTheme.dark());
        String demoFontFamily = resolveDemoFontFamily();
        if (demoFontFamily != null) {
            editor.getSettings().setFontFamily(demoFontFamily);
        }
        editor.getSettings().setCursorAnimationEnabled(true);
        editor.getSettings().setGutterAnimationEnabled(true);

        statusLabel = new JLabel("Ready");
        statusLabel.setBorder(BorderFactory.createEmptyBorder(4, 8, 4, 4));

        registerDemoStylesForCurrentTheme();

        try {
            DemoDecorationProvider.ensureSweetLineReady(resolveSyntaxFiles());
        } catch (IOException e) {
            throw new RuntimeException(e);
        }

        editor.getSettings().setCurrentLineRenderMode(CurrentLineRenderMode.BORDER);

        demoProvider = new DemoDecorationProvider();
        editor.addDecorationProvider(demoProvider);

        demoCompletionProvider = new DemoCompletionProvider();
        editor.addCompletionProvider(demoCompletionProvider);
        editor.subscribe(CodeLensClickEvent.class, e ->
                updateStatus("CodeLens " + describeCodeLensCommand(e.commandId) + " at line: " + (e.line + 1)));
        editor.subscribe(LinkClickEvent.class, e -> updateStatus("Link: " + e.target));

        JPanel toolbar = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 4));
        fileComboBox = new JComboBox<>();
        fileComboBox.setPreferredSize(new Dimension(140, 28));
        fileComboBox.addActionListener(e -> {
            if (suppressFileSelection) {
                return;
            }
            int selectedIndex = fileComboBox.getSelectedIndex();
            if (selectedIndex < 0 || selectedIndex >= demoFiles.size()) {
                return;
            }
            loadDemoFile(demoFiles.get(selectedIndex));
        });

        toolbar.add(fileComboBox);
        toolbar.add(makeButton("Undo", e -> {
            if (editor.canUndo()) {
                editor.undo();
                updateStatus("Undo");
            } else {
                updateStatus("Nothing to undo");
            }
        }));
        toolbar.add(makeButton("Redo", e -> {
            if (editor.canRedo()) {
                editor.redo();
                updateStatus("Redo");
            } else {
                updateStatus("Nothing to redo");
            }
        }));
        toolbar.add(makeButton("Theme", e -> {
            isDarkTheme = !isDarkTheme;
            editor.applyTheme(isDarkTheme ? EditorTheme.dark() : EditorTheme.light());
            registerDemoStylesForCurrentTheme();
            updateStatus(isDarkTheme ? "Switched to dark theme" : "Switched to light theme");
        }));
        toolbar.add(makeButton("WrapMode", e -> cycleWrapMode()));
        toolbar.add(makeButton("Search", e -> openSearchPanel(false)));
        toolbar.add(makeButton("Replace", e -> openSearchPanel(true)));
        toolbar.add(statusLabel);

        searchPanel = new JPanel();
        searchPanel.setLayout(new BoxLayout(searchPanel, BoxLayout.Y_AXIS));
        searchPanel.setBorder(BorderFactory.createEmptyBorder(2, 6, 6, 6));
        searchPanel.setVisible(false);

        JPanel searchRow = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 2));
        searchField = new JTextField(22);
        searchField.getDocument().addDocumentListener(new SimpleDocumentListener(this::performSearch));
        searchField.addActionListener(e -> findNextSearchMatch());
        searchRow.add(new JLabel("Search"));
        searchRow.add(searchField);
        searchRow.add(makeButton("\\n", e -> insertNewlineToken(searchField)));
        searchCounterLabel = new JLabel("0/0");
        searchCounterLabel.setPreferredSize(new Dimension(52, 24));
        searchRow.add(searchCounterLabel);
        matchCaseButton = makeToggle("Aa", e -> performSearch());
        wholeWordButton = makeToggle("Word", e -> performSearch());
        regexButton = makeToggle(".*", e -> performSearch());
        searchRow.add(matchCaseButton);
        searchRow.add(wholeWordButton);
        searchRow.add(regexButton);
        searchRow.add(makeButton("Prev", e -> findPreviousSearchMatch()));
        searchRow.add(makeButton("Next", e -> findNextSearchMatch()));
        searchRow.add(makeButton("Close", e -> closeSearchPanel()));
        searchPanel.add(searchRow);

        replaceRow = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 2));
        replaceField = new JTextField(22);
        replaceField.addActionListener(e -> replaceCurrentSearchMatch());
        replaceRow.add(new JLabel("Replace"));
        replaceRow.add(replaceField);
        replaceRow.add(makeButton("\\n", e -> insertNewlineToken(replaceField)));
        replaceRow.add(makeButton("Replace", e -> replaceCurrentSearchMatch()));
        replaceRow.add(makeButton("All", e -> replaceAllSearchMatches()));
        searchPanel.add(replaceRow);

        JPanel topPanel = new JPanel(new BorderLayout());
        topPanel.add(toolbar, BorderLayout.NORTH);
        topPanel.add(searchPanel, BorderLayout.SOUTH);

        setLayout(new BorderLayout());
        add(topPanel, BorderLayout.NORTH);
        add(editor, BorderLayout.CENTER);

        installSearchShortcuts();
        setupFileSpinner();
    }

    private JButton makeButton(String text, ActionListener action) {
        JButton btn = new JButton(text);
        btn.setMargin(new Insets(2, 6, 2, 6));
        btn.addActionListener(action);
        return btn;
    }

    private JToggleButton makeToggle(String text, ActionListener action) {
        JToggleButton btn = new JToggleButton(text);
        btn.setMargin(new Insets(2, 6, 2, 6));
        btn.addActionListener(action);
        return btn;
    }

    private void setupFileSpinner() {
        demoFiles.clear();
        demoFiles.addAll(listDemoFiles());

        DefaultComboBoxModel<String> model = new DefaultComboBoxModel<>();
        for (Path file : demoFiles) {
            model.addElement(file.getFileName().toString());
        }

        suppressFileSelection = true;
        fileComboBox.setModel(model);
        suppressFileSelection = false;

        if (demoFiles.isEmpty()) {
            loadDemoText(FALLBACK_FILE_NAME, FALLBACK_SAMPLE_CODE);
            return;
        }

        fileComboBox.setSelectedIndex(0);
    }

    private void loadDemoFile(Path filePath) {
        try {
            String text = Files.readString(filePath, StandardCharsets.UTF_8);
            loadDemoText(filePath.getFileName().toString(), text);
        } catch (IOException e) {
            loadDemoText(filePath.getFileName().toString(), FALLBACK_SAMPLE_CODE);
        }
    }

    private void loadDemoText(String fileName, String text) {
        String normalizedText = normalizeNewlines(text);
        demoProvider.setDocumentSource(fileName, normalizedText);
        editor.loadDocument(new Document(normalizedText));
        editor.setMetadata(new DemoDecorationProvider.DemoFileMetadata(fileName));
        editor.requestDecorationRefresh();
        SwingUtilities.invokeLater(editor::requestDecorationRefresh);
        clearSearchState();
        updateStatus("Loaded: " + fileName);
    }

    private void openSearchPanel(boolean replaceMode) {
        searchPanel.setVisible(true);
        replaceRow.setVisible(replaceMode);
        revalidate();
        repaint();
        searchField.requestFocusInWindow();
        searchField.selectAll();
        if (!searchField.getText().isEmpty()) {
            performSearch();
        }
    }

    private void closeSearchPanel() {
        clearSearchState();
        searchPanel.setVisible(false);
        revalidate();
        repaint();
        editor.requestFocusInWindow();
    }

    private void clearSearchState() {
        editor.clearSearch();
        searchCounterLabel.setText("0/0");
    }

    private void performSearch() {
        if (!searchPanel.isVisible()) {
            return;
        }
        String pattern = decodeNewlineTokens(searchField.getText());
        if (pattern.isEmpty()) {
            clearSearchState();
            return;
        }
        SearchOptions options = new SearchOptions();
        options.caseSensitive = matchCaseButton.isSelected();
        options.wholeWord = wholeWordButton.isSelected();
        options.useRegex = regexButton.isSelected();
        editor.search(new SearchRequest(pattern, options));
        refreshSearchState();
    }

    private void findNextSearchMatch() {
        if (searchField.getText().isEmpty()) {
            return;
        }
        editor.findNextSearchMatch();
        refreshSearchState();
    }

    private void findPreviousSearchMatch() {
        if (searchField.getText().isEmpty()) {
            return;
        }
        editor.findPreviousSearchMatch();
        refreshSearchState();
    }

    private void replaceCurrentSearchMatch() {
        if (searchField.getText().isEmpty()) {
            return;
        }
        SearchState state = editor.getSearchState();
        if (state.status == SearchStatus.FAILED || !state.hasCurrentMatch) {
            return;
        }
        editor.replaceCurrentSearchMatch(decodeNewlineTokens(replaceField.getText()));
        performSearch();
        updateStatus("Replace");
    }

    private void replaceAllSearchMatches() {
        if (searchField.getText().isEmpty()) {
            return;
        }
        SearchState state = editor.getSearchState();
        if (state.status == SearchStatus.FAILED || state.matchCount <= 0) {
            return;
        }
        int count = state.matchCount;
        editor.replaceAllSearchMatches(decodeNewlineTokens(replaceField.getText()));
        performSearch();
        updateStatus("Replaced " + count + " matches");
    }

    private void refreshSearchState() {
        SearchState state = editor.getSearchState();
        if (state.status == SearchStatus.FAILED) {
            searchCounterLabel.setText("Error");
            updateStatus(state.errorMessage.isEmpty() ? "Search error" : state.errorMessage);
        } else if (state.matchCount <= 0) {
            searchCounterLabel.setText("0/0");
            updateStatus("No matches");
        } else {
            int current = state.currentIndex >= 0 ? state.currentIndex + 1 : 0;
            searchCounterLabel.setText(current + "/" + state.matchCount);
            updateStatus("Search " + current + "/" + state.matchCount);
        }
    }

    private void installSearchShortcuts() {
        int menuMask = Toolkit.getDefaultToolkit().getMenuShortcutKeyMaskEx();
        InputMap inputMap = getRootPane().getInputMap(JComponent.WHEN_IN_FOCUSED_WINDOW);
        inputMap.put(KeyStroke.getKeyStroke(KeyEvent.VK_F, menuMask), "openSearch");
        inputMap.put(KeyStroke.getKeyStroke(KeyEvent.VK_H, menuMask), "openReplace");
        inputMap.put(KeyStroke.getKeyStroke(KeyEvent.VK_ESCAPE, 0), "closeSearch");
        inputMap.put(KeyStroke.getKeyStroke(KeyEvent.VK_ENTER, InputEvent.SHIFT_DOWN_MASK), "previousSearchMatch");
        getRootPane().getActionMap().put("openSearch", new AbstractAction() {
            @Override
            public void actionPerformed(java.awt.event.ActionEvent e) {
                openSearchPanel(false);
            }
        });
        getRootPane().getActionMap().put("openReplace", new AbstractAction() {
            @Override
            public void actionPerformed(java.awt.event.ActionEvent e) {
                openSearchPanel(true);
            }
        });
        getRootPane().getActionMap().put("closeSearch", new AbstractAction() {
            @Override
            public void actionPerformed(java.awt.event.ActionEvent e) {
                if (searchPanel.isVisible()) {
                    closeSearchPanel();
                }
            }
        });
        getRootPane().getActionMap().put("previousSearchMatch", new AbstractAction() {
            @Override
            public void actionPerformed(java.awt.event.ActionEvent e) {
                if (searchPanel.isVisible()) {
                    findPreviousSearchMatch();
                }
            }
        });
    }

    private void insertNewlineToken(JTextField field) {
        int start = Math.max(field.getSelectionStart(), 0);
        int end = Math.max(field.getSelectionEnd(), 0);
        if (start > end) {
            int temp = start;
            start = end;
            end = temp;
        }
        String text = field.getText();
        field.setText(text.substring(0, start) + "\\n" + text.substring(end));
        field.setCaretPosition(start + 2);
    }

    private String decodeNewlineTokens(String text) {
        StringBuilder builder = new StringBuilder(text.length());
        for (int i = 0; i < text.length(); i++) {
            char ch = text.charAt(i);
            if (ch == '\\' && i + 1 < text.length()) {
                char next = text.charAt(i + 1);
                if (next == 'n') {
                    builder.append('\n');
                    i++;
                    continue;
                }
                if (next == '\\') {
                    builder.append('\\');
                    i++;
                    continue;
                }
            }
            builder.append(ch);
        }
        return builder.toString();
    }

    private void cycleWrapMode() {
        WrapMode[] wrapModes = WrapMode.values();
        wrapModePreset = wrapModes[(wrapModePreset.ordinal() + 1) % wrapModes.length];
        editor.getSettings().setWrapMode(wrapModePreset);
        updateStatus("WrapMode: " + wrapModePreset.name());
    }

    private void updateStatus(String message) {
        statusLabel.setText(message);
    }

    private String describeCodeLensCommand(int commandId) {
        if (commandId == DemoDecorationProvider.CODELENS_RUN) {
            return "▶ Run";
        }
        if (commandId == DemoDecorationProvider.CODELENS_DEBUG) {
            return "◎ Debug";
        }
        return "Command#" + commandId;
    }

    private void registerDemoStylesForCurrentTheme() {
        int color = isDarkTheme ? 0xFFB5CEA8 : 0xFF098658;
        int linkColor = isDarkTheme ? 0xFF7DCFFF : 0xFF005FB8;
        editor.registerTextStyle(DemoDecorationProvider.STYLE_COLOR, color, 0);
        editor.registerTextStyle(DemoDecorationProvider.STYLE_LINK, linkColor, 0);
    }

    private static String resolveDemoFontFamily() {
        String osName = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        if (osName.contains("win")) {
            return "Consolas";
        }
        if (osName.contains("mac")) {
            return "Menlo";
        }
        return null;
    }

    private static String normalizeNewlines(String text) {
        return text.replace("\r\n", "\n").replace('\r', '\n');
    }

    private static final class SimpleDocumentListener implements DocumentListener {
        private final Runnable callback;

        private SimpleDocumentListener(Runnable callback) {
            this.callback = callback;
        }

        @Override
        public void insertUpdate(DocumentEvent e) {
            callback.run();
        }

        @Override
        public void removeUpdate(DocumentEvent e) {
            callback.run();
        }

        @Override
        public void changedUpdate(DocumentEvent e) {
            callback.run();
        }
    }

    private static List<Path> listDemoFiles() {
        Path resRoot = resolveDemoResRoot();
        if (resRoot == null) {
            return List.of();
        }
        Path filesDir = resRoot.resolve("files");
        if (!Files.isDirectory(filesDir)) {
            return List.of();
        }
        try (var stream = Files.list(filesDir)) {
            return stream
                    .filter(Files::isRegularFile)
                    .sorted(Comparator.comparing(path -> path.getFileName().toString().toLowerCase()))
                    .toList();
        } catch (IOException e) {
            return List.of();
        }
    }

    private static List<Path> resolveSyntaxFiles() throws IOException {
        Path resRoot = resolveDemoResRoot();
        if (resRoot == null) {
            throw new IOException("Cannot resolve demo _res directory");
        }
        Path syntaxDir = resRoot.resolve("syntaxes");
        if (!Files.isDirectory(syntaxDir)) {
            throw new IOException("Cannot resolve syntaxes directory: " + syntaxDir);
        }
        try (var stream = Files.walk(syntaxDir)) {
            List<Path> syntaxFiles = stream
                    .filter(Files::isRegularFile)
                    .filter(path -> path.getFileName().toString().toLowerCase().endsWith(".json"))
                    .sorted(Comparator.comparing(path -> path.getFileName().toString().toLowerCase()))
                    .toList();
            if (syntaxFiles.isEmpty()) {
                throw new IOException("No syntax files found under " + syntaxDir);
            }
            return syntaxFiles;
        }
    }

    private static Path resolveDemoResRoot() {
        String resDir = System.getProperty("sweeteditor.demo.res.dir");
        if (resDir != null && !resDir.isEmpty()) {
            Path candidate = Paths.get(resDir).toAbsolutePath().normalize();
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
        }
        Path cwd = Paths.get("").toAbsolutePath().normalize();
        for (Path dir = cwd; dir != null; dir = dir.getParent()) {
            Path candidate = dir.resolve("_res");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            candidate = dir.resolve("platform").resolve("_res");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
        }
        return null;
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            } catch (Exception ignored) {
            }
            new Main().setVisible(true);
        });
    }
}
