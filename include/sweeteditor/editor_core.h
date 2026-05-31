//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_EDITOR_CORE_H
#define SWEETEDITOR_EDITOR_CORE_H

#include <sweeteditor/editor_types.h>
#include <sweeteditor/document.h>
#include <sweeteditor/visual.h>
#include <sweeteditor/gesture.h>
#include <sweeteditor/ime_types.h>
#include <sweeteditor/layout.h>
#include <sweeteditor/interaction.h>
#include <sweeteditor/render_composer.h>
#include <sweeteditor/undo.h>
#include <sweeteditor/linked_editing.h>
#include <sweeteditor/ime_composition.h>

namespace NS_SWEETEDITOR {

  enum struct SE_PROTOCOL_ENUM(action, NONE) EditorActionReason : uint8_t {
    NONE = 0,
    SETUP = 1,
    TEXT_EDIT = 2,
    KEY_INPUT = 3,
    IME = 4,
    GESTURE = 5,
    ANIMATION = 6,
    PROGRAMMATIC = 7,
    DECORATION = 8,
    FOLDING = 9,
    LINKED_EDITING = 10,
    TEXT_INSERT = 11,
    TEXT_REPLACE = 12,
    TEXT_DELETE = 13,
    TEXT_UNDO = 14,
    TEXT_REDO = 15,
  };

  struct SE_PROTOCOL_OUT(action) EditorActionResult {
    bool handled {false};
    bool needs_redraw {false};
    SE_PROTOCOL_WIRE(enum_i32)
    EditorActionReason reason {EditorActionReason::NONE};

    bool content_changed {false};
    bool cursor_changed {false};
    bool selection_changed {false};
    bool scroll_changed {false};
    bool scale_changed {false};
    bool pointer_cursor_changed {false};
    bool composition_changed {false};
    bool decoration_changed {false};
    bool needs_ime_sync {false};

    bool needs_edge_scroll {false};
    bool needs_fling {false};
    bool needs_animation {false};
    bool is_handle_drag {false};

    Vector<TextChange> changes;

    TextPosition cursor_before;
    TextPosition cursor_after;
    bool has_selection_before {false};
    bool has_selection_after {false};
    TextRange selection_before;
    TextRange selection_after;

    float scroll_x_before {0};
    float scroll_y_before {0};
    float scroll_x_after {0};
    float scroll_y_after {0};
    float scale_before {1};
    float scale_after {1};

    SE_PROTOCOL_WIRE(enum_i32)
    PointerCursorType pointer_cursor_before {PointerCursorType::TEXT};
    SE_PROTOCOL_WIRE(enum_i32)
    PointerCursorType pointer_cursor_after {PointerCursorType::TEXT};

    ImeSyncSnapshot ime_sync;
    SE_PROTOCOL_WIRE(enum_i32)
    GestureType gesture_type {GestureType::UNDEFINED};
    SE_PROTOCOL_WIRE(enum_i32)
    EventType gesture_event_type {EventType::UNDEFINED};
    PointF tap_point {};
    HitTarget hit_target;
    SE_PROTOCOL_WIRE(i32)
    KeyModifier modifiers {KeyModifier::NONE};
    SE_PROTOCOL_WIRE(i32)
    EditorCommandId command {0};
  };

  /// Editor core class
  class EditorCore {
    friend class CompositionController;
  public:
    explicit EditorCore(const SharedPtr<TextMeasurer>& measurer, const EditorOptions& options);

#pragma region [Setup & View State]

    /// Set selection handle configuration at runtime
    /// @param config Handle appearance and touch parameters
    EditorActionResult setHandleConfig(const HandleConfig& config);

    /// Set scrollbar configuration at runtime
    /// @param config Scrollbar geometry/behavior parameters
    EditorActionResult setScrollbarConfig(const ScrollbarConfig& config);

    /// Load text content
    /// @param document Document instance
    EditorActionResult loadDocument(const SharedPtr<Document>& document);
    /// Set editor viewport size
    /// @param viewport Viewport area
    EditorActionResult setViewport(const Viewport& viewport);

    /// Reset text measurement, usually called when editor font is reset
    EditorActionResult onFontMetricsChanged();

    /// Set auto wrap mode
    /// @param mode WrapMode
    EditorActionResult setWrapMode(WrapMode mode);

    /// Set tab size (number of spaces per tab stop)
    /// @param tab_size Tab size (default 4, minimum 1)
    EditorActionResult setTabSize(uint32_t tab_size);

    /// Manually set editor scale factor
    /// @param scale Scale factor
    EditorActionResult setScale(float scale);

    /// Set fold arrow display mode (affects reserved gutter width)
    /// @param mode AUTO=show when fold regions exist, ALWAYS=always reserve, HIDDEN=always hide
    EditorActionResult setFoldArrowMode(FoldArrowMode mode);

    /// Set line spacing params (formula: line_height = font_height * mult + add)
    /// @param add Extra line spacing in pixels (default 0)
    /// @param mult Line spacing multiplier (default 1.0)
    EditorActionResult setLineSpacing(float add, float mult);

    /// Set extra horizontal padding between gutter split and text content start
    /// @param padding Padding in pixels (clamped to >= 0)
    EditorActionResult setContentStartPadding(float padding);

    /// Set whether to show gutter split line
    /// @param show true=show split line, false=hide split line
    EditorActionResult setShowSplitLine(bool show);

    /// Set current line render mode
    /// @param mode BACKGROUND=fill line background, BORDER=draw line border, NONE=disable
    EditorActionResult setCurrentLineRenderMode(CurrentLineRenderMode mode);

    /// Set whether gutter stays fixed during horizontal scroll
    /// @param sticky true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style)
    EditorActionResult setGutterSticky(bool sticky);

    /// Set whether gutter area is visible
    /// @param visible true=show gutter (line numbers, icons, fold arrows), false=hide entire gutter
    EditorActionResult setGutterVisible(bool visible);

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
    EditorActionResult handleGestureEvent(const GestureEvent& event);

    /// Recompute pointer presentation for the last observed mouse position after modifier keys change.
    /// @param modifiers Current modifier key flags
    /// @return Editor state changes caused by pointer presentation refresh
    EditorActionResult updatePointerModifiers(KeyModifier modifiers);

    /// Unified animation tick: advances all active animations (edge-scroll, fling).
    /// Platform can use a single frame callback driven by needs_animation and call this.
    /// @return Updated gesture result with needs_animation reflecting whether any animation is still active
    EditorActionResult tickAnimations();

    /// Immediately stop any active fling animation
    EditorActionResult stopFling();

    /// Handle keyboard event (optional default key mapping; platform can bypass and call atomic edit APIs directly)
    /// @param event Keyboard event data
    /// @return Keyboard event handling result
    EditorActionResult handleKeyEvent(const KeyEvent& event);

    /// Replace the current key map with a custom one
    EditorActionResult setKeyMap(KeyMap key_map);

#pragma endregion

#pragma region [Editing & Cursor]

    /// Insert text at cursor position (replace selection if any)
    /// @param text UTF8 text
    /// @return Exact change info
    EditorActionResult insertText(const U8String& text);

    /// Replace text in given range (atomic op, for exact replace cases like textEdit)
    /// @param range Text range to replace (same as insert when start == end)
    /// @param new_text New text after replace (same as delete when empty)
    /// @return Exact change info
    EditorActionResult replaceText(const TextRange& range, const U8String& new_text);

    /// Delete text in given range
    /// @param range Text range to delete
    /// @return Exact change info
    EditorActionResult deleteText(const TextRange& range);

    /// Delete selection; if no selection, delete one char before cursor (Backspace behavior)
    /// @return Exact change info
    EditorActionResult backspace();

    /// Delete selection; if no selection, delete one char after cursor (Delete behavior)
    /// @return Exact change info
    EditorActionResult deleteForward();
    /// Move current line (or lines covered by selection) up by one line
    /// @return Exact change info
    EditorActionResult moveLineUp();

    /// Move current line (or lines covered by selection) down by one line
    /// @return Exact change info
    EditorActionResult moveLineDown();

    /// Copy current line (or lines covered by selection) upward
    /// @return Exact change info
    EditorActionResult copyLineUp();

    /// Copy current line (or lines covered by selection) downward
    /// @return Exact change info
    EditorActionResult copyLineDown();

    /// Delete current line (or all lines covered by selection)
    /// @return Exact change info
    EditorActionResult deleteLine();

    /// Insert empty line above current line
    /// @return Exact change info
    EditorActionResult insertLineAbove();

    /// Insert empty line below current line
    /// @return Exact change info
    EditorActionResult insertLineBelow();
    /// Undo last edit operation
    /// @return Exact change info (changed=false means nothing to undo)
    EditorActionResult undo();

    /// Redo last undone operation
    /// @return Exact change info (changed=false means nothing to redo)
    EditorActionResult redo();

    /// Whether undo is available
    bool canUndo() const;

    /// Whether redo is available
    bool canRedo() const;
    /// Set cursor position
    /// @param position Text position
    EditorActionResult setCursorPosition(const TextPosition& position);

    /// Get cursor position
    TextPosition getCursorPosition() const;

    /// Set text selection range
    /// @param range Selection range (start is anchor, end is active end)
    EditorActionResult setSelection(const TextRange& range);

    /// Get current selection range
    TextRange getSelection() const;

    /// Whether there is a selection
    bool hasSelection() const;

    /// Clear selection
    EditorActionResult clearSelection();

    /// Select all
    EditorActionResult selectAll();

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
    EditorActionResult moveCursorLeft(bool extend_selection = false);

    /// Move cursor right
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorRight(bool extend_selection = false);

    /// Move cursor up
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorUp(bool extend_selection = false);

    /// Move cursor down
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorDown(bool extend_selection = false);

    /// Move cursor to line start
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorToLineStart(bool extend_selection = false);

    /// Move cursor to line end
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorToLineEnd(bool extend_selection = false);

    /// Move cursor up by one page (viewport height / line height)
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorPageUp(bool extend_selection = false);

    /// Move cursor down by one page (viewport height / line height)
    /// @param extend_selection Whether to extend selection
    EditorActionResult moveCursorPageDown(bool extend_selection = false);

    /// Set read-only mode
    /// @param read_only true=read-only (block all edit actions), false=editable
    EditorActionResult setReadOnly(bool read_only);

    /// Get whether read-only mode is active
    bool isReadOnly() const;
    /// Set auto indent mode
    /// @param mode Auto indent mode
    EditorActionResult setAutoIndentMode(AutoIndentMode mode);

    /// Get current auto indent mode
    AutoIndentMode getAutoIndentMode() const;

    /// Set backspace unindent behavior
    /// @param enabled true = backspace on leading whitespace unindents or merges blank line
    EditorActionResult setBackspaceUnindent(bool enabled);

    /// Set whether Tab inserts spaces up to the next tab stop instead of a literal '\t'
    /// @param enabled true = insert spaces, false = insert '\t'
    EditorActionResult setInsertSpaces(bool enabled);

    /// Insert VSCode snippet template and enter linked editing mode (helper method)
    /// @param snippet_template VSCode snippet syntax template
    /// @return Exact change info (changes from inserting template text)
    EditorActionResult insertSnippet(const U8String& snippet_template);

    /// Start linked editing mode with generic LinkedEditingModel
    /// Model is built outside; ranges must already point to correct positions in document
    /// @param model Linked editing model
    EditorActionResult startLinkedEditing(LinkedEditingModel&& model);

    /// Whether linked editing mode is active
    bool isInLinkedEditing() const;

    /// Linked editing: jump to next tab stop
    /// @return false means already at end; session ends automatically
    EditorActionResult linkedEditingNextTabStop();

    /// Linked editing: jump to previous tab stop
    /// @return false means already at first
    EditorActionResult linkedEditingPrevTabStop();

    /// Cancel linked editing mode
    EditorActionResult cancelLinkedEditing();

    /// Finish linked editing mode and place cursor at $0 position (called after Enter/Tab flow)
    EditorActionResult finishLinkedEditing();

#pragma endregion

#pragma region [IME]

    /// Get the current IME synchronization snapshot
    ImeSyncSnapshot getImeSyncSnapshot() const;

    EditorActionResult setImeKeyboardScriptClass(ImeScriptClass script_class);

    ImeScriptClass getImeKeyboardScriptClass() const;

    EditorActionResult updateImePreedit(const U8String& text,
                                     ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult setImeComposingText(const U8String& text,
                                         int cursor_offset,
                                         ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult setImeComposingText(const U8String& text,
                                         size_t selection_start_offset,
                                         size_t selection_end_offset,
                                         ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult commitImeText(const U8String& text,
                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult commitImeText(const U8String& text,
                                   int cursor_offset,
                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult finishImePreedit();

    EditorActionResult cancelImePreedit();

    EditorActionResult markImeDocumentRange(const TextRange& range,
                                         ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult markImeDocumentRange(size_t start_offset,
                                          size_t end_offset,
                                          ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult replaceImeText(const ImeTextReplacement& replacement);

    EditorActionResult replaceImeDocumentText(const ImeDocumentTextReplacement& replacement);

    EditorActionResult replaceImeInputContextText(const ImeInputContextTextReplacement& replacement);

    EditorActionResult markImeInputContextRange(size_t start_offset,
                                              size_t end_offset,
                                              ImeScriptClass script_class = ImeScriptClass::UNKNOWN);

    EditorActionResult notifyImeDocumentSelectionChanged(size_t start_offset, size_t end_offset);

    EditorActionResult notifyImeInputContextSelectionChanged(size_t start_offset, size_t end_offset);

    EditorActionResult updateImeTextModelState(const ImeTextModelState& state);

    EditorActionResult updateImeTextModelDelta(const ImeTextModelDelta& delta);

    EditorActionResult updateImeInputStateSelection(uint64_t context_id,
                                                  int32_t document_start_offset,
                                                  int32_t selection_start_offset,
                                                  int32_t selection_end_offset);

    EditorActionResult replaceImeInputStateText(const ImeInputStateTextReplacement& replacement);

    EditorActionResult deleteImeBackward(size_t before_length = 1,
                                       ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);

    EditorActionResult deleteImeForward(size_t after_length = 1,
                                      ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);

    EditorActionResult deleteImeSurrounding(size_t before_length,
                                          size_t after_length,
                                          ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);

    EditorActionResult notifyImeSelectionChanged(const TextRange& range);

    EditorActionResult notifyImeCursorChanged(const TextPosition& cursor);

    ImeInputContext getImeInputContext(size_t before_length, size_t after_length);

    ImeInputContext getImeTextModelInputContext(ImeTextModelMode mode,
                                                size_t before_length,
                                                size_t after_length);

    /// Whether a composition session exists
    bool hasComposingSession() const;

    /// Get current composition state
    const CompositionState& getCompositionState() const;

    /// Whether composition is active
    bool isComposing() const;

#pragma endregion

#pragma region [Navigation & Decorations]

    /// Scroll to target line
    /// @param line Line number
    /// @param behavior Scroll behavior
    EditorActionResult scrollToLine(size_t line, ScrollBehavior behavior);

    /// Go to target line and column (scroll + cursor placement)
    /// @param line Line number (0-based)
    /// @param column Column number (0-based)
    EditorActionResult gotoPosition(size_t line, size_t column);

    /// Adjust scroll offset just enough to keep current cursor inside viewport
    EditorActionResult ensureCursorVisible();

    /// Manually set editor scroll offset
    /// @param scroll_x Horizontal scroll offset
    /// @param scroll_y Vertical scroll offset
    EditorActionResult setScroll(float scroll_x, float scroll_y);

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
    EditorActionResult registerTextStyle(uint32_t style_id, TextStyle&& style);

    /// Batch register highlight styles (loop register in registry + mark dirty once)
    /// @param entries Array of style_id->text style pairs (passed with move semantics)
    EditorActionResult registerBatchTextStyles(Vector<std::pair<uint32_t, TextStyle>>&& entries);

    /// Set highlight spans for given line and layer
    /// @param line Line number
    /// @param layer Highlight layer (SYNTAX / SEMANTIC)
    /// @param spans Highlight span list
    EditorActionResult setLineSpans(size_t line, SpanLayer layer, Vector<StyleSpan>&& spans);

    /// Batch set highlight spans for multiple lines (loop setLineSpans + mark dirty once)
    /// @param layer Highlight layer (SYNTAX / SEMANTIC)
    /// @param entries Array of line->span list pairs (passed with move semantics)
    EditorActionResult setBatchLineSpans(SpanLayer layer, Vector<std::pair<size_t, Vector<StyleSpan>>>&& entries);

    /// Set inlay hints for given line (replace whole line, already sorted by column ascending)
    /// @param line Line number
    /// @param hints Inlay hint list
    EditorActionResult setLineInlayHints(size_t line, Vector<InlayHint>&& hints);

    /// Batch set inlay hints for multiple lines (loop setLineInlayHints + mark dirty once)
    /// @param entries Array of line->hint list pairs
    EditorActionResult setBatchLineInlayHints(Vector<std::pair<size_t, Vector<InlayHint>>>&& entries);

    /// Set phantom texts for given line (replace whole line, already sorted by column ascending)
    /// @param line Line number
    /// @param phantoms Phantom text list
    EditorActionResult setLinePhantomTexts(size_t line, Vector<PhantomText>&& phantoms);

    /// Batch set phantom texts for multiple lines (loop setLinePhantomTexts + mark dirty once)
    /// @param entries Array of line->phantom list pairs
    EditorActionResult setBatchLinePhantomTexts(Vector<std::pair<size_t, Vector<PhantomText>>>&& entries);

    /// Set gutter icons for given line (replace whole line)
    /// @param line Line number
    /// @param icons Icon list
    EditorActionResult setLineGutterIcons(size_t line, Vector<GutterIcon>&& icons);

    /// Batch set gutter icons for multiple lines (loop setLineGutterIcons, no dirty mark)
    /// @param entries Array of line->icon list pairs
    EditorActionResult setBatchLineGutterIcons(Vector<std::pair<size_t, Vector<GutterIcon>>>&& entries);

    /// Set max icon count in gutter (affects reserved gutter width)
    /// @param count Max icon count (0=no reserved space, default 0)
    EditorActionResult setMaxGutterIcons(uint32_t count);

    /// Set CodeLens items for given line (replace whole line)
    /// @param line Line number
    /// @param items CodeLens item list
    EditorActionResult setLineCodeLens(size_t line, Vector<CodeLensItem>&& items);

    /// Batch set CodeLens items for multiple lines
    /// @param entries Array of line->items pairs
    EditorActionResult setBatchLineCodeLens(Vector<std::pair<size_t, Vector<CodeLensItem>>>&& entries);

    /// Clear all CodeLens items
    EditorActionResult clearCodeLens();

    /// Set link ranges for a given line (replace whole line)
    EditorActionResult setLineLinks(size_t line, Vector<LinkSpan>&& links);

    /// Batch set link ranges for multiple lines
    EditorActionResult setBatchLineLinks(Vector<std::pair<size_t, Vector<LinkSpan>>>&& entries);

    /// Clear all link ranges
    EditorActionResult clearLinks();

    /// Resolve link target by logical line and column inside that link.
    /// Returns an empty string when no link matches the requested position.
    U8String getLinkTargetAt(size_t line, size_t column) const;

    /// Set diagnostic decorations for given line (wavy underline/underline)
    /// @param line Line number
    /// @param diagnostics Diagnostic list
    EditorActionResult setLineDiagnostics(size_t line, Vector<Diagnostic>&& diagnostics);

    /// Batch set diagnostic decorations for multiple lines (loop setLineDiagnostics, no dirty mark)
    /// @param entries Array of line->diagnostic list pairs
    EditorActionResult setBatchLineDiagnostics(Vector<std::pair<size_t, Vector<Diagnostic>>>&& entries);

    /// Clear all diagnostic decorations
    EditorActionResult clearDiagnostics();

    EditorActionResult setIndentGuides(Vector<IndentGuide>&& guides);
    EditorActionResult setBracketGuides(Vector<BracketGuide>&& guides);
    EditorActionResult setFlowGuides(Vector<FlowGuide>&& guides);
    EditorActionResult setSeparatorGuides(Vector<SeparatorGuide>&& guides);

    /// Set fold region list (replace existing list)
    /// @param regions Fold region list
    EditorActionResult setFoldRegions(Vector<FoldRegion>&& regions);

    /// Fold region at given line
    /// @param line Line number (usually fold start line)
    /// @return true means region was found and folded
    EditorActionResult foldAt(size_t line);

    /// Unfold region at given line
    /// @param line Line number
    /// @return true means region was found and unfolded
    EditorActionResult unfoldAt(size_t line);

    /// Toggle fold state of region at given line
    /// @param line Line number
    /// @return true means region was found
    EditorActionResult toggleFoldAt(size_t line);

    /// Fold all regions
    EditorActionResult foldAll();

    /// Unfold all regions
    EditorActionResult unfoldAll();

    /// Check whether given line is visible (not hidden by folding)
    bool isLineVisible(size_t line) const;

    /// Clear highlight spans in given layer (affects layout, mark dirty)
    EditorActionResult clearHighlights(SpanLayer layer);

    /// Clear highlight spans in all layers (affects layout, mark dirty)
    EditorActionResult clearHighlights();

    /// Clear all inlay hints (affects layout, mark dirty)
    EditorActionResult clearInlayHints();

    /// Clear all phantom texts (affects layout, mark dirty)
    EditorActionResult clearPhantomTexts();

    /// Clear all gutter icons (mark dirty)
    EditorActionResult clearGutterIcons();

    /// Clear all code structure guides (indent lines, bracket pair lines, control flow arrows, separators)
    EditorActionResult clearGuides();

    /// Clear all decoration data (highlights, inlay hints, phantom texts, icons, guide lines)
    EditorActionResult clearAllDecorations();

    /// Set bracket pair list (override default (){}[])
    /// @param pairs Bracket pair list
    EditorActionResult setBracketPairs(Vector<BracketPair>&& pairs);

    /// Set auto-closing pair list (empty = disable auto-closing)
    /// @param pairs Auto-closing pair list
    EditorActionResult setAutoClosingPairs(Vector<BracketPair>&& pairs);

    /// Set exact bracket match result from outside (override built-in char scan)
    /// @param open Opening bracket position
    /// @param close Closing bracket position
    EditorActionResult setMatchedBrackets(const TextPosition& open, const TextPosition& close);

    /// Clear external bracket match result (fall back to built-in char scan)
    EditorActionResult clearMatchedBrackets();

#pragma endregion

  private:
    struct PointerProbeResult {
      HitTarget hot_target;
      PointerCursorType cursor_type {PointerCursorType::TEXT};
    };

    struct ActionSnapshot {
      TextPosition cursor;
      bool has_selection {false};
      TextRange selection;
      float scroll_x {0};
      float scroll_y {0};
      float scale {1};
      PointerCursorType pointer_cursor_type {PointerCursorType::TEXT};
      HitTarget active_hit_target;
      CompositionState composition;
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

    ImeInputContext m_ime_input_context_;
    uint64_t m_next_ime_input_context_id_ {1};
    int32_t m_ime_input_context_revision_ {0};
    bool m_ime_text_model_has_pending_composition_clear_ {false};
    ImeTextRange m_ime_text_model_pending_composition_clear_ {-1, -1};

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
    /// Last mouse point reported by the platform for pointer presentation refresh.
    PointF m_last_mouse_point_;
    bool m_has_last_mouse_point_ {false};
    /// Current pointer cursor type for the last observed mouse location.
    PointerCursorType m_pointer_cursor_type_ {PointerCursorType::TEXT};

    /// Max character distance for built-in bracket scan
    static constexpr size_t kMaxBracketScanChars = 10000;

    /// Delete selection and place cursor at selection start
    void deleteSelection();
    TextEditResult insertTextInternal(const U8String& text);
    TextEditResult replaceTextInternal(const TextRange& range, const U8String& new_text);
    TextEditResult deleteTextInternal(const TextRange& range);
    TextEditResult backspaceInternal();
    TextEditResult deleteForwardInternal();
    TextEditResult moveLineUpInternal();
    TextEditResult moveLineDownInternal();
    TextEditResult copyLineUpInternal();
    TextEditResult copyLineDownInternal();
    TextEditResult deleteLineInternal();
    TextEditResult insertLineAboveInternal();
    TextEditResult insertLineBelowInternal();
    TextEditResult undoInternal();
    TextEditResult redoInternal();
    TextEditResult insertSnippetInternal(const U8String& snippet_template);
    void startLinkedEditingInternal(LinkedEditingModel&& model);
    bool linkedEditingNextTabStopInternal();
    bool linkedEditingPrevTabStopInternal();
    void cancelLinkedEditingInternal();
    void finishLinkedEditingInternal();
    bool foldAtInternal(size_t line);
    bool unfoldAtInternal(size_t line);
    bool toggleFoldAtInternal(size_t line);
    void foldAllInternal();
    void unfoldAllInternal();
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
    size_t documentUtf16Length() const;
    TextRange textRangeFromUtf16Offsets(size_t start_offset, size_t end_offset) const;
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
    ActionSnapshot captureActionSnapshot() const;
    EditorActionResult finishAction(const ActionSnapshot& before,
                                    EditorActionReason reason,
                                    bool handled,
                                    TextEditResult edit_result = {},
                                    bool force_redraw = false,
                                    bool decoration_changed = false) const;
    EditorActionResult finishGestureAction(const ActionSnapshot& before,
                                           GestureResult gesture_result,
                                           EditorActionReason reason,
                                           EventType event_type = EventType::UNDEFINED,
                                           bool decoration_changed = false) const;
    EditorActionResult finishImeAction(const ActionSnapshot& before,
                                       const ImeActionResult& ime_result) const;
    void normalizeScrollState();

    /// Linked editing: apply synced replace to all linked ranges in current tab stop, return all changes
    std::vector<TextChange> performLinkedEdits(const U8String& new_text);

    /// Linked editing: apply replace and return one edit result (based on primary range)
    TextEditResult applyLinkedEditsWithResult(const U8String& new_text);

    /// Linked editing: jump to target tab stop and select default text
    void activateCurrentTabStop();

#pragma region [IME Internals]

    ImeActionResult updateImePreeditInternal(const U8String& text,
                                             ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult setImeComposingTextInternal(const U8String& text,
                                                int cursor_offset,
                                                ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult setImeComposingTextInternal(const U8String& text,
                                                size_t selection_start_offset,
                                                size_t selection_end_offset,
                                                ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitImeTextInternal(const U8String& text,
                                          ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitImeTextInternal(const U8String& text,
                                          int cursor_offset,
                                          ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult finishImePreeditInternal();
    ImeActionResult cancelImePreeditInternal();
    ImeActionResult markImeDocumentRangeInternal(const TextRange& range,
                                                 ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult markImeDocumentRangeInternal(size_t start_offset,
                                                 size_t end_offset,
                                                 ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult replaceImeTextInternal(const TextRange& range,
                                           const U8String& text,
                                           ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult replaceImeDocumentTextInternal(size_t start_offset,
                                                   size_t end_offset,
                                                   const U8String& text,
                                                   int cursor_offset,
                                                   ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult replaceImeInputContextTextInternal(size_t start_offset,
                                                       size_t end_offset,
                                                       const U8String& text,
                                                       int cursor_offset,
                                                       ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult markImeInputContextRangeInternal(size_t start_offset,
                                                     size_t end_offset,
                                                     ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult notifyImeDocumentSelectionChangedInternal(size_t start_offset, size_t end_offset);
    ImeActionResult notifyImeInputContextSelectionChangedInternal(size_t start_offset, size_t end_offset);
    ImeActionResult updateImeInputStateTextInternal(uint64_t context_id,
                                                    int32_t document_start_offset,
                                                    const U8String& text,
                                                    int32_t selection_start_offset,
                                                    int32_t selection_end_offset,
                                                    int32_t composing_start_offset,
                                                    int32_t composing_end_offset,
                                                    ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult updateImeTextModelStateInternal(ImeTextModelMode mode,
                                                    uint64_t context_id,
                                                    int32_t document_start_offset,
                                                    const U8String& text,
                                                    int32_t selection_start_offset,
                                                    int32_t selection_end_offset,
                                                    int32_t composing_start_offset,
                                                    int32_t composing_end_offset,
                                                    ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult updateImeTextModelDeltaInternal(ImeTextModelMode mode,
                                                    uint64_t context_id,
                                                    int32_t document_start_offset,
                                                    const U8String& old_text,
                                                    int32_t delta_start_offset,
                                                    int32_t delta_end_offset,
                                                    const U8String& delta_text,
                                                    int32_t selection_start_offset,
                                                    int32_t selection_end_offset,
                                                    int32_t composing_start_offset,
                                                    int32_t composing_end_offset,
                                                    ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult updateImeInputStateSelectionInternal(uint64_t context_id,
                                                         int32_t document_start_offset,
                                                         int32_t selection_start_offset,
                                                         int32_t selection_end_offset);
    ImeActionResult replaceImeInputStateTextInternal(uint64_t context_id,
                                                     int32_t document_start_offset,
                                                     size_t start_offset,
                                                     size_t end_offset,
                                                     const U8String& text,
                                                     int cursor_offset,
                                                     ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult commitImeInputStateTextReplacementInternal(uint64_t context_id,
                                                               int32_t document_start_offset,
                                                               size_t start_offset,
                                                               size_t end_offset,
                                                               const U8String& text,
                                                               int cursor_offset,
                                                               ImeScriptClass script_class = ImeScriptClass::UNKNOWN);
    ImeActionResult deleteImeBackwardInternal(size_t before_length = 1,
                                              ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteImeForwardInternal(size_t after_length = 1,
                                             ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult deleteImeSurroundingInternal(size_t before_length,
                                                 size_t after_length,
                                                 ImeTextUnit text_unit = ImeTextUnit::GRAPHEME);
    ImeActionResult notifyImeSelectionChangedInternal(const TextRange& range);
    ImeActionResult notifyImeCursorChangedInternal(const TextPosition& cursor);
    TextRange textRangeFromImeInputContextOffsets(size_t start_offset, size_t end_offset) const;
    TextRange textRangeFromImeInputStateOffsets(uint64_t context_id,
                                                int32_t document_start_offset,
                                                size_t start_offset,
                                                size_t end_offset) const;
    TextRange textRangeFromImeCompositionOffsets(const ImeActionResult& result,
                                                size_t start_offset,
                                                size_t end_offset) const;
    ImeInputContext buildImeInputContext(size_t before_length,
                                         size_t after_length,
                                         ImeInputContextKind kind);
    ImeInputContextKind resolveImeDocumentInputContextKind(size_t before_length,
                                                           size_t after_length) const;
    void applyImeCursorOffset(ImeActionResult& result, const U8String& text, int cursor_offset);
    void rememberImeInputState(uint64_t context_id,
                               int32_t document_start_offset,
                               const U8String& text,
                               int32_t selection_start_offset,
                               int32_t selection_end_offset,
                               int32_t composing_start_offset,
                               int32_t composing_end_offset,
                               ImeInputContextKind kind);
    void resetImeTextModelPendingState();
    void invalidateImeInputContext();
    bool isDocumentRangeReadable(const TextRange& range) const;
    TextEditResult deleteCodePointBackward();
    TextEditResult deleteCodePointForward();

#pragma endregion
  };

}

#endif //SWEETEDITOR_EDITOR_CORE_H
