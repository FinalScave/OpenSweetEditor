//
// Created by Scave on 2025/12/1.
//
#ifndef SWEETEDITOR_EDITOR_CORE_H
#define SWEETEDITOR_EDITOR_CORE_H

#include <document.h>
#include <visual.h>
#include <gesture.h>
#include <layout.h>
#include <undo.h>
#include <linked_editing.h>

namespace NS_SWEETEDITOR {
  /// Bracket pair definitions (for match highlight + TODO: auto close/surround selection)
  struct BracketPair {
    char32_t open;            ///< Opening bracket char, like '('
    char32_t close;           ///< Closing bracket char, like ')'
    bool auto_close {true};   ///< Auto insert closing char when typing open char (reserved)
    bool surround {true};     ///< Use this pair to wrap selected text (reserved)
  };

  /// Construction-time immutable options for EditorCore
  struct EditorOptions {
    /// Threshold to treat a gesture as move; below this it is a tap
    float touch_slop {10};
    /// Double tap time threshold
    int64_t double_tap_timeout {300};
    /// Long press time threshold
    int64_t long_press_ms {500};
    /// Max undo stack size (0 = unlimited)
    size_t max_undo_stack_size {512};

    TouchConfig simpleAsTouchConfig() const;
    U8String dump() const;
  };

  /// Selection handle appearance and touch configuration
  struct HandleConfig {
    /// Water-drop circle radius
    float radius {22.0f};
    /// Distance from water-drop circle center to the tip
    float center_dist {56.0f};
    /// Cursor vertical line width
    float line_width {3.0f};
    /// Touch hot-zone expansion around the vertical line
    float touch_padding {10.0f};
    /// Vertical offset for drag position (moves finger up to avoid occlusion)
    float drag_y_offset {50.0f};
  };

  enum class ScrollbarMode : uint8_t {
    ALWAYS = 0,
    TRANSIENT = 1,
    NEVER = 2,
  };

  enum class ScrollbarTrackTapMode : uint8_t {
    JUMP = 0,
    DISABLED = 1,
  };

  /// Scrollbar configuration (geometry + interaction behavior)
  struct ScrollbarConfig {
    /// Scrollbar track/thumb thickness in pixels
    float thickness {10.0f};
    /// Minimum thumb length in pixels
    float min_thumb {24.0f};
    /// Extra thumb hit-test padding in pixels (applied on all sides)
    float thumb_hit_padding {0.0f};
    /// Visibility mode across platforms
    ScrollbarMode mode {ScrollbarMode::ALWAYS};
    /// Whether thumb drag interaction is enabled
    bool thumb_draggable {true};
    /// Track tap behavior
    ScrollbarTrackTapMode track_tap_mode {ScrollbarTrackTapMode::JUMP};
    /// Delay before hide (TRANSIENT mode)
    uint16_t fade_delay_ms {700};
    /// Fade duration in milliseconds (TRANSIENT mode; used for both fade-in and fade-out)
    uint16_t fade_duration_ms {300};
  };

  /// Runtime-mutable editor settings (modified via individual setters)
  struct EditorSettings {
    /// Max scale factor
    float max_scale {5};
    /// Read-only mode; block all edit actions (insert/delete/undo/redo/IME input)
    bool read_only {false};
    /// Auto indent mode; default keeps previous line indent
    AutoIndentMode auto_indent_mode {AutoIndentMode::KEEP_INDENT};
    /// Whether to enable IME composition; if off, compositionUpdate falls back to direct insertText
    bool enable_composition {false};
    /// Selection handle configuration
    HandleConfig handle;
    /// Scrollbar geometry configuration
    ScrollbarConfig scrollbar;
    /// Extra horizontal padding between gutter split and text rendering start (pixels)
    float content_start_padding {0.0f};
    /// Whether to render the gutter split line
    bool show_split_line {true};
    /// Current line render mode
    CurrentLineRenderMode current_line_render_mode {CurrentLineRenderMode::BACKGROUND};

    U8String dump() const;
  };

  /// Core metric data needed by scrollbars
  struct ScrollMetrics {
    float scale {1};
    float scroll_x {0};
    float scroll_y {0};
    float max_scroll_x {0};
    float max_scroll_y {0};
    float content_width {0};
    float content_height {0};
    float viewport_width {0};
    float viewport_height {0};
    float text_area_x {0};
    float text_area_width {0};
    bool can_scroll_x {false};
    bool can_scroll_y {false};
  };

  /// One text change (exact change info at one edit location)
  struct TextChange {
    /// Replaced/deleted text range (coordinates before the operation)
    TextRange range;
    /// Old text (used only in C++ core, not serialized to platform layer)
    U8String old_text;
    /// New text (content after insert/replace; empty for pure delete)
    U8String new_text;
  };

  /// Full result of a text edit operation (may include many changes)
  struct TextEditResult {
    /// Whether there is an actual change
    bool changed {false};
    /// List of all changes (normal edit: 1; linked edit/compound undo/redo: maybe many)
    std::vector<TextChange> changes;
    /// Cursor position before operation
    TextPosition cursor_before;
    /// Cursor position after operation
    TextPosition cursor_after;
  };

  /// Keyboard event handling result
  struct KeyEventResult {
    /// Whether it was handled (event consumed)
    bool handled {false};
    /// Whether document content changed (needs incremental sync)
    bool content_changed {false};
    /// Whether cursor position changed
    bool cursor_changed {false};
    /// Whether selection changed
    bool selection_changed {false};
    /// Exact text edit info (valid when content_changed is true)
    TextEditResult edit_result;
  };

  /// IME composition state
  struct CompositionState {
    /// Whether composition is active
    bool is_composing {false};
    /// Start position of composition (position in document)
    TextPosition start_position;
    /// Current composing text (UTF8)
    U8String composing_text;
    /// UTF16 column count of current composing text (for exact cursor placement)
    size_t composing_columns {0};
  };

  /// Screen-space rectangle for cursor/text position (for panel placement)
  struct CursorRect {
    float x {0};       ///< x coordinate relative to top-left of editor view
    float y {0};       ///< y coordinate relative to top-left of editor view (line top)
    float height {0};  ///< Line height (same as cursor height)
  };

  /// Editor core class
  class EditorCore {
  public:
    explicit EditorCore(const Ptr<TextMeasurer>& measurer, const EditorOptions& options);

    /// Set selection handle configuration at runtime
    /// @param config Handle appearance and touch parameters
    void setHandleConfig(const HandleConfig& config);

    /// Set scrollbar configuration at runtime
    /// @param config Scrollbar geometry/behavior parameters
    void setScrollbarConfig(const ScrollbarConfig& config);

    /// Load text content
    /// @param document Document instance
    void loadDocument(const Ptr<Document>& document);

#pragma region [Appearance-Font]
    /// Set editor viewport size
    /// @param viewport Viewport area
    void setViewport(const Viewport& viewport);

    /// Reset text measurement, usually called when editor font is reset
    void resetMeasurer();

    /// Set auto wrap mode
    /// @param mode WrapMode
    void setWrapMode(WrapMode mode);

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
#pragma endregion

#pragma region [Rendering]
    /// Get editor text-style registry
    /// @return Text-style registry
    Ptr<TextStyleRegistry> getTextStyleRegistry() const;

    /// Build editor render model
    /// @param model Input EditorRenderModel
    void buildRenderModel(EditorRenderModel& model);

    /// Get current editor state, including scale, scroll, and more
    ViewState getViewState() const;

    /// Get full metric data needed for scrollbar calculations
    ScrollMetrics getScrollMetrics() const;

    /// Get editor layout metrics
    LayoutMetrics& getLayoutMetrics() const;
#pragma endregion

#pragma region [Gesture-KeyEvent]
    /// Handle gesture event
    /// @param event Gesture data
    /// @return Gesture handling result (includes editor state)
    GestureResult handleGestureEvent(const GestureEvent& event);

    /// Called by platform timer (~16ms interval) while needs_edge_scroll is true.
    /// Scrolls the viewport and updates the selection based on saved edge-scroll state.
    /// @return Updated gesture result (platform should redraw; check needs_edge_scroll to decide
    ///         whether to continue the timer)
    GestureResult tickEdgeScroll();

    /// Handle keyboard event (optional default key mapping; platform can bypass and call atomic edit APIs directly)
    /// @param event Keyboard event data
    /// @return Keyboard event handling result
    KeyEventResult handleKeyEvent(const KeyEvent& event);
#pragma endregion

#pragma region [Editing]
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
#pragma endregion

#pragma region [Line-Operation]
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
#pragma endregion

#pragma region [Undo-Redo]
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
#pragma endregion

#pragma region [Cursor-Selection]
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
#pragma endregion

#pragma region [IME-Composition]
    /// Notify editor that IME composition starts
    /// Called by platform side when compositionstart / composingText starts
    void compositionStart();

    /// Update IME composition text
    /// Called by platform side when compositionupdate / setComposingText is received
    /// @param text Current composing text (UTF8), full text each time instead of delta
    void compositionUpdate(const U8String& text);

    /// End IME composition and commit final text
    /// Called by platform side when compositionend / commitText / finishComposingText is received
    /// @param committed_text Final committed text (UTF8); if empty, use current composing text
    /// @return Exact change info
    TextEditResult compositionEnd(const U8String& committed_text);

    /// Cancel IME composition (commit no text)
    void compositionCancel();

    /// Get current composition state
    const CompositionState& getCompositionState() const;

    /// Whether composition is active
    bool isComposing() const;

    /// Set whether IME composition is enabled
    void setCompositionEnabled(bool enabled);

    /// Get whether IME composition is enabled
    bool isCompositionEnabled() const;
#pragma endregion

#pragma region [ReadOnly]
    /// Set read-only mode
    /// @param read_only true=read-only (block all edit actions), false=editable
    void setReadOnly(bool read_only);

    /// Get whether read-only mode is active
    bool isReadOnly() const;
#pragma endregion

#pragma region [AutoIndent]
    /// Set auto indent mode
    /// @param mode Auto indent mode
    void setAutoIndentMode(AutoIndentMode mode);

    /// Get current auto indent mode
    AutoIndentMode getAutoIndentMode() const;
#pragma endregion

#pragma region [Cursor-ScreenRect]
    /// Get screen-space rectangle for any text position (for floating panel placement)
    /// @param position Text position (line, column)
    /// @return Position coordinates and line height inside editor view
    CursorRect getPositionScreenRect(const TextPosition& position);

    /// Get screen-space rectangle of current cursor position (shortcut)
    /// @return Current cursor coordinates and line height inside editor view
    CursorRect getCursorScreenRect();
#pragma endregion

#pragma region [LinkedEditing]
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

#pragma region [Scroll-Goto]
    /// Scroll to target line
    /// @param line Line number
    /// @param behavior Scroll behavior
    void scrollToLine(size_t line, ScrollBehavior behavior);

    /// Go to target line and column (scroll + cursor placement)
    /// @param line Line number (0-based)
    /// @param column Column number (0-based)
    void gotoPosition(size_t line, size_t column);

    /// Manually set editor scroll offset
    /// @param scroll_x Horizontal scroll offset
    /// @param scroll_y Vertical scroll offset
    void setScroll(float scroll_x, float scroll_y);
#pragma endregion

#pragma region [Decorations]
    /// Register a highlight style
    /// @param style_id Style ID
    /// @param style Text style definition
    void registerTextStyle(uint32_t style_id, TextStyle&& style);

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
    void setBracketPairs(Vector<BracketPair> pairs);

    /// Set exact bracket match result from outside (override built-in char scan)
    /// @param open Opening bracket position
    /// @param close Closing bracket position
    void setMatchedBrackets(const TextPosition& open, const TextPosition& close);

    /// Clear external bracket match result (fall back to built-in char scan)
    void clearMatchedBrackets();
#pragma endregion
  private:
    Ptr<TextMeasurer> m_measurer_;
    EditorOptions m_options_;
    EditorSettings m_settings_;
    Ptr<Document> m_document_;
    Ptr<DecorationManager> m_decorations_;
    UPtr<GestureHandler> m_gesture_handler_;
    UPtr<TextLayout> m_text_layout_;
    UPtr<UndoManager> m_undo_manager_;
    // Cache of render height for each logical line
    HashMap<size_t, float> m_line_heights_;

    Viewport m_viewport_;
    ViewState m_view_state_;

    /// Logical cursor position in text
    TextPosition m_cursor_position_;
    /// Selection range (start = anchor, end = active end/cursor end)
    TextRange m_selection_;
    /// Whether selection is active
    bool m_has_selection_ {false};

    /// Drag target for selection handle
    enum class HandleDragTarget { NONE, START, END };
    HandleDragTarget m_dragging_handle_ {HandleDragTarget::NONE};

    /// Drag target for scrollbar interaction
    enum class ScrollbarDragTarget { NONE, VERTICAL, HORIZONTAL };
    /// Last user-scroll interaction time in ms (used by TRANSIENT scrollbar mode)
    int64_t m_scrollbar_last_interaction_ms_ {0};
    /// Start timestamp of current transient scrollbar cycle (used by fade-in)
    int64_t m_scrollbar_cycle_start_ms_ {0};
    ScrollbarDragTarget m_dragging_scrollbar_ {ScrollbarDragTarget::NONE};
    /// Scrollbar drag start pointer position (screen coordinates)
    PointF m_scrollbar_drag_start_point_;
    /// Scroll value at drag start
    float m_scrollbar_drag_start_scroll_x_ {0};
    float m_scrollbar_drag_start_scroll_y_ {0};
    /// Thumb travel distance in pixels
    float m_scrollbar_drag_travel_x_ {0};
    float m_scrollbar_drag_travel_y_ {0};
    /// Max scroll range cached at drag start
    float m_scrollbar_drag_max_scroll_x_ {0};
    float m_scrollbar_drag_max_scroll_y_ {0};

    /// Cached screen positions of selection handles (for hit test, updated each buildRenderModel frame)
    PointF m_cached_start_handle_pos_;
    PointF m_cached_end_handle_pos_;
    float m_cached_handle_height_ {0};
    bool m_cached_handles_valid_ {false};

    /// Edge-scroll state: saved when finger is near viewport edge during drag.
    /// The platform timer calls tickEdgeScroll() which uses this state to scroll + update selection.
    struct EdgeScrollState {
      bool active {false};         ///< Whether edge scrolling is needed
      float speed {0};             ///< Scroll speed in pixels per tick (positive = down, negative = up)
      PointF last_screen_point;    ///< Last finger position (used to re-run hitTest after scroll)
      bool is_handle_drag {false}; ///< true = handle drag, false = select drag
      bool is_mouse {false};       ///< Mouse drag (no y-offset)
    };
    EdgeScrollState m_edge_scroll_;

    /// IME composition state
    CompositionState m_composition_;
    /// Whether current composing text is already inserted into document (for safe remove)
    bool m_composition_text_in_document_ {false};

    /// Linked editing session (nullptr means not in linked editing mode)
    UPtr<LinkedEditingSession> m_linked_editing_session_;

    /// Bracket pair list (default (){}[])
    Vector<BracketPair> m_bracket_pairs_ {
      {U'(', U')', true, true},
      {U'{', U'}', true, true},
      {U'[', U']', true, true},
    };

    /// Exact bracket match positions set from outside
    TextPosition m_external_bracket_open_;
    TextPosition m_external_bracket_close_;
    bool m_has_external_brackets_ {false};

    /// Max character distance for built-in bracket scan
    static constexpr size_t kMaxBracketScanChars = 10000;

    /// Check whether touch point hits a selection handle
    /// @return Hit drag target (NONE / START / END)
    HandleDragTarget hitTestHandle(const PointF& screen_point) const;
    /// Drag selection handle to target position
    void dragHandleTo(HandleDragTarget target, const PointF& screen_point);
    /// Mark scrollbar interaction timestamp for transient visibility/alpha timeline
    void markScrollbarInteraction();

    /// Delete selection and place cursor at selection start
    void deleteSelection();
    /// Place cursor by screen coordinates
    void placeCursorAt(const PointF& screen_point);
    /// Select word at screen coordinates
    void selectWordAt(const PointF& screen_point);
    /// Drag selection to screen coordinates
    /// @param is_mouse true for mouse drag (no y-offset), false for touch long-press drag (apply y-offset)
    void dragSelectTo(const PointF& screen_point, bool is_mouse = false);
    /// Ensure cursor is visible after edit scroll
    void ensureCursorVisible();
    /// Compute edge-scroll state from finger position (does NOT scroll; just updates m_edge_scroll_).
    /// Called from dragHandleTo / dragSelectTo to decide whether edge scrolling is needed.
    void updateEdgeScrollState(const PointF& screen_point, bool is_handle_drag, bool is_mouse);
    /// Update cursor movement (handle selection extension logic)
    void moveCursorTo(const TextPosition& new_pos, bool extend_selection);
    /// Get normalized selection (start < end)
    TextRange getNormalizedSelection() const;
    /// Calculate UTF16 column count for UTF8 text
    static size_t calcUtf16Columns(const U8String& text);
    /// Calculate new cursor position after inserting UTF8 text
    TextPosition calcPositionAfterInsert(const TextPosition& start, const U8String& text) const;
    /// Remove temporary composing text (remove from document)
    void removeComposingText();
    /// Unified edit entry: apply document edit and record undo operation
    /// @param range Range to replace (for pure insert, start == end)
    /// @param new_text New text (for pure delete, use empty string)
    /// @param record_undo Whether to record in undo stack (pass false during undo/redo)
    /// @return Exact change info
    TextEditResult applyEdit(const TextRange& range, const U8String& new_text, bool record_undo = true);

    /// Fill cursor render data (position, height, current line background)
    void buildCursorModel(EditorRenderModel& model, float line_height);

    /// Fill IME composition decoration (underline area)
    void buildCompositionDecoration(EditorRenderModel& model, float line_height, float font_height);

    /// Fill selection highlight rects and selection handles
    void buildSelectionRects(EditorRenderModel& model, float line_height);

    /// Fill linked editing highlight rects
    void buildLinkedEditingRects(EditorRenderModel& model, float line_height);

    /// Fill bracket match highlight rects (built-in char scan + external override)
    void buildBracketHighlightRects(EditorRenderModel& model, float line_height);

    /// Generate render primitives from guide data in DecorationManager
    void buildGuideSegments(EditorRenderModel& model, float line_height);

    /// Generate render decorations from diagnostic data in DecorationManager
    void buildDiagnosticDecorations(EditorRenderModel& model, float line_height);

    /// Handle scrollbar click/drag gestures in core; return true when consumed
    bool handleScrollbarGesture(const GestureEvent& event, GestureResult& result);

    /// Compute vertical/horizontal scrollbar models from current view state
    void computeScrollbarModels(ScrollbarModel& vertical, ScrollbarModel& horizontal) const;

    /// Build scrollbar geometry in render model
    void buildScrollbarModel(EditorRenderModel& model) const;

    /// Sync fold state in DecorationManager to each LogicalLine.is_fold_hidden
    void syncFoldState();

    /// Auto unfold when edit range overlaps folded region
    void autoUnfoldForEdit(const TextRange& range);

    /// Fill current editor state into GestureResult (remove duplicate assignments)
    void fillGestureResult(GestureResult& result) const;
    /// Mark all logical lines as layout dirty
    void markAllLinesDirty();
    /// Reset composition state (clear composing flag and text)
    void resetCompositionState();
    void normalizeScrollState();

    /// Linked editing: apply synced replace to all linked ranges in current tab stop, return all changes
    std::vector<TextChange> performLinkedEdits(const U8String& new_text);

    /// Linked editing: apply replace and return one edit result (based on primary range)
    TextEditResult applyLinkedEditsWithResult(const U8String& new_text);

    /// Linked editing: jump to target tab stop and select default text
    void activateCurrentTabStop();
  };

  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextChange, range, old_text, new_text)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(TextEditResult, changed, changes, cursor_before, cursor_after)
  NLOHMANN_DEFINE_TYPE_NON_INTRUSIVE(KeyEventResult, handled, content_changed, cursor_changed, selection_changed, edit_result)
}

#endif //SWEETEDITOR_EDITOR_CORE_H

