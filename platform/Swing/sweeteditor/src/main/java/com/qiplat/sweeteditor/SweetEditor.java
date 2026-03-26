package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.completion.*;
import com.qiplat.sweeteditor.core.Document;
import com.qiplat.sweeteditor.core.EditorCore;
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
import com.qiplat.sweeteditor.event.*;

import javax.swing.*;
import java.awt.*;
import java.awt.event.*;
import java.awt.im.InputMethodRequests;
import java.text.AttributedCharacterIterator;
import java.text.AttributedString;
import java.util.List;
import java.util.Map;

/**
 * SweetEditor Swing editor component.
 * <p>
 * Based on {@link EditorCore} C++ engine providing code editing, syntax highlighting, code folding, InlayHint, etc.
 */
public class SweetEditor extends JPanel {
    private static final float DEFAULT_CONTENT_START_PADDING_DP = 3.0f;

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
    private EditorTheme currentTheme;
    private EditorRenderModel renderModel;
    private EditorRenderer renderer;

    private Timer cursorBlinkTimer;
    private boolean cursorVisible = true;

    // Unified animation timer: drives edge-scroll, fling, etc. at ~16ms
    private static final int ANIMATION_INTERVAL_MS = 16;
    private Timer animationTimer;
    private boolean animationActive = false;

    // Event bus
    private EditorSettings settings;
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

        renderer = new EditorRenderer(theme);

        editorCore = new EditorCore(renderer.getTextMeasureCallback(), new EditorOptions(20.0f, 300));

        // Completion manager and popup controller
        completionProviderManager = new CompletionProviderManager(this);
        completionPopupController = new CompletionPopupController(this, theme);
        completionProviderManager.setListener(completionPopupController);
        completionPopupController.setConfirmListener(this::applyCompletionItem);

        settings = new EditorSettings(this);
        settings.setContentStartPadding(dpToPx(DEFAULT_CONTENT_START_PADDING_DP));

        if (currentTheme != null && !currentTheme.textStyles.isEmpty()) {
            editorCore.registerBatchTextStyles(currentTheme.textStyles);
        }

        setBackground(currentTheme.backgroundColor);
        setFont(renderer.getRegularFont());
        setupEventListeners();
        setupCursorBlink();
        setupAnimationTimer();
        enableInputMethods(true);
    }

    private static float dpToPx(float dp) {
        return dp * getUiScale();
    }

    private static float getUiScale() {
        try {
            int dpi = Toolkit.getDefaultToolkit().getScreenResolution();
            if (dpi > 0) {
                return dpi / 96.0f;
            }
        } catch (HeadlessException ignored) {
        }
        return 1.0f;
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

    public EditorSettings getSettings() { return settings; }

    public void applyTheme(EditorTheme theme) {
        this.currentTheme = theme;
        renderer.applyTheme(theme);
        setBackground(theme.backgroundColor);
        if (theme != null && !theme.textStyles.isEmpty()) {
            editorCore.registerBatchTextStyles(theme.textStyles);
        }
        if (completionPopupController != null) {
            completionPopupController.applyTheme(theme);
        }
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



    // ==================== Position/Coordinate Query ====================

    public CursorRect getPositionRect(int line, int column) { return editorCore.getPositionRect(line, column); }
    public CursorRect getCursorRect() { return editorCore.getCursorRect(); }

    // ==================== Scroll/Navigation ====================

    public void gotoPosition(int line, int column) { editorCore.gotoPosition(line, column); flush(); }
    public void setScroll(float scrollX, float scrollY) { editorCore.setScroll(scrollX, scrollY); flush(); }
    public ScrollMetrics getScrollMetrics() { return editorCore.getScrollMetrics(); }

    // ==================== Decoration System ====================

    // -------------------- Style Registration + Highlight Spans --------------------

    public void registerTextStyle(int styleId, int color, int bgColor, int fontStyle) {
        editorCore.registerTextStyle(styleId, color, bgColor, fontStyle);
    }
    public void registerTextStyle(int styleId, int color, int fontStyle) {
        editorCore.registerTextStyle(styleId, color, fontStyle);
    }
    public void registerBatchTextStyles(Map<Integer, ? extends TextStyle> textStyles) { editorCore.registerBatchTextStyles(textStyles); }
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
        if (config != null) {
            if (!config.getBrackets().isEmpty()) {
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
            if (config.getTabSize() != null && config.getTabSize() > 0) {
                editorCore.setTabSize(config.getTabSize());
            }
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
        renderer.setEditorIconProvider(provider);
    }

    /**
     * Get the current editor icon provider.
     */
    public EditorIconProvider getEditorIconProvider() {
        return renderer.getEditorIconProvider();
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



    // ===================== Painting =====================

    @Override
    protected void paintComponent(Graphics g) {
        super.paintComponent(g);
        Graphics2D g2 = (Graphics2D) g;

        renderer.render(g2, renderModel, getWidth(), getHeight(), cursorVisible);

        if (renderModel != null && completionPopupController != null
                && renderModel.cursor != null && renderModel.cursor.position != null) {
            completionPopupController.updateCursorPosition(
                    renderModel.cursor.position.x, renderModel.cursor.position.y, renderModel.cursor.height);
        }
    }



    // ===================== Event Handling =====================

    private void setupEventListeners() {
        addMouseListener(new MouseAdapter() {
            @Override
            public void mousePressed(MouseEvent e) {
                requestFocusInWindow();
                int mods = getModifiers(e);
                if (SwingUtilities.isLeftMouseButton(e)) {
                    handleGesture(MOUSE_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                } else if (SwingUtilities.isRightMouseButton(e)) {
                    handleGesture(MOUSE_RIGHT_DOWN, e.getX(), e.getY(), mods, 0, 0, 1);
                }
            }

            @Override
            public void mouseReleased(MouseEvent e) {
                if (SwingUtilities.isLeftMouseButton(e)) {
                    handleGesture(MOUSE_UP, e.getX(), e.getY(), getModifiers(e), 0, 0, 1);
                }
            }
        });

        addMouseMotionListener(new MouseMotionAdapter() {
            @Override
            public void mouseDragged(MouseEvent e) {
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
                    NewLineAction action = newLineActionProviderManager.provideNewLineAction();
                    if (action != null) {
                        TextEditResult editResult = editorCore.insertText(action.text);
                        e.consume();
                        dispatchTextChanged(TextChangeAction.KEY, editResult);
                        resetCursorBlink();
                        flush();
                        return;
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
            updateAnimationTimer(result.needsAnimation);
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
        CompletionItem.TextEdit textEdit = item.textEdit;
        boolean isSnippet = item.insertTextFormat == CompletionItem.INSERT_TEXT_FORMAT_SNIPPET;
        String text = item.insertText != null ? item.insertText : item.label;

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

    private void setupAnimationTimer() {
        animationTimer = new Timer(ANIMATION_INTERVAL_MS, e -> {
            if (!animationActive) return;
            GestureResult result = editorCore.tickAnimations();
            if (result != null) {
                fireGestureEvents(result, null);
            }
            flush();
            if (result == null || !result.needsAnimation) {
                animationActive = false;
                animationTimer.stop();
            }
        });
        animationTimer.setRepeats(true);
    }

    private void updateAnimationTimer(boolean needsAnimation) {
        if (needsAnimation && !animationActive) {
            animationActive = true;
            animationTimer.start();
        } else if (!needsAnimation && animationActive) {
            animationActive = false;
            animationTimer.stop();
        }
    }

    // ===================== Helpers =====================

    void syncPlatformScale(float scale) {
        renderer.syncPlatformScale(scale);
        setFont(renderer.getRegularFont());
    }

    /**
     * Flush all pending changes (decoration / layout / scroll / selection) and trigger a redraw.
     * <p>
     * Decoration setters (setLineSpans, clearHighlights, setFoldRegions, etc.) no longer
     * trigger a redraw automatically. Call this method once after a batch of decoration
     * updates to make them take effect.
     */
    public void flush() {
        editorCore.onFontMetricsChanged();
        renderModel = editorCore.buildRenderModel();
        repaint();
    }

}
