package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.WrapMode;

import javax.swing.*;
import java.awt.*;
import java.util.*;
import java.util.List;

public class Main extends JFrame {

    private static final String SAMPLE_CODE =
            "// SweetEditor Demo\n" +
            "#include <iostream>\n" +
            "#include <string>\n" +
            "#include <vector>\n" +
            "//==== Basic Utilities ====\n" +
            "namespace editor {\n" +
            "class Logger {\n" +
            "public:\n" +
            "    enum Level { DEBUG, INFO, WARN, ERROR };\n" +
            "    void log(Level level, const std::string& msg) {\n" +
            "        const char* tags[] = {\"D\", \"I\", \"W\", \"E\"};\n" +
            "        std::cout << \"[\" << tags[level] << \"] \" << msg << std::endl;\n" +
            "    }\n" +
            "};\n" +
            "//---- Lexical Analysis ----\n" +
            "struct Token {\n" +
            "    int type;\n" +
            "    size_t start;\n" +
            "    size_t length;\n" +
            "};\n" +
            "std::vector<Token> tokenize(const std::string& line) {\n" +
            "    std::vector<Token> result;\n" +
            "    for (size_t i = 0; i < line.size(); ++i) {\n" +
            "        switch (line[i]) {\n" +
            "            case '#':\n" +
            "                result.push_back({1, i, 1});\n" +
            "                break;\n" +
            "            case '\"':\n" +
            "                result.push_back({2, i, 1});\n" +
            "                break;\n" +
            "            case '/':\n" +
            "                result.push_back({3, i, 1});\n" +
            "                break;\n" +
            "            default:\n" +
            "                result.push_back({0, i, 1});\n" +
            "                break;\n" +
            "        }\n" +
            "    }\n" +
            "    return result;\n" +
            "}\n" +
            "} // namespace editor\n" +
            "//==== Main Program ====\n" +
            "int main() {\n" +
            "    editor::Logger logger;\n" +
            "    logger.log(editor::Logger::INFO, \"SweetEditor started\");\n" +
            "    auto tokens = editor::tokenize(\"int x = 42;\");\n" +
            "    std::cout << \"Tokens: \" << tokens.size() << std::endl;\n" +
            "    return 0;\n" +
            "}\n";

    private final SweetEditor editor;
    private final JLabel statusLabel;
    private boolean isDarkTheme = true;
    private WrapMode wrapModePreset = WrapMode.NONE;
    private DemoDecorationProvider demoProvider;
    private DemoCompletionProvider demoCompletionProvider;

    public Main() {
        super("SweetEditor - Swing Demo");
        setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        setSize(1200, 800);
        setLocationRelativeTo(null);

        editor = new SweetEditor(EditorTheme.dark());
        statusLabel = new JLabel("就绪");
        statusLabel.setBorder(BorderFactory.createEmptyBorder(4, 8, 4, 4));

        // Auto-load document and decorations at startup.
        Document doc = new Document(SAMPLE_CODE);
        editor.loadDocument(doc);
        applyAllDecorations();

        // Register DecorationProvider (demonstrates the receiver callback pattern).
        demoProvider = new DemoDecorationProvider();
        editor.addDecorationProvider(demoProvider);

        // Register CompletionProvider (demonstrates completion callback pattern).
        demoCompletionProvider = new DemoCompletionProvider();
        editor.addCompletionProvider(demoCompletionProvider);

        JPanel toolbar = new JPanel(new FlowLayout(FlowLayout.LEFT, 4, 4));
        toolbar.add(makeButton("撤销", e -> { if (editor.canUndo()) { editor.undo(); updateStatus("撤销"); } }));
        toolbar.add(makeButton("重做", e -> { if (editor.canRedo()) { editor.redo(); updateStatus("重做"); } }));
        toolbar.add(makeButton("全选", e -> { editor.selectAll(); updateStatus("全选"); }));
        toolbar.add(makeButton("获取选区", e -> {
            String sel = editor.getSelectedText();
            updateStatus(sel == null || sel.isEmpty() ? "无选区" : "选区: " + sel.substring(0, Math.min(30, sel.length())));
        }));
        toolbar.add(makeButton("加载装饰", e -> applyAllDecorations()));
        toolbar.add(makeButton("清除装饰", e -> {
            editor.clearAllDecorations(); editor.clearGuides(); editor.clearDiagnostics();
            updateStatus("已清除装饰");
        }));
        toolbar.add(makeButton("切换主题", e -> {
            isDarkTheme = !isDarkTheme;
            editor.applyTheme(isDarkTheme ? EditorTheme.dark() : EditorTheme.light());
            updateStatus(isDarkTheme ? "已切换到深色主题" : "已切换到浅色主题");
        }));
        toolbar.add(makeButton("WrapMode", e -> cycleWrapMode()));
        toolbar.add(statusLabel);

        setLayout(new BorderLayout());
        add(toolbar, BorderLayout.NORTH);
        add(editor, BorderLayout.CENTER);
    }

    private JButton makeButton(String text, java.awt.event.ActionListener action) {
        JButton btn = new JButton(text);
        btn.setMargin(new Insets(2, 6, 2, 6));
        btn.addActionListener(action);
        return btn;
    }

    private void updateStatus(String message) {
        statusLabel.setText(message);
    }

    private void cycleWrapMode() {
        WrapMode[] wrapModes = WrapMode.values();
        wrapModePreset = wrapModes[(wrapModePreset.ordinal() + 1) % wrapModes.length];
        editor.setWrapMode(wrapModePreset);
        updateStatus("WrapMode: " + wrapModePreset.name());
    }

    private void applyAllDecorations() {
        editor.clearAllDecorations();
        editor.clearGuides();
        editor.clearDiagnostics();
        applySyntaxHighlight();
        applyInlayHints();
        applyGuides();
        applyFoldRegions();
        applyDiagnostics();
        updateStatus("已应用全部装饰");
    }

    private void applySyntaxHighlight() {
        int SK = 1, ST = 2, SS = 3, SC = 4, SP = 5, SF = 6, SN = 7, SL = 8;

        Map<Integer, List<StyleSpan>> spans = new HashMap<>();
        spans.put(0, List.of(new StyleSpan(0, 19, SC)));
        spans.put(1, List.of(new StyleSpan(0, 8, SP), new StyleSpan(9, 10, SS)));
        spans.put(2, List.of(new StyleSpan(0, 8, SP), new StyleSpan(9, 8, SS)));
        spans.put(3, List.of(new StyleSpan(0, 8, SP), new StyleSpan(9, 8, SS)));
        spans.put(4, List.of(new StyleSpan(0, 27, SC)));
        spans.put(5, List.of(new StyleSpan(0, 9, SK)));
        spans.put(6, List.of(new StyleSpan(0, 5, SK), new StyleSpan(6, 6, SL)));
        spans.put(7, List.of(new StyleSpan(0, 6, SK)));
        spans.put(8, List.of(new StyleSpan(4, 4, SK), new StyleSpan(9, 5, SL)));
        spans.put(9, List.of(new StyleSpan(4, 4, SK), new StyleSpan(9, 3, SF), new StyleSpan(13, 5, SL), new StyleSpan(26, 5, SK)));
        spans.put(10, List.of(new StyleSpan(8, 5, SK), new StyleSpan(14, 4, ST), new StyleSpan(30, 3, SS), new StyleSpan(35, 3, SS), new StyleSpan(40, 3, SS), new StyleSpan(45, 3, SS)));
        spans.put(11, List.of(new StyleSpan(21, 3, SS), new StyleSpan(43, 4, SS)));
        spans.put(14, List.of(new StyleSpan(0, 28, SC)));
        spans.put(15, List.of(new StyleSpan(0, 6, SK), new StyleSpan(7, 5, SL)));
        spans.put(16, List.of(new StyleSpan(4, 3, ST)));
        spans.put(17, List.of(new StyleSpan(4, 6, ST)));
        spans.put(18, List.of(new StyleSpan(4, 6, ST)));
        spans.put(20, List.of(new StyleSpan(12, 5, SL), new StyleSpan(19, 8, SF), new StyleSpan(28, 5, SK)));
        spans.put(22, List.of(new StyleSpan(4, 3, SK), new StyleSpan(9, 6, ST), new StyleSpan(20, 1, SN)));
        spans.put(23, List.of(new StyleSpan(8, 6, SK)));
        spans.put(24, List.of(new StyleSpan(12, 4, SK), new StyleSpan(17, 3, SS)));
        spans.put(25, List.of(new StyleSpan(34, 1, SN), new StyleSpan(40, 1, SN)));
        spans.put(27, List.of(new StyleSpan(12, 4, SK), new StyleSpan(17, 3, SS)));
        spans.put(28, List.of(new StyleSpan(34, 1, SN), new StyleSpan(40, 1, SN)));
        spans.put(30, List.of(new StyleSpan(12, 4, SK), new StyleSpan(17, 3, SS)));
        spans.put(31, List.of(new StyleSpan(34, 1, SN), new StyleSpan(40, 1, SN)));
        spans.put(33, List.of(new StyleSpan(12, 7, SK)));
        spans.put(34, List.of(new StyleSpan(34, 1, SN), new StyleSpan(40, 1, SN)));
        for (int i : new int[]{26, 29, 32, 35}) {
            spans.put(i, List.of(new StyleSpan(16, 5, SK)));
        }
        spans.put(38, List.of(new StyleSpan(4, 6, SK)));
        spans.put(40, List.of(new StyleSpan(2, 19, SC)));
        spans.put(41, List.of(new StyleSpan(0, 24, SC)));
        spans.put(42, List.of(new StyleSpan(0, 3, ST), new StyleSpan(4, 4, SF)));
        spans.put(43, List.of(new StyleSpan(12, 6, SL)));
        spans.put(44, List.of(new StyleSpan(11, 3, SF), new StyleSpan(23, 6, SL), new StyleSpan(37, 21, SS)));
        spans.put(45, List.of(new StyleSpan(4, 4, SK), new StyleSpan(26, 8, SF), new StyleSpan(35, 13, SS)));
        spans.put(46, List.of(new StyleSpan(17, 10, SS)));
        spans.put(47, List.of(new StyleSpan(4, 6, SK), new StyleSpan(11, 1, SN)));

        editor.setBatchLineSpans(SpanLayer.SYNTAX.value, spans);
    }

    private void applyInlayHints() {
        Map<Integer, List<InlayHint>> hints = new HashMap<>();
        hints.put(44, List.of(InlayHint.text(15, "level: "), InlayHint.text(37, "msg: ")));
        hints.put(45, List.of(InlayHint.text(35, "line: ")));
        hints.put(10, List.of(
                InlayHint.color(30, (int) 0xFF4CAF50),
                InlayHint.color(35, (int) 0xFF2196F3),
                InlayHint.color(40, (int) 0xFFFF9800),
                InlayHint.color(45, (int) 0xFFF44336)
        ));
        editor.setBatchLineInlayHints(hints);

        Map<Integer, List<PhantomText>> phantoms = new HashMap<>();
        phantoms.put(13, List.of(new PhantomText(2, " // end class Logger")));
        phantoms.put(39, List.of(new PhantomText(1, " // end tokenize")));
        phantoms.put(48, List.of(new PhantomText(1, " // end main")));
        phantoms.put(12, List.of(new PhantomText(5, "\n    void warn(const std::string& m) { log(WARN, m); }")));
        editor.setBatchLinePhantomTexts(phantoms);
    }

    private void applyGuides() {
        editor.clearGuides();

        editor.setIndentGuides(List.of(
                new IndentGuide(6, 0, 13, 0),
                new IndentGuide(9, 4, 12, 4),
                new IndentGuide(20, 0, 39, 0),
                new IndentGuide(22, 4, 37, 4),
                new IndentGuide(23, 8, 36, 8),
                new IndentGuide(42, 0, 48, 0)
        ));

        editor.setBracketGuides(List.of(
                new BracketGuide(
                        new TextPosition(23, 8),
                        new TextPosition(36, 8),
                        new TextPosition[]{
                                new TextPosition(24, 12),
                                new TextPosition(27, 12),
                                new TextPosition(30, 12),
                                new TextPosition(33, 12)
                        }
                )
        ));

        editor.setFlowGuides(List.of(
                new FlowGuide(22, 4, 37, 4)
        ));

        editor.setSeparatorGuides(List.of(
                new SeparatorGuide(4, SeparatorStyle.DOUBLE.value, 4, 27),
                new SeparatorGuide(14, SeparatorStyle.SINGLE.value, 4, 28),
                new SeparatorGuide(41, SeparatorStyle.DOUBLE.value, 4, 24)
        ));
    }

    private void applyFoldRegions() {
        editor.setFoldRegions(List.of(
                new FoldRegion(6, 13, false),
                new FoldRegion(9, 12, false),
                new FoldRegion(15, 19, true),
                new FoldRegion(20, 39, false),
                new FoldRegion(22, 37, false),
                new FoldRegion(23, 36, true),
                new FoldRegion(42, 48, false),
                new FoldRegion(5, 40, false)
        ));
    }

    private void applyDiagnostics() {
        editor.clearDiagnostics();

        Map<Integer, List<DiagnosticItem>> diags = new HashMap<>();
        diags.put(9, List.of(new DiagnosticItem(13, 5, 0, 0)));
        diags.put(16, List.of(new DiagnosticItem(8, 4, 1, 0)));
        diags.put(22, List.of(new DiagnosticItem(4, 3, 3, 0)));
        diags.put(44, List.of(new DiagnosticItem(38, 20, 2, 0)));
        diags.put(45, List.of(new DiagnosticItem(4, 4, 1, (int) 0xFFFF8C00)));
        diags.put(46, List.of(
                new DiagnosticItem(17, 10, 2, 0),
                new DiagnosticItem(31, 6, 0, 0)
        ));
        editor.setBatchLineDiagnostics(diags);
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(() -> {
            try {
                UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName());
            } catch (Exception ignored) {}
            new Main().setVisible(true);
        });
    }
}
