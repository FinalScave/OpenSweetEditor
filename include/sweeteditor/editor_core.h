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
#include <sweeteditor/undo.h>
#include <sweeteditor/linked_editing.h>
#include <sweeteditor/search.h>
#include <atomic>

namespace NS_SWEETEDITOR {

  class RenderModelComposer;

  struct SE_PROTOCOL_OUT(action) EditorActionResult {
    bool handled{false};
    bool needs_redraw{false};
    SE_PROTOCOL_WIRE(enum_i32)
    EditorActionSource source{EditorActionSource::NONE};
    SE_PROTOCOL_WIRE(enum_i32)
    TextChangeKind text_change_kind{TextChangeKind::NONE};

    bool content_changed{false};
    bool cursor_changed{false};
    bool selection_changed{false};
    bool scroll_changed{false};
    bool scale_changed{false};
    bool pointer_cursor_changed{false};
    bool composition_changed{false};
    bool decoration_changed{false};

    /// AnimationFlag bit set describing active core-managed animations.
    uint32_t animation_flags{0};
    /// Delay before the next animation tick; zero requests the next display frame.
    uint32_t next_animation_delay_ms{0};
    /// InteractionFlag bit set describing active input interactions.
    uint32_t interaction_flags{0};

    Vector<TextChange> changes;

    TextPosition cursor_before;
    TextPosition cursor_after;
    bool has_selection_before{false};
    bool has_selection_after{false};
    TextRange selection_before;
    TextRange selection_after;

    float scroll_x_before{0};
    float scroll_y_before{0};
    float scroll_x_after{0};
    float scroll_y_after{0};
    float scale_before{1};
    float scale_after{1};

    SE_PROTOCOL_WIRE(enum_i32)
    PointerCursorType pointer_cursor_before{PointerCursorType::TEXT};
    SE_PROTOCOL_WIRE(enum_i32)
    PointerCursorType pointer_cursor_after{PointerCursorType::TEXT};

    SE_PROTOCOL_WIRE(enum_i32)
    ImeHostAction ime_host_action{ImeHostAction::NONE};
    ImeState ime_state;
    SE_PROTOCOL_WIRE(enum_i32)
    GestureType gesture_type{GestureType::UNDEFINED};
    SE_PROTOCOL_WIRE(enum_i32)
    EventType gesture_event_type{EventType::UNDEFINED};
    PointF tap_point{};
    HitTarget hit_target;
    SE_PROTOCOL_WIRE(i32)
    KeyModifier modifiers{KeyModifier::NONE};
    SE_PROTOCOL_WIRE(i32)
    EditorCommandId command{0};

    bool hasAnimationFlag(AnimationFlag flag) const {
      return (animation_flags & static_cast<uint32_t>(flag)) != 0;
    }

    bool needsAnimation() const {
      return animation_flags != 0;
    }

    bool needsViewportMotion() const {
      return hasAnimationFlag(AnimationFlag::EDGE_SCROLL) || hasAnimationFlag(AnimationFlag::FLING);
    }

    bool hasInteractionFlag(InteractionFlag flag) const {
      return (interaction_flags & static_cast<uint32_t>(flag)) != 0;
    }

    bool hasActiveInteraction() const {
      return interaction_flags != 0;
    }
  };

  /// Editor core class
  class EditorCore {
  public:
    explicit EditorCore(const SharedPtr<TextMeasurer>& measurer, const EditorOptions& options);
    ~EditorCore();
    EditorCore(const EditorCore&) = delete;
    EditorCore& operator=(const EditorCore&) = delete;
    EditorCore(EditorCore&&) = delete;
    EditorCore& operator=(EditorCore&&) = delete;

#pragma region[Setup & View State]

    /// Set selection handle configuration at runtime
    /// @param config Handle appearance and touch parameters
    EditorActionResult setHandleConfig(const HandleConfig& config);

    /// Set scrollbar configuration at runtime
    /// @param config Scrollbar geometry/behavior parameters
    EditorActionResult setScrollbarConfig(const ScrollbarConfig& config);

    /// Set editor colors resolved by the core when building visual runs
    /// @param colors Editor render colors
    EditorActionResult setEditorRenderColors(const EditorRenderColors& colors);

    /// Set range-effect styles resolved by the core when building the render model
    /// @param styles Range-effect styles
    EditorActionResult setEditorRangeEffectStyles(const EditorRangeEffectStyles& styles);

    /// Load text content
    /// @param document Document instance
    EditorActionResult loadDocument(const SharedPtr<Document>& document);
    /// Set editor viewport size
    /// @param viewport Viewport area
    EditorActionResult setViewport(const Size& viewport);

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

    /// Set whitespace marker rendering mode
    /// @param mode Whitespace marker visibility mode
    EditorActionResult setRenderWhitespace(WhitespaceRenderMode mode);

    /// Set whether source line endings should be rendered as markers
    /// @param enabled true=render line-ending markers, false=hide them
    EditorActionResult setRenderLineBreaks(bool enabled);

    /// Set whether gutter stays fixed during horizontal scroll
    /// @param sticky true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style)
    EditorActionResult setGutterSticky(bool sticky);

    /// Set whether gutter area is visible
    /// @param visible true=show gutter (line numbers, icons, fold arrows), false=hide entire gutter
    EditorActionResult setGutterVisible(bool visible);

#pragma endregion

#pragma region[Rendering & Input]

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

    /// Unified animation tick for all core-managed animation flags.
    /// Platform schedules the next call from animation_flags and next_animation_delay_ms.
    /// @return Updated action result with the next animation schedule
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

#pragma region[Editing & Cursor]

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

    /// Apply multiple text edits as one undoable operation
    /// @param edits Text edits using the original document coordinates. The first edit is the primary edit.
    /// @return Exact change info
    EditorActionResult applyTextEdits(Vector<TextEdit>&& edits);

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
    /// @return Exact change info (content_changed=false means nothing to undo)
    EditorActionResult undo();

    /// Redo last undone operation
    /// @return Exact change info (content_changed=false means nothing to redo)
    EditorActionResult redo();

    /// Whether undo is available
    bool canUndo() const;

    /// Whether redo is available
    bool canRedo() const;

    /// Search document text and make results available to the next render pass
    EditorActionResult search(const SearchRequest& request);

    /// Move to the next search match
    EditorActionResult findNextSearchMatch();

    /// Move to the previous search match
    EditorActionResult findPreviousSearchMatch();

    /// Replace the current search match
    EditorActionResult replaceCurrentSearchMatch(const U8String& replacement);

    /// Replace every current search match
    EditorActionResult replaceAllSearchMatches(const U8String& replacement);

    /// Clear active search state, rendered highlights, and the current search-owned selection
    EditorActionResult clearSearch();

    /// Get the latest search state
    SearchState getSearchState();

    /// Set cursor position
    /// @param position Text position
    EditorActionResult setCursorPosition(const TextPosition& position);

    /// Get cursor position
    TextPosition getCursorPosition() const;

    /// Get visual affinity of the active caret endpoint.
    CaretAffinity getCaretAffinity() const;

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

    /// Start linked editing mode with externally built tab stop groups
    /// Ranges must already point to correct positions in document
    EditorActionResult startLinkedEditing(Vector<TabStopGroup>&& groups);

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

#pragma region[IME]

    ImeState beginImeSession(ImeMutationModel mutation_model);

    EditorActionResult endImeSession(uint64_t session_id);

    EditorActionResult applyImeCommands(const ImeCommandBatch& batch);

    EditorActionResult applyImeTextUpdates(const ImeTextUpdateBatch& batch);

    ImeState getImeState(uint64_t session_id) const;

    ImeTextContext getImeContext(uint64_t session_id, ImeTextSource source, int64_t start_utf16,
                                 int64_t length_utf16) const;

    /// Get current composition state
    const std::optional<CompositionState>& getCompositionState() const;

    /// Whether a preedit is active
    bool hasPreedit() const;

#pragma endregion

#pragma region[Navigation & Decorations]

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

    /// Set document highlight decorations for given line
    /// @param line Line number
    /// @param highlights Document highlight list
    EditorActionResult setLineDocumentHighlights(size_t line, Vector<DocumentHighlight>&& highlights);

    /// Batch set document highlight decorations for multiple lines
    /// @param entries Array of line->document highlight list pairs
    EditorActionResult setBatchLineDocumentHighlights(Vector<std::pair<size_t, Vector<DocumentHighlight>>>&& entries);

    /// Clear all document highlight decorations
    EditorActionResult clearDocumentHighlights();

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
      PointerCursorType cursor_type{PointerCursorType::TEXT};
    };

    struct ActionSnapshot {
      CaretState caret;
      float scroll_x{0};
      float scroll_y{0};
      float scale{1};
      PointerCursorType pointer_cursor_type{PointerCursorType::TEXT};
      HitTarget active_hit_target;
      std::optional<CompositionState> composition;
      bool ime_session_active{false};
    };

    struct EditTransaction;

    SharedPtr<TextMeasurer> m_measurer_;
    EditorOptions m_options_;
    EditorSettings m_settings_;
    SharedPtr<Document> m_document_;
    SharedPtr<DecorationManager> m_decorations_;
    UniquePtr<TextLayout> m_text_layout_;
    UniquePtr<EditorInteraction> m_interaction_;
    UniquePtr<RenderModelComposer> m_render_model_composer_;
    UniquePtr<UndoManager> m_undo_manager_;
    KeyResolver m_key_resolver_;

    Size m_viewport_;
    ViewState m_view_state_;
    IntRange m_visible_line_range_;

    /// Unified caret state.
    CaretState m_caret_;
    /// Horizontal screen coordinate retained across consecutive vertical moves.
    bool m_has_preferred_cursor_x_{false};
    float m_preferred_cursor_x_{0};

    std::optional<ImeSessionState> m_ime_session_;
    uint64_t m_next_ime_session_id_{1};

    /// Linked editing session (nullptr means not in linked editing mode)
    UniquePtr<LinkedEditingSession> m_linked_editing_session_;

    /// Bracket pair list (default (){}[])
    Vector<BracketPair> m_bracket_pairs_{
        {U'(', U')'},
        {U'{', U'}'},
        {U'[', U']'},
    };

    /// Auto-closing pair list (empty = disabled)
    Vector<BracketPair> m_auto_closing_pairs_;

    /// Exact bracket match positions set from outside
    TextPosition m_external_bracket_open_;
    TextPosition m_external_bracket_close_;
    bool m_has_external_brackets_{false};

    UniquePtr<std::atomic<uint64_t>> m_search_generation_{makeUnique<std::atomic<uint64_t>>(0)};
    SearchState m_search_state_;
    Vector<SearchMatch> m_search_matches_;
    Vector<Vector<uint32_t>> m_search_match_indices_by_line_;
    SharedPtr<SearchResult> m_pending_search_result_;
    SharedPtr<const SearchState> m_published_search_state_{makeShared<const SearchState>(SearchState{})};

    /// Hovered clickable hit target for interactive runs such as CodeLens and Link.
    HitTarget m_hover_hit_target_;
    /// Pressed clickable hit target.
    HitTarget m_press_hit_target_;
    /// Whether the primary mouse button is currently pressed.
    bool m_mouse_button_down_{false};
    /// Last mouse point reported by the platform for pointer presentation refresh.
    PointF m_last_mouse_point_;
    bool m_has_last_mouse_point_{false};
    /// Current pointer cursor type for the last observed mouse location.
    PointerCursorType m_pointer_cursor_type_{PointerCursorType::TEXT};

    /// Max character distance for built-in bracket scan
    static constexpr size_t kMaxBracketScanChars = 10000;

#pragma region[Setup & View State Internals]

    /// Mark all logical lines as layout dirty
    void markAllLinesDirty(bool reset_heights = false);
    void normalizeScrollState();

#pragma endregion

#pragma region[Rendering & Input Internals]

    /// Presentation-state helpers for clickable decoration hot targets.
    void clearHoverHitTarget();
    void clearPressHitTarget();
    HitTarget getActiveHitTarget() const;
    PointerProbeResult probePointer(const PointF& point, KeyModifier modifiers) const;
    bool updatePointerHitTargetLifecycle(const GestureEvent& event, const HitTarget& primary_hot_target);
    ActionSnapshot captureActionSnapshot() const;
    EditorActionResult finishAction(const ActionSnapshot& before, EditorActionSource source, bool handled,
                                    TextEditResult edit_result = {}, bool force_redraw = false,
                                    bool decoration_changed = false);
    EditorActionResult finishInteractionAction(const ActionSnapshot& before, InteractionResult interaction_result,
                                               EditorActionSource source, EventType event_type = EventType::UNDEFINED,
                                               bool decoration_changed = false);

#pragma endregion

#pragma region[Editing & Cursor Internals]

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
    TextEditResult finishCompositionForAction();
    static void appendTextEditResult(TextEditResult& target, TextEditResult&& source);
    TextEditResult insertSnippetInternal(const U8String& snippet_template);
    void startLinkedEditingInternal(Vector<TabStopGroup>&& groups);
    bool linkedEditingNextTabStopInternal();
    bool linkedEditingPrevTabStopInternal();
    void cancelLinkedEditingInternal();
    void finishLinkedEditingInternal();
    bool hasValidLinkedEditingGroup() const;
    std::optional<Vector<TextEdit>> planLinkedEdit(const TextRange& range, const U8String& text) const;
    /// Linked editing: apply a local replacement and return one edit result
    TextEditResult applyLinkedEditWithResult(const TextRange& range, const U8String& text);
    /// Linked editing: jump to target tab stop and select default text
    void activateCurrentTabStop();
    TextPosition clampDocumentPosition(const TextPosition& position, bool prefer_right,
                                       bool line_overflow_to_end) const;
    TextRange clampDocumentRange(const TextRange& range, bool collapse_point_range, bool line_overflow_to_end) const;
    void setCursorPositionInternal(const TextPosition& position, CaretAffinity affinity = CaretAffinity::DOWNSTREAM,
                                   bool preserve_preferred_cursor_x = false);
    void setSelectionInternal(const TextRange& range, CaretAffinity affinity = CaretAffinity::DOWNSTREAM,
                              bool preserve_preferred_cursor_x = false);
    /// Update cursor movement (handle selection extension logic)
    void moveCursorTo(const TextPosition& new_pos, bool extend_selection,
                      CaretAffinity affinity = CaretAffinity::DOWNSTREAM, bool preserve_preferred_cursor_x = false);
    void restoreCaretState(const CaretState& caret);
    bool hasDistinctCaretAffinities(const TextPosition& position);
    size_t documentUtf16Length() const;
    TextRange textRangeFromUtf16Offsets(size_t start_offset, size_t end_offset) const;
    SearchSnapshot buildSearchSnapshot(const SearchRequest& request, uint64_t generation) const;
    void publishSearchState(const SearchState& state);
    void publishPendingSearchResult(SearchResult&& result);
    void clearPendingSearchResult();
    void drainPendingSearchResult();
    void installSearchResult(SearchResult&& result);
    void rebuildSearchLineIndex();
    void markSearchStaleForDocumentChange();
    void noteDocumentContentChanged();
    void chooseCurrentSearchMatch(SearchResult& result) const;
    void chooseCurrentSearchMatch(SearchResult& result, const TextPosition& position) const;
    size_t firstSearchMatchAtOrAfter(const TextPosition& position) const;
    void selectSearchMatch(size_t index);
    /// Calculate new cursor position after inserting UTF8 text
    TextPosition calcPositionAfterInsert(const TextPosition& start, const U8String& text) const;
    /// Apply non-overlapping replacements that share one pre-edit coordinate space.
    TextEditResult applyEditBatch(const Vector<TextEdit>& edits, bool update_fold_state = true);
    /// Build and store one atomic history entry after the final caret is known.
    void recordHistory(const Vector<TextChange>& changes, const CaretState& caret_before, const CaretState& caret_after,
                       bool allows_merge = false);
    /// Unified edit entry: apply document edit and record undo operation
    /// @param range Range to replace (for pure insert, start == end)
    /// @param new_text New text (for pure delete, use empty string)
    /// @param record_undo Whether to record in undo stack (pass false during undo/redo)
    /// @return Exact change info
    TextEditResult applyEdit(const TextRange& range, const U8String& new_text, bool record_undo = true);

#pragma endregion

#pragma region[Navigation & Decorations Internals]

    bool foldAtInternal(size_t line);
    bool unfoldAtInternal(size_t line);
    bool toggleFoldAtInternal(size_t line);
    void foldAllInternal();
    void unfoldAllInternal();
    /// Sync fold state in DecorationManager to each LogicalLine.is_fold_hidden
    void syncFoldState();

    /// Auto unfold when edit range overlaps folded region
    void autoUnfoldForEdit(const TextRange& range);
    /// Place cursor by screen coordinates
    void placeCursorAt(const PointF& screen_point);
    /// Select word at screen coordinates
    void selectWordAt(const PointF& screen_point);

#pragma endregion

#pragma region[IME Internals]

    const std::optional<CompositionState>& compositionState() const;
    CaretState transformCaretForChanges(const CaretState& caret, const Vector<TextChange>& changes) const;
    bool isDocumentRangeValid(const TextRange& range) const;
    bool validateTransaction(const EditTransaction& transaction) const;
    void beginComposition(const TextRange& range, EditTransaction& transaction);
    void replaceCompositionText(const U8String& text, EditTransaction& transaction);
    bool stageLinkedEdit(const TextRange& range, const U8String& text, EditTransaction& transaction);
    void appendLinkedCompositionEdits(const CompositionState& state, const TextRange& baseline_range,
                                      const U8String& final_text_raw, EditTransaction& transaction);
    bool linkedRangesAffectedByChanges(const Vector<TextChange>& changes) const;
    void settleComposition(const U8String& final_text_raw, EditTransaction& transaction, bool replace_current_text);
    void cancelComposition(EditTransaction& transaction);
    TextEditResult commitTransaction(EditTransaction& transaction);
    ImeActionResult applyTextUpdatePlan(const Vector<TextEdit>& edits,
                                        const std::optional<TextRange>& composition_after,
                                        const std::optional<TextRange>& rollover_baseline,
                                        const U8String& composition_text, const CaretState& caret_after,
                                        bool finish_after);
    ImeActionResult applyCommandBatch(const Vector<ImeCommand>& commands);
    TextEditResult finishPreedit();
    TextEditResult cancelPreedit();
    Vector<TextRange> deletionRangesForCaret(const CaretState& caret, size_t before_length, size_t after_length,
                                             ImeTextUnit text_unit) const;
    ImeActionResult rejectImeMutation();
    ImeState buildImeState() const;
    ImeState emptyImeState(ImeResultCode result_code) const;
    bool hasMatchingImeSession(uint64_t session_id) const;
    bool isImeCommandSession() const;
    bool isImeTextUpdateSession() const;
    void closeImeSession();
    bool validateImeCommand(const ImeCommand& command) const;
    bool validateImeTextUpdateStep(const ImeTextUpdateStep& step) const;
    EditorActionResult finishImeAction(const ActionSnapshot& before, const ImeActionResult& ime_result);

#pragma endregion
  };

}

#endif //SWEETEDITOR_EDITOR_CORE_H
