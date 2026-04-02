package com.qiplat.sweeteditor.demo;

import android.content.Context;
import android.util.SparseArray;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.EditorTheme;
import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.Diagnostic;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;

import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
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

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Demo DecorationProvider:
 * 1) sync push InlayHint
 * 2) sync push SweetLine syntax/indent/fold analysis
 * 3) async push simulated diagnostics
 */
public class DemoDecorationProvider implements DecorationProvider {

    private static final String SYNTAX_ASSET_DIR = "syntaxes";
    private static final String DEFAULT_ANALYSIS_FILE_NAME = "sample.cpp";
    private static final int STYLE_COLOR = EditorTheme.STYLE_USER_BASE + 1;
    private static final int MAX_DYNAMIC_DIAGNOSTICS = 8;

    public static final int ICON_TYPE = 1;
    public static final int ICON_AT = 2;

    private final SweetEditor editor;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private static HighlightEngine highlightEngine;
    private DocumentAnalyzer documentAnalyzer;
    private DocumentHighlight cacheHighlight;
    @NonNull
    private String analyzedFileName = DEFAULT_ANALYSIS_FILE_NAME;

    public DemoDecorationProvider(@NonNull SweetEditor editor) {
        this.editor = editor;
    }

    @NonNull
    @Override
    public EnumSet<DecorationType> getCapabilities() {
        return EnumSet.of(
                DecorationType.SYNTAX_HIGHLIGHT,
                DecorationType.INDENT_GUIDE,
                DecorationType.FOLD_REGION,
                DecorationType.INLAY_HINT,
                DecorationType.DIAGNOSTIC
        );
    }

    @Override
    public void provideDecorations(@NonNull DecorationContext context, @NonNull DecorationReceiver receiver) {
        SparseArray<List<Diagnostic>> diagnostics = new SparseArray<>();

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

    @NonNull
    private DecorationResult buildSweetLineDecorationResult(@NonNull DecorationContext context,
                                                            @NonNull SparseArray<List<Diagnostic>> dynamicDiagnostics) {
        if (highlightEngine == null) {
            return new DecorationResult.Builder().build();
        }
        SparseArray<List<StyleSpan>> syntaxSpans = new SparseArray<>();
        SparseArray<List<InlayHint>> colorInlayHints = new SparseArray<>();
        SparseArray<List<GutterIcon>> gutterIcons = new SparseArray<>();
        List<IndentGuide> indentGuides = new ArrayList<>();
        List<FoldRegion> foldRegions = new ArrayList<>();
        List<SeparatorGuide> separatorGuides = new ArrayList<>();
        Set<String> seenColorHints = new HashSet<>();
        Set<String> seenDiagnostics = new HashSet<>();
        int[] diagnosticCount = new int[]{0};
        TokenRangeInfo firstKeywordRange = null;

        Document editorDocument = editor.getDocument();
        if (editorDocument == null) {
            return new DecorationResult.Builder()
                    .syntaxSpans(syntaxSpans, DecorationResult.ApplyMode.MERGE)
                    .inlayHints(colorInlayHints, DecorationResult.ApplyMode.REPLACE_RANGE)
                    .indentGuides(indentGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .foldRegions(foldRegions, DecorationResult.ApplyMode.REPLACE_ALL)
                    .separatorGuides(separatorGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .gutterIcons(gutterIcons, DecorationResult.ApplyMode.REPLACE_ALL)
                    .build();
        }
        String text = editorDocument.getText();
        String currentFileName = resolveCurrentFileName(context);

        boolean fileChanged = !currentFileName.equals(analyzedFileName);
        if (cacheHighlight == null || documentAnalyzer == null || fileChanged) {
            documentAnalyzer = highlightEngine.loadDocument(
                    new com.qiplat.sweetline.Document(buildAnalysisUri(currentFileName), text));
            cacheHighlight = documentAnalyzer.analyze();
            analyzedFileName = currentFileName;
        } else if (!context.textChanges.isEmpty()) {
            for (EditorCore.TextChange change : context.textChanges) {
                cacheHighlight = documentAnalyzer.analyzeIncremental(
                        convertAsSLTextRange(change.range),
                        change.newText
                );
            }
        }
        if (cacheHighlight == null || cacheHighlight.lines == null || cacheHighlight.lines.isEmpty()) {
            return new DecorationResult.Builder()
                    .syntaxSpans(syntaxSpans, DecorationResult.ApplyMode.MERGE)
                    .inlayHints(colorInlayHints, DecorationResult.ApplyMode.REPLACE_RANGE)
                    .indentGuides(indentGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .foldRegions(foldRegions, DecorationResult.ApplyMode.REPLACE_ALL)
                    .separatorGuides(separatorGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                    .gutterIcons(gutterIcons, DecorationResult.ApplyMode.REPLACE_ALL)
                    .build();
        }
        int renderStartLine = Math.max(0, context.visibleStartLine);
        int maxLine = Math.min(context.visibleEndLine, cacheHighlight.lines.size() - 1);
        for (int i = renderStartLine; i <= maxLine; i++) {
            LineHighlight lineHighlight = cacheHighlight.lines.get(i);
            for (TokenSpan token : lineHighlight.spans) {
                appendStyleSpan(syntaxSpans, token);
                appendColorInlayHint(colorInlayHints, seenColorHints, editorDocument, token);
                appendTextInlayHint(colorInlayHints, editorDocument, token);
                appendSeparator(separatorGuides, editorDocument, token);
                appendGutterIcons(gutterIcons, editorDocument, token);
                firstKeywordRange = appendDynamicDemoDecorations(
                        dynamicDiagnostics,
                        seenDiagnostics,
                        diagnosticCount,
                        firstKeywordRange,
                        editorDocument,
                        token
                );
            }
        }
        appendDiagnosticFallbackIfNeeded(dynamicDiagnostics, seenDiagnostics, diagnosticCount, firstKeywordRange);

        // Only analyze indent guides under 2048 lines
        if (context.totalLineCount < 2048) {
            IndentGuideResult guideResult = documentAnalyzer.analyzeIndentGuides();
            if (guideResult != null && guideResult.guideLines != null) {
                Set<String> seenFolds = new HashSet<>();
                for (IndentGuideLine guide : guideResult.guideLines) {
                    if (guide == null) continue;
                    if (guide.endLine < guide.startLine) continue;

                    int column = Math.max(guide.column, 0);
                    indentGuides.add(new IndentGuide(
                            new TextPosition(guide.startLine, column),
                            new TextPosition(guide.endLine, column)
                    ));

                    if (guide.endLine <= guide.startLine) continue;
                    String key = guide.startLine + ":" + guide.endLine;
                    if (seenFolds.add(key)) {
                        foldRegions.add(new FoldRegion(guide.startLine, guide.endLine));
                    }
                }
            }
        }

        return new DecorationResult.Builder()
                .syntaxSpans(syntaxSpans, DecorationResult.ApplyMode.MERGE)
                .inlayHints(colorInlayHints, DecorationResult.ApplyMode.REPLACE_RANGE)
                .indentGuides(indentGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                .foldRegions(foldRegions, DecorationResult.ApplyMode.REPLACE_ALL)
                .separatorGuides(separatorGuides, DecorationResult.ApplyMode.REPLACE_ALL)
                .gutterIcons(gutterIcons, DecorationResult.ApplyMode.REPLACE_ALL)
                .build();
    }

    private TokenRangeInfo appendDynamicDemoDecorations(@NonNull SparseArray<List<Diagnostic>> diagnostics,
                                                        @NonNull Set<String> seenDiagnostics,
                                                        @NonNull int[] diagnosticCount,
                                                        TokenRangeInfo firstKeywordRange,
                                                        @NonNull Document editorDocument,
                                                        TokenSpan token) {
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return firstKeywordRange;
        }
        String literal = getTokenLiteral(editorDocument, range);
        if (literal.isEmpty()) {
            return firstKeywordRange;
        }

        if (token.styleId == EditorTheme.STYLE_KEYWORD) {
            if (firstKeywordRange == null) {
                firstKeywordRange = range;
            }
            return firstKeywordRange;
        }

        if (token.styleId == EditorTheme.STYLE_COMMENT) {
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

        if (token.styleId == STYLE_COLOR) {
            return firstKeywordRange;
        }

        if (token.styleId == EditorTheme.STYLE_ANNOTATION) {
            appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                    range.line, range.startColumn, range.length(), 3, 0);
        }
        return firstKeywordRange;
    }

    private static void appendDiagnostic(@NonNull SparseArray<List<Diagnostic>> diagnostics,
                                         @NonNull Set<String> seenDiagnostics,
                                         @NonNull int[] diagnosticCount,
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
        List<Diagnostic> lineItems = diagnostics.get(line);
        if (lineItems == null) {
            lineItems = new ArrayList<>();
            diagnostics.put(line, lineItems);
        }
        lineItems.add(new Diagnostic(column, length, severity, color));
        diagnosticCount[0]++;
    }

    private static void appendDiagnosticFallbackIfNeeded(@NonNull SparseArray<List<Diagnostic>> diagnostics,
                                                         @NonNull Set<String> seenDiagnostics,
                                                         @NonNull int[] diagnosticCount,
                                                         TokenRangeInfo firstKeywordRange) {
        if (diagnosticCount[0] > 0 || firstKeywordRange == null) {
            return;
        }
        appendDiagnostic(diagnostics, seenDiagnostics, diagnosticCount,
                firstKeywordRange.line,
                firstKeywordRange.startColumn,
                firstKeywordRange.length(),
                3,
                0);
    }

    @NonNull
    private static String buildAnalysisUri(@NonNull String fileName) {
        return "file:///" + fileName;
    }

    @NonNull
    private static String resolveCurrentFileName(@NonNull DecorationContext context) {
        if (context.editorMetadata instanceof DemoFileMetadata) {
            String fileName = ((DemoFileMetadata) context.editorMetadata).fileName;
            if (fileName != null && !fileName.isEmpty()) {
                return fileName;
            }
        }
        return DEFAULT_ANALYSIS_FILE_NAME;
    }

    private void appendStyleSpan(@NonNull SparseArray<List<StyleSpan>> syntaxSpans,
                                 TokenSpan token) {
        if (token.styleId <= 0) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }

        List<StyleSpan> lineSpans = syntaxSpans.get(range.line);
        if (lineSpans == null) {
            lineSpans = new ArrayList<>();
            syntaxSpans.put(range.line, lineSpans);
        }
        lineSpans.add(new StyleSpan(range.startColumn, range.length(), token.styleId));
    }

    private void appendColorInlayHint(@NonNull SparseArray<List<InlayHint>> colorHints,
                                      @NonNull Set<String> seenHints,
                                      @NonNull Document editorDocument,
                                      TokenSpan token) {
        if (token.styleId != STYLE_COLOR) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String literal = getTokenLiteral(editorDocument, range);
        Integer color = parseColorLiteral(literal);
        if (color == null) {
            return;
        }

        String key = range.line + ":" + range.startColumn + ":" + literal;
        if (!seenHints.add(key)) {
            return;
        }

        List<InlayHint> lineHints = colorHints.get(range.line);
        if (lineHints == null) {
            lineHints = new ArrayList<>();
            colorHints.put(range.line, lineHints);
        }
        lineHints.add(InlayHint.color(range.startColumn, color));
    }

    private Integer parseColorLiteral(@NonNull String literal) {
        if (literal.length() > 2
                && literal.charAt(0) == '0'
                && (literal.charAt(1) == 'X' || literal.charAt(1) == 'x')) {
            try {
                String hex = literal.substring(2).replaceAll("[_uUlL]", "");
                return (int) Long.parseLong(hex, 16);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private void appendTextInlayHint(@NonNull SparseArray<List<InlayHint>> colorHints,
                                     @NonNull Document editorDocument, TokenSpan token) {
        if (token.styleId != EditorTheme.STYLE_KEYWORD) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String literal = getTokenLiteral(editorDocument, range);
        List<InlayHint> lineHints = colorHints.get(range.line);
        if (lineHints == null) {
            lineHints = new ArrayList<>();
            colorHints.put(range.line, lineHints);
        }
        if ("const".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "immutable"));
        } else if ("return".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "value: "));
        } else if ("case".equals(literal)) {
            lineHints.add(InlayHint.text(range.endColumn + 1, "condition: "));
        }
    }

    private void appendSeparator(@NonNull List<SeparatorGuide> separatorGuides,
                                 @NonNull Document editorDocument, TokenSpan token) {
        if (token.styleId != EditorTheme.STYLE_COMMENT) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        String lineText = editorDocument.getLineText(range.line);
        if (lineText == null) {
            return;
        }
        if (range.endColumn > lineText.length()) {
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
            SeparatorGuide separatorGuide = new SeparatorGuide(range.line, isDouble ? 1 : 0, count, lineText.length());
            separatorGuides.add(separatorGuide);
        }
    }

    private void appendGutterIcons(@NonNull SparseArray<List<GutterIcon>> gutterIcons,
                                   @NonNull Document editorDocument, TokenSpan token) {
        if (token.styleId != EditorTheme.STYLE_KEYWORD && token.styleId != EditorTheme.STYLE_ANNOTATION) {
            return;
        }
        TokenRangeInfo range = extractSingleLineTokenRange(token);
        if (range == null) {
            return;
        }
        if (token.styleId == EditorTheme.STYLE_KEYWORD) {
            String literal = getTokenLiteral(editorDocument, range);
            if ("class".equals(literal) || "struct".equals(literal)) {
                List<GutterIcon> lineIcons = gutterIcons.get(range.line);
                if (lineIcons == null) {
                    lineIcons = new ArrayList<>();
                    gutterIcons.put(range.line, lineIcons);
                }
                lineIcons.add(new GutterIcon(ICON_TYPE));
            }
        } else {
            List<GutterIcon> lineIcons = gutterIcons.get(range.line);
            if (lineIcons == null) {
                lineIcons = new ArrayList<>();
                gutterIcons.put(range.line, lineIcons);
            }
            lineIcons.add(new GutterIcon(ICON_AT));
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

    private static TokenRangeInfo extractSingleLineTokenRange(TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return null;
        }
        int startLine = token.range.start.line;
        int endLine = token.range.end.line;
        int startColumn = token.range.start.column;
        int endColumn = token.range.end.column;
        if (startLine < 0 || startLine != endLine || startColumn < 0 || endColumn <= startColumn) {
            return null;
        }
        return new TokenRangeInfo(startLine, startColumn, endColumn);
    }

    private static String getTokenLiteral(@NonNull Document editorDocument, @NonNull TokenRangeInfo range) {
        String lineText = editorDocument.getLineText(range.line);
        if (lineText == null || range.endColumn > lineText.length()) {
            return "";
        }
        return lineText.substring(range.startColumn, range.endColumn);
    }

    public static boolean ensureSweetLineReady(Context context) throws IOException {
        if (highlightEngine != null) {
            return true;
        }

        HighlightConfig config = new HighlightConfig(false, false, 4);
        HighlightEngine engine = new HighlightEngine(config);
        registerDemoStyleMap(engine);

        List<String> syntaxAssets = collectSyntaxAssetFiles(context, SYNTAX_ASSET_DIR);
        if (syntaxAssets.isEmpty()) {
            throw new IOException("No syntax files found under assets/" + SYNTAX_ASSET_DIR);
        }
        for (String assetPath : syntaxAssets) {
            String syntaxJson = loadAssetText(context, assetPath);
            try {
                engine.compileSyntaxFromJson(syntaxJson);
            } catch (SyntaxCompileError e) {
                throw new RuntimeException("Failed to compile syntax asset: " + assetPath, e);
            }
        }

        highlightEngine = engine;
        return true;
    }

    @NonNull
    private static List<String> collectSyntaxAssetFiles(@NonNull Context context, @NonNull String assetDir) throws IOException {
        List<String> files = new ArrayList<>();
        collectSyntaxAssetFilesRecursive(context, assetDir, files);
        files.sort(String::compareToIgnoreCase);
        return files;
    }

    private static void collectSyntaxAssetFilesRecursive(@NonNull Context context,
                                                         @NonNull String assetPath,
                                                         @NonNull List<String> outFiles) throws IOException {
        String[] entries = context.getAssets().list(assetPath);
        if (entries == null || entries.length == 0) {
            if (assetPath.endsWith(".json")) {
                outFiles.add(assetPath);
            }
            return;
        }
        for (String entry : entries) {
            if (entry == null || entry.isEmpty()) {
                continue;
            }
            String childPath = assetPath + "/" + entry;
            collectSyntaxAssetFilesRecursive(context, childPath, outFiles);
        }
    }

    private static void registerDemoStyleMap(@NonNull HighlightEngine engine) {
        engine.registerStyleName("keyword", EditorTheme.STYLE_KEYWORD);
        engine.registerStyleName("type", EditorTheme.STYLE_TYPE);
        engine.registerStyleName("string", EditorTheme.STYLE_STRING);
        engine.registerStyleName("comment", EditorTheme.STYLE_COMMENT);
        engine.registerStyleName("preprocessor", EditorTheme.STYLE_PREPROCESSOR);
        engine.registerStyleName("macro", EditorTheme.STYLE_PREPROCESSOR);
        engine.registerStyleName("method", EditorTheme.STYLE_FUNCTION);
        engine.registerStyleName("function", EditorTheme.STYLE_FUNCTION);
        engine.registerStyleName("variable", EditorTheme.STYLE_VARIABLE);
        engine.registerStyleName("field", EditorTheme.STYLE_VARIABLE);
        engine.registerStyleName("number", EditorTheme.STYLE_NUMBER);
        engine.registerStyleName("class", EditorTheme.STYLE_CLASS);
        engine.registerStyleName("builtin", EditorTheme.STYLE_BUILTIN);
        engine.registerStyleName("annotation", EditorTheme.STYLE_ANNOTATION);
        engine.registerStyleName("color", STYLE_COLOR);
    }

    @NonNull
    private static String loadAssetText(Context context, String assetPath) throws IOException {
        StringBuilder builder = new StringBuilder();
        try (InputStream is = context.getAssets().open(assetPath);
             BufferedReader reader = new BufferedReader(new InputStreamReader(is))) {
            String line;
            while ((line = reader.readLine()) != null) {
                if (builder.length() > 0) {
                    builder.append('\n');
                }
                builder.append(line);
            }
        }
        return builder.toString();
    }

    private static com.qiplat.sweetline.TextRange convertAsSLTextRange(TextRange seRange) {
        com.qiplat.sweetline.TextPosition slStart = new com.qiplat.sweetline.TextPosition(seRange.start.line, seRange.start.column);
        com.qiplat.sweetline.TextPosition slEnd = new com.qiplat.sweetline.TextPosition(seRange.end.line, seRange.end.column);
        return new com.qiplat.sweetline.TextRange(slStart, slEnd);
    }
}
