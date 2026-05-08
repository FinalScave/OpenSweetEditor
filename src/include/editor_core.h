//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_EDITOR_CORE_H
#define SWEETEDITOR_EDITOR_CORE_H

#include "editor_types.h"
#include "document.h"
#include "visual.h"
#include "gesture.h"
#include "layout.h"
#include "interaction.h"
#include "render_composer.h"
#include "undo.h"
#include "linked_editing.h"
#include "ime.h"

namespace NS_SWEETEDITOR {

  /// Editor core class
  class EditorCore : private CompositionController::Host {
  public:
    explicit EditorCore(const SharedPtr<TextMeasurer>& measurer, const EditorOptions& options);

#pragma region [Setup & View State]

    /// Set selection handle configuration at runtime
    /// @param config Handle appearance and touch parameters
    void setHandleConfig(const HandleConfig& config);

    /// Set scrollbar configuration at runtime
    /// @param config Scrollbar geometry/behavior parameters
    void setScrollbarConfig(const ScrollbarConfig& config);

    /// Load text content
    /// @param document Document instance
    void loadDocument(const SharedPtr<Document>& document);
    /// Set editor viewport size
    /// @param viewport Viewport area
    void setViewport(const Viewport& viewport);

    /// Reset text measurement, usually called when editor font is reset
    void onFontMetricsChanged();

    /// Set auto wrap mode
    /// @param mode WrapMode
    void setWrapMode(WrapMode mode);

    /// Set tab size (number of spaces per tab stop)
    /// @param tab_size Tab size (default 4, minimum 1)
    void setTabSize(uint32_t tab_size);

    /// Manually set editor scale factor
    /// @param scale Scale factor
    void setScale(float scale);

    /// Set fold arrow display mode (affects reserved gutter width)
    /// @param mode AUTO=show when fold regions exist, ALWAYS=always reserve, HIDDEN=always hide
    void setFoldArrowMode(FoldArrowMode mode);

    /// Set line spacing params (formula: line_height = font_height * mult + add)
    /// @param add Extra line spacing in pixels (default 0)
    /// @param mult Line spacing multiplier (default 1.0)
    void setLineSpacing(float add, float mult);

    /// Set extra horizontal padding between gutter split and text content start
    /// @param padding Padding in pixels (clamped to >= 0)
    void setContentStartPadding(float padding);

    /// Set whether to show gutter split line
    /// @param show true=show split line, false=hide split line
    void setShowSplitLine(bool show);

    /// Set current line render mode
    /// @param mode BACKGROUND=fill line background, BORDER=draw line border, NONE=disable
    void setCurrentLineRenderMode(CurrentLineRenderMode mode);

    /// Set whether gutter stays fixed during horizontal scroll
    /// @param sticky true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style)
    void setGutterSticky(bool sticky);

    /// Set whether gutter area is visible
    /// @param visible true=show gutter (line numbers, icons, fold arrows), false=hide entire gutter
    void setGutterVisible(bool visible);

#pragma endregion

#pragma region [Rendering & Input]

    /// Get editor text-style registry
    /// @return Text-style registry
    SharedPtr<TextStyleRegistry> getTextStyleRegistry() const;

    /// Build editor render model
    /// @param model Input EditorRenderModel
    void buildRenderModel(EditorRenderModel& model);

    /// Get current editor state, including scale, scroll, and more
    ViewState getViewState() const;

    /// Get full metric data needed for scrollbar calculations
    ScrollMetrics getScrollMetrics() const;

    /// Get cached visible logical line range from the most recent completed layout pass
    IntRange getVisibleLineRange() const;

    /// Get editor layout metrics
    LayoutMetrics& getLayoutMetrics() const;

    /// Handle gesture event
    /// @param event Gesture data
    /// @return Gesture handling result (includes editor state)
    GestureResult handleGestureEvent(const GestureEvent& event);

    /// Called by platform timer (~16ms interval) while needs_edge_scroll is true.
    /// Scrolls the viewport and updates the selection based on saved edge-scroll state.
    /// @return Updated gesture result (platform should redraw; check needs_edge_scroll to decide
    ///         whether to continue the timer)
    GestureResult tickEdgeScroll();

    /// Called by platform each frame while needs_fling is true.
    /// Advances fling animation using real elapsed time and applies scroll delta.
    /// @return Updated gesture result (platform should redraw; check needs_fling to decide
    ///         whether to continue the timer)
    GestureResult tickFling();

    /// Unified animation tick: advances all active animations (edge-scroll, fling).
    /// Platform can use a single frame callback driven by needs_animation and call this
    /// instead of tickEdgeScroll() / tickFling() separately.
    /// @return Updated gesture result with needs_animation reflecting whether any animation is still active
    GestureResult tickAnimations();

    /// Immediately stop any active fling animation
    void stopFling();

    /// Handle keyboard event (optional default key mapping; platform can bypass and call atomic edit APIs directly)
    /// @param event Keyboard event data
    /// @return Keyboard event handling result
    KeyEventResult handleKeyEvent(const KeyEvent& event);

    /// Replace the current key map with a custom one
    void setKeyMap(KeyMap key_map);

#pragma endregion

#pragma region [Editing & Cursor/IME]

    /// Insert text at cursor position (replace selection if any)
    /// @param text UTF8 text
    /// @return Exact change info
    TextEditResult insertText(const U8String& text);

    /// Replace text in given range (atomic op, for exact replace cases like textEdit)
    /// @param range Text range to replace (same as insert when start == end)
    /// @param new_text New text after replace (same as delete when empty)
    /// @return Exact change info
    TextEditResult replaceText(const TextRange& range, const U8String& new_text);

    /// Delete text in given range
    /// @param range Text range to delete
    /// @return Exact change info
    TextEditResult deleteText(const TextRange& range);

    /// Delete selection; if no selection, delete one char before cursor (Backspace behavior)
    /// @return Exact change info
    TextEditResult backspace();

    /// Delete selection; if no selection, delete one char after cursor (Delete behavior)
    /// @return Exact change info
    TextEditResult deleteForward();
    /// Move current line (or lines covered by selection) up by one line
    /// @return Exact change info
    TextEditResult moveLineUp();

    /// Move current line (or lines covered by selection) down by one line
    /// @return Exact change info
    TextEditResult moveLineDown();

    /// Copy current line (or lines covered by selection) upward
    /// @return Exact change info
    TextEditResult copyLineUp();

    /// Copy current line (or lines covered by selection) downward
    /// @return Exact change info
    TextEditResult copyLineDown();

    /// Delete current line (or all lines covered by selection)
    /// @return Exact change info
    TextEditResult deleteLine();

    /// Insert empty line above current line
    /// @return Exact change info
    TextEditResult insertLineAbove();

    /// Insert empty line below current line
    /// @return Exact change info
    TextEditResult insertLineBelow();
    /// Undo last edit operation
    /// @return Exact change info (changed=false means nothing to undo)
    TextEditResult undo();

    /// Redo last undone operation
    /// @return Exact change info (changed=false means nothing to redo)
    TextEditResult redo();

    /// Whether undo is available
    bool canUndo() const;

    /// Whether redo is available
    bool canRedo() const;
    /// Set cursor position
    /// @param position Text position
    void setCursorPosition(const TextPosition& position);

    /// Get cursor position
    TextPosition getCursorPosition() const;

    /// Set text selection range
    /// @param range Selection range (start is anchor, end is active end)
    void setSelection(const TextRange& range);

    /// Get current selection range
    TextRange getSelection() const;

    /// Whether there is a selection
    bool hasSelection() const;

    /// Clear selection
    void clearSelection();

    /// Select all
    void selectAll();

    /// Get selected text (UTF8)
    U8String getSelectedText() const;

    /// Get text range of word at cursor (scan left through continuous word chars)
    /// @return TextRange of current word (start.column = word start, end.column = cursor column)
    TextRange getWordRangeAtCursor() const;

    /// Get word text at cursor (UTF8)
    /// @return Current word text; empty string if cursor is not on a word
    U8String getWordAtCursor() const;

    /// Move cursor left
    /// @param extend_selection Whether to extend selection (Shift key)
    void moveCursorLeft(bool extend_selection = false);

    /// Move cursor right
    /// @param extend_selection Whether to extend selection
    void moveCursorRight(bool extend_selection = false);

    /// Move cursor up
    /// @param extend_selection Whether to extend selection
    void moveCursorUp(bool extend_selection = false);

    /// Move cursor down
    /// @param extend_selection Whether to extend selection
    void moveCursorDown(bool extend_selection = false);

    /// Move cursor to line start
    /// @param extend_selection Whether to extend selection
    void moveCursorToLineStart(bool extend_selection = false);

    /// Move cursor to line end
    /// @param extend_selection Whether to extend selection
    void moveCursorToLineEnd(bool extend_selection = false);

    /// Move cursor up by one page (viewport height / line height)
    /// @param extend_selection Whether to extend selection
    void moveCursorPageUp(bool extend_selection = false);

    /// Move cursor down by one page (viewport height / line height)
    /// @param extend_selection Whether to extend selection
    void moveCursorPageDown(bool extend_selection = false);

    /// Get the current IME synchronization snapshot
    ImeSyncSnapshot getImeSyncSnapshot() const;

    /// Set the core IME composition policy
    void setImeCompositionPolicy(const ImeCompositionPolicy& policy);

    /// Get the core IME composition policy
    const ImeCompositionPolicy& getImeCompositionPolicy() const;

    void setImeKeyboardScriptClass(ImeScriptClass script_class);

    ImeScriptClass getImeKeyboardScriptClass() const;

    ImeActionResult refreshImeCompositionAtCursor(ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    ImeActionResult updateImePreedit(const U8String& text,
                                     ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    ImeActionResult commitImeText(const U8String& text,
                                  ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    ImeActionResult finishImePreedit();

    ImeActionResult cancelImePreedit();

    ImeActionResult markImeDocumentRange(const TextRange& range,
                                         ImeScriptClass script_class = ImeScriptClass::UNKNOWN,
                                         ImeDocumentRangeRole role = ImeDocumentRangeRole::PLATFORM_PREFIX_PREEDIT);

    ImeActionResult replaceImeText(const TextRange& range,
                                   const U8String& text,
                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    ImeActionResult deleteImeBackward(size_t before_length = 1,
                                      ImeTextUnit text_unit = ImeTextUnit::UTF16_CODE_UNIT);

    ImeActionResult deleteImeForward(size_t after_length = 1,
                                     ImeTextUnit text_unit = ImeTextUnit::UTF16_CODE_UNIT);

    ImeActionResult deleteImeSurrounding(size_t before_length,
                                         size_t after_length,
                                         ImeTextUnit text_unit = ImeTextUnit::UTF16_CODE_UNIT);

    ImeActionResult notifyImeSelectionChanged(const TextRange& range);

    ImeActionResult notifyImeCursorChanged(const TextPosition& cursor);

    /// Whether a visible or hidden composition session exists
    bool hasComposingSession() const;

    /// Get current composition state
    const CompositionState& getCompositionState() const;

    /// Whether composition is active
    bool isComposing() const;

    /// Legacy no-op; IME composition is always supported when editable.
    void setCompositionEnabled(bool enabled);

    /// Legacy compatibility query; returns true while editable IME is supported.
    bool isCompositionEnabled() const;
    /// Set read-only mode
    /// @param read_only true=read-only (block all edit actions), false=editable
    void setReadOnly(bool read_only);

    /// Get whether read-only mode is active
    bool isReadOnly() const;
    /// Set auto indent mode
    /// @param mode Auto indent mode
    void setAutoIndentMode(AutoIndentMode mode);

    /// Get current auto indent mode
    AutoIndentMode getAutoIndentMode() const;

    /// Set backspace unindent behavior
    /// @param enabled true = backspace on leading whitespace unindents or merges blank line
    void setBackspaceUnindent(bool enabled);

    /// Set whether Tab inserts spaces up to the next tab stop instead of a literal '\t'
    /// @param enabled true = insert spaces, false = insert '\t'
    void setInsertSpaces(bool enabled);

    /// Insert VSCode snippet template and enter linked editing mode (helper method)
    /// @param snippet_template VSCode snippet syntax template
    /// @return Exact change info (changes from inserting template text)
    TextEditResult insertSnippet(const U8String& snippet_template);

    /// Start linked editing mode with generic LinkedEditingModel
    /// Model is built outside; ranges must already point to correct positions in document
    /// @param model Linked editing model
    void startLinkedEditing(LinkedEditingModel&& model);

    /// Whether linked editing mode is active
    bool isInLinkedEditing() const;

    /// Linked editing: jump to next tab stop
    /// @return false means already at end; session ends automatically
    bool linkedEditingNextTabStop();

    /// Linked editing: jump to previous tab stop
    /// @return false means already at first
    bool linkedEditingPrevTabStop();

    /// Cancel linked editing mode
    void cancelLinkedEditing();

    /// Finish linked editing mode and place cursor at $0 position (called after Enter/Tab flow)
    void finishLinkedEditing();

#pragma endregion

#pragma region [Navigation & Decorations]

    /// Scroll to target line
    /// @param line Line number
    /// @param behavior Scroll behavior
    void scrollToLine(size_t line, ScrollBehavior behavior);

    /// Go to target line and column (scroll + cursor placement)
    /// @param line Line number (0-based)
    /// @param column Column number (0-based)
    void gotoPosition(size_t line, size_t column);

    /// Adjust scroll offset just enough to keep current cursor inside viewport
    void ensureCursorVisible();

    /// Manually set editor scroll offset
    /// @param scroll_x Horizontal scroll offset
    /// @param scroll_y Vertical scroll offset
    void setScroll(float scroll_x, float scroll_y);

    /// Get screen-space rectangle for any text position (for floating panel placement)
    /// @param position Text position (line, column)
    /// @return Position coordinates and line height inside editor view
    CursorRect getPositionScreenRect(const TextPosition& position);

    /// Get screen-space rectangle of current cursor position (shortcut)
    /// @return Current cursor coordinates and line height inside editor view
    CursorRect getCursorScreenRect();

    /// Register a highlight style
    /// @param style_id Style ID
    /// @param style Text style definition
    void registerTextStyle(uint32_t style_id, TextStyle&& style);

    /// Batch register highlight styles (loop register in registry + mark dirty once)
    /// @param entries Array of style_id->text style pairs (passed with move semantics)
    void registerBatchTextStyles(Vector<std::pair<uint32_t, TextStyle>>&& entries);

    /// Set highlight spans for given line and layer
    /// @param line Line number
    /// @param layer Highlight layer (SYNTAX / SEMANTIC)
    /// @param spans Highlight span list
    void setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans);

    /// Batch set highlight spans for multiple lines (loop setLineSpans + mark dirty once)
    /// @param layer Highlight layer (SYNTAX / SEMANTIC)
    /// @param entries Array of line->span list pairs (passed with move semantics)
    void setBatchLineSpans(SpanLayer layer, Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries);

    /// Set inlay hints for given line (replace whole line, already sorted by column ascending)
    /// @param line Line number
    /// @param hints Inlay hint list
    void setLineInlayHints(size_t line, Vector<InlayHint>&& hints);

    /// Batch set inlay hints for multiple lines (loop setLineInlayHints + mark dirty once)
    /// @param entries Array of line->hint list pairs
    void setBatchLineInlayHints(Vector<std::pair<size_t, Vector<InlayHint>>>&& entries);

    /// Set phantom texts for given line (replace whole line, already sorted by column ascending)
    /// @param line Line number
    /// @param phantoms Phantom text list
    void setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms);

    /// Batch set phantom texts for multiple lines (loop setLinePhantomTexts + mark dirty once)
    /// @param entries Array of line->phantom list pairs
    void setBatchLinePhantomTexts(Vector<std::pair<size_t, Vector<PhantomText>>>&& entries);

    /// Set gutter icons for given line (replace whole line)
    /// @param line Line number
    /// @param icons Icon list
    void setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons);

    /// Batch set gutter icons for multiple lines (loop setLineGutterIcons, no dirty mark)
    /// @param entries Array of line->icon list pairs
    void setBatchLineGutterIcons(Vector<std::pair<size_t, Vector<GutterIcon>>>&& entries);

    /// Set max icon count in gutter (affects reserved gutter width)
    /// @param count Max icon count (0=no reserved space, default 0)
    void setMaxGutterIcons(uint32_t count);

    /// Set CodeLens items for given line (replace whole line)
    /// @param line Line number
    /// @param items CodeLens item list
    void setLineCodeLens(size_t line, Vector<CodeLensItem>&& items);

    /// Batch set CodeLens items for multiple lines
    /// @param entries Array of line->items pairs
    void setBatchLineCodeLens(Vector<std::pair<size_t, Vector<CodeLensItem>>>&& entries);

    /// Clear all CodeLens items
    void clearCodeLens();

    /// Set link ranges for a given line (replace whole line)
    void setLineLinks(size_t line, Vector<LinkSpan>&& links);

    /// Batch set link ranges for multiple lines
    void setBatchLineLinks(Vector<std::pair<size_t, Vector<LinkSpan>>>&& entries);

    /// Clear all link ranges
    void clearLinks();

    /// Resolve link target by logical line and column inside that link.
    /// Returns an empty string when no link matches the requested position.
    U8String getLinkTargetAt(size_t line, size_t column) const;

    /// Set diagnostic decorations for given line (wavy underline/underline)
    /// @param line Line number
    /// @param diagnostics Diagnostic span list
    void setLineDiagnostics(size_t line, Vector<DiagnosticSpan>&& diagnostics);

    /// Batch set diagnostic decorations for multiple lines (loop setLineDiagnostics, no dirty mark)
    /// @param entries Array of line->diagnostic list pairs
    void setBatchLineDiagnostics(Vector<std::pair<size_t, Vector<DiagnosticSpan>>>&& entries);

    /// Clear all diagnostic decorations
    void clearDiagnostics();

    void setIndentGuides(Vector<IndentGuide>&& guides);
    void setBracketGuides(Vector<BracketGuide>&& guides);
    void setFlowGuides(Vector<FlowGuide>&& guides);
    void setSeparatorGuides(Vector<SeparatorGuide>&& guides);

    /// Set fold region list (replace existing list)
    /// @param regions Fold region list
    void setFoldRegions(Vector<FoldRegion>&& regions);

    /// Fold region at given line
    /// @param line Line number (usually fold start line)
    /// @return true means region was found and folded
    bool foldAt(size_t line);

    /// Unfold region at given line
    /// @param line Line number
    /// @return true means region was found and unfolded
    bool unfoldAt(size_t line);

    /// Toggle fold state of region at given line
    /// @param line Line number
    /// @return true means region was found
    bool toggleFoldAt(size_t line);

    /// Fold all regions
    void foldAll();

    /// Unfold all regions
    void unfoldAll();

    /// Check whether given line is visible (not hidden by folding)
    bool isLineVisible(size_t line) const;

    /// Clear highlight spans in given layer (affects layout, mark dirty)
    void clearHighlights(SpanLayer layer);

    /// Clear highlight spans in all layers (affects layout, mark dirty)
    void clearHighlights();

    /// Clear all inlay hints (affects layout, mark dirty)
    void clearInlayHints();

    /// Clear all phantom texts (affects layout, mark dirty)
    void clearPhantomTexts();

    /// Clear all gutter icons (mark dirty)
    void clearGutterIcons();

    /// Clear all code structure guides (indent lines, bracket pair lines, control flow arrows, separators)
    void clearGuides();

    /// Clear all decoration data (highlights, inlay hints, phantom texts, icons, guide lines)
    void clearAllDecorations();

    /// Set bracket pair list (override default (){}[])
    /// @param pairs Bracket pair list
    void setBracketPairs(Vector<BracketPair>&& pairs);

    /// Set auto-closing pair list (empty = disable auto-closing)
    /// @param pairs Auto-closing pair list
    void setAutoClosingPairs(Vector<BracketPair>&& pairs);

    /// Set exact bracket match result from outside (override built-in char scan)
    /// @param open Opening bracket position
    /// @param close Closing bracket position
    void setMatchedBrackets(const TextPosition& open, const TextPosition& close);

    /// Clear external bracket match result (fall back to built-in char scan)
    void clearMatchedBrackets();

#pragma endregion

  private:
    struct PointerProbeResult {
      HitTarget hot_target;
      PointerCursorType cursor_type {PointerCursorType::TEXT};
    };

    SharedPtr<TextMeasurer> m_measurer_;
    EditorOptions m_options_;
    EditorSettings m_settings_;
    SharedPtr<Document> m_document_;
    SharedPtr<DecorationManager> m_decorations_;
    UniquePtr<TextLayout> m_text_layout_;
    UniquePtr<EditorInteraction> m_interaction_;
    UniquePtr<RenderComposer> m_render_composer_;
    UniquePtr<UndoManager> m_undo_manager_;
    KeyResolver m_key_resolver_;

    Viewport m_viewport_;
    ViewState m_view_state_;
    IntRange m_visible_line_range_;

    /// Unified caret state: cursor position + selection
    CaretState m_caret_;

    /// Core-owned IME composition controller
    CompositionController m_composition_controller_;

    /// Linked editing session (nullptr means not in linked editing mode)
    UniquePtr<LinkedEditingSession> m_linked_editing_session_;

    /// Bracket pair list (default (){}[])
    Vector<BracketPair> m_bracket_pairs_ {
      {U'(', U')'},
      {U'{', U'}'},
      {U'[', U']'},
    };

    /// Auto-closing pair list (empty = disabled)
    Vector<BracketPair> m_auto_closing_pairs_;

    /// Exact bracket match positions set from outside
    TextPosition m_external_bracket_open_;
    TextPosition m_external_bracket_close_;
    bool m_has_external_brackets_ {false};

    /// Hovered clickable hit target for interactive runs such as CodeLens and Link.
    HitTarget m_hover_hit_target_;
    /// Pressed clickable hit target.
    HitTarget m_press_hit_target_;
    /// Whether the primary mouse button is currently pressed.
    bool m_mouse_button_down_ {false};
    /// Current pointer cursor type for the last observed mouse location.
    PointerCursorType m_pointer_cursor_type_ {PointerCursorType::TEXT};

    /// Max character distance for built-in bracket scan
    static constexpr size_t kMaxBracketScanChars = 10000;

    /// Delete selection and place cursor at selection start
    void deleteSelection();
    /// Place cursor by screen coordinates
    void placeCursorAt(const PointF& screen_point);
    /// Select word at screen coordinates
    void selectWordAt(const PointF& screen_point);
    void setCursorPositionInternal(const TextPosition& position, bool commit_composition);
    void setSelectionInternal(const TextRange& range, bool commit_composition);
    /// Update cursor movement (handle selection extension logic)
    void moveCursorTo(const TextPosition& new_pos, bool extend_selection);
    /// Calculate UTF16 column count for UTF8 text
    static size_t calcUtf16Columns(const U8String& text);
    /// Calculate new cursor position after inserting UTF8 text
    TextPosition calcPositionAfterInsert(const TextPosition& start, const U8String& text) const;
    /// Unified edit entry: apply document edit and record undo operation
    /// @param range Range to replace (for pure insert, start == end)
    /// @param new_text New text (for pure delete, use empty string)
    /// @param record_undo Whether to record in undo stack (pass false during undo/redo)
    /// @return Exact change info
    TextEditResult applyEdit(const TextRange& range, const U8String& new_text, bool record_undo = true);

    /// Sync fold state in DecorationManager to each LogicalLine.is_fold_hidden
    void syncFoldState();

    /// Auto unfold when edit range overlaps folded region
    void autoUnfoldForEdit(const TextRange& range);

    /// Mark all logical lines as layout dirty
    void markAllLinesDirty(bool reset_heights = false);
    /// Presentation-state helpers for clickable decoration hot targets.
    void clearHoverHitTarget();
    void clearPressHitTarget();
    HitTarget getActiveHitTarget() const;
    PointerProbeResult probePointer(const PointF& point, KeyModifier modifiers) const;
    void finalizeGestureResult(GestureResult& result) const;
    bool isDocumentRangeReadable(const TextRange& range) const;
    TextEditResult deleteCodePointBackward();
    TextEditResult deleteCodePointForward();
    bool imeHasDocument() const override;
    bool imeReadOnly() const override;
    bool imeIsLinkedEditingActive() const override;
    TextPosition imeCursor() const override;
    bool imeHasSelection() const override;
    TextRange imeSelection() const override;
    TextRange imeClampDocumentRange(const TextRange& range) const override;
    bool imeIsDocumentRangeReadable(const TextRange& range) const override;
    U8String imeDocumentText(const TextRange& range) const override;
    size_t imeDocumentLineCount() const override;
    uint32_t imeLineColumns(size_t line) const override;
    size_t imeCharIndexFromPosition(const TextPosition& position) const override;
    TextPosition imePositionAfterInsert(const TextPosition& start, const U8String& text) const override;
    size_t imeUtf16Columns(const U8String& text) const override;
    TextEditResult imeApplyEdit(const TextRange& range, const U8String& text) override;
    TextEditResult imeInsertText(const U8String& text) override;
    void imeDeleteSelectionForComposition() override;
    void imeDeleteDocumentRange(const TextRange& range) override;
    void imeInsertDocumentText(const TextPosition& position, const U8String& text) override;
    TextEditResult imeBackspace() override;
    TextEditResult imeDeleteForward() override;
    TextEditResult imeDeleteCodePointBackward() override;
    TextEditResult imeDeleteCodePointForward() override;
    void imeSetCursorPosition(const TextPosition& cursor) override;
    void imeSetSelection(const TextRange& range) override;
    void imeSetCursorPositionInternal(const TextPosition& cursor) override;
    void imeSetSelectionInternal(const TextRange& range) override;
    void imeSetRawCursorPosition(const TextPosition& cursor) override;
    void imeInvalidateContentMetrics(size_t line) override;
    void imeEnsureCursorVisible() override;
    void normalizeScrollState();

    /// Linked editing: apply synced replace to all linked ranges in current tab stop, return all changes
    std::vector<TextChange> performLinkedEdits(const U8String& new_text);

    /// Linked editing: apply replace and return one edit result (based on primary range)
    TextEditResult applyLinkedEditsWithResult(const U8String& new_text);

    /// Linked editing: jump to target tab stop and select default text
    void activateCurrentTabStop();
  };

}

#endif //SWEETEDITOR_EDITOR_CORE_H
