package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.animation.AnimationHolder;
import com.qiplat.sweeteditor.completion.*;
import com.qiplat.sweeteditor.copilot.InlineSuggestion;
import com.qiplat.sweeteditor.copilot.InlineSuggestionController;
import com.qiplat.sweeteditor.copilot.InlineSuggestionListener;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.action.EditorActionSource;
import com.qiplat.sweeteditor.core.action.EditorActionResult;
import com.qiplat.sweeteditor.core.action.ScrollBehavior;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.config.EditorOptions;
import com.qiplat.sweeteditor.core.config.EditorRangeEffectStyles;
import com.qiplat.sweeteditor.core.config.EditorRenderColors;
import com.qiplat.sweeteditor.core.config.RangeEffectStyle;
import com.qiplat.sweeteditor.core.config.RangeEffectUnderlineStyle;
import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.foundation.PointF;
import com.qiplat.sweeteditor.core.ime.ImeCommandKind;
import com.qiplat.sweeteditor.core.ime.ImeCommandMessage;
import com.qiplat.sweeteditor.core.ime.ImeInputContext;
import com.qiplat.sweeteditor.core.ime.ImeOffsetRange;
import com.qiplat.sweeteditor.core.ime.ImeScriptClass;
import com.qiplat.sweeteditor.core.ime.ImeTextUnit;
import com.qiplat.sweeteditor.core.interaction.GestureType;
import com.qiplat.sweeteditor.core.interaction.HitTargetType;
import com.qiplat.sweeteditor.core.keymap.KeyBinding;
import com.qiplat.sweeteditor.core.keymap.KeyCode;
import com.qiplat.sweeteditor.core.search.SearchRequest;
import com.qiplat.sweeteditor.core.search.SearchState;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.core.snippet.*;
import com.qiplat.sweeteditor.core.visual.Cursor;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationProviderManager;
import com.qiplat.sweeteditor.newline.NewLineAction;
import com.qiplat.sweeteditor.newline.NewLineActionProvider;
import com.qiplat.sweeteditor.newline.NewLineActionProviderManager;
import com.qiplat.sweeteditor.perf.PerfStepRecorder;
import com.qiplat.sweeteditor.event.*;

import javax.swing.*;
import java.awt.*;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.StringSelection;
import java.awt.event.*;
import java.awt.font.TextHitInfo;
import java.awt.im.InputMethodRequests;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static java.awt.Cursor.DEFAULT_CURSOR;
import static java.awt.Cursor.HAND_CURSOR;
import static java.awt.Cursor.TEXT_CURSOR;
import static java.awt.Cursor.getPredefinedCursor;

/**
 * SweetEditor Swing editor component.
 * <p>
 * Based on {@link EditorCore} C++ engine providing code editing, syntax highlighting, code folding, InlayHint, etc.
 */
public class SweetEditor extends JPanel {
    // Event type constants (aligned with C++ EventType)
    private static final int MOUSE_DOWN = 7;
    private static final int MOUSE_MOVE = 8;
    private static final int MOUSE_UP = 9;
    private static final int MOUSE_WHEEL = 10;
    private static final int MOUSE_RIGHT_DOWN = 11;

    // Modifier bit flags
    private static final int MOD_SHIFT = 1;
    private static final int MOD_CTRL = 2;
    private static final int MOD_ALT = 4;
    private static final int MOD_META = 8;

    private EditorCore editorCore;
    private EditorKeyMap keyMap;
    private EditorTheme currentTheme;
    private EditorRenderModel renderModel;
    private boolean renderModelDirty = true;
    private boolean fontMetricsDirty = true;
    private EditorRenderer renderer;
    private AnimationHolder animationHolder;

    private Timer cursorBlinkTimer;
    private Timer cursorAnimationTimer;
    private Timer gutterAnimationTimer;
    private boolean cursorVisible = true;

    // Unified animation timer: drives edge-scroll, fling, etc. at ~16ms
    private static final int ANIMATION_INTERVAL_MS = 16;
    private Timer animationTimer;
    private boolean animationActive = false;
    private boolean primaryMouseDown = false;

    // Event bus
    private EditorSettings settings;
    private final EditorEventBus eventBus = new EditorEventBus();
    private final DecorationProviderManager decorationProviderManager = new DecorationProviderManager(this);
    private CompletionProviderManager completionProviderManager;
    private CompletionPopupController completionPopupController;
    private NewLineActionProviderManager newLineActionProviderManager;
    private InlineSuggestionController inlineSuggestionController;
    private LanguageConfiguration languageConfiguration;
    private EditorMetadata metadata;

    public SweetEditor() {
        this(EditorTheme.dark());
    }

    public SweetEditor(EditorTheme theme) {
        this.currentTheme = theme;
        setFocusable(true);
        setFocusTraversalKeysEnabled(false);
        setCursor(getPredefinedCursor(TEXT_CURSOR));
        setDoubleBuffered(true);

        renderer = new EditorRenderer(theme);
        animationHolder = new AnimationHolder();

        editorCore = new EditorCore(renderer.getTextMeasurer(), new EditorOptions(20.0f, 300L, 500L, 3.5f, 50.0f, 8000.0f, 512L, 2000L, false));
        keyMap = createDefaultKeyMap();
        editorCore.setKeyMap(keyMap.getBindings());

        // Completion manager and popup controller
        completionProviderManager = new CompletionProviderManager(this);
        completionPopupController = new CompletionPopupController(this, theme);
        completionProviderManager.setListener(new CompletionProviderManager.CompletionUpdateListener() {
            @Override
            public void onCompletionItemsUpdated(List<CompletionItem> items) {
                ensureRenderModelUpToDate();
                updateCompletionPopupCursorAnchor();
                completionPopupController.onCompletionItemsUpdated(items);
            }

            @Override
            public void onCompletionDismissed() {
                completionPopupController.onCompletionDismissed();
            }
        });
        completionPopupController.setConfirmListener(this::applyCompletionItem);

        settings = new EditorSettings(this);

        inlineSuggestionController = new InlineSuggestionController(this);

        if (currentTheme != null) {
            editorCore.setEditorRenderColors(buildEditorRenderColors(currentTheme));
            editorCore.setEditorRangeEffectStyles(buildEditorRangeEffectStyles(currentTheme));
        }
        if (currentTheme != null && !currentTheme.textStyles.isEmpty()) {
            editorCore.registerBatchTextStyles(currentTheme.textStyles);
        }

        setBackground(currentTheme.backgroundColor);
        setFont(renderer.getRegularFont());
        setAutoscrolls(true);
        setupEventListeners();
        setupCursorBlink();
        setupCursorAnimation();
        setupGutterAnimation();
        setupAnimationTimer();
        enableInputMethods(true);
    }

    // ==================== Document Loading ====================

    public void loadDocument(Document document) {
        if (document == null) return;
        EditorActionResult result = editorCore.loadDocument(document);
        renderModel = null;
        decorationProviderManager.onDocumentLoaded();
        eventBus.publish(new DocumentLoadedEvent());
        dispatchEditorActionResult(result);
    }

    public Document getDocument() {
        return editorCore.getDocument();
    }

    // ==================== Settings / Theme / Core Access ====================

    public EditorSettings getSettings() {
        return settings;
    }

    public EditorCore getEditorCore() {
        return editorCore;
    }

    public EditorKeyMap getKeyMap() {
        return keyMap;
    }

    public void setKeyMap(EditorKeyMap keyMap) {
        if (keyMap == null) return;
        this.keyMap = keyMap;
        dispatchEditorActionResult(editorCore.setKeyMap(keyMap.getBindings()));
    }

    public EditorTheme getTheme() {
        return currentTheme;
    }

    public void applyTheme(EditorTheme theme) {
        if (theme == null) return;
        this.currentTheme = theme;
        renderer.applyTheme(theme);
        setBackground(theme.backgroundColor);
        dispatchEditorActionResult(editorCore.setEditorRenderColors(buildEditorRenderColors(theme)));
        dispatchEditorActionResult(editorCore.setEditorRangeEffectStyles(buildEditorRangeEffectStyles(theme)));
        EditorActionResult result = null;
        if (theme != null && !theme.textStyles.isEmpty()) {
            result = editorCore.registerBatchTextStyles(theme.textStyles);
        }
        if (completionPopupController != null) {
            completionPopupController.applyTheme(theme);
        }
        if (inlineSuggestionController != null) {
            inlineSuggestionController.applyTheme(theme);
        }
        dispatchEditorActionResult(result);
        flush();
    }

    private EditorRenderColors buildEditorRenderColors(EditorTheme theme) {
        int codeLensForeground = colorToArgb(theme.codeLensColor != null ? theme.codeLensColor : theme.inlayHintTextColor);
        int activeCodeLensForeground = colorToArgb(theme.codeLensActiveColor != null
                ? theme.codeLensActiveColor
                : (theme.currentLineNumberColor != null ? theme.currentLineNumberColor : theme.lineNumberColor));
        int linkForeground = colorToArgb(theme.linkColor);
        if (linkForeground == 0) linkForeground = codeLensForeground;
        int activeLinkForeground = colorToArgb(theme.linkActiveColor != null
                ? theme.linkActiveColor
                : theme.linkColor);
        if (activeLinkForeground == 0) activeLinkForeground = activeCodeLensForeground;
        return new EditorRenderColors(
                colorToArgb(theme.textColor),
                linkForeground,
                activeLinkForeground,
                codeLensForeground,
                activeCodeLensForeground);
    }

    private EditorRangeEffectStyles buildEditorRangeEffectStyles(EditorTheme theme) {
        EditorRangeEffectStyles styles = new EditorRangeEffectStyles();
        styles.selection = new RangeEffectStyle(
                colorToArgb(theme.selectionTextColor),
                colorToArgb(theme.selectionColor),
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.searchMatch = new RangeEffectStyle(
                0,
                colorToArgb(theme.searchMatchBgColor),
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.searchCurrent = new RangeEffectStyle(
                0,
                colorToArgb(theme.searchCurrentBgColor),
                colorToArgb(theme.searchCurrentBorderColor),
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightText = new RangeEffectStyle(
                0,
                colorToArgb(theme.documentHighlightTextBgColor),
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightRead = new RangeEffectStyle(
                0,
                colorToArgb(theme.documentHighlightReadBgColor),
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.documentHighlightWrite = new RangeEffectStyle(
                0,
                colorToArgb(theme.documentHighlightWriteBgColor),
                0,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.imeComposition = new RangeEffectStyle(
                0,
                0,
                0,
                colorToArgb(theme.compositionUnderlineColor),
                RangeEffectUnderlineStyle.SOLID);
        styles.diagnosticError = diagnosticStyle(theme.diagnosticErrorColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticWarning = diagnosticStyle(theme.diagnosticWarningColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticInfo = diagnosticStyle(theme.diagnosticInfoColor, RangeEffectUnderlineStyle.WAVY);
        styles.diagnosticHint = diagnosticStyle(theme.diagnosticHintColor, RangeEffectUnderlineStyle.DASHED);
        int activeLinked = colorToArgb(theme.linkedEditingActiveColor);
        styles.linkedEditingActive = new RangeEffectStyle(
                0,
                withAlpha(activeLinked, 0x20),
                activeLinked,
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.linkedEditingInactive = new RangeEffectStyle(
                0,
                0,
                colorToArgb(theme.linkedEditingInactiveColor),
                0,
                RangeEffectUnderlineStyle.NONE);
        styles.bracketMatch = new RangeEffectStyle(
                0,
                colorToArgb(theme.bracketHighlightBgColor),
                colorToArgb(theme.bracketHighlightBorderColor),
                0,
                RangeEffectUnderlineStyle.NONE);
        return styles;
    }

    private RangeEffectStyle diagnosticStyle(Color color, RangeEffectUnderlineStyle underlineStyle) {
        return new RangeEffectStyle(0, 0, 0, colorToArgb(color), underlineStyle);
    }

    private int withAlpha(int color, int alpha) {
        return color == 0 ? 0 : (color & 0x00FFFFFF) | ((alpha & 0xFF) << 24);
    }

    private int colorToArgb(Color color) {
        return color == null ? 0 : color.getRGB();
    }

    public IntRange getVisibleLineRange() {
        if (renderModelDirty) {
            ensureRenderModelUpToDate();
        }
        return editorCore.getVisibleLineRange();
    }

    public int getTotalLineCount() {
        Document doc = editorCore.getDocument();
        return doc == null ? -1 : doc.getLineCount();
    }

    // ==================== Text Editing ====================

    public void insertText(String text) {
        EditorActionResult result = editorCore.insertText(text);
        dispatchEditorActionResult(result);
    }

    /**
     * Insert text at the specified document position.
     *
     * @param position insertion position
     * @param text     text to insert
     */
    public void insertTextAt(TextPosition position, String text) {
        replaceText(new TextRange(position, position), text);
    }

    public void replaceText(TextRange range, String newText) {
        EditorActionResult result = editorCore.replaceText(range, newText);
        dispatchEditorActionResult(result);
    }

    public void deleteText(TextRange range) {
        EditorActionResult result = editorCore.deleteText(range);
        dispatchEditorActionResult(result);
    }

    /**
     * Apply multiple text edits as one undoable operation.
     *
     * @param edits text edits using the original document coordinates. The first edit is the primary edit.
     */
    public void applyTextEdits(List<? extends TextEdit> edits) {
        EditorActionResult result = editorCore.applyTextEdits(edits);
        dispatchEditorActionResult(result);
    }

    // ==================== Line Operations ====================

    public void moveLineUp() {
        EditorActionResult result = editorCore.moveLineUp();
        dispatchEditorActionResult(result);
    }

    public void moveLineDown() {
        EditorActionResult result = editorCore.moveLineDown();
        dispatchEditorActionResult(result);
    }

    public void copyLineUp() {
        EditorActionResult result = editorCore.copyLineUp();
        dispatchEditorActionResult(result);
    }

    public void copyLineDown() {
        EditorActionResult result = editorCore.copyLineDown();
        dispatchEditorActionResult(result);
    }

    public void deleteLine() {
        EditorActionResult result = editorCore.deleteLine();
        dispatchEditorActionResult(result);
    }

    public void insertLineAbove() {
        EditorActionResult result = editorCore.insertLineAbove();
        dispatchEditorActionResult(result);
    }

    public void insertLineBelow() {
        EditorActionResult result = editorCore.insertLineBelow();
        dispatchEditorActionResult(result);
    }

    // ==================== Undo/Redo ====================

    public void undo() {
        EditorActionResult result = editorCore.undo();
        dispatchEditorActionResult(result);
    }

    public void redo() {
        EditorActionResult result = editorCore.redo();
        dispatchEditorActionResult(result);
    }

    public boolean canUndo() {
        return editorCore.canUndo();
    }

    public boolean canRedo() {
        return editorCore.canRedo();
    }

    // ==================== Search ====================

    public void search(SearchRequest request) {
        EditorActionResult result = editorCore.search(request);
        dispatchEditorActionResult(result);
    }

    public void findNextSearchMatch() {
        EditorActionResult result = editorCore.findNextSearchMatch();
        dispatchEditorActionResult(result);
    }

    public void findPreviousSearchMatch() {
        EditorActionResult result = editorCore.findPreviousSearchMatch();
        dispatchEditorActionResult(result);
    }

    public void replaceCurrentSearchMatch(String replacement) {
        EditorActionResult result = editorCore.replaceCurrentSearchMatch(replacement);
        dispatchEditorActionResult(result);
    }

    public void replaceAllSearchMatches(String replacement) {
        EditorActionResult result = editorCore.replaceAllSearchMatches(replacement);
        dispatchEditorActionResult(result);
    }

    public void clearSearch() {
        EditorActionResult result = editorCore.clearSearch();
        dispatchEditorActionResult(result);
    }

    public SearchState getSearchState() {
        return editorCore.getSearchState();
    }

    // ==================== Cursor/Selection Management ====================

    public void selectAll() {
        EditorActionResult result = editorCore.selectAll();
        dispatchEditorActionResult(result);
    }

    public String getSelectedText() {
        return editorCore.getSelectedText();
    }

    public void setSelection(int startLine, int startColumn, int endLine, int endColumn) {
        EditorActionResult result = editorCore.setSelection(startLine, startColumn, endLine, endColumn);
        dispatchEditorActionResult(result);
    }

    public TextRange getSelection() {
        return editorCore.getSelection();
    }

    public void setCursorPosition(TextPosition position) {
        EditorActionResult result = editorCore.setCursorPosition(position.line, position.column);
        dispatchEditorActionResult(result);
    }

    public TextPosition getCursorPosition() {
        return editorCore.getCursorPosition();
    }

    public TextRange getWordRangeAtCursor() {
        return editorCore.getWordRangeAtCursor();
    }

    public String getWordAtCursor() {
        return editorCore.getWordAtCursor();
    }

    // ==================== Clipboard ====================

    public void copyToClipboard() {
        String selectedText = getSelectedText();
        if (selectedText == null || selectedText.isEmpty()) return;
        Toolkit.getDefaultToolkit().getSystemClipboard().setContents(new StringSelection(selectedText), null);
    }

    public void pasteFromClipboard() {
        try {
            Object value = Toolkit.getDefaultToolkit().getSystemClipboard().getData(DataFlavor.stringFlavor);
            if (value instanceof String text && !text.isEmpty()) {
                insertText(text);
            }
        } catch (Exception ignored) {
        }
    }

    public void cutToClipboard() {
        TextRange selection = getSelection();
        if (selection == null) return;
        copyToClipboard();
        deleteText(selection);
    }

    // ==================== Position/Coordinate Query ====================

    public CursorRect getPositionRect(int line, int column) {
        return editorCore.getPositionRect(line, column);
    }

    public CursorRect getCursorRect() {
        return editorCore.getCursorRect();
    }

    // ==================== Scroll/Navigation ====================

    public void gotoPosition(int line, int column) {
        EditorActionResult result = editorCore.gotoPosition(line, column);
        dispatchEditorActionResult(result);
    }

    public void scrollToLine(int line, ScrollBehavior behavior) {
        EditorActionResult result = editorCore.scrollToLine(line, behavior.value);
        dispatchEditorActionResult(result);
    }

    public void setScroll(float scrollX, float scrollY) {
        EditorActionResult result = editorCore.setScroll(scrollX, scrollY);
        dispatchEditorActionResult(result);
    }

    public ScrollMetrics getScrollMetrics() {
        return editorCore.getScrollMetrics();
    }

    // ==================== Decoration System ====================

    public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle) {
        EditorActionResult result = editorCore.registerTextStyle(styleId, color, bgColor, fontStyle);
        dispatchEditorActionResult(result);
    }

    public void registerTextStyle(int styleId, int color, int fontStyle) {
        EditorActionResult result = editorCore.registerTextStyle(styleId, color, fontStyle);
        dispatchEditorActionResult(result);
    }

    public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) {
        EditorActionResult result = editorCore.registerBatchTextStyles(textStyles);
        dispatchEditorActionResult(result);
    }

    public void setLineSpans(int line, SpanLayer layer, List<? extends StyleSpan> spans) {
        EditorActionResult result = editorCore.setLineSpans(line, layer.value, spans);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineSpans(SpanLayer layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) {
        EditorActionResult result = editorCore.setBatchLineSpans(layer.value, spansByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineInlayHints(int line, List<? extends InlayHint> hints) {
        EditorActionResult result = editorCore.setLineInlayHints(line, hints);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) {
        EditorActionResult result = editorCore.setBatchLineInlayHints(hintsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms) {
        EditorActionResult result = editorCore.setLinePhantomTexts(line, phantoms);
        dispatchEditorActionResult(result);
    }

    public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) {
        EditorActionResult result = editorCore.setBatchLinePhantomTexts(phantomsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineGutterIcons(int line, List<? extends GutterIcon> icons) {
        EditorActionResult result = editorCore.setLineGutterIcons(line, icons);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) {
        EditorActionResult result = editorCore.setBatchLineGutterIcons(iconsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineCodeLens(int line, List<? extends CodeLensItem> items) {
        EditorActionResult result = editorCore.setLineCodeLens(line, items);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineCodeLens(Map<Integer, ? extends List<? extends CodeLensItem>> itemsByLine) {
        EditorActionResult result = editorCore.setBatchLineCodeLens(itemsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineLinks(int line, List<? extends LinkSpan> links) {
        EditorActionResult result = editorCore.setLineLinks(line, links);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineLinks(Map<Integer, ? extends List<? extends LinkSpan>> linksByLine) {
        EditorActionResult result = editorCore.setBatchLineLinks(linksByLine);
        dispatchEditorActionResult(result);
    }

    public String getLinkTargetAt(int line, int column) {
        return editorCore.getLinkTargetAt(line, column);
    }

    public void setLineDiagnostics(int line, List<? extends Diagnostic> items) {
        EditorActionResult result = editorCore.setLineDiagnostics(line, items);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends Diagnostic>> diagsByLine) {
        EditorActionResult result = editorCore.setBatchLineDiagnostics(diagsByLine);
        dispatchEditorActionResult(result);
    }

    public void setLineDocumentHighlights(int line, List<? extends DocumentHighlight> items) {
        EditorActionResult result = editorCore.setLineDocumentHighlights(line, items);
        dispatchEditorActionResult(result);
    }

    public void setBatchLineDocumentHighlights(Map<Integer, ? extends List<? extends DocumentHighlight>> highlightsByLine) {
        EditorActionResult result = editorCore.setBatchLineDocumentHighlights(highlightsByLine);
        dispatchEditorActionResult(result);
    }

    public void setIndentGuides(List<? extends IndentGuide> guides) {
        EditorActionResult result = editorCore.setIndentGuides(guides);
        dispatchEditorActionResult(result);
    }

    public void setBracketGuides(List<? extends BracketGuide> guides) {
        EditorActionResult result = editorCore.setBracketGuides(guides);
        dispatchEditorActionResult(result);
    }

    public void setFlowGuides(List<? extends FlowGuide> guides) {
        EditorActionResult result = editorCore.setFlowGuides(guides);
        dispatchEditorActionResult(result);
    }

    public void setSeparatorGuides(List<? extends SeparatorGuide> guides) {
        EditorActionResult result = editorCore.setSeparatorGuides(guides);
        dispatchEditorActionResult(result);
    }

    // ==================== Folding ====================

    public void setFoldRegions(List<? extends FoldRegion> regions) {
        EditorActionResult result = editorCore.setFoldRegions(regions);
        dispatchEditorActionResult(result);
    }

    public void toggleFoldAt(int line) {
        EditorActionResult result = editorCore.toggleFoldAt(line);
        dispatchEditorActionResult(result);
    }

    public void foldAt(int line) {
        EditorActionResult result = editorCore.foldAt(line);
        dispatchEditorActionResult(result);
    }

    public void unfoldAt(int line) {
        EditorActionResult result = editorCore.unfoldAt(line);
        dispatchEditorActionResult(result);
    }

    public void foldAll() {
        EditorActionResult result = editorCore.foldAll();
        dispatchEditorActionResult(result);
    }

    public void unfoldAll() {
        EditorActionResult result = editorCore.unfoldAll();
        dispatchEditorActionResult(result);
    }

    public boolean isLineVisible(int line) {
        return editorCore.isLineVisible(line);
    }

    // ==================== Snippet / Linked Editing ====================

    public void insertSnippet(String snippetTemplate) {
        EditorActionResult result = editorCore.insertSnippet(snippetTemplate);
        dispatchEditorActionResult(result);
    }

    public void startLinkedEditing(LinkedEditingModel model) {
        EditorActionResult result = editorCore.startLinkedEditing(model);
        dispatchEditorActionResult(result);
    }

    public boolean isInLinkedEditing() {
        return editorCore.isInLinkedEditing();
    }

    public void linkedEditingNext() {
        EditorActionResult result = editorCore.linkedEditingNext();
        dispatchEditorActionResult(result);
    }

    public void linkedEditingPrev() {
        EditorActionResult result = editorCore.linkedEditingPrev();
        dispatchEditorActionResult(result);
    }

    public void cancelLinkedEditing() {
        EditorActionResult result = editorCore.cancelLinkedEditing();
        dispatchEditorActionResult(result);
    }

    // ==================== Clear Decorations ====================

    public void clearHighlights() {
        EditorActionResult result = editorCore.clearHighlights();
        dispatchEditorActionResult(result);
    }

    public void clearHighlights(com.qiplat.sweeteditor.core.adornment.SpanLayer layer) {
        EditorActionResult result = editorCore.clearHighlights(layer.value);
        dispatchEditorActionResult(result);
    }

    public void clearInlayHints() {
        EditorActionResult result = editorCore.clearInlayHints();
        dispatchEditorActionResult(result);
    }

    public void clearPhantomTexts() {
        EditorActionResult result = editorCore.clearPhantomTexts();
        dispatchEditorActionResult(result);
    }

    public void clearGutterIcons() {
        EditorActionResult result = editorCore.clearGutterIcons();
        dispatchEditorActionResult(result);
    }

    public void clearCodeLens() {
        EditorActionResult result = editorCore.clearCodeLens();
        dispatchEditorActionResult(result);
    }

    public void clearLinks() {
        EditorActionResult result = editorCore.clearLinks();
        dispatchEditorActionResult(result);
    }

    public void clearGuides() {
        EditorActionResult result = editorCore.clearGuides();
        dispatchEditorActionResult(result);
    }

    public void clearDiagnostics() {
        EditorActionResult result = editorCore.clearDiagnostics();
        dispatchEditorActionResult(result);
    }

    public void clearDocumentHighlights() {
        EditorActionResult result = editorCore.clearDocumentHighlights();
        dispatchEditorActionResult(result);
    }

    public void clearAllDecorations() {
        EditorActionResult result = editorCore.clearAllDecorations();
        dispatchEditorActionResult(result);
    }

    /**
     * Flush pending layout and render state when the core reports a redraw requirement.
     */
    public void flush() {
        renderModelDirty = true;
        repaint();
    }

    // ==================== View Layer Extension Configuration ====================

    public void setLanguageConfiguration(LanguageConfiguration config) {
        this.languageConfiguration = config;
        if (config == null) {
            dispatchEditorActionResult(editorCore.setBracketPairs(new int[0], new int[0]));
            dispatchEditorActionResult(editorCore.setAutoClosingPairs(new int[0], new int[0]));
            dispatchEditorActionResult(editorCore.setTabSize(LanguageConfiguration.DEFAULT_TAB_SIZE));
            dispatchEditorActionResult(editorCore.setInsertSpaces(false));
            return;
        }

        List<LanguageConfiguration.BracketPair> brackets = config.getBrackets();
        if (brackets != null && !brackets.isEmpty()) {
            int size = brackets.size();
            int[] opens = new int[size];
            int[] closes = new int[size];
            for (int i = 0; i < size; i++) {
                LanguageConfiguration.BracketPair pair = brackets.get(i);
                opens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                closes[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            dispatchEditorActionResult(editorCore.setBracketPairs(opens, closes));
        } else {
            dispatchEditorActionResult(editorCore.setBracketPairs(new int[0], new int[0]));
        }
        List<LanguageConfiguration.BracketPair> acPairs = config.getAutoClosingPairs();
        if (acPairs != null && !acPairs.isEmpty()) {
            int acSize = acPairs.size();
            int[] acOpens = new int[acSize];
            int[] acCloses = new int[acSize];
            for (int i = 0; i < acSize; i++) {
                LanguageConfiguration.BracketPair pair = acPairs.get(i);
                acOpens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                acCloses[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            dispatchEditorActionResult(editorCore.setAutoClosingPairs(acOpens, acCloses));
        } else {
            dispatchEditorActionResult(editorCore.setAutoClosingPairs(new int[0], new int[0]));
        }
        Integer tabSize = config.getTabSize();
        dispatchEditorActionResult(editorCore.setTabSize(tabSize != null && tabSize > 0
                ? tabSize
                : LanguageConfiguration.DEFAULT_TAB_SIZE));

        Boolean insertSpaces = config.getInsertSpaces();
        dispatchEditorActionResult(editorCore.setInsertSpaces(insertSpaces != null ? insertSpaces : false));
    }

    public LanguageConfiguration getLanguageConfiguration() {
        return languageConfiguration;
    }

    public <T extends EditorMetadata> void setMetadata(T metadata) {
        this.metadata = metadata;
    }

    @SuppressWarnings("unchecked")
    public <T extends EditorMetadata> T getMetadata() {
        return (T) metadata;
    }

    /**
     * Set the editor icon provider.
     *
     * @param provider Icon provider, pass null to remove
     */
    public void setEditorIconProvider(EditorIconProvider provider) {
        renderer.setEditorIconProvider(provider);
    }

    /**
     * Get the current editor icon provider.
     */
    public EditorIconProvider getEditorIconProvider() {
        return renderer.getEditorIconProvider();
    }

    // ==================== Extension Provider API ====================

    public void addDecorationProvider(DecorationProvider provider) {
        decorationProviderManager.addProvider(provider);
    }

    public void removeDecorationProvider(DecorationProvider provider) {
        decorationProviderManager.removeProvider(provider);
    }

    public void requestDecorationRefresh() {
        decorationProviderManager.requestRefresh();
    }

    public void addCompletionProvider(CompletionProvider provider) {
        if (completionProviderManager != null) completionProviderManager.addProvider(provider);
    }

    public void removeCompletionProvider(CompletionProvider provider) {
        if (completionProviderManager != null) completionProviderManager.removeProvider(provider);
    }

    public void triggerCompletion() {
        if (completionProviderManager != null) {
            completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.INVOKED, null);
        }
    }

    public void showCompletionItems(List<CompletionItem> items) {
        if (completionProviderManager != null) completionProviderManager.showItems(items);
    }

    public void dismissCompletion() {
        if (completionProviderManager != null) completionProviderManager.dismiss();
    }

    public void setCompletionCellRenderer(CompletionCellRenderer renderer) {
        if (completionPopupController != null) completionPopupController.setCellRenderer(renderer);
    }

    // ==================== Inline Suggestion (Copilot) API ====================

    public void showInlineSuggestion(InlineSuggestion suggestion) {
        if (inlineSuggestionController != null) {
            inlineSuggestionController.show(suggestion);
        }
    }

    public void dismissInlineSuggestion() {
        if (inlineSuggestionController != null) {
            inlineSuggestionController.dismiss();
        }
    }

    public boolean isInlineSuggestionShowing() {
        return inlineSuggestionController != null && inlineSuggestionController.isShowing();
    }

    public void setInlineSuggestionListener(InlineSuggestionListener listener) {
        if (inlineSuggestionController != null) {
            inlineSuggestionController.setListener(listener);
        }
    }

    public void addNewLineActionProvider(NewLineActionProvider provider) {
        if (newLineActionProviderManager == null) {
            newLineActionProviderManager = new NewLineActionProviderManager(this);
        }
        newLineActionProviderManager.addProvider(provider);
    }

    public void removeNewLineActionProvider(NewLineActionProvider provider) {
        if (newLineActionProviderManager != null) {
            newLineActionProviderManager.removeProvider(provider);
        }
    }

    // ==================== Event Subscription ====================

    public <T extends EditorEvent> void subscribe(Class<T> eventType, EditorEventListener<T> listener) {
        eventBus.subscribe(eventType, listener);
    }

    public <T extends EditorEvent> void unsubscribe(Class<T> eventType, EditorEventListener<T> listener) {
        eventBus.unsubscribe(eventType, listener);
    }

    // ==================== Performance Overlay ====================

    public void setPerfOverlayEnabled(boolean enabled) {
        renderer.setPerfOverlayEnabled(enabled);
        repaint();
    }

    public boolean isPerfOverlayEnabled() {
        return renderer.isPerfOverlayEnabled();
    }

    // ===================== Painting =====================

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2 = (Graphics2D) g;
        renderer.prepareGraphicsForRender(g2);
        ensureRenderModelUpToDate();

        renderer.render(g2, renderModel, getWidth(), getHeight(), cursorVisible, animationHolder);
        updateCompletionPopupCursorAnchor();
        updateInlineSuggestionPosition();
    }


    // ===================== Event Handling =====================

    private void setupEventListeners() {
        addMouseListener(new MouseAdapter() {
            @Override
            public void mouseEntered(MouseEvent e) {
                handleGesture(MOUSE_MOVE, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
            }

            @Override
            public void mousePressed(MouseEvent e) {
                requestFocusInWindow();
                int mods = getModifiers(e);
                if (SwingUtilities.isLeftMouseButton(e)) {
                    primaryMouseDown = true;
                    handleGesture(MOUSE_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                } else if (SwingUtilities.isRightMouseButton(e)) {
                    handleGesture(MOUSE_RIGHT_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                }
            }

            @Override
            public void mouseReleased(MouseEvent e) {
                if (primaryMouseDown || SwingUtilities.isLeftMouseButton(e)) {
                    primaryMouseDown = false;
                    handleGesture(MOUSE_UP, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                }
            }
            @Override
            public void mouseExited(MouseEvent e) {
                boolean primaryDown = primaryMouseDown || isPrimaryButtonDown(e);
                if (primaryDown) {
                    ensurePrimaryMouseDown(e);
                    handleGesture(MOUSE_MOVE, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                } else {
                    handleGesture(MOUSE_MOVE, -1, -1, getModifiers(e), 0, 0, 1);
                }
            }

        });

        addMouseMotionListener(new MouseMotionAdapter() {
            @Override
            public void mouseDragged(MouseEvent e) {
                boolean primaryDown = primaryMouseDown || isPrimaryButtonDown(e);
                if (primaryDown) {
                    ensurePrimaryMouseDown(e);
                    handleGesture(MOUSE_MOVE, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                }
            }
            @Override
            public void mouseMoved(MouseEvent e) {
                handleGesture(MOUSE_MOVE, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
            }

        });

        addMouseWheelListener(e -> {
            float deltaY = (float) (-e.getPreciseWheelRotation() * 40);
            handleGesture(MOUSE_WHEEL, e.getX(), e.getY(), getModifiers(e), 0, deltaY, 1);
        });

        addKeyListener(new KeyAdapter() {
            @Override
            public void keyPressed(KeyEvent e) {
                long inputPerfStart = startInputPerf();
                try {
                    refreshPointerModifiers(e);

                    if (editorCore.hasPreedit()) {
                        handleComposingKeyPressed(e);
                        return;
                    }

                    // Inline suggestion keyboard interception (Tab=accept, Esc=dismiss)
                    if (inlineSuggestionController != null && inlineSuggestionController.isShowing()) {
                        if (inlineSuggestionController.handleKeyEvent(e.getKeyCode())) {
                            e.consume();
                            return;
                        }
                    }

                    // Completion panel keyboard interception
                    if (completionPopupController != null && completionPopupController.isShowing()) {
                        if (completionPopupController.handleSwingKeyCode(e.getKeyCode())) {
                            e.consume();
                            return;
                        }
                    }

                    int mods = getModifiers(e);

                    int keyCode = mapKeyCode(e.getKeyCode());
                    if (keyCode == 0 && (e.isControlDown() || e.isMetaDown() || e.isAltDown())) {
                        keyCode = mapShortcutKeyCode(e.getKeyCode());
                    }

                    // Prioritize letting NewLineActionProvider handle Enter (Provider decides indentation),
                    // if no Provider or returns null then fallback to Core layer default behavior
                    if (keyCode == 13 && newLineActionProviderManager != null) {
                        NewLineAction action = newLineActionProviderManager.provideNewLineAction();
                        if (action != null) {
                            EditorActionResult editResult = editorCore.handleKeyEvent(KeyCode.NONE, action.text, mods);
                            e.consume();
                            resetCursorBlink();
                            dispatchEditorActionResult(editResult);
                            return;
                        }
                    }

                    if (keyCode != 0) {
                        EditorActionResult result = editorCore.handleKeyEvent(keyCode, null, mods);
                        if (result != null && result.handled) {
                            e.consume();
                            if (dispatchKeyMapCommand(result.command, keyCode, mods)) {
                                resetCursorBlink();
                                dispatchEditorActionResult(result);
                                return;
                            }
                            resetCursorBlink();
                            dispatchEditorActionResult(result);
                        }
                    }
                } finally {
                    finishInputPerf("keyPressed", inputPerfStart);
                }
            }

            @Override
            public void keyReleased(KeyEvent e) {
                refreshPointerModifiers(e);
            }

            @Override
            public void keyTyped(KeyEvent e) {
                long inputPerfStart = startInputPerf();
                try {
                    if (editorCore.hasPreedit()) return;
                    char ch = e.getKeyChar();
                    if (!Character.isISOControl(ch) && ch != KeyEvent.CHAR_UNDEFINED) {
                        EditorActionResult result = editorCore.handleKeyEvent(KeyCode.NONE, String.valueOf(ch), 0);
                        e.consume();
                        resetCursorBlink();
                        dispatchEditorActionResult(result);
                    }
                } finally {
                    finishInputPerf("keyTyped", inputPerfStart);
                }
            }
        });

        addInputMethodListener(new InputMethodListener() {
            @Override
            public void inputMethodTextChanged(InputMethodEvent event) {
                long inputPerfStart = startInputPerf();
                try {
                    AttributedCharacterIterator aci = event.getText();
                    if (aci == null) return;

                    int committedCount = event.getCommittedCharacterCount();
                    StringBuilder committed = new StringBuilder();
                    StringBuilder composed = new StringBuilder();

                    char c = aci.first();
                    for (int i = 0; i < committedCount && c != AttributedCharacterIterator.DONE; i++, c = aci.next()) {
                        committed.append(c);
                    }
                    while (c != AttributedCharacterIterator.DONE) {
                        composed.append(c);
                        c = aci.next();
                    }

                    boolean changed = false;
                    if (committed.length() > 0) {
                        ImeCommandMessage message = new ImeCommandMessage();
                        message.kind = ImeCommandKind.COMMIT_TEXT;
                        message.text = committed.toString();
                        message.scriptClass = ImeScriptClass.UNKNOWN;
                        EditorActionResult result = editorCore.handleImeCommandMessage(message);
                        dispatchEditorActionResult(result);
                        changed = true;
                    }
                    if (composed.length() > 0) {
                        int caretOffset = getComposedCaretOffset(event, committedCount, composed.length());
                        ImeCommandMessage message = new ImeCommandMessage();
                        message.kind = ImeCommandKind.SET_PREEDIT_TEXT;
                        message.text = composed.toString();
                        message.selection = new ImeOffsetRange(caretOffset, caretOffset);
                        message.scriptClass = ImeScriptClass.UNKNOWN;
                        EditorActionResult result = editorCore.handleImeCommandMessage(message);
                        dispatchEditorActionResult(result);
                        changed = true;
                    } else if (editorCore.hasPreedit() && committed.length() == 0) {
                        ImeCommandMessage message = new ImeCommandMessage();
                        message.kind = ImeCommandKind.CANCEL_PREEDIT;
                        EditorActionResult result = editorCore.handleImeCommandMessage(message);
                        dispatchEditorActionResult(result);
                        changed = true;
                    }
                    if (changed) {
                        resetCursorBlink();
                    }

                    event.consume();
                } finally {
                    finishInputPerf("ime", inputPerfStart);
                }
            }

            @Override
            public void caretPositionChanged(InputMethodEvent event) {
                event.consume();
            }
        });

        addComponentListener(new ComponentAdapter() {
            @Override
            public void componentResized(ComponentEvent e) {
                dispatchEditorActionResult(editorCore.setViewport(getWidth(), getHeight()));
            }
        });
    }

    @Override
    public InputMethodRequests getInputMethodRequests() {
        return new InputMethodRequests() {
            @Override
            public Rectangle getTextLocation(TextHitInfo offset) {
                ensureRenderModelUpToDate();
                if (renderModel != null && renderModel.cursor != null) {
                    Point p = getLocationOnScreen();
                    return new Rectangle(
                            p.x + (int) renderModel.cursor.position.x,
                            p.y + (int) renderModel.cursor.position.y,
                            0, (int) renderModel.cursor.height);
                }
                Point p = getLocationOnScreen();
                return new Rectangle(p.x, p.y, 0, 20);
            }

            @Override
            public TextHitInfo getLocationOffset(int x, int y) {
                return null;
            }

            @Override
            public int getInsertPositionOffset() {
                ImeInputContext context = editorCore.getImeCommandInputContext(0, 0);
                return context.documentStartOffset + context.selection.start;
            }

            @Override
            public AttributedCharacterIterator getCommittedText(int beginIndex, int endIndex, AttributedCharacterIterator.Attribute[] attributes) {
                String text = getDocumentTextForInputMethod();
                int start = clampTextOffset(beginIndex, text.length());
                int end = clampTextOffset(endIndex, text.length());
                if (end < start) {
                    end = start;
                }
                return new AttributedString(text.substring(start, end)).getIterator();
            }

            @Override
            public int getCommittedTextLength() {
                return getDocumentTextForInputMethod().length();
            }

            @Override
            public AttributedCharacterIterator cancelLatestCommittedText(AttributedCharacterIterator.Attribute[] attributes) {
                return null;
            }

            @Override
            public AttributedCharacterIterator getSelectedText(AttributedCharacterIterator.Attribute[] attributes) {
                String selectedText = editorCore.getSelectedText();
                return selectedText == null || selectedText.isEmpty()
                        ? null
                        : new AttributedString(selectedText).getIterator();
            }
        };
    }

    private void handleComposingKeyPressed(KeyEvent e) {
        EditorActionResult result = null;
        ImeCommandMessage message = new ImeCommandMessage();
        switch (e.getKeyCode()) {
            case KeyEvent.VK_BACK_SPACE:
                message.kind = ImeCommandKind.DELETE_SURROUNDING_TEXT;
                message.deleteBefore = 1;
                message.textUnit = ImeTextUnit.GRAPHEME;
                result = editorCore.handleImeCommandMessage(message);
                break;
            case KeyEvent.VK_DELETE:
                message.kind = ImeCommandKind.DELETE_SURROUNDING_TEXT;
                message.deleteAfter = 1;
                message.textUnit = ImeTextUnit.GRAPHEME;
                result = editorCore.handleImeCommandMessage(message);
                break;
            case KeyEvent.VK_ESCAPE:
                message.kind = ImeCommandKind.CANCEL_PREEDIT;
                result = editorCore.handleImeCommandMessage(message);
                break;
            default:
                return;
        }
        e.consume();
        dispatchEditorActionResult(result);
        resetCursorBlink();
    }

    private int getComposedCaretOffset(InputMethodEvent event, int committedCount, int composedLength) {
        TextHitInfo caret = event.getCaret();
        if (caret == null) {
            return composedLength;
        }
        int insertionIndex = caret.getInsertionIndex();
        if (insertionIndex > composedLength && insertionIndex >= committedCount) {
            insertionIndex -= committedCount;
        }
        return clampTextOffset(insertionIndex, composedLength);
    }

    private String getDocumentTextForInputMethod() {
        Document document = getDocument();
        return document != null ? document.getText() : "";
    }

    private int clampTextOffset(int offset, int length) {
        return Math.max(0, Math.min(offset, length));
    }

    private void handleGesture(int type, float x, float y, int modifiers, float wheelDeltaX, float wheelDeltaY, float directScale) {
        long inputPerfStart = startInputPerf();
        try {
            float[] points = {x, y};
            EditorActionResult result = editorCore.handleGestureEvent(
                    type, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
            resetCursorBlink();
            dispatchEditorActionResult(result);
        } finally {
            finishInputPerf(getGesturePerfTag(type), inputPerfStart);
        }
    }

    // ===================== Event Dispatching =====================

    private void fireGestureEvents(EditorActionResult result, PointF locationInEditor) {
        if (result.gestureType == null) return;
        switch (result.gestureType) {
            case LONG_PRESS:
                eventBus.publish(new LongPressEvent(result.cursorAfter, locationInEditor));
                break;
            case DOUBLE_TAP:
                eventBus.publish(new DoubleTapEvent(result.cursorAfter, result.hasSelectionAfter,
                        result.selectionAfter, locationInEditor));
                break;
            case TAP:
                // Close completion panel on tap
                if (completionPopupController != null && completionPopupController.isShowing()) {
                    completionProviderManager.dismiss();
                }
                if (result.hitTarget != null) {
                    HitTargetType hitType = result.hitTarget.type;
                    switch (hitType) {
                        case INLAY_HINT_TEXT:
                        case INLAY_HINT_ICON:
                            eventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line, result.hitTarget.column,
                                    hitType == HitTargetType.INLAY_HINT_ICON ? InlayType.ICON : InlayType.TEXT,
                                    result.hitTarget.iconId,
                                    locationInEditor));
                            break;
                        case INLAY_HINT_COLOR:
                            eventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line, result.hitTarget.column,
                                    InlayType.COLOR,
                                    result.hitTarget.colorValue,
                                    locationInEditor));
                            break;
                        case GUTTER_ICON:
                            eventBus.publish(new GutterIconClickEvent(
                                    result.hitTarget.line, result.hitTarget.iconId, locationInEditor));
                            break;
                        case FOLD_PLACEHOLDER:
                        case FOLD_GUTTER:
                            eventBus.publish(new FoldToggleEvent(
                                    result.hitTarget.line,
                                    hitType == HitTargetType.FOLD_GUTTER,
                                    locationInEditor));
                            break;
                        case CODELENS:
                            eventBus.publish(new CodeLensClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    result.hitTarget.iconId,
                                    locationInEditor));
                            break;
                        case LINK:
                            eventBus.publish(new LinkClickEvent(
                                    result.hitTarget.line,
                                    result.hitTarget.column,
                                    getLinkTargetAt(result.hitTarget.line, result.hitTarget.column),
                                    locationInEditor));
                            break;
                        default:
                            break;
                    }
                }
                break;
            case SCROLL:
            case FAST_SCROLL:
                break;
            case SCALE:
                break;
            case DRAG_SELECT:
                break;
            case CONTEXT_MENU:
                eventBus.publish(new ContextMenuEvent(result.cursorAfter, locationInEditor));
                break;
        }
    }

    private void dispatchStateEvents(EditorActionResult result) {
        if (result.contentChanged) {
            dispatchTextChanged(result);
        }
        if (result.cursorChanged) {
            eventBus.publish(new CursorChangedEvent(result.cursorAfter));
        }
        if (result.selectionChanged) {
            eventBus.publish(new SelectionChangedEvent(result.hasSelectionAfter,
                    result.hasSelectionAfter ? result.selectionAfter : null,
                    result.cursorAfter));
        }
        if (result.scrollChanged) {
            handleScrollChanged(result);
        }
        if (result.scaleChanged) {
            syncPlatformScale(result.scaleAfter);
            eventBus.publish(new ScaleChangedEvent(result.scaleAfter));
        }
    }

    private void handleScrollChanged(EditorActionResult result) {
        eventBus.publish(new ScrollChangedEvent(result.scrollXAfter, result.scrollYAfter));
        decorationProviderManager.onScrollChanged();
        if (completionPopupController != null && completionPopupController.isShowing()) {
            completionProviderManager.dismiss();
        }
        if (settings.isCursorAnimationEnabled()) {
            ensureRenderModelUpToDate();
            animationHolder.cursorAnimatedX = renderModel.cursor.position.x;
            animationHolder.cursorAnimatedY = renderModel.cursor.position.y;
        }
    }

    private void applyCompletionItem(CompletionItem item) {
        boolean isSnippet = item.insertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.insertText != null ? item.insertText : item.label;

        if (item.textEdit != null) {
            text = item.textEdit.newText;
            List<TextEdit> edits = new ArrayList<>(item.additionalTextEdits.size() + 1);
            edits.add(isSnippet ? new TextEdit(item.textEdit.range, "") : item.textEdit);
            edits.addAll(item.additionalTextEdits);
            applyTextEdits(edits);
            if (isSnippet) {
                insertSnippet(text);
            }
        } else if (item.additionalTextEdits.isEmpty()) {
            if (isSnippet) {
                insertSnippet(text);
            } else {
                insertText(text);
            }
        } else {
            TextPosition cursor = getCursorPosition();
            TextEdit primaryEdit = new TextEdit(new TextRange(cursor, cursor), isSnippet ? "" : text);
            List<TextEdit> edits = new ArrayList<>(item.additionalTextEdits.size() + 1);
            edits.add(primaryEdit);
            edits.addAll(item.additionalTextEdits);
            applyTextEdits(edits);
            if (isSnippet) {
                insertSnippet(text);
            }
        }
        resetCursorBlink();
    }

    private void dispatchTextChanged(EditorActionResult result) {
        if (result != null && result.changes != null && !result.changes.isEmpty()) {
            eventBus.publish(new TextChangedEvent(result.changes, result.textChangeKind, result.source));
            decorationProviderManager.onTextChanged(result.changes);
            if (result.source == EditorActionSource.KEYBOARD && !editorCore.isInLinkedEditing()) {
                TextChange primaryChange = result.changes.get(0);
                if (completionProviderManager != null && primaryChange.newText.length() == 1) {
                    String text = primaryChange.newText;
                    if (completionProviderManager.isTriggerCharacter(text)) {
                        completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.CHARACTER, text);
                    } else if (completionPopupController != null && completionPopupController.isShowing()) {
                        completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.RETRIGGER, null);
                    }
                } else if (completionProviderManager != null
                        && completionPopupController != null
                        && completionPopupController.isShowing()) {
                    completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.RETRIGGER, null);
                }
            }
        }
    }

    void dispatchEditorActionResult(EditorActionResult result) {
        if (result == null) {
            return;
        }
        if (result.pointerCursorChanged) {
            updateMouseCursor(result.pointerCursorAfter);
        }
        if (result.gestureType != null && result.gestureType != GestureType.UNDEFINED) {
            fireGestureEvents(result, result.tapPoint);
        }
        updateAnimationTimer(result);
        dispatchStateEvents(result);
        if (result.needsRedraw) {
            flush();
        }
    }

    private boolean dispatchKeyMapCommand(int command, int keyCode, int modifiers) {
        if (keyMap == null) return false;
        EditorKeyMap.ShortcutHandler handler = keyMap.getCommand(command);
        if (handler == null) return false;
        handler.onShortcut(new KeyBinding(modifiers, keyCode, command), this);
        return true;
    }

    private void refreshPointerModifiers(KeyEvent e) {
        if (!isPointerModifierKey(e.getKeyCode())) {
            return;
        }
        dispatchEditorActionResult(editorCore.updatePointerModifiers(getModifiers(e)));
    }

    private int getModifiers(MouseEvent e) {
        int mods = 0;
        if (e.isShiftDown()) mods |= MOD_SHIFT;
        if (e.isControlDown()) mods |= MOD_CTRL;
        if (e.isAltDown()) mods |= MOD_ALT;
        if (e.isMetaDown()) mods |= MOD_META;
        return mods;
    }

    private int getModifiers(KeyEvent e) {
        int mods = 0;
        if (e.isShiftDown()) mods |= MOD_SHIFT;
        if (e.isControlDown()) mods |= MOD_CTRL;
        if (e.isAltDown()) mods |= MOD_ALT;
        if (e.isMetaDown()) mods |= MOD_META;
        return mods;
    }

    private static boolean isPointerModifierKey(int keyCode) {
        return keyCode == KeyEvent.VK_SHIFT
                || keyCode == KeyEvent.VK_CONTROL
                || keyCode == KeyEvent.VK_ALT
                || keyCode == KeyEvent.VK_META;
    }

    private static int mapKeyCode(int keyCode) {
        return switch (keyCode) {
            case KeyEvent.VK_BACK_SPACE -> KeyCode.BACKSPACE;
            case KeyEvent.VK_TAB -> KeyCode.TAB;
            case KeyEvent.VK_ENTER -> KeyCode.ENTER;
            case KeyEvent.VK_ESCAPE -> KeyCode.ESCAPE;
            case KeyEvent.VK_DELETE -> KeyCode.DELETE_KEY;
            case KeyEvent.VK_LEFT -> KeyCode.LEFT;
            case KeyEvent.VK_UP -> KeyCode.UP;
            case KeyEvent.VK_RIGHT -> KeyCode.RIGHT;
            case KeyEvent.VK_DOWN -> KeyCode.DOWN;
            case KeyEvent.VK_HOME -> KeyCode.HOME;
            case KeyEvent.VK_END -> KeyCode.END;
            case KeyEvent.VK_PAGE_UP -> KeyCode.PAGE_UP;
            case KeyEvent.VK_PAGE_DOWN -> KeyCode.PAGE_DOWN;
            default -> 0;
        };
    }

    private static int mapShortcutKeyCode(int keyCode) {
        return switch (keyCode) {
            case KeyEvent.VK_A -> KeyCode.A;
            case KeyEvent.VK_C -> KeyCode.C;
            case KeyEvent.VK_D -> KeyCode.D;
            case KeyEvent.VK_K -> KeyCode.K;
            case KeyEvent.VK_SPACE -> KeyCode.SPACE;
            case KeyEvent.VK_V -> KeyCode.V;
            case KeyEvent.VK_X -> KeyCode.X;
            case KeyEvent.VK_Y -> KeyCode.Y;
            case KeyEvent.VK_Z -> KeyCode.Z;
            default -> 0;
        };
    }

    private EditorKeyMap createDefaultKeyMap() {
        return EditorKeyMap.defaultKeyMap();
    }

    // ===================== Cursor Blink =====================

    private void setupCursorBlink() {
        cursorBlinkTimer = new Timer(530, e -> {
            cursorVisible = !cursorVisible;
            flush();
        });
        cursorBlinkTimer.start();
    }

    private void resetCursorBlink() {
        cursorVisible = true;
        if (cursorBlinkTimer != null) {
            cursorBlinkTimer.restart();
        }
    }

    private void setupCursorAnimation() {
        cursorAnimationTimer = new Timer(ANIMATION_INTERVAL_MS, e -> {
            if (renderModel == null || renderModel.cursor == null || renderModel.cursor.position == null) {
                return;
            }
            Cursor cursor = renderModel.cursor;
            PointF position = cursor.position;
            float targetX = position.x;
            float targetY = position.y;

            if (animationHolder.cursorAnimatedX == -1f || animationHolder.cursorAnimatedY == -1f) {
                animationHolder.cursorAnimatedX = targetX;
                animationHolder.cursorAnimatedY = targetY;
            }

            animationHolder.cursorAnimatedX += (targetX - animationHolder.cursorAnimatedX) * 0.35f;
            animationHolder.cursorAnimatedY += (targetY - animationHolder.cursorAnimatedY) * 0.35f;

            if (Math.abs(targetX - animationHolder.cursorAnimatedX) < 0.01f) {
                animationHolder.cursorAnimatedX = targetX;
            }

            if (Math.abs(targetY - animationHolder.cursorAnimatedY) < 0.01f) {
                animationHolder.cursorAnimatedY = targetY;
            }

            flush();
        });
        cursorAnimationTimer.setInitialDelay(530);
        cursorAnimationTimer.start();
    }

    public void requestCursorAnimationRefresh() {
        if (settings.isCursorAnimationEnabled()) {
            cursorAnimationTimer.start();
        } else {
            cursorAnimationTimer.stop();
            animationHolder.cursorAnimatedX = -1;
            animationHolder.cursorAnimatedY = -1;
        }
    }

    private void setupGutterAnimation() {
        gutterAnimationTimer = new Timer(ANIMATION_INTERVAL_MS, e -> {
            if (renderModel == null) {
                return;
            }
            float targetX = renderModel.splitX;

            if (animationHolder.splitAnimatedX == -1f) {
                animationHolder.splitAnimatedX = targetX;
            }

            animationHolder.splitAnimatedX += (targetX - animationHolder.splitAnimatedX) * 0.25f;

            if (Math.abs(targetX - animationHolder.splitAnimatedX) < 0.01f) {
                animationHolder.splitAnimatedX = targetX;
            }

            flush();
        });
        gutterAnimationTimer.setInitialDelay(530);
        gutterAnimationTimer.start();
    }

    public void requestGutterAnimationRefresh() {
        if (settings.isGutterAnimationEnabled()) {
            gutterAnimationTimer.start();
        } else {
            gutterAnimationTimer.stop();
            animationHolder.splitAnimatedX = -1f;
        }
    }

    private void setupAnimationTimer() {
        animationTimer = new Timer(ANIMATION_INTERVAL_MS, e -> {
            if (!animationActive) {
                return;
            }
            animationTimer.stop();
            EditorActionResult result = editorCore.tickAnimations();
            dispatchEditorActionResult(result);
        });
        animationTimer.setRepeats(false);
    }

    private void updateAnimationTimer(EditorActionResult result) {
        if (!result.needsAnimation()) {
            animationActive = false;
            animationTimer.stop();
            return;
        }
        animationActive = true;
        int delayMs = result.nextAnimationDelayMs <= 0
                ? ANIMATION_INTERVAL_MS
                : result.nextAnimationDelayMs;
        animationTimer.setInitialDelay(Math.max(1, delayMs));
        animationTimer.restart();
    }

    // ===================== Helpers =====================

    void syncPlatformScale(float scale) {
        renderer.syncPlatformScale(scale);
        setFont(renderer.getRegularFont());
        fontMetricsDirty = true;
        renderModelDirty = true;
    }

    void updateFonts(String fontFamily, float textSize) {
        renderer.updateFonts(fontFamily, textSize);
        setFont(renderer.getRegularFont());
        fontMetricsDirty = false;
        dispatchEditorActionResult(editorCore.onFontMetricsChanged());
    }


    private void ensureRenderModelUpToDate() {
        if (!renderModelDirty) {
            return;
        }
        PerfStepRecorder buildPerf = renderer.isPerfOverlayEnabled() ? PerfStepRecorder.start() : null;
        if (fontMetricsDirty) {
            dispatchEditorActionResult(editorCore.onFontMetricsChanged());
            fontMetricsDirty = false;
        }
        if (buildPerf != null) {
            buildPerf.mark(PerfStepRecorder.STEP_PREP);
            renderer.getMeasurePerfStats().reset();
        }
        renderModel = editorCore.buildRenderModel();
        renderModelDirty = false;
        if (renderModel != null) {
            updateMouseCursor(renderModel.pointerCursorType);
        }
        if (buildPerf != null) {
            buildPerf.mark(PerfStepRecorder.STEP_BUILD);
            buildPerf.finish();
            renderer.getPerfOverlay().recordBuild(buildPerf, renderer.getMeasurePerfStats().buildSummary());
        }
    }

    private void updateMouseCursor(PointerCursorType pointerCursorType) {
        int awtCursor;
        switch (pointerCursorType) {
            case HAND:
                awtCursor = HAND_CURSOR;
                break;
            case DEFAULT:
                awtCursor = DEFAULT_CURSOR;
                break;
            default:
                awtCursor = TEXT_CURSOR;
                break;
        }
        setCursor(getPredefinedCursor(awtCursor));
    }

    private void updateCompletionPopupCursorAnchor() {
        if (renderModel != null && completionPopupController != null
                && renderModel.cursor != null && renderModel.cursor.position != null) {
            completionPopupController.updateCursorPosition(
                    renderModel.cursor.position.x, renderModel.cursor.position.y, renderModel.cursor.height);
        }
    }

    private void updateInlineSuggestionPosition() {
        if (renderModel != null && inlineSuggestionController != null
                && inlineSuggestionController.isShowing()
                && renderModel.cursor != null && renderModel.cursor.position != null) {
            inlineSuggestionController.updatePosition(
                    renderModel.cursor.position.x, renderModel.cursor.position.y, renderModel.cursor.height);
        }
    }

    private long startInputPerf() {
        return renderer.isPerfOverlayEnabled() ? System.nanoTime() : 0L;
    }

    private void finishInputPerf(String tag, long startNanos) {
        if (startNanos == 0L) {
            return;
        }
        float elapsedMs = (System.nanoTime() - startNanos) / 1_000_000f;
        renderer.getPerfOverlay().recordInput(tag, elapsedMs);
    }

    private static String getGesturePerfTag(int type) {
        return switch (type) {
            case MOUSE_DOWN -> "mouseDown";
            case MOUSE_MOVE -> "mouseMove";
            case MOUSE_UP -> "mouseUp";
            case MOUSE_WHEEL -> "mouseWheel";
            case MOUSE_RIGHT_DOWN -> "mouseRightDown";
            default -> "gesture";
        };
    }

    private static boolean isPrimaryButtonDown(MouseEvent e) {
        return (e.getModifiersEx() & InputEvent.BUTTON1_DOWN_MASK) != 0;
    }

    private void ensurePrimaryMouseDown(MouseEvent e) {
        if (primaryMouseDown) {
            return;
        }
        primaryMouseDown = true;
        handleGesture(MOUSE_DOWN, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
    }

}
