package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.completion.*;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.EditorNative;
import com.qiplat.sweeteditor.core.EditorOptions;
import com.qiplat.sweeteditor.core.adornment.*;
import com.qiplat.sweeteditor.core.foundation.*;
import com.qiplat.sweeteditor.core.visual.*;
import com.qiplat.sweeteditor.core.snippet.*;
import com.qiplat.sweeteditor.decoration.DecorationProvider;
import com.qiplat.sweeteditor.decoration.DecorationProviderManager;
import com.qiplat.sweeteditor.newline.NewLineAction;
import com.qiplat.sweeteditor.newline.NewLineActionProvider;
import com.qiplat.sweeteditor.newline.NewLineActionProviderManager;
import com.qiplat.sweeteditor.newline.NewLineContext;
import com.qiplat.sweeteditor.event.*;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.font.FontRenderContext;
import java.awt.font.LineMetrics;
import java.awt.geom.*;
import java.awt.im.InputMethodRequests;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.List;
import java.util.Map;

/**
 * SweetEditor Swing editor component.
 * <p>
 * Based on {@link EditorCore} C++ engine providing code editing, syntax highlighting, code folding, InlayHint, etc.
 */
public class SweetEditor extends JPanel implements EditorCore.TextMeasureCallback {

    /**
     * Editor icon provider interface.
     * Platform-side implements this interface to provide icon Image for gutter icons and InlayHint ICON type rendering.
     */
    public interface EditorIconProvider {
        /**
         * Return the corresponding Image for the given icon ID.
         *
         * @param iconId Icon ID (passed by setLineGutterIcons / InlayHint.iconId)
         * @return Icon Image, return null to skip rendering
         */
        Image getIconImage(int iconId);
    }

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
    private static final float SCROLLBAR_THICKNESS = 10.0f;
    private static final float SCROLLBAR_MIN_THUMB = 24.0f;

    private EditorCore editorCore;
    private EditorTheme currentTheme;
    private EditorRenderModel renderModel;
    private EditorIconProvider editorIconProvider;

    private Font regularFont;
    private Font boldFont;
    private Font italicFont;
    private Font boldItalicFont;
    private Font inlayHintFont;
    private Font inlayHintBoldFont;
    private Font inlayHintItalicFont;
    private Font inlayHintBoldItalicFont;
    private final Font baseRegularFont;
    private final Font baseInlayHintFont;

    private Timer cursorBlinkTimer;
    private boolean cursorVisible = true;
    private int currentDrawingLineNumber = -1;
    private ScrollMetrics scrollMetrics;
    private final Rectangle2D.Float verticalScrollbarTrack = new Rectangle2D.Float();
    private final Rectangle2D.Float verticalScrollbarThumb = new Rectangle2D.Float();
    private final Rectangle2D.Float horizontalScrollbarTrack = new Rectangle2D.Float();
    private final Rectangle2D.Float horizontalScrollbarThumb = new Rectangle2D.Float();
    private boolean draggingVerticalScrollbar = false;
    private boolean draggingHorizontalScrollbar = false;
    private float scrollbarDragStartMouseX = 0;
    private float scrollbarDragStartMouseY = 0;
    private float scrollbarDragStartScrollX = 0;
    private float scrollbarDragStartScrollY = 0;
    private float scrollbarDragTravelX = 0;
    private float scrollbarDragTravelY = 0;
    private float scrollbarDragMaxScrollX = 0;
    private float scrollbarDragMaxScrollY = 0;

    // Event bus
    private final EditorEventBus eventBus = new EditorEventBus();
    private final DecorationProviderManager decorationProviderManager = new DecorationProviderManager(this);
    private CompletionProviderManager completionProviderManager;
    private CompletionPopupController completionPopupController;
    private NewLineActionProviderManager newLineActionProviderManager;
    private LanguageConfiguration languageConfiguration;
    private EditorMetadata metadata;

    public SweetEditor() {
        this(EditorTheme.dark());
    }

    public SweetEditor(EditorTheme theme) {
        this.currentTheme = theme;
        setFocusable(true);
        setFocusTraversalKeysEnabled(false);
        setDoubleBuffered(true);

        baseRegularFont = findMonospaceFont(14);
        baseInlayHintFont = new Font("SansSerif", Font.PLAIN, 12);
        syncPlatformScale(1.0f);

        editorCore = new EditorCore(this, new EditorOptions(20.0f, 300));

        // Completion manager and popup controller
        completionProviderManager = new CompletionProviderManager(this);
        completionPopupController = new CompletionPopupController(this);
        completionProviderManager.setListener(completionPopupController);
        completionPopupController.setConfirmListener(this::applyCompletionItem);

        for (var entry : currentTheme.syntaxStyles.entrySet()) {
            int[] v = entry.getValue();
            editorCore.registerStyle(entry.getKey(), v[0], v[1]);
        }

        setBackground(argbToColor(currentTheme.backgroundColor));
        setupEventListeners();
        setupCursorBlink();
        enableInputMethods(true);
    }

    // ==================== Document Loading ====================

    public void loadDocument(Document document) {
        editorCore.loadDocument(document);
        decorationProviderManager.onDocumentLoaded();
        eventBus.publish(new DocumentLoadedEvent());
        flush();
    }

    public Document getDocument() { return editorCore.getDocument(); }

    // ==================== Viewport/Font/Appearance Configuration ====================

    public EditorTheme getEditorTheme() { return currentTheme; }

    public void applyTheme(EditorTheme theme) {
        this.currentTheme = theme;
        setBackground(argbToColor(theme.backgroundColor));
        for (var entry : theme.syntaxStyles.entrySet()) {
            int[] v = entry.getValue();
            editorCore.registerStyle(entry.getKey(), v[0], v[1]);
        }
        flush();
    }

    public void setFoldArrowMode(FoldArrowMode mode) { editorCore.setFoldArrowMode(mode.value); }
    public void setWrapMode(WrapMode mode) { editorCore.setWrapMode(mode.value); flush(); }
    public void setLineSpacing(float add, float mult) { editorCore.setLineSpacing(add, mult); flush(); }
    public void setScale(float scale) {
        editorCore.setScale(scale);
        syncPlatformScale(scale);
        flush();
    }

    public EditorCore getEditorCore() { return editorCore; }

    public int[] getVisibleLineRange() {
        EditorRenderModel model = editorCore.buildRenderModel();
        if (model == null || model.lines == null || model.lines.isEmpty()) {
            return new int[]{0, -1};
        }
        int start = Integer.MAX_VALUE;
        int end = -1;
        for (VisualLine line : model.lines) {
            if (line.logicalLine < start) start = line.logicalLine;
            if (line.logicalLine > end) end = line.logicalLine;
        }
        if (start == Integer.MAX_VALUE) start = 0;
        return new int[]{start, end};
    }

    public int getTotalLineCount() {
        Document doc = editorCore.getDocument();
        return doc == null ? -1 : doc.getLineCount();
    }

    // ==================== Text Editing ====================

    public void insertText(String text) {
        TextEditResult result = editorCore.insertText(text);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
    }
    public TextEditResult replaceText(TextRange range, String newText) {
        TextEditResult result = editorCore.replaceText(range, newText);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult deleteText(TextRange range) {
        TextEditResult result = editorCore.deleteText(range);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }

    // ==================== Line Operations ====================

    public TextEditResult moveLineUp() {
        TextEditResult result = editorCore.moveLineUp();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult moveLineDown() {
        TextEditResult result = editorCore.moveLineDown();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult copyLineUp() {
        TextEditResult result = editorCore.copyLineUp();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult copyLineDown() {
        TextEditResult result = editorCore.copyLineDown();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult deleteLine() {
        TextEditResult result = editorCore.deleteLine();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult insertLineAbove() {
        TextEditResult result = editorCore.insertLineAbove();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public TextEditResult insertLineBelow() {
        TextEditResult result = editorCore.insertLineBelow();
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }

    // ==================== Undo/Redo ====================

    public boolean undo() {
        TextEditResult result = editorCore.undo();
        if (result.changes != null && !result.changes.isEmpty()) { dispatchTextChanged(TextChangeAction.UNDO, result); flush(); return true; }
        return false;
    }
    public boolean redo() {
        TextEditResult result = editorCore.redo();
        if (result.changes != null && !result.changes.isEmpty()) { dispatchTextChanged(TextChangeAction.REDO, result); flush(); return true; }
        return false;
    }
    public boolean canUndo() { return editorCore.canUndo(); }
    public boolean canRedo() { return editorCore.canRedo(); }

    // ==================== Cursor/Selection Management ====================

    public void selectAll() { editorCore.selectAll(); flush(); }
    public String getSelectedText() { return editorCore.getSelectedText(); }
    public int[] getCursorPosition() { return editorCore.getCursorPosition(); }
    public int[] getWordRangeAtCursor() { return editorCore.getWordRangeAtCursor(); }
    public String getWordAtCursor() { return editorCore.getWordAtCursor(); }

    // ==================== Read-only Mode ====================

    public void setReadOnly(boolean readOnly) { editorCore.setReadOnly(readOnly); }
    public boolean isReadOnly() { return editorCore.isReadOnly(); }

    // ==================== Auto-indent ====================

    public void setAutoIndentMode(AutoIndentMode mode) { editorCore.setAutoIndentMode(mode.value); }
    public int getAutoIndentMode() { return editorCore.getAutoIndentMode(); }

    // ==================== Position/Coordinate Query ====================

    public CursorRect getPositionRect(int line, int column) { return editorCore.getPositionRect(line, column); }
    public CursorRect getCursorRect() { return editorCore.getCursorRect(); }

    // ==================== Scroll/Navigation ====================

    public void gotoPosition(int line, int column) { editorCore.gotoPosition(line, column); flush(); }
    public void setScroll(float scrollX, float scrollY) { editorCore.setScroll(scrollX, scrollY); flush(); }
    public ScrollMetrics getScrollMetrics() { return editorCore.getScrollMetrics(); }

    // ==================== Decoration System ====================

    // -------------------- Style Registration + Highlight Spans --------------------

    public void registerStyle(int styleId, int color, int bgColor, int fontStyle) { editorCore.registerStyle(styleId, color, bgColor, fontStyle); }
    public void registerStyle(int styleId, int color, int fontStyle) { editorCore.registerStyle(styleId, color, fontStyle); }
    public void setLineSpans(int line, int layer, List<? extends StyleSpan> spans) { editorCore.setLineSpans(line, layer, spans); }
    public void setBatchLineSpans(int layer, Map<Integer, ? extends List<? extends StyleSpan>> spansByLine) { editorCore.setBatchLineSpans(layer, spansByLine); }

    // -------------------- InlayHint / PhantomText --------------------

    public void setLineInlayHints(int line, List<? extends InlayHint> hints) { editorCore.setLineInlayHints(line, hints); }
    public void setBatchLineInlayHints(Map<Integer, ? extends List<? extends InlayHint>> hintsByLine) { editorCore.setBatchLineInlayHints(hintsByLine); }
    public void setLinePhantomTexts(int line, List<? extends PhantomText> phantoms) { editorCore.setLinePhantomTexts(line, phantoms); }
    public void setBatchLinePhantomTexts(Map<Integer, ? extends List<? extends PhantomText>> phantomsByLine) { editorCore.setBatchLinePhantomTexts(phantomsByLine); }

    // -------------------- Gutter Icons --------------------

    public void setLineGutterIcons(int line, List<? extends GutterIcon> icons) { editorCore.setLineGutterIcons(line, icons); }
    public void setBatchLineGutterIcons(Map<Integer, ? extends List<? extends GutterIcon>> iconsByLine) { editorCore.setBatchLineGutterIcons(iconsByLine); }
    public void setMaxGutterIcons(int count) { editorCore.setMaxGutterIcons(count); }

    // -------------------- Diagnostic Decorations --------------------

    public void setLineDiagnostics(int line, List<? extends DiagnosticItem> items) { editorCore.setLineDiagnostics(line, items); }
    public void setBatchLineDiagnostics(Map<Integer, ? extends List<? extends DiagnosticItem>> diagsByLine) { editorCore.setBatchLineDiagnostics(diagsByLine); }

    // -------------------- Guide (Code Structure Lines) --------------------

    public void setIndentGuides(List<? extends IndentGuide> guides) { editorCore.setIndentGuides(guides); }
    public void setBracketGuides(List<? extends BracketGuide> guides) { editorCore.setBracketGuides(guides); }
    public void setFlowGuides(List<? extends FlowGuide> guides) { editorCore.setFlowGuides(guides); }
    public void setSeparatorGuides(List<? extends SeparatorGuide> guides) { editorCore.setSeparatorGuides(guides); }

    // -------------------- Fold (Code Folding) --------------------

    public void setFoldRegions(List<? extends FoldRegion> regions) { editorCore.setFoldRegions(regions); }
    public boolean toggleFold(int line) { boolean r = editorCore.toggleFold(line); if (r) flush(); return r; }
    public void foldAll() { editorCore.foldAll(); flush(); }
    public void unfoldAll() { editorCore.unfoldAll(); flush(); }

    // -------------------- Linked Editing --------------------

    public TextEditResult insertSnippet(String snippetTemplate) {
        TextEditResult result = editorCore.insertSnippet(snippetTemplate);
        dispatchTextChanged(TextChangeAction.INSERT, result);
        flush();
        return result;
    }
    public void startLinkedEditing(LinkedEditingModel model) { editorCore.startLinkedEditing(model); flush(); }
    public boolean isInLinkedEditing() { return editorCore.isInLinkedEditing(); }
    public boolean linkedEditingNext() { boolean r = editorCore.linkedEditingNext(); flush(); return r; }
    public boolean linkedEditingPrev() { boolean r = editorCore.linkedEditingPrev(); flush(); return r; }
    public void cancelLinkedEditing() { editorCore.cancelLinkedEditing(); flush(); }

    // -------------------- Clear Decorations --------------------

    public void clearHighlights() { editorCore.clearHighlights(); }
    public void clearHighlights(com.qiplat.sweeteditor.core.adornment.SpanLayer layer) { editorCore.clearHighlights(layer.value); }
    public void clearInlayHints() { editorCore.clearInlayHints(); }
    public void clearPhantomTexts() { editorCore.clearPhantomTexts(); }
    public void clearGutterIcons() { editorCore.clearGutterIcons(); }
    public void clearGuides() { editorCore.clearGuides(); }
    public void clearDiagnostics() { editorCore.clearDiagnostics(); }
    public void clearAllDecorations() { editorCore.clearAllDecorations(); }

    // ==================== View Layer Extension Configuration ====================

    public void setLanguageConfiguration(LanguageConfiguration config) {
        this.languageConfiguration = config;
        if (config != null && !config.getBrackets().isEmpty()) {
            int size = config.getBrackets().size();
            int[] opens = new int[size];
            int[] closes = new int[size];
            for (int i = 0; i < size; i++) {
                LanguageConfiguration.BracketPair pair = config.getBrackets().get(i);
                opens[i] = pair.open.isEmpty() ? 0 : pair.open.codePointAt(0);
                closes[i] = pair.close.isEmpty() ? 0 : pair.close.codePointAt(0);
            }
            editorCore.setBracketPairs(opens, closes);
        }
    }
    public LanguageConfiguration getLanguageConfiguration() { return languageConfiguration; }

    public <T extends EditorMetadata> void setMetadata(T metadata) { this.metadata = metadata; }

    @SuppressWarnings("unchecked")
    public <T extends EditorMetadata> T getMetadata() { return (T) metadata; }

    /**
     * Set the editor icon provider.
     *
     * @param provider Icon provider, pass null to remove
     */
    public void setEditorIconProvider(EditorIconProvider provider) {
        this.editorIconProvider = provider;
    }

    /**
     * Get the current editor icon provider.
     */
    public EditorIconProvider getEditorIconProvider() {
        return editorIconProvider;
    }

    // ==================== Extension Provider API ====================

    public void addDecorationProvider(DecorationProvider provider) { decorationProviderManager.addProvider(provider); }
    public void removeDecorationProvider(DecorationProvider provider) { decorationProviderManager.removeProvider(provider); }
    public void requestDecorationRefresh() { decorationProviderManager.requestRefresh(); }

    public void addCompletionProvider(CompletionProvider provider) {
        if (completionProviderManager != null) completionProviderManager.addProvider(provider);
    }

    public void removeCompletionProvider(CompletionProvider provider) {
        if (completionProviderManager != null) completionProviderManager.removeProvider(provider);
    }

    public void triggerCompletion() {
        if (completionProviderManager != null)
            completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.INVOKED, null);
    }

    public void showCompletionItems(java.util.List<CompletionItem> items) {
        if (completionProviderManager != null) completionProviderManager.showItems(items);
    }

    public void dismissCompletion() {
        if (completionProviderManager != null) completionProviderManager.dismiss();
    }

    public void setCompletionCellRenderer(CompletionCellRenderer renderer) {
        if (completionPopupController != null) completionPopupController.setCellRenderer(renderer);
    }

    public void addNewLineActionProvider(NewLineActionProvider provider) {
        if (newLineActionProviderManager == null) {
            newLineActionProviderManager = new NewLineActionProviderManager();
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

    // ===================== TextMeasureCallback =====================

    @Override
    public float measureTextWidth(MemorySegment textPtr, int fontStyle) {
        String text = EditorNative.readUtf16String(textPtr);
        if (text == null || text.isEmpty()) return 0f;
        Font font = getFontByStyle(fontStyle);
        FontRenderContext frc = getFontRenderContext();
        return (float) font.getStringBounds(text, frc).getWidth();
    }

    @Override
    public float measureInlayHintWidth(MemorySegment textPtr) {
        String text = EditorNative.readUtf16String(textPtr);
        if (text == null || text.isEmpty()) return 0f;
        FontRenderContext frc = getFontRenderContext();
        return (float) inlayHintFont.getStringBounds(text, frc).getWidth();
    }

    @Override
    public float measureIconWidth(int iconId) {
        FontRenderContext frc = getFontRenderContext();
        LineMetrics lm = regularFont.getLineMetrics("M", frc);
        return lm.getAscent() + lm.getDescent();
    }

    @Override
    public void getFontMetrics(MemorySegment arrPtr, long length) {
        FontRenderContext frc = getFontRenderContext();
        LineMetrics lm = regularFont.getLineMetrics("M", frc);
        float ascent = lm.getAscent();
        float descent = lm.getDescent();
        arrPtr.reinterpret(length * 4).set(ValueLayout.JAVA_FLOAT, 0, -ascent);
        arrPtr.reinterpret(length * 4).set(ValueLayout.JAVA_FLOAT, 4, descent);
    }

    private FontRenderContext getFontRenderContext() {
        Graphics2D g2 = (Graphics2D) getGraphics();
        if (g2 != null) {
            FontRenderContext frc = g2.getFontRenderContext();
            g2.dispose();
            return frc;
        }
        return new FontRenderContext(null, true, true);
    }

    // ===================== Painting =====================

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2 = (Graphics2D) g;
        g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_LCD_HRGB);
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);

        g2.setColor(argbToColor(currentTheme.backgroundColor));
        g2.fillRect(0, 0, getWidth(), getHeight());

        if (renderModel == null) return;

        drawCurrentLineHighlight(g2, renderModel, getWidth());
        drawSelectionRects(g2, renderModel);
        drawLines(g2, renderModel);
        drawGuideSegments(g2, renderModel);
        if (renderModel.compositionDecoration != null && renderModel.compositionDecoration.active) {
            drawCompositionDecoration(g2, renderModel.compositionDecoration);
        }
        drawDiagnosticDecorations(g2, renderModel);
        drawLinkedEditingRects(g2, renderModel);
        drawBracketHighlightRects(g2, renderModel);
        drawCursor(g2, renderModel);
        drawGutterOverlay(g2, renderModel);
        drawLineNumbers(g2, renderModel);
        drawScrollbars(g2);

        // Completion panel cursor following
        if (completionPopupController != null && renderModel.cursor != null && renderModel.cursor.position != null) {
            completionPopupController.updateCursorPosition(
                    renderModel.cursor.position.x, renderModel.cursor.position.y, renderModel.cursor.height);
        }
    }

    private static Font findMonospaceFont(int size) {
        String[] candidates = {
            "JetBrains Mono", "Menlo", "SF Mono", "Consolas",
            "Fira Code", "Source Code Pro", "DejaVu Sans Mono",
            "Liberation Mono", "Courier New", Font.MONOSPACED
        };
        java.util.Set<String> available = new java.util.HashSet<>(
            java.util.Arrays.asList(java.awt.GraphicsEnvironment
                .getLocalGraphicsEnvironment().getAvailableFontFamilyNames()));
        for (String name : candidates) {
            if (available.contains(name)) {
                return new Font(name, Font.PLAIN, size);
            }
        }
        return new Font(Font.MONOSPACED, Font.PLAIN, size);
    }

    private Font getFontByStyle(int fontStyle) {
        boolean bold = (fontStyle & FontStyle.BOLD) != 0;
        boolean italic = (fontStyle & FontStyle.ITALIC) != 0;
        if (bold && italic) return boldItalicFont;
        if (bold) return boldFont;
        if (italic) return italicFont;
        return regularFont;
    }

    private Font getInlayHintFontByStyle(int fontStyle) {
        boolean bold = (fontStyle & FontStyle.BOLD) != 0;
        boolean italic = (fontStyle & FontStyle.ITALIC) != 0;
        if (bold && italic) return inlayHintBoldItalicFont;
        if (bold) return inlayHintBoldFont;
        if (italic) return inlayHintItalicFont;
        return inlayHintFont;
    }

    private float getFontAscent(Graphics2D g, Font font) {
        java.awt.FontMetrics fm = g.getFontMetrics(font);
        return fm.getAscent();
    }

    private float getFontHeight(Graphics2D g, Font font) {
        java.awt.FontMetrics fm = g.getFontMetrics(font);
        return fm.getAscent() + fm.getDescent();
    }

    private int getTextWidth(Graphics2D g, String text, Font font) {
        if (text == null || text.isEmpty()) return 0;
        return g.getFontMetrics(font).stringWidth(text);
    }

    // ---- Drawing methods ----

    private void drawCurrentLineHighlight(Graphics2D g, EditorRenderModel model, float width) {
        if (model.lines == null || model.lines.isEmpty()) return;
        float lineH = model.cursor != null && model.cursor.height > 0 ? model.cursor.height : getFontHeight(g, regularFont);
        g.setColor(argbToColor(currentTheme.currentLineColor));
        g.fillRect(0, (int) model.currentLine.y, (int) width, (int) lineH);
    }

    private void drawSelectionRects(Graphics2D g, EditorRenderModel model) {
        if (model.selectionRects == null || model.selectionRects.isEmpty()) return;
        g.setColor(argbToColor(currentTheme.selectionColor));
        for (SelectionRect r : model.selectionRects) {
            g.fillRect((int) r.origin.x, (int) r.origin.y, (int) r.width, (int) r.height);
        }
    }

    private void drawLines(Graphics2D g, EditorRenderModel model) {
        if (model.lines == null) return;
        for (VisualLine line : model.lines) {
            if (line.runs == null) continue;
            for (VisualRun run : line.runs) {
                drawVisualRun(g, run);
            }
        }
    }

    private void drawVisualRun(Graphics2D g, VisualRun run) {
        String text = run.text;
        boolean hasText = text != null && !text.isEmpty();
        if (!hasText && run.type != VisualRunType.INLAY_HINT) return;

        Font font = (run.type == VisualRunType.INLAY_HINT)
                ? getInlayHintFontByStyle(run.style != null ? run.style.fontStyle : 0)
                : getFontByStyle(run.style != null ? run.style.fontStyle : 0);

        Color color = (run.style != null && run.style.color != 0)
                ? argbToColor(run.style.color)
                : argbToColor(currentTheme.textColor);

        float ascent = getFontAscent(g, font);
        float topY = run.y - ascent;
        float fontHeight = getFontHeight(g, font);

        if (run.type == VisualRunType.FOLD_PLACEHOLDER) {
            float mgn = run.margin;
            float bgLeft = run.x + mgn;
            float bgWidth = run.width - mgn * 2;
            float radius = fontHeight * 0.2f;
            g.setColor(argbToColor(currentTheme.foldPlaceholderBgColor));
            g.fill(new RoundRectangle2D.Float(bgLeft, topY, bgWidth, fontHeight, radius * 2, radius * 2));
            if (hasText) {
                float textX = run.x + mgn + run.padding;
                g.setColor(argbToColor(currentTheme.foldPlaceholderTextColor));
                g.setFont(font);
                g.drawString(text, textX, run.y);
            }
        } else if (run.type == VisualRunType.INLAY_HINT) {
            float mgn = run.margin;
            float bgLeft = run.x + mgn;
            float bgWidth = run.width - mgn * 2;

            if (run.colorValue != 0) {
                // COLOR type: solid color block, no rounded corners
                float blockSize = fontHeight;
                g.setColor(argbToColor(run.colorValue));
                g.fillRect((int) (run.x + mgn), (int) topY, (int) blockSize, (int) blockSize);
            } else {
                // TEXT / ICON type: rounded background + content
                float radius = fontHeight * 0.2f;
                g.setColor(argbToColor(currentTheme.inlayHintBgColor));
                g.fill(new RoundRectangle2D.Float(bgLeft, topY, bgWidth, fontHeight, radius * 2, radius * 2));
                if (hasText) {
                    float textX = run.x + mgn + run.padding;
                    g.setColor(color);
                    g.setFont(font);
                    g.drawString(text, textX, run.y);
                }
            }
        } else {
            // Normal text / whitespace / phantom text
            if (run.style != null && run.style.backgroundColor != 0) {
                g.setColor(argbToColor(run.style.backgroundColor));
                g.fillRect((int) run.x, (int) topY, (int) Math.ceil(run.width), (int) Math.ceil(fontHeight));
            }
            if (hasText) {
                Color drawColor = (run.type == VisualRunType.PHANTOM_TEXT)
                        ? argbToColor(currentTheme.phantomTextColor)
                        : color;
                g.setColor(drawColor);
                g.setFont(font);
                g.drawString(text, run.x, run.y);
            }
        }

        // Strikethrough
        if (run.style != null && (run.style.fontStyle & FontStyle.STRIKETHROUGH) != 0) {
            float strikeY = topY + ascent * 0.5f;
            g.setColor(color);
            g.setStroke(new BasicStroke(1f));
            g.drawLine((int) run.x, (int) strikeY, (int) (run.x + run.width), (int) strikeY);
        }
    }

    private void drawGutterOverlay(Graphics2D g, EditorRenderModel model) {
        if (model.splitX <= 0) return;
        g.setColor(argbToColor(currentTheme.backgroundColor));
        g.fillRect(0, 0, (int) model.splitX, getHeight());
        drawCurrentLineHighlight(g, model, model.splitX);
        g.setColor(argbToColor(currentTheme.splitLineColor));
        g.drawLine((int) model.splitX, 0, (int) model.splitX, getHeight());
    }

    private void drawLineNumbers(Graphics2D g, EditorRenderModel model) {
        if (model.lines == null) return;
        currentDrawingLineNumber = -1;
        for (VisualLine line : model.lines) {
            drawLineNumber(g, line, model);
        }
    }

    private void drawScrollbars(Graphics2D g) {
        updateScrollbarGeometry();
        boolean hasVertical = verticalScrollbarTrack.width > 0 && verticalScrollbarTrack.height > 0;
        boolean hasHorizontal = horizontalScrollbarTrack.width > 0 && horizontalScrollbarTrack.height > 0;
        if (!hasVertical && !hasHorizontal) {
            return;
        }

        Color trackColor = withAlpha(currentTheme.splitLineColor, 72);
        Color thumbColor = withAlpha(currentTheme.lineNumberColor, 170);
        Color activeThumbColor = withAlpha(currentTheme.lineNumberColor, 220);

        if (hasVertical) {
            g.setColor(trackColor);
            g.fill(verticalScrollbarTrack);
            g.setColor(draggingVerticalScrollbar ? activeThumbColor : thumbColor);
            g.fill(new RoundRectangle2D.Float(
                    verticalScrollbarThumb.x,
                    verticalScrollbarThumb.y,
                    verticalScrollbarThumb.width,
                    verticalScrollbarThumb.height,
                    SCROLLBAR_THICKNESS,
                    SCROLLBAR_THICKNESS));
        }

        if (hasHorizontal) {
            g.setColor(trackColor);
            g.fill(horizontalScrollbarTrack);
            g.setColor(draggingHorizontalScrollbar ? activeThumbColor : thumbColor);
            g.fill(new RoundRectangle2D.Float(
                    horizontalScrollbarThumb.x,
                    horizontalScrollbarThumb.y,
                    horizontalScrollbarThumb.width,
                    horizontalScrollbarThumb.height,
                    SCROLLBAR_THICKNESS,
                    SCROLLBAR_THICKNESS));
        }

        if (hasVertical && hasHorizontal) {
            g.setColor(trackColor);
            g.fillRect(
                    (int) verticalScrollbarTrack.x,
                    (int) horizontalScrollbarTrack.y,
                    (int) verticalScrollbarTrack.width,
                    (int) horizontalScrollbarTrack.height);
        }
    }

    private void updateScrollbarGeometry() {
        if (scrollMetrics == null) {
            resetScrollbarRects();
            return;
        }

        float width = getWidth();
        float height = getHeight();
        if (width <= 0 || height <= 0) {
            resetScrollbarRects();
            return;
        }

        boolean showVertical = scrollMetrics.canScrollY();
        boolean showHorizontal = scrollMetrics.canScrollX();

        float verticalTrackX = width - SCROLLBAR_THICKNESS;
        float verticalTrackHeight = height - (showHorizontal ? SCROLLBAR_THICKNESS : 0.0f);
        if (showVertical && verticalTrackHeight > 0.0f) {
            verticalScrollbarTrack.setRect(verticalTrackX, 0.0f, SCROLLBAR_THICKNESS, verticalTrackHeight);
            float viewport = Math.max(1.0f, scrollMetrics.viewportHeight());
            float contentSpan = Math.max(viewport, scrollMetrics.maxScrollY() + viewport);
            float thumbHeight = Math.max(SCROLLBAR_MIN_THUMB, verticalTrackHeight * viewport / contentSpan);
            thumbHeight = Math.min(thumbHeight, verticalTrackHeight);
            float travel = Math.max(0.0f, verticalTrackHeight - thumbHeight);
            float ratio = scrollMetrics.maxScrollY() <= 0.0f ? 0.0f : (scrollMetrics.scrollY() / scrollMetrics.maxScrollY());
            ratio = clamp01(ratio);
            float thumbY = travel <= 0.0f ? 0.0f : (travel * ratio);
            verticalScrollbarThumb.setRect(verticalTrackX, thumbY, SCROLLBAR_THICKNESS, thumbHeight);
        } else {
            verticalScrollbarTrack.setRect(0, 0, 0, 0);
            verticalScrollbarThumb.setRect(0, 0, 0, 0);
        }

        float horizontalTrackX = Math.max(0.0f, scrollMetrics.textAreaX());
        float horizontalTrackWidth = width - horizontalTrackX - (showVertical ? SCROLLBAR_THICKNESS : 0.0f);
        float horizontalTrackY = height - SCROLLBAR_THICKNESS;
        if (showHorizontal && horizontalTrackWidth > 0.0f && horizontalTrackY >= 0.0f) {
            horizontalScrollbarTrack.setRect(horizontalTrackX, horizontalTrackY, horizontalTrackWidth, SCROLLBAR_THICKNESS);
            float viewport = Math.max(1.0f, scrollMetrics.textAreaWidth());
            float contentSpan = Math.max(viewport, scrollMetrics.maxScrollX() + viewport);
            float thumbWidth = Math.max(SCROLLBAR_MIN_THUMB, horizontalTrackWidth * viewport / contentSpan);
            thumbWidth = Math.min(thumbWidth, horizontalTrackWidth);
            float travel = Math.max(0.0f, horizontalTrackWidth - thumbWidth);
            float ratio = scrollMetrics.maxScrollX() <= 0.0f ? 0.0f : (scrollMetrics.scrollX() / scrollMetrics.maxScrollX());
            ratio = clamp01(ratio);
            float thumbX = horizontalTrackX + (travel <= 0.0f ? 0.0f : (travel * ratio));
            horizontalScrollbarThumb.setRect(thumbX, horizontalTrackY, thumbWidth, SCROLLBAR_THICKNESS);
        } else {
            horizontalScrollbarTrack.setRect(0, 0, 0, 0);
            horizontalScrollbarThumb.setRect(0, 0, 0, 0);
        }
    }

    private void resetScrollbarRects() {
        verticalScrollbarTrack.setRect(0, 0, 0, 0);
        verticalScrollbarThumb.setRect(0, 0, 0, 0);
        horizontalScrollbarTrack.setRect(0, 0, 0, 0);
        horizontalScrollbarThumb.setRect(0, 0, 0, 0);
    }

    private static float clamp01(float value) {
        if (value < 0.0f) return 0.0f;
        if (value > 1.0f) return 1.0f;
        return value;
    }

    private static float clamp(float value, float min, float max) {
        return Math.max(min, Math.min(max, value));
    }

    private static Color withAlpha(int argb, int alpha) {
        int a = Math.max(0, Math.min(255, alpha));
        return new Color((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, a);
    }

    private void drawLineNumber(Graphics2D g, VisualLine vl, EditorRenderModel model) {
        if (vl.wrapIndex != 0 || vl.isPhantomLine) return;
        PointF pos = vl.lineNumberPosition;
        float ascent = getFontAscent(g, regularFont);
        float topY = pos.y - ascent;
        float lineHeight = getFontHeight(g, regularFont);
        int newLineNumber = vl.logicalLine + 1;

        if (newLineNumber != currentDrawingLineNumber) {
        g.setColor(argbToColor(currentTheme.lineNumberColor));
            g.setFont(regularFont);
            g.drawString(String.valueOf(newLineNumber), pos.x, pos.y);
            currentDrawingLineNumber = newLineNumber;
        }

        // Draw fold arrows
        if (vl.foldState != null && vl.foldState != FoldState.NONE) {
            float halfSize = lineHeight * 0.2f;
            float centerX = model.foldArrowX > 0 ? model.foldArrowX : model.splitX - lineHeight * 0.5f;
            float centerY = topY + lineHeight * 0.5f;

        g.setColor(argbToColor(currentTheme.lineNumberColor));
            g.setStroke(new BasicStroke(Math.max(1f, lineHeight * 0.1f), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));

            GeneralPath path = new GeneralPath();
            if (vl.foldState == FoldState.COLLAPSED) {
                path.moveTo(centerX - halfSize * 0.5f, centerY - halfSize);
                path.lineTo(centerX + halfSize * 0.5f, centerY);
                path.lineTo(centerX - halfSize * 0.5f, centerY + halfSize);
            } else {
                path.moveTo(centerX - halfSize, centerY - halfSize * 0.5f);
                path.lineTo(centerX, centerY + halfSize * 0.5f);
                path.lineTo(centerX + halfSize, centerY - halfSize * 0.5f);
            }
            g.draw(path);
        }
    }

    private void drawCursor(Graphics2D g, EditorRenderModel model) {
        if (model.cursor == null || !model.cursor.visible || !cursorVisible) return;
        g.setColor(argbToColor(currentTheme.cursorColor));
        g.fillRect((int) model.cursor.position.x, (int) model.cursor.position.y,
                2, (int) model.cursor.height);
    }

    private void drawCompositionDecoration(Graphics2D g, CompositionDecoration comp) {
        float y = comp.origin.y + comp.height;
        g.setColor(argbToColor(currentTheme.compositionUnderlineColor));
        g.setStroke(new BasicStroke(2f));
        g.drawLine((int) comp.origin.x, (int) y, (int) (comp.origin.x + comp.width), (int) y);
    }

    private void drawDiagnosticDecorations(Graphics2D g, EditorRenderModel model) {
        if (model.diagnosticDecorations == null || model.diagnosticDecorations.isEmpty()) return;
        for (DiagnosticDecoration diag : model.diagnosticDecorations) {
            Color c = diag.color != 0 ? argbToColor(diag.color) : switch (diag.severity) {
                case 0 -> argbToColor(currentTheme.diagnosticErrorColor);
                case 1 -> argbToColor(currentTheme.diagnosticWarningColor);
                case 2 -> argbToColor(currentTheme.diagnosticInfoColor);
                default -> argbToColor(currentTheme.diagnosticHintColor);
            };

            float startX = diag.origin.x;
            float endX = startX + diag.width;
            float baseY = diag.origin.y + diag.height - 1f;

            g.setColor(c);
            g.setStroke(new BasicStroke(2f));

            if (diag.severity == 3) {
                // HINT: dashed underline
                g.setStroke(new BasicStroke(2f, BasicStroke.CAP_BUTT, BasicStroke.JOIN_MITER, 10f, new float[]{3f, 2f}, 0f));
                g.drawLine((int) startX, (int) baseY, (int) endX, (int) baseY);
            } else {
                // Wavy line
                float halfWave = 7f;
                float amplitude = 3.5f;
                GeneralPath path = new GeneralPath();
                float x = startX;
                int step = 0;
                path.moveTo(x, baseY);
                while (x < endX) {
                    float nextX = Math.min(x + halfWave, endX);
                    float midX = (x + nextX) / 2f;
                    float peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude;
                    path.quadTo(midX, peakY, nextX, baseY);
                    x = nextX;
                    step++;
                }
                g.setStroke(new BasicStroke(2f));
                g.draw(path);
            }
        }
    }

    private void drawLinkedEditingRects(Graphics2D g, EditorRenderModel model) {
        if (model.linkedEditingRects == null || model.linkedEditingRects.isEmpty()) return;
        for (LinkedEditingRect rect : model.linkedEditingRects) {
            if (rect.origin == null) continue;
            if (rect.isActive) {
                // Active tab stop: semi-transparent fill + border
                g.setColor(withAlpha(currentTheme.linkedEditingActiveColor, 32));
                g.fillRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
                g.setColor(argbToColor(currentTheme.linkedEditingActiveColor));
                g.setStroke(new BasicStroke(2f));
            } else {
                // Inactive tab stop: border only
                g.setColor(argbToColor(currentTheme.linkedEditingInactiveColor));
                g.setStroke(new BasicStroke(1f));
            }
            g.drawRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
        }
    }

    private void drawBracketHighlightRects(Graphics2D g, EditorRenderModel model) {
        if (model.bracketHighlightRects == null || model.bracketHighlightRects.isEmpty()) return;
        for (BracketHighlightRect rect : model.bracketHighlightRects) {
            if (rect.origin == null) continue;
            // Background fill
            g.setColor(argbToColor(currentTheme.bracketHighlightBgColor));
            g.fillRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
            // Border
            g.setColor(argbToColor(currentTheme.bracketHighlightBorderColor));
            g.setStroke(new BasicStroke(1.5f));
            g.drawRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
        }
    }

    private void drawGuideSegments(Graphics2D g, EditorRenderModel model) {
        if (model.guideSegments == null || model.guideSegments.isEmpty()) return;
        for (GuideSegment seg : model.guideSegments) {
            Color c = argbToColor((seg.type == GuideType.SEPARATOR) ? currentTheme.separatorLineColor : currentTheme.guideColor);
            g.setColor(c);
            float lineWidth = (seg.type == GuideType.INDENT) ? 1f : 1.2f;
            g.setStroke(new BasicStroke(lineWidth));

            if (seg.arrowEnd) {
                float arrowLen = 9f;
                float arrowAngle = (float) (Math.PI * 28.0 / 180.0);
                float arrowDepth = (float) (arrowLen * Math.cos(arrowAngle));
                float dx = seg.end.x - seg.start.x;
                float dy = seg.end.y - seg.start.y;
                float len = (float) Math.sqrt(dx * dx + dy * dy);
                float trim = arrowDepth + lineWidth * 0.5f;
                if (len > trim) {
                    float ratio = (len - trim) / len;
                    float lineEndX = seg.start.x + dx * ratio;
                    float lineEndY = seg.start.y + dy * ratio;
                    g.draw(new Line2D.Float(seg.start.x, seg.start.y, lineEndX, lineEndY));
                }
                drawArrowHead(g, c, seg.start, seg.end, arrowLen, arrowAngle);
            } else {
                g.draw(new Line2D.Float(seg.start.x, seg.start.y, seg.end.x, seg.end.y));
            }
        }
    }

    private void drawArrowHead(Graphics2D g, Color color, PointF from, PointF to, float arrowLen, float arrowAngle) {
        float dx = to.x - from.x;
        float dy = to.y - from.y;
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        if (len < 1f) return;
        float ux = dx / len, uy = dy / len;
        float cosA = (float) Math.cos(arrowAngle), sinA = (float) Math.sin(arrowAngle);
        float ax1 = to.x - arrowLen * (ux * cosA - uy * sinA);
        float ay1 = to.y - arrowLen * (uy * cosA + ux * sinA);
        float ax2 = to.x - arrowLen * (ux * cosA + uy * sinA);
        float ay2 = to.y - arrowLen * (uy * cosA - ux * sinA);

        GeneralPath path = new GeneralPath();
        path.moveTo(to.x, to.y);
        path.lineTo(ax1, ay1);
        path.lineTo(ax2, ay2);
        path.closePath();
        g.setColor(color);
        g.fill(path);
    }

    // ===================== Event Handling =====================

    private void setupEventListeners() {
        addMouseListener(new MouseAdapter() {
            @Override
            public void mousePressed(MouseEvent e) {
                requestFocusInWindow();
                if (SwingUtilities.isLeftMouseButton(e) && handleScrollbarMousePressed(e)) {
                    e.consume();
                    return;
                }
                int mods = getModifiers(e);
                if (SwingUtilities.isLeftMouseButton(e)) {
                    handleGesture(MOUSE_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                } else if (SwingUtilities.isRightMouseButton(e)) {
                    handleGesture(MOUSE_RIGHT_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                }
            }

            @Override
            public void mouseReleased(MouseEvent e) {
                if (SwingUtilities.isLeftMouseButton(e) && handleScrollbarMouseReleased()) {
                    e.consume();
                    return;
                }
                if (SwingUtilities.isLeftMouseButton(e)) {
                    handleGesture(MOUSE_UP, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                }
            }
        });

        addMouseMotionListener(new MouseMotionAdapter() {
            @Override
            public void mouseDragged(MouseEvent e) {
                if (handleScrollbarMouseDragged(e)) {
                    e.consume();
                    return;
                }
                if (SwingUtilities.isLeftMouseButton(e)) {
                    handleGesture(MOUSE_MOVE, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                }
            }
        });

        addMouseWheelListener(e -> {
            float deltaY = (float) (-e.getPreciseWheelRotation() * 40);
            handleGesture(MOUSE_WHEEL, e.getX(), e.getY(), getModifiers(e), 0, deltaY, 1);
        });

        addKeyListener(new KeyAdapter() {
            @Override
            public void keyPressed(KeyEvent e) {
                if (editorCore.isComposing() && e.getKeyCode() != KeyEvent.VK_ESCAPE) return;

                // Completion panel keyboard interception
                if (completionPopupController != null && completionPopupController.isShowing()) {
                    if (completionPopupController.handleSwingKeyCode(e.getKeyCode())) {
                        e.consume();
                        return;
                    }
                }

                // Ctrl+Space / Meta+Space manually trigger completion
                if ((e.isControlDown() || e.isMetaDown()) && e.getKeyCode() == KeyEvent.VK_SPACE) {
                    triggerCompletion();
                    e.consume();
                    return;
                }

                int mods = 0;
                if (e.isShiftDown()) mods |= MOD_SHIFT;
                if (e.isControlDown()) mods |= MOD_CTRL;
                if (e.isAltDown()) mods |= MOD_ALT;
                if (e.isMetaDown()) mods |= MOD_META;

                int keyCode = mapKeyCode(e.getKeyCode());
                boolean isCtrlShortcut = (e.isControlDown() || e.isMetaDown()) && isCtrlKey(e.getKeyCode());

                // Prioritize letting NewLineActionProvider handle Enter (Provider decides indentation),
                // if no Provider or returns null then fallback to Core layer default behavior
                if (keyCode == 13 && newLineActionProviderManager != null) {
                    int[] cursor = editorCore.getCursorPosition();
                    if (cursor != null) {
                        Document doc = editorCore.getDocument();
                        String lineText = (doc != null) ? doc.getLineText(cursor[0]) : "";
                        if (lineText == null) lineText = "";
                        NewLineContext ctx = new NewLineContext(
                                cursor[0], cursor[1], lineText,
                                getLanguageConfiguration());
                        NewLineAction action = newLineActionProviderManager.provideNewLineAction(ctx);
                        if (action != null) {
                            TextEditResult editResult = editorCore.insertText(action.text);
                            e.consume();
                            dispatchTextChanged(TextChangeAction.KEY, editResult);
                            resetCursorBlink();
                            flush();
                            return;
                        }
                    }
                }

                if (keyCode != 0 || isCtrlShortcut) {
                    if (keyCode == 0 && isCtrlShortcut) keyCode = e.getKeyCode();
                    KeyEventResult result = editorCore.handleKeyEvent(keyCode, null, mods);
                    if (result != null && result.handled) {
                        e.consume();
                        dispatchKeyEventResult(result);
                        // When content changes, if completion panel is visible and not in linked editing, retrigger to refresh candidates
                        if (result.contentChanged && !editorCore.isInLinkedEditing()
                                && completionPopupController != null
                                && completionPopupController.isShowing() && completionProviderManager != null) {
                            completionProviderManager.triggerCompletion(
                                    CompletionContext.TriggerKind.RETRIGGER, null);
                        }
                        resetCursorBlink();
                        flush();
                    }
                }
            }

            @Override
            public void keyTyped(KeyEvent e) {
                if (editorCore.isComposing()) return;
                char ch = e.getKeyChar();
                if (!Character.isISOControl(ch) && ch != KeyEvent.CHAR_UNDEFINED) {
                    TextEditResult result = editorCore.insertText(String.valueOf(ch));
                    e.consume();
                    dispatchTextChanged(TextChangeAction.KEY, result);
                    // Suppress completion trigger during linked editing to avoid conflicts between completion popup and Enter/Tab keys
                    if (!editorCore.isInLinkedEditing()) {
                        String charStr = String.valueOf(ch);
                        if (completionProviderManager != null) {
                            if (completionProviderManager.isTriggerCharacter(charStr)) {
                                completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.CHARACTER, charStr);
                            } else if (completionPopupController != null && completionPopupController.isShowing()) {
                                completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.RETRIGGER, null);
                            } else if (Character.isLetterOrDigit(ch) || ch == '_') {
                                completionProviderManager.triggerCompletion(CompletionContext.TriggerKind.INVOKED, null);
                            }
                        }
                    }
                    resetCursorBlink();
                    flush();
                }
            }
        });

        addInputMethodListener(new java.awt.event.InputMethodListener() {
            @Override
            public void inputMethodTextChanged(java.awt.event.InputMethodEvent event) {
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

                if (committed.length() > 0) {
                    TextEditResult editResult;
                    if (editorCore.isComposing()) {
                        editResult = editorCore.compositionEnd(committed.toString());
                        dispatchTextChanged(TextChangeAction.COMPOSITION, editResult);
                    } else {
                        editResult = editorCore.insertText(committed.toString());
                        dispatchTextChanged(TextChangeAction.INSERT, editResult);
                    }
                    resetCursorBlink();
                    flush();
                }
                if (composed.length() > 0) {
                    if (!editorCore.isComposing()) {
                        editorCore.compositionStart();
                    }
                    editorCore.compositionUpdate(composed.toString());
                    flush();
                } else if (editorCore.isComposing() && committed.length() == 0) {
                    editorCore.compositionCancel();
                    flush();
                }

                event.consume();
            }

            @Override
            public void caretPositionChanged(java.awt.event.InputMethodEvent event) {
                event.consume();
            }
        });

        addComponentListener(new ComponentAdapter() {
            @Override
            public void componentResized(ComponentEvent e) {
                editorCore.setViewport(getWidth(), getHeight());
                flush();
            }
        });
    }

    @Override
    public InputMethodRequests getInputMethodRequests() {
        return new InputMethodRequests() {
            @Override
            public Rectangle getTextLocation(java.awt.font.TextHitInfo offset) {
                if (renderModel != null && renderModel.cursor != null) {
                    java.awt.Point p = getLocationOnScreen();
                    return new Rectangle(
                            p.x + (int) renderModel.cursor.position.x,
                            p.y + (int) renderModel.cursor.position.y,
                            0, (int) renderModel.cursor.height);
                }
                java.awt.Point p = getLocationOnScreen();
                return new Rectangle(p.x, p.y, 0, 20);
            }
            @Override public java.awt.font.TextHitInfo getLocationOffset(int x, int y) { return null; }
            @Override public int getInsertPositionOffset() { return 0; }
            @Override public AttributedCharacterIterator getCommittedText(int beginIndex, int endIndex, AttributedCharacterIterator.Attribute[] attributes) { return new AttributedString("").getIterator(); }
            @Override public int getCommittedTextLength() { return 0; }
            @Override public AttributedCharacterIterator cancelLatestCommittedText(AttributedCharacterIterator.Attribute[] attributes) { return null; }
            @Override public AttributedCharacterIterator getSelectedText(AttributedCharacterIterator.Attribute[] attributes) { return null; }
        };
    }

    private void handleGesture(int type, float x, float y, int modifiers, float wheelDeltaX, float wheelDeltaY, float directScale) {
        float[] points = {x, y};
        GestureResult result = editorCore.handleGestureEvent(type, points, modifiers, wheelDeltaX, wheelDeltaY, directScale);
        if (result != null && result.type == GestureType.SCALE) {
            // C++ core already applied scale during gesture handling; only sync platform fonts/measurer.
            syncPlatformScale(result.viewScale);
        }
        resetCursorBlink();
        flush();
        if (result != null) {
            fireGestureEvents(result, new Point((int) x, (int) y));
        }
    }

    private boolean handleScrollbarMousePressed(MouseEvent e) {
        updateScrollbarGeometry();
        float x = e.getX();
        float y = e.getY();

        if (verticalScrollbarThumb.contains(x, y)) {
            draggingVerticalScrollbar = true;
            draggingHorizontalScrollbar = false;
            scrollbarDragStartMouseY = y;
            scrollbarDragStartScrollY = scrollMetrics != null ? scrollMetrics.scrollY() : 0.0f;
            scrollbarDragTravelY = Math.max(0.0f, verticalScrollbarTrack.height - verticalScrollbarThumb.height);
            scrollbarDragMaxScrollY = scrollMetrics != null ? Math.max(0.0f, scrollMetrics.maxScrollY()) : 0.0f;
            return true;
        }

        if (horizontalScrollbarThumb.contains(x, y)) {
            draggingHorizontalScrollbar = true;
            draggingVerticalScrollbar = false;
            scrollbarDragStartMouseX = x;
            scrollbarDragStartScrollX = scrollMetrics != null ? scrollMetrics.scrollX() : 0.0f;
            scrollbarDragTravelX = Math.max(0.0f, horizontalScrollbarTrack.width - horizontalScrollbarThumb.width);
            scrollbarDragMaxScrollX = scrollMetrics != null ? Math.max(0.0f, scrollMetrics.maxScrollX()) : 0.0f;
            return true;
        }

        if (scrollMetrics != null && verticalScrollbarTrack.contains(x, y)) {
            if (verticalScrollbarTrack.height > 0.0f && scrollMetrics.maxScrollY() > 0.0f) {
                float travel = Math.max(0.0f, verticalScrollbarTrack.height - verticalScrollbarThumb.height);
                float ratio = travel <= 0.0f
                        ? 0.0f
                        : clamp01((y - verticalScrollbarTrack.y - verticalScrollbarThumb.height * 0.5f) / travel);
                float targetY = ratio * scrollMetrics.maxScrollY();
                setScrollFromScrollbar(scrollMetrics.scrollX(), targetY);
            }
            return true;
        }

        if (scrollMetrics != null && horizontalScrollbarTrack.contains(x, y)) {
            if (horizontalScrollbarTrack.width > 0.0f && scrollMetrics.maxScrollX() > 0.0f) {
                float travel = Math.max(0.0f, horizontalScrollbarTrack.width - horizontalScrollbarThumb.width);
                float ratio = travel <= 0.0f
                        ? 0.0f
                        : clamp01((x - horizontalScrollbarTrack.x - horizontalScrollbarThumb.width * 0.5f) / travel);
                float targetX = ratio * scrollMetrics.maxScrollX();
                setScrollFromScrollbar(targetX, scrollMetrics.scrollY());
            }
            return true;
        }

        return false;
    }

    private boolean handleScrollbarMouseDragged(MouseEvent e) {
        if (!draggingVerticalScrollbar && !draggingHorizontalScrollbar) {
            return false;
        }
        if (scrollMetrics == null) {
            return true;
        }

        if (draggingVerticalScrollbar) {
            float targetY = scrollbarDragStartScrollY;
            if (scrollbarDragTravelY > 0.0f && scrollbarDragMaxScrollY > 0.0f) {
                float delta = e.getY() - scrollbarDragStartMouseY;
                targetY += delta * scrollbarDragMaxScrollY / scrollbarDragTravelY;
            }
            targetY = clamp(targetY, 0.0f, scrollMetrics.maxScrollY());
            setScrollFromScrollbar(scrollMetrics.scrollX(), targetY);
            return true;
        }

        if (draggingHorizontalScrollbar) {
            float targetX = scrollbarDragStartScrollX;
            if (scrollbarDragTravelX > 0.0f && scrollbarDragMaxScrollX > 0.0f) {
                float delta = e.getX() - scrollbarDragStartMouseX;
                targetX += delta * scrollbarDragMaxScrollX / scrollbarDragTravelX;
            }
            targetX = clamp(targetX, 0.0f, scrollMetrics.maxScrollX());
            setScrollFromScrollbar(targetX, scrollMetrics.scrollY());
            return true;
        }

        return false;
    }

    private boolean handleScrollbarMouseReleased() {
        if (!draggingVerticalScrollbar && !draggingHorizontalScrollbar) {
            return false;
        }
        draggingVerticalScrollbar = false;
        draggingHorizontalScrollbar = false;
        return true;
    }

    private void setScrollFromScrollbar(float scrollX, float scrollY) {
        editorCore.setScroll(scrollX, scrollY);
        resetCursorBlink();
        flush();
        if (scrollMetrics != null) {
            eventBus.publish(new ScrollChangedEvent(scrollMetrics.scrollX(), scrollMetrics.scrollY()));
        }
        decorationProviderManager.onScrollChanged();
        if (completionPopupController != null && completionPopupController.isShowing() && completionProviderManager != null) {
            completionProviderManager.dismiss();
        }
    }

    // ===================== Event Dispatching =====================

    private void fireGestureEvents(GestureResult result, Point screenPoint) {
        if (result.type == null) return;
        switch (result.type) {
            case LONG_PRESS:
                eventBus.publish(new LongPressEvent(result.cursorPosition, screenPoint));
                eventBus.publish(new CursorChangedEvent(result.cursorPosition));
                break;
            case DOUBLE_TAP:
                eventBus.publish(new DoubleTapEvent(result.cursorPosition, result.hasSelection, result.selection, screenPoint));
                eventBus.publish(new CursorChangedEvent(result.cursorPosition));
                if (result.hasSelection) {
                    eventBus.publish(new SelectionChangedEvent(true, result.selection, result.cursorPosition));
                }
                break;
            case TAP:
                eventBus.publish(new CursorChangedEvent(result.cursorPosition));
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
                                    result.hitTarget.iconId,
                                    hitType == HitTargetType.INLAY_HINT_ICON,
                                    screenPoint));
                            break;
                        case INLAY_HINT_COLOR:
                            eventBus.publish(new InlayHintClickEvent(
                                    result.hitTarget.line, result.hitTarget.column,
                                    result.hitTarget.colorValue,
                                    screenPoint));
                            break;
                        case GUTTER_ICON:
                            eventBus.publish(new GutterIconClickEvent(
                                    result.hitTarget.line, result.hitTarget.iconId, screenPoint));
                            break;
                        case FOLD_PLACEHOLDER:
                        case FOLD_GUTTER:
                            eventBus.publish(new FoldToggleEvent(
                                    result.hitTarget.line,
                                    hitType == HitTargetType.FOLD_GUTTER,
                                    screenPoint));
                            break;
                        default:
                            break;
                    }
                }
                break;
            case SCROLL:
            case FAST_SCROLL:
                eventBus.publish(new ScrollChangedEvent(result.viewScrollX, result.viewScrollY));
                decorationProviderManager.onScrollChanged();
                // Close completion panel on scroll
                if (completionPopupController != null && completionPopupController.isShowing()) {
                    completionProviderManager.dismiss();
                }
                break;
            case SCALE:
                eventBus.publish(new ScaleChangedEvent(result.viewScale));
                break;
            case DRAG_SELECT:
                eventBus.publish(new SelectionChangedEvent(result.hasSelection, result.selection, result.cursorPosition));
                break;
            case CONTEXT_MENU:
                eventBus.publish(new ContextMenuEvent(result.cursorPosition, screenPoint));
                break;
        }
    }

    private void applyCompletionItem(CompletionItem item) {
        CompletionItem.TextEdit textEdit = item.getTextEdit();
        boolean isSnippet = item.getInsertTextFormat() == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.getInsertText() != null ? item.getInsertText() : item.getLabel();

        // Determine the range to replace: textEdit takes priority, otherwise fallback to wordRange
        TextRange replaceRange = null;
        if (textEdit != null) {
            replaceRange = textEdit.range;
            text = textEdit.newText;
        } else {
            int[] wr = getWordRangeAtCursor();
            if (wr[0] != wr[2] || wr[1] != wr[3]) {
                replaceRange = new TextRange(
                        new TextPosition(wr[0], wr[1]),
                        new TextPosition(wr[2], wr[3]));
            }
        }

        // First delete the range to replace (already typed prefix), then insert new text
        if (replaceRange != null) {
            deleteText(replaceRange);
        }
        if (isSnippet) {
            insertSnippet(text);
        } else {
            insertText(text);
        }
        resetCursorBlink();
    }

    private void dispatchTextChanged(TextChangeAction action, TextEditResult editResult) {
        if (editResult != null && editResult.changes != null && !editResult.changes.isEmpty()) {
            for (TextChange change : editResult.changes) {
                eventBus.publish(new TextChangedEvent(action, change.range, change.newText));
            }
            decorationProviderManager.onTextChanged(editResult.changes);
        } else {
            eventBus.publish(new TextChangedEvent(action, null, null));
            decorationProviderManager.onTextChanged(null);
        }
    }

    private void dispatchKeyEventResult(KeyEventResult result) {
        if (result.contentChanged) {
            if (result.editResult != null && result.editResult.changes != null && !result.editResult.changes.isEmpty()) {
                for (TextChange change : result.editResult.changes) {
                    eventBus.publish(new TextChangedEvent(TextChangeAction.KEY, change.range, change.newText));
                }
                decorationProviderManager.onTextChanged(result.editResult.changes);
            } else {
                eventBus.publish(new TextChangedEvent(TextChangeAction.KEY, null, null));
            }
        }
        if (result.cursorChanged) {
            int[] pos = editorCore.getCursorPosition();
            TextPosition cursor = new TextPosition();
            cursor.line = pos[0];
            cursor.column = pos[1];
            eventBus.publish(new CursorChangedEvent(cursor));
        }
        if (result.selectionChanged) {
            // Selection details not available from KeyEventResult; publish with current cursor
            int[] pos = editorCore.getCursorPosition();
            TextPosition cursor = new TextPosition();
            cursor.line = pos[0];
            cursor.column = pos[1];
            eventBus.publish(new SelectionChangedEvent(false, null, cursor));
        }
    }

    private int getModifiers(MouseEvent e) {
        int mods = 0;
        if (e.isShiftDown()) mods |= MOD_SHIFT;
        if (e.isControlDown()) mods |= MOD_CTRL;
        if (e.isAltDown()) mods |= MOD_ALT;
        if (e.isMetaDown()) mods |= MOD_META;
        return mods;
    }

    private static int mapKeyCode(int keyCode) {
        return switch (keyCode) {
            case KeyEvent.VK_BACK_SPACE -> 8;
            case KeyEvent.VK_TAB -> 9;
            case KeyEvent.VK_ENTER -> 13;
            case KeyEvent.VK_ESCAPE -> 27;
            case KeyEvent.VK_DELETE -> 46;
            case KeyEvent.VK_LEFT -> 37;
            case KeyEvent.VK_UP -> 38;
            case KeyEvent.VK_RIGHT -> 39;
            case KeyEvent.VK_DOWN -> 40;
            case KeyEvent.VK_HOME -> 36;
            case KeyEvent.VK_END -> 35;
            case KeyEvent.VK_PAGE_UP -> 33;
            case KeyEvent.VK_PAGE_DOWN -> 34;
            default -> 0;
        };
    }

    private static boolean isCtrlKey(int keyCode) {
        return keyCode == KeyEvent.VK_A || keyCode == KeyEvent.VK_C || keyCode == KeyEvent.VK_V
                || keyCode == KeyEvent.VK_X || keyCode == KeyEvent.VK_Z || keyCode == KeyEvent.VK_Y;
    }

    // ===================== Cursor Blink =====================

    private void setupCursorBlink() {
        cursorBlinkTimer = new Timer(530, e -> {
            cursorVisible = !cursorVisible;
            repaint();
        });
        cursorBlinkTimer.start();
    }

    private void resetCursorBlink() {
        cursorVisible = true;
        if (cursorBlinkTimer != null) {
            cursorBlinkTimer.restart();
        }
    }

    // ===================== Helpers =====================

    private void syncPlatformScale(float scale) {
        if (scale <= 0f) return;

        float textSize = baseRegularFont.getSize2D() * scale;
        regularFont = baseRegularFont.deriveFont(Font.PLAIN, textSize);
        boldFont = baseRegularFont.deriveFont(Font.BOLD, textSize);
        italicFont = baseRegularFont.deriveFont(Font.ITALIC, textSize);
        boldItalicFont = baseRegularFont.deriveFont(Font.BOLD | Font.ITALIC, textSize);

        float inlayHintSize = baseInlayHintFont.getSize2D() * scale;
        inlayHintFont = baseInlayHintFont.deriveFont(Font.PLAIN, inlayHintSize);
        inlayHintBoldFont = baseInlayHintFont.deriveFont(Font.BOLD, inlayHintSize);
        inlayHintItalicFont = baseInlayHintFont.deriveFont(Font.ITALIC, inlayHintSize);
        inlayHintBoldItalicFont = baseInlayHintFont.deriveFont(Font.BOLD | Font.ITALIC, inlayHintSize);

        setFont(regularFont);
    }

    /**
     * Flush all pending changes (decoration / layout / scroll / selection) and trigger a redraw.
     * <p>
     * Decoration setters (setLineSpans, clearHighlights, setFoldRegions, etc.) no longer
     * trigger a redraw automatically. Call this method once after a batch of decoration
     * updates to make them take effect.
     */
    public void flush() {
        editorCore.resetMeasurer();
        renderModel = editorCore.buildRenderModel();
        scrollMetrics = editorCore.getScrollMetrics();
        updateScrollbarGeometry();
        repaint();
    }

    private static Color argbToColor(int argb) {
        int a = (argb >> 24) & 0xFF;
        int r = (argb >> 16) & 0xFF;
        int g2 = (argb >> 8) & 0xFF;
        int b = argb & 0xFF;
        return new Color(r, g2, b, a);
    }
}
