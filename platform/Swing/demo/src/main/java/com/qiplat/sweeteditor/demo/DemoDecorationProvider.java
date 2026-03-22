package com.qiplat.sweeteditor.demo;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.EditorMetadata;
import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.foundation.TextChange;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.core.foundation.TextRange;
import com.qiplat.sweeteditor.decoration.DecorationContext;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationReceiver;
import com.qiplat.sweeteditor.decoration.DecorationResult;
import com.qiplat.sweeteditor.decoration.DecorationType;
import com.qiplat.sweetline.DocumentAnalyzer;
import com.qiplat.sweetline.DocumentHighlight;
import com.qiplat.sweetline.HighlightConfig;
import com.qiplat.sweetline.HighlightEngine;
import com.qiplat.sweetline.IndentGuideLine;
import com.qiplat.sweetline.IndentGuideResult;
import com.qiplat.sweetline.LineHighlight;
import com.qiplat.sweetline.SyntaxCompileError;
import com.qiplat.sweetline.TokenSpan;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class DemoDecorationProvider implements DecorationProvider {
    private static final String DEFAULT_ANALYSIS_FILE_NAME = "example.cpp";
    private static final int STYLE_KEYWORD = EditorTheme.STYLE_KEYWORD;
    private static final int STYLE_STRING = EditorTheme.STYLE_STRING;
    private static final int STYLE_COMMENT = EditorTheme.STYLE_COMMENT;
    private static final int STYLE_NUMBER = EditorTheme.STYLE_NUMBER;
    private static final int STYLE_TYPE = EditorTheme.STYLE_TYPE;
    private static final int STYLE_FUNCTION = EditorTheme.STYLE_FUNCTION;
    private static final int STYLE_PREPROCESSOR = EditorTheme.STYLE_PREPROCESSOR;
    private static final int STYLE_CLASS = EditorTheme.STYLE_CLASS;
    private static final int STYLE_BUILTIN = EditorTheme.STYLE_BUILTIN;
    private static final int STYLE_VARIABLE = EditorTheme.STYLE_VARIABLE;
    private static final int STYLE_ANNOTATION = EditorTheme.STYLE_ANNOTATION;
    private static final int STYLE_COLOR = EditorTheme.STYLE_PREPROCESSOR + 1;
    private static final int MAX_DYNAMIC_DIAGNOSTICS = 8;
    private static final String PHANTOM_MEMBER_STUB =
            "\n    void debugTrace(const std::string& tag) {\n        log(DEBUG, tag);\n    }";
    private static final String PHANTOM_INLINE_HINT = " /* demo phantom */";

    public static final int ICON_CLASS = 1;

    private static HighlightEngine highlightEngine;

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final Object stateLock = new Object();

    private DocumentAnalyzer documentAnalyzer;
    private DocumentHighlight cacheHighlight;
    private String sourceFileName = DEFAULT_ANALYSIS_FILE_NAME;
    private String sourceText = "";
    private String analyzedFileName = DEFAULT_ANALYSIS_FILE_NAME;

    @Override
    public EnumSet<DecorationType> getCapabilities() {
        return EnumSet.of(
                DecorationType.SYNTAX_HIGHLIGHT,
                DecorationType.INDENT_GUIDE,
                DecorationType.FOLD_REGION,
                DecorationType.SEPARATOR_GUIDE,
                DecorationType.GUTTER_ICON,
                DecorationType.INLAY_HINT,
                DecorationType.PHANTOM_TEXT,
                DecorationType.DIAGNOSTIC
        );
    }

    public void setDocumentSource(String fileName, String text) {
        synchronized (stateLock) {
            sourceFileName = (fileName == null || fileName.isEmpty()) ? DEFAULT_ANALYSIS_FILE_NAME : fileName;
            sourceText = text != null ? text : "";
            documentAnalyzer = null;
            cacheHighlight = null;
            analyzedFileName = sourceFileName;
        }
    }

    @Override
    public void provideDecorations(DecorationContext context, DecorationReceiver receiver) {
        Map<Integer, List<DiagnosticItem>> diagnostics = new HashMap<>();

        DecorationResult sweetLineResult = buildSweetLineDecorationResult(context, diagnostics);
        receiver.accept(sweetLineResult);

        executor.submit(() -> {
            try {
                Thread.sleep(500);
            } catch (InterruptedException ignored) {
            }

            if (receiver.isCancelled()) {
                return;
            }

            receiver.accept(new DecorationResult.Builder()
                    .diagnostics(diagnostics, DecorationResult.ApplyMode.REPLACE_ALL)
                    .build());
        });
    }

    private DecorationResult buildSweetLineDecorationResult(DecorationContext context,
                                                            Map<Integer, List<DiagnosticItem>> dynamicDiagnostics) {
        Map<Integer, List<PhantomText>> dynamicPhantoms = new HashMap<>();
        Map<Integer, List<StyleSpan>> syntaxSpans = new HashMap<>();
        Map<Integer, List<InlayHint>> colorInlayHints = new HashMap<>();
        Map<Integer, List<GutterIcon>> gutterIcons = new HashMap<>();
        List<IndentGuide> indentGuides = new ArrayList<>();
        List<FoldRegion> foldRegions = new ArrayList<>();
        List<SeparatorGuide> separatorGuides = new ArrayList<>();
        Set<String> seenColorHints = new HashSet<>();
        Set<Integer> phantomLines = new HashSet<>();
        Set<String> seenDiagnostics = new HashSet<>();
        int[] diagnosticCount = new int[]{0};
        TokenRangeInfo firstKeywordRange = null;

        DocumentAnalyzer analyzerSnapshot;
        DocumentHighlight highlightSnapshot;
        String textSnapshot;
        synchronized (stateLock) {
            if (highlightEngine == null) {
                return new DecorationResult.Builder()
                        .phantomTexts(dynamicPhantoms, DecorationResult.ApplyMode.REPLACE_ALL)
                        .build();
            }

            String currentFileName = resolveCurrentFileName(context);
            if (!currentFileName.equals(sourceFileName)) {
                sourceFileName = currentFileName;
            }

            if (cacheHighlight == null || documentAnalyzer == null || !currentFileName.equals(analyzedFileName)) {
                try (com.qiplat.sweetline.Document sweetDoc =
                             new com.qiplat.sweetline.Document(buildAnalysisUri(currentFileName), sourceText)) {
                    documentAnalyzer = highlightEngine.loadDocument(sweetDoc);
                    cacheHighlight = documentAnalyzer != null ? documentAnalyzer.analyze() : null;
                    analyzedFileName = currentFileName;
                }
            } else if (context.textChanges != null && !context.textChanges.isEmpty()) {
                for (TextChange change : context.textChanges) {
                    if (change == null || change.range == null || documentAnalyzer == null) {
                        continue;
                    }
                    String newText = change.newText != null ? change.newText : "";
                    cacheHighlight = documentAnalyzer.analyzeIncremental(convertAsSLTextRange(change.range), newText);
                    sourceText = applyTextChange(sourceText, change.range, newText);
                }
            }

            analyzerSnapshot = documentAnalyzer;
            highlightSnapshot = cacheHighlight;
            textSnapshot = sourceText;
        }

        if (highlightSnapshot == null || highlightSnapshot.lines() == null || highlightSnapshot.lines().isEmpty()) {
            return new DecorationResult.Builder()
                    .phantomTexts(dynamicPhantoms, DecorationResult.ApplyMode.REPLACE_ALL)
                    .syntaxSpans(syntaxSpans, DecorationResult.ApplyMode.MERGE)
                    .inlayHints(colorInlayHints, DecorationResult.ApplyMode.REPLACE_RANGE)
                    .indentGuides(indentGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .foldRegions(foldRegions, DecorationResult.ApplyMode.REPLACE_ALL)
                    .separatorGuides(separatorGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .gutterIcons(gutterIcons, DecorationResult.ApplyMode.REPLACE_ALL)
                    .build();
        }

        List<String> textLines = splitLines(textSnapshot);
        int renderStartLine = Math.max(0, context.visibleStartLine);
        int maxLine = Math.min(context.visibleEndLine, highlightSnapshot.lines().size() - 1);
        for (int i = renderStartLine; i <= maxLine; i++) {
            LineHighlight lineHighlight = highlightSnapshot.lines().get(i);
            if (lineHighlight == null || lineHighlight.spans() == null) {
                continue;
            }
            for (TokenSpan token : lineHighlight.spans()) {
                appendStyleSpan(syntaxSpans, token);
                appendColorInlayHint(colorInlayHints, seenColorHints, textLines, token);
                appendTextInlayHint(colorInlayHints, textLines, token);
                appendSeparator(separatorGuides, textLines, token);
                appendGutterIcons(gutterIcons, textLines, token);
                firstKeywordRange = appendDynamicDemoDecorations(
                        dynamicPhantoms,
                        phantomLines,
                        dynamicDiagnostics,
                        seenDiagnostics,
                        diagnosticCount,
                        firstKeywordRange,
                        textLines,
                        token
                );
            }
        }
        appendDiagnosticFallbackIfNeeded(dynamicDiagnostics, seenDiagnostics, diagnosticCount, firstKeywordRange);

        if (analyzerSnapshot != null && (context.totalLineCount < 0 || context.totalLineCount < 2048)) {
            IndentGuideResult guideResult = analyzerSnapshot.analyzeIndentGuides();
            if (guideResult != null && guideResult.guideLines() != null) {
                Set<String> seenFolds = new HashSet<>();
                for (IndentGuideLine guide : guideResult.guideLines()) {
                    if (guide == null) {
                        continue;
                    }
                    if (guide.endLine() < guide.startLine()) {
                        continue;
                    }

                    int column = Math.max(guide.column(), 0);
                    indentGuides.add(new IndentGuide(
                            new TextPosition(guide.startLine(), column),
                            new TextPosition(guide.endLine(), column)
                    ));

                    if (guide.endLine() <= guide.startLine()) {
                        continue;
                    }
                    String key = guide.startLine() + ":" + guide.endLine();
                    if (seenFolds.add(key)) {
                        foldRegions.add(new FoldRegion(guide.startLine(), guide.endLine()));
                    }
                }
            }
        }

        return new DecorationResult.Builder()
                .phantomTexts(dynamicPhantoms, DecorationResult.ApplyMode.REPLACE_ALL)
                .syntaxSpans(syntaxSpans, DecorationResult.ApplyMode.MERGE)
                .inlayHints(colorInlayHints, DecorationResult.ApplyMode.REPLACE_RANGE)
                .indentGuides(indentGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                .foldRegions(foldRegions, DecorationResult.ApplyMode.REPLACE_ALL)
                .separatorGuides(separatorGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                .gutterIcons(gutterIcons, DecorationResult.ApplyMode.REPLACE_ALL)
                .build();
    }

    private static TokenRangeInfo appendDynamicDemoDecorations(Map<Integer, List<PhantomText>> phantoms,
                                                               Set<Integer> phantomLines,
                                                               Map<Integer, List<DiagnosticItem>> diagnostics,
                                                               Set<String> seenDiagnostics,
                                                               int[] diagnosticCount,
                                                               TokenRangeInfo firstKeywordRange,
                                                               List<String> textLines,
                                                               TokenSpan token) {
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return firstKeywordRange;
        }
        String literal = getTokenLiteral(textLines, range);
        if (literal.isEmpty()) {
            return firstKeywordRange;
        }

        if (token.styleId() == STYLE_KEYWORD) {
            if (firstKeywordRange == null) {
                firstKeywordRange = range;
            }
            if (phantomLines.isEmpty() && ("class".equals(literal) || "struct".equals(literal))) {
                phantoms.computeIfAbsent(range.line, ignored -> new ArrayList<>())
                        .add(new PhantomText(range.endColumn, PHANTOM_MEMBER_STUB));
                phantomLines.add(range.line);
            } else if (phantomLines.isEmpty() && "return".equals(literal)) {
                phantoms.computeIfAbsent(range.line, ignored -> new ArrayList<>())
                        .add(new PhantomText(range.endColumn, PHANTOM_INLINE_HINT));
                phantomLines.add(range.line);
            }
            return firstKeywordRange;
        }

        if (token.styleId() == STYLE_COMMENT) {
            String upper = literal.toUpperCase(Locale.ROOT);
            int fixmeIndex = upper.indexOf("FIXME");
            if (fixmeIndex >= 0) {
                appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                        range.line, range.startColumn + fixmeIndex, 5, 0, 0);
            }
            int todoIndex = upper.indexOf("TODO");
            if (todoIndex >= 0) {
                appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                        range.line, range.startColumn + todoIndex, 4, 1, 0);
            }
            return firstKeywordRange;
        }

        if (token.styleId() == STYLE_COLOR) {
            Integer color = parseColorLiteral(literal);
            if (color != null) {
                appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                        range.line, range.startColumn, range.length(), 2, color);
            }
            return firstKeywordRange;
        }

        if (token.styleId() == STYLE_ANNOTATION) {
            appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                    range.line, range.startColumn, range.length(), 3, 0);
        }
        return firstKeywordRange;
    }

    private static void appendDiagnostic(Map<Integer, List<DiagnosticItem>> diagnostics,
                                         Set<String> seenDiagnostics,
                                         int[] diagnosticCount,
                                         int line,
                                         int column,
                                         int length,
                                         int severity,
                                         int color) {
        if (diagnosticCount[0] >= MAX_DYNAMIC_DIAGNOSTICS) {
            return;
        }
        if (line < 0 || column < 0 || length <= 0) {
            return;
        }
        String key = line + ":" + column + ":" + length + ":" + severity + ":" + color;
        if (!seenDiagnostics.add(key)) {
            return;
        }
        diagnostics.computeIfAbsent(line, ignored -> new ArrayList<>())
                .add(new DiagnosticItem(column, length, severity, color));
        diagnosticCount[0]++;
    }

    private static void appendDiagnosticFallbackIfNeeded(Map<Integer, List<DiagnosticItem>> diagnostics,
                                                         Set<String> seenDiagnostics,
                                                         int[] diagnosticCount,
                                                         TokenRangeInfo firstKeywordRange) {
        if (diagnosticCount[0] > 0 || firstKeywordRange == null) {
            return;
        }
        appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                firstKeywordRange.line, firstKeywordRange.startColumn, firstKeywordRange.length(), 3, 0);
    }

    private void appendStyleSpan(Map<Integer, List<StyleSpan>> syntaxSpans, TokenSpan token) {
        if (token.styleId() <= 0) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        syntaxSpans.computeIfAbsent(range.line, ignored -> new ArrayList<>())
                .add(new StyleSpan(range.startColumn, range.length(), token.styleId()));
    }

    private void appendColorInlayHint(Map<Integer, List<InlayHint>> colorHints,
                                      Set<String> seenHints,
                                      List<String> textLines,
                                      TokenSpan token) {
        if (token.styleId() != STYLE_COLOR) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String literal = getTokenLiteral(textLines, range);
        Integer color = parseColorLiteral(literal);
        if (color == null) {
            return;
        }
        String key = range.line + ":" + range.startColumn + ":" + literal;
        if (!seenHints.add(key)) {
            return;
        }
        colorHints.computeIfAbsent(range.line, ignored -> new ArrayList<>())
                .add(InlayHint.color(range.startColumn, color));
    }

    private void appendTextInlayHint(Map<Integer, List<InlayHint>> inlayHints,
                                     List<String> textLines,
                                     TokenSpan token) {
        if (token.styleId() != STYLE_KEYWORD) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String literal = getTokenLiteral(textLines, range);
        List<InlayHint> lineHints = inlayHints.computeIfAbsent(range.line, ignored -> new ArrayList<>());
        if ("const".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "immutable"));
        } else if ("return".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "value: "));
        } else if ("case".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "condition: "));
        }
    }

    private void appendSeparator(List<SeparatorGuide> separatorGuides, List<String> textLines, TokenSpan token) {
        if (token.styleId() != STYLE_COMMENT) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String lineText = getLineText(textLines, range.line);
        if (lineText == null || range.endColumn > lineText.length()) {
            return;
        }
        int count = -1;
        boolean isDouble = false;
        for (int i = 0; i < lineText.length(); i++) {
            char ch = lineText.charAt(i);
            if (count < 0) {
                if (ch == '/') {
                    continue;
                }
                if (ch == '=') {
                    count = 1;
                    isDouble = true;
                } else if (ch == '-') {
                    count = 1;
                    isDouble = false;
                }
            } else if (isDouble && ch == '=') {
                count++;
            } else if (!isDouble && ch == '-') {
                count++;
            } else {
                break;
            }
        }
        if (count > 0) {
            separatorGuides.add(new SeparatorGuide(range.line, isDouble ? 1 : 0, count, lineText.length()));
        }
    }

    private void appendGutterIcons(Map<Integer, List<GutterIcon>> gutterIcons, List<String> textLines, TokenSpan token) {
        if (token.styleId() != STYLE_KEYWORD) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String literal = getTokenLiteral(textLines, range);
        if ("class".equals(literal) || "struct".equals(literal)) {
            gutterIcons.computeIfAbsent(range.line, ignored -> new ArrayList<>())
                    .add(new GutterIcon(ICON_CLASS));
        }
    }

    private static Integer parseColorLiteral(String literal) {
        if (literal.startsWith("0X")) {
            try {
                return (int) Long.parseLong(literal.substring(2), 16);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private static String getTokenLiteral(List<String> textLines, TokenRangeInfo range) {
        String lineText = getLineText(textLines, range.line);
        if (lineText == null || range.endColumn > lineText.length()) {
            return "";
        }
        return lineText.substring(range.startColumn, range.endColumn);
    }

    private static String getLineText(List<String> lines, int line) {
        if (line < 0 || line >= lines.size()) {
            return null;
        }
        return lines.get(line);
    }

    private static TokenRangeInfo extractSingleLineTokenRange(TokenSpan token) {
        if (token == null || token.range() == null || token.range().start() == null || token.range().end() == null) {
            return null;
        }
        int startLine = token.range().start().line();
        int endLine = token.range().end().line();
        int startColumn = token.range().start().column();
        int endColumn = token.range().end().column();
        if (startLine < 0 || startLine != endLine || startColumn < 0 || endColumn <= startColumn) {
            return null;
        }
        return new TokenRangeInfo(startLine, startColumn, endColumn);
    }

    private static String buildAnalysisUri(String fileName) {
        return "file:///" + fileName;
    }

    private static List<String> splitLines(String text) {
        List<String> lines = new ArrayList<>();
        int start = 0;
        for (int i = 0; i < text.length(); i++) {
            if (text.charAt(i) == '\n') {
                String line = text.substring(start, i);
                if (line.endsWith("\r")) {
                    line = line.substring(0, line.length() - 1);
                }
                lines.add(line);
                start = i + 1;
            }
        }
        String tail = text.substring(start);
        if (tail.endsWith("\r")) {
            tail = tail.substring(0, tail.length() - 1);
        }
        lines.add(tail);
        return lines;
    }

    private static String applyTextChange(String originalText, TextRange range, String newText) {
        if (range == null || range.start == null || range.end == null) {
            return originalText;
        }
        int startOffset = lineColumnToOffset(originalText, range.start.line, range.start.column);
        int endOffset = lineColumnToOffset(originalText, range.end.line, range.end.column);
        if (startOffset > endOffset) {
            int tmp = startOffset;
            startOffset = endOffset;
            endOffset = tmp;
        }
        StringBuilder builder = new StringBuilder(
                Math.max(0, originalText.length() - (endOffset - startOffset)) + newText.length());
        builder.append(originalText, 0, startOffset);
        builder.append(newText);
        builder.append(originalText, endOffset, originalText.length());
        return builder.toString();
    }

    private static int lineColumnToOffset(String text, int targetLine, int targetColumn) {
        int line = 0;
        int index = 0;
        int length = text.length();

        while (index < length && line < Math.max(0, targetLine)) {
            char ch = text.charAt(index++);
            if (ch == '\n') {
                line++;
            }
        }

        int column = 0;
        while (index < length && column < Math.max(0, targetColumn)) {
            char ch = text.charAt(index);
            if (ch == '\n') {
                break;
            }
            index++;
            column++;
        }
        return index;
    }

    public static synchronized boolean ensureSweetLineReady(List<Path> syntaxFiles) throws IOException {
        if (highlightEngine != null) {
            return true;
        }

        if (syntaxFiles == null || syntaxFiles.isEmpty()) {
            throw new IOException("No syntax files configured");
        }

        HighlightEngine engine = new HighlightEngine(new HighlightConfig(false, false));
        registerDemoStyleMap(engine);

        for (Path syntaxFile : syntaxFiles) {
            String syntaxJson = Files.readString(syntaxFile, StandardCharsets.UTF_8);
            try {
                engine.compileSyntaxFromJson(syntaxJson);
            } catch (SyntaxCompileError e) {
                throw new RuntimeException("Failed to compile syntax file: " + syntaxFile, e);
            }
        }

        highlightEngine = engine;
        return true;
    }

    private static void registerDemoStyleMap(HighlightEngine engine) {
        engine.registerStyleName("keyword", STYLE_KEYWORD);
        engine.registerStyleName("type", STYLE_TYPE);
        engine.registerStyleName("string", STYLE_STRING);
        engine.registerStyleName("comment", STYLE_COMMENT);
        engine.registerStyleName("preprocessor", STYLE_PREPROCESSOR);
        engine.registerStyleName("macro", STYLE_PREPROCESSOR);
        engine.registerStyleName("method", STYLE_FUNCTION);
        engine.registerStyleName("function", STYLE_FUNCTION);
        engine.registerStyleName("variable", STYLE_VARIABLE);
        engine.registerStyleName("field", STYLE_VARIABLE);
        engine.registerStyleName("number", STYLE_NUMBER);
        engine.registerStyleName("class", STYLE_CLASS);
        engine.registerStyleName("color", STYLE_COLOR);
        engine.registerStyleName("builtin", STYLE_BUILTIN);
        engine.registerStyleName("annotation", STYLE_ANNOTATION);
    }

    private static String resolveCurrentFileName(DecorationContext context) {
        if (context.editorMetadata instanceof DemoFileMetadata fileMetadata) {
            if (fileMetadata.fileName != null && !fileMetadata.fileName.isEmpty()) {
                return fileMetadata.fileName;
            }
        }
        return DEFAULT_ANALYSIS_FILE_NAME;
    }

    private static com.qiplat.sweetline.TextRange convertAsSLTextRange(TextRange range) {
        return new com.qiplat.sweetline.TextRange(
                new com.qiplat.sweetline.TextPosition(range.start.line, range.start.column),
                new com.qiplat.sweetline.TextPosition(range.end.line, range.end.column)
        );
    }

    public static final class DemoFileMetadata implements EditorMetadata {
        public final String fileName;

        public DemoFileMetadata(String fileName) {
            this.fileName = fileName;
        }
    }

    private static final class TokenRangeInfo {
        final int line;
        final int startColumn;
        final int endColumn;

        TokenRangeInfo(int line, int startColumn, int endColumn) {
            this.line = line;
            this.startColumn = startColumn;
            this.endColumn = endColumn;
        }

        int length() {
            return endColumn - startColumn;
        }
    }
}
