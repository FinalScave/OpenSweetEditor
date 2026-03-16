package com.qiplat.sweeteditor.demo;

import android.content.Context;
import android.util.Log;
import android.util.SparseArray;

import androidx.annotation.NonNull;

import com.qiplat.sweeteditor.SweetEditor;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.adornment.DiagnosticItem;
import com.qiplat.sweeteditor.core.adornment.FoldRegion;
import com.qiplat.sweeteditor.core.adornment.GutterIcon;
import com.qiplat.sweeteditor.core.adornment.IndentGuide;
import com.qiplat.sweeteditor.core.adornment.InlayHint;
import com.qiplat.sweeteditor.core.adornment.PhantomText;
import com.qiplat.sweeteditor.core.adornment.SeparatorGuide;
import com.qiplat.sweeteditor.core.adornment.StyleSpan;
import com.qiplat.sweeteditor.core.foundation.TextPosition;
import com.qiplat.sweeteditor.decoration.DecorationContext;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationReceiver;
import com.qiplat.sweeteditor.decoration.DecorationResult;
import com.qiplat.sweeteditor.decoration.DecorationType;
import com.qiplat.sweetline.DocumentHighlight;
import com.qiplat.sweetline.HighlightConfig;
import com.qiplat.sweetline.HighlightEngine;
import com.qiplat.sweetline.IndentGuideLine;
import com.qiplat.sweetline.IndentGuideResult;
import com.qiplat.sweetline.LineHighlight;
import com.qiplat.sweetline.SyntaxCompileError;
import com.qiplat.sweetline.TextAnalyzer;
import com.qiplat.sweetline.TokenSpan;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.*;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Demo DecorationProvider:
 * 1) sync push InlayHint + PhantomText
 * 2) sync push SweetLine syntax/indent/fold analysis
 * 3) async push simulated diagnostics
 */
public class DemoDecorationProvider implements DecorationProvider {

    private static final String TAG = "DemoDecorationProvider";
    private static final String CPP_SYNTAX_ASSET = "syntaxes/cpp.json";
    private static final String CPP_SYNTAX_NAME = "cpp";
    private static final int STYLE_KEYWORD = 1;
    private static final int STYLE_TYPE = 2;
    private static final int STYLE_STRING = 3;
    private static final int STYLE_COMMENT = 4;
    private static final int STYLE_PREPROCESSOR = 5;
    private static final int STYLE_FUNCTION = 6;
    private static final int STYLE_NUMBER = 7;
    private static final int STYLE_CLASS = 8;
    private static final int STYLE_COLOR = 9;

    public static final int ICON_CLASS = 1;

    private final Context appContext;
    private final SweetEditor editor;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    private HighlightEngine sweetLineEngine;
    private TextAnalyzer sweetLineAnalyzer;

    public DemoDecorationProvider(@NonNull Context context, @NonNull SweetEditor editor) {
        this.appContext = context.getApplicationContext();
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
                DecorationType.PHANTOM_TEXT,
                DecorationType.DIAGNOSTIC
        );
    }

    @Override
    public void provideDecorations(@NonNull DecorationContext context, @NonNull DecorationReceiver receiver) {
        Log.d(TAG, "provideDecorations: visible=" + context.visibleStartLine + "-" + context.visibleEndLine);

        SparseArray<List<PhantomText>> phantoms = new SparseArray<>();
        phantoms.put(15, Collections.singletonList(
                new PhantomText(5, "\n    void warn(const std::string& m) {\n        log(WARN, m);\n    }")));

        DecorationResult sweetLineResult = buildSweetLineDecorationResult();
        SparseArray<List<InlayHint>> mergedHints = sweetLineResult.getInlayHints();
        receiver.accept(new DecorationResult.Builder()
                .inlayHints(mergedHints)
                .phantomTexts(phantoms)
                .syntaxSpans(sweetLineResult.getSyntaxSpans())
                .indentGuides(sweetLineResult.getIndentGuides())
                .foldRegions(sweetLineResult.getFoldRegions())
                .separatorGuides(sweetLineResult.getSeparatorGuides())
                .gutterIcons(sweetLineResult.getGutterIcons())
                .build());
        Log.d(TAG, "Synchronous push complete: InlayHint + PhantomText + SweetLine");

        executor.submit(() -> {
            try {
                Thread.sleep(500);
            } catch (InterruptedException ignored) {
            }

            if (receiver.isCancelled()) {
                Log.d(TAG, "Asynchronous Diagnostic cancelled (document changed)");
                return;
            }

            SparseArray<List<DiagnosticItem>> diags = new SparseArray<>();
            diags.put(9, Collections.singletonList(new DiagnosticItem(13, 5, 0, 0)));
            diags.put(16, Collections.singletonList(new DiagnosticItem(8, 4, 1, 0)));
            diags.put(22, Collections.singletonList(new DiagnosticItem(4, 3, 3, 0)));
            diags.put(44, Collections.singletonList(new DiagnosticItem(38, 20, 2, 0)));
            diags.put(45, Collections.singletonList(new DiagnosticItem(4, 4, 1, (int) 0xFFFF8C00)));
            diags.put(46, Arrays.asList(
                    new DiagnosticItem(17, 10, 2, 0),
                    new DiagnosticItem(31, 6, 0, 0)
            ));

            receiver.accept(new DecorationResult.Builder()
                    .diagnostics(diags)
                    .build());

            Log.d(TAG, "Asynchronous push complete: Diagnostic (500ms delay)");
        });
    }

    @NonNull
    private DecorationResult buildSweetLineDecorationResult() {
        SparseArray<List<StyleSpan>> syntaxSpans = new SparseArray<>();
        SparseArray<List<InlayHint>> colorInlayHints = new SparseArray<>();
        SparseArray<List<GutterIcon>> gutterIcons = new SparseArray<>();
        List<IndentGuide> indentGuides = new ArrayList<>();
        List<FoldRegion> foldRegions = new ArrayList<>();
        List<SeparatorGuide> separatorGuides = new ArrayList<>();
        Set<String> seenColorHints = new HashSet<>();

        try {
            if (!ensureSweetLineReady()) {
                return new DecorationResult.Builder()
                        .syntaxSpans(syntaxSpans)
                        .inlayHints(colorInlayHints)
                        .indentGuides(indentGuides)
                        .foldRegions(foldRegions)
                        .separatorGuides(separatorGuides)
                        .gutterIcons(gutterIcons)
                        .build();
            }

            Document editorDocument = editor.getDocument();
            String text = editorDocument != null ? editorDocument.getText() : "";

            DocumentHighlight highlight = sweetLineAnalyzer.analyzeText(text);
            if (highlight != null && highlight.lines != null) {
                for (LineHighlight lineHighlight : highlight.lines) {
                    if (lineHighlight == null || lineHighlight.spans == null) continue;
                    for (TokenSpan token : lineHighlight.spans) {
                        appendStyleSpan(syntaxSpans, token);
                        appendColorInlayHint(colorInlayHints, seenColorHints, editorDocument, token);
                        appendTextInlayHint(colorInlayHints, editorDocument, token);
                        appendSeparator(separatorGuides, editorDocument, token);
                        appendGutterIcons(gutterIcons, editorDocument, token);
                    }
                }
            }

            IndentGuideResult guideResult = sweetLineAnalyzer.analyzeIndentGuides(text);
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
                        foldRegions.add(new FoldRegion(guide.startLine, guide.endLine, false));
                    }
                }
            }
        } catch (Throwable t) {
            Log.e(TAG, "SweetLine analyze failed", t);
        }

        return new DecorationResult.Builder()
                .syntaxSpans(syntaxSpans)
                .inlayHints(colorInlayHints)
                .indentGuides(indentGuides)
                .foldRegions(foldRegions)
                .separatorGuides(separatorGuides)
                .gutterIcons(gutterIcons)
                .build();
    }

    private void appendStyleSpan(@NonNull SparseArray<List<StyleSpan>> syntaxSpans,
                                 TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return;
        }
        if (token.styleId <= 0) {
            return;
        }

        int startLine = token.range.start.line;
        int endLine = token.range.end.line;
        int startColumn = token.range.start.column;
        int endColumn = token.range.end.column;
        if (startLine != endLine) {
            return;
        }
        int length = endColumn - startColumn;
        if (startLine < 0 || startColumn < 0 || length <= 0) {
            return;
        }

        List<StyleSpan> lineSpans = syntaxSpans.get(startLine);
        if (lineSpans == null) {
            lineSpans = new ArrayList<>();
            syntaxSpans.put(startLine, lineSpans);
        }
        lineSpans.add(new StyleSpan(startColumn, length, token.styleId));
    }

    private void appendColorInlayHint(@NonNull SparseArray<List<InlayHint>> colorHints,
                                      @NonNull Set<String> seenHints,
                                      @NonNull Document editorDocument,
                                      TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return;
        }
        if (token.styleId != STYLE_COLOR) {
            return;
        }

        int startLine = token.range.start.line;
        int endLine = token.range.end.line;
        int startColumn = token.range.start.column;
        int endColumn = token.range.end.column;
        if (startLine < 0 || startLine != endLine || startColumn < 0 || endColumn <= startColumn) {
            return;
        }

        String lineText = editorDocument.getLineText(startLine);
        if (lineText == null) {
            return;
        }
        if (endColumn > lineText.length()) {
            return;
        }

        String literal = lineText.substring(startColumn, endColumn);
        Integer color = parseColorLiteral(literal);
        if (color == null) {
            return;
        }

        String key = startLine + ":" + startColumn + ":" + literal;
        if (!seenHints.add(key)) {
            return;
        }

        List<InlayHint> lineHints = colorHints.get(startLine);
        if (lineHints == null) {
            lineHints = new ArrayList<>();
            colorHints.put(startLine, lineHints);
        }
        lineHints.add(InlayHint.color(startColumn, color));
    }

    private Integer parseColorLiteral(@NonNull String literal) {
        if (literal.startsWith("0X")) {
            try {
                return (int) Long.parseLong(literal.substring(2), 16);
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }

    private void appendTextInlayHint(@NonNull SparseArray<List<InlayHint>> colorHints,
                                      @NonNull Document editorDocument, TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return;
        }
        if (token.styleId != STYLE_KEYWORD) {
            return;
        }

        int startLine = token.range.start.line;
        int endLine = token.range.end.line;
        int startColumn = token.range.start.column;
        int endColumn = token.range.end.column;
        if (startLine < 0 || startLine != endLine || startColumn < 0 || endColumn <= startColumn) {
            return;
        }

        String lineText = editorDocument.getLineText(startLine);
        if (lineText == null) {
            return;
        }
        if (endColumn > lineText.length()) {
            return;
        }

        List<InlayHint> lineHints = colorHints.get(startLine);
        if (lineHints == null) {
            lineHints = new ArrayList<>();
            colorHints.put(startLine, lineHints);
        }
        String literal = lineText.substring(startColumn, endColumn);
        if ("const".equals(literal)) {
            lineHints.add(InlayHint.text(endColumn + 1, "immutable"));
        } else if ("return".equals(literal)) {
            lineHints.add(InlayHint.text(endColumn + 1, "value: "));
        } else if ("case".equals(literal)) {
            lineHints.add(InlayHint.text(endColumn + 1, "condition: "));
        }
    }

    private void appendSeparator(@NonNull List<SeparatorGuide> separatorGuides,
                                 @NonNull Document editorDocument, TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return;
        }
        if (token.styleId != STYLE_COMMENT) {
            return;
        }
        int startLine = token.range.start.line;
        int endColumn = token.range.end.column;
        String lineText = editorDocument.getLineText(startLine);
        if (lineText == null) {
            return;
        }
        if (endColumn > lineText.length()) {
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
            SeparatorGuide separatorGuide = new SeparatorGuide(startLine, isDouble ? 1 : 0, count, lineText.length());
            separatorGuides.add(separatorGuide);
        }
    }

    private void appendGutterIcons(@NonNull SparseArray<List<GutterIcon>> gutterIcons,
                                 @NonNull Document editorDocument, TokenSpan token) {
        if (token == null || token.range == null || token.range.start == null || token.range.end == null) {
            return;
        }
        if (token.styleId != STYLE_KEYWORD) {
            return;
        }

        int startLine = token.range.start.line;
        int startColumn = token.range.start.column;
        int endColumn = token.range.end.column;

        String lineText = editorDocument.getLineText(startLine);
        if (lineText == null) {
            return;
        }
        if (endColumn > lineText.length()) {
            return;
        }
        String literal = lineText.substring(startColumn, endColumn);
        if ("class".equals(literal) || "struct".equals(literal)) {
            List<GutterIcon> lineIcons = gutterIcons.get(startLine);
            if (lineIcons == null) {
                lineIcons = new ArrayList<>();
                gutterIcons.put(startLine, lineIcons);
            }
            lineIcons.add(new GutterIcon(ICON_CLASS));
        }
    }

    private boolean ensureSweetLineReady() throws IOException {
        if (sweetLineAnalyzer != null) {
            return true;
        }

        HighlightConfig config = new HighlightConfig(false, false, 4);
        HighlightEngine engine = new HighlightEngine(config);
        registerDemoStyleMap(engine);

        String syntaxJson = loadAssetText(CPP_SYNTAX_ASSET);
        try {
            engine.compileSyntaxFromJson(syntaxJson);
        } catch (SyntaxCompileError e) {
            throw new RuntimeException(e);
        }

        TextAnalyzer analyzer = engine.createAnalyzerByName(CPP_SYNTAX_NAME);
        if (analyzer == null) {
            return false;
        }

        sweetLineEngine = engine;
        sweetLineAnalyzer = analyzer;
        return true;
    }

    private void registerDemoStyleMap(@NonNull HighlightEngine engine) {
        engine.registerStyleName("keyword", STYLE_KEYWORD);
        engine.registerStyleName("type", STYLE_TYPE);
        engine.registerStyleName("string", STYLE_STRING);
        engine.registerStyleName("comment", STYLE_COMMENT);
        engine.registerStyleName("preprocessor", STYLE_PREPROCESSOR);
        engine.registerStyleName("macro", STYLE_PREPROCESSOR);
        engine.registerStyleName("method", STYLE_FUNCTION);
        engine.registerStyleName("function", STYLE_FUNCTION);
        engine.registerStyleName("number", STYLE_NUMBER);
        engine.registerStyleName("class", STYLE_CLASS);
        engine.registerStyleName("color", STYLE_COLOR);
        engine.registerStyleName("builtin", STYLE_TYPE);
        engine.registerStyleName("annotation", STYLE_KEYWORD);
    }

    @NonNull
    private String loadAssetText(@NonNull String assetPath) throws IOException {
        StringBuilder builder = new StringBuilder();
        try (InputStream is = appContext.getAssets().open(assetPath);
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
}
