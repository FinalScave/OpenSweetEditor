package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.config.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.config.WrapMode;
import com.qiplat.sweeteditor.event.CodeLensClickEvent;
import com.qiplat.sweeteditor.event.LinkClickEvent;

import javax.swing.BorderFactory;
import javax.swing.DefaultComboBoxModel;
import javax.swing.JButton;
import javax.swing.JComboBox;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.SwingUtilities;
import javax.swing.UIManager;
import java.awt.*;
import java.awt.event.ActionListener;
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
    private static final float LINUX_EDITOR_TEXT_SIZE = 26f;
    private static final float DESKTOP_EDITOR_TEXT_SIZE = 18f;
    private static final String FALLBACK_SAMPLE_CODE =
            "// SweetEditor Demo\n" +
            "int main() {\n" +
            "    return 0;\n" +
            "}\n";

    private final SweetEditor editor;
    private final JLabel statusLabel;
    private final JComboBox<String> fileComboBox;
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
        editor.getSettings().setEditorTextSize(resolveDemoEditorTextSize());
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
        toolbar.add(statusLabel);

        setLayout(new BorderLayout());
        add(toolbar, BorderLayout.NORTH);
        add(editor, BorderLayout.CENTER);

        setupFileSpinner();
    }

    private JButton makeButton(String text, ActionListener action) {
        JButton btn = new JButton(text);
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
        updateStatus("Loaded: " + fileName);
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

    private static float resolveDemoEditorTextSize() {
        String osName = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);
        return osName.contains("linux") ? LINUX_EDITOR_TEXT_SIZE : DESKTOP_EDITOR_TEXT_SIZE;
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
