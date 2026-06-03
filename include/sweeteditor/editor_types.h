#ifndef SWEETEDITOR_EDITOR_TYPES_H
#define SWEETEDITOR_EDITOR_TYPES_H

#include <sweeteditor/foundation.h>
#include <sweeteditor/keymap.h>

namespace NS_SWEETEDITOR {
  struct TouchConfig;

  /// Editor viewport.
  struct Viewport {
    /// Editor width.
    float width {0};
    /// Editor height.
    float height {0};

    bool valid() const;
    U8String dump() const;
  };

  /// Editor view state.
  struct ViewState {
    /// Scale factor.
    float scale {1};
    /// Horizontal scroll offset.
    float scroll_x {0};
    /// Vertical scroll offset.
    float scroll_y {0};

    U8String dump() const;
  };

  /// Keyboard event data.
  struct KeyEvent {
    /// Key code.
    KeyCode key_code {KeyCode::NONE};
    /// Input text used for regular character input.
    U8String text;
    /// Modifier key state.
    KeyModifier modifiers {KeyModifier::NONE};

    /// Whether this is plain text input.
    bool isTextInput() const;
  };

  enum struct SE_PROTOCOL_ENUM(action, GOTO_TOP) ScrollBehavior {
    /// Make the target line visible at the top.
    GOTO_TOP,
    /// Scroll the target line to the center.
    GOTO_CENTER,
    /// Scroll the target line to the bottom.
    GOTO_BOTTOM,
  };

  /// Unified caret state.
  struct CaretState {
    /// Logical cursor position in text.
    TextPosition cursor;
    /// Selection range where start is the anchor and end is the active side.
    TextRange selection;
    /// Whether there is an active selection.
    bool has_selection {false};

    void setSelection(const TextRange& range);
    void clearSelection();
    TextRange normalizedSelection() const;
  };

  /// Auto-indent modes.
  enum struct SE_PROTOCOL_ENUM(config, NONE) AutoIndentMode {
    /// No auto-indent; new line starts at column 0.
    NONE = 0,
    /// Keep previous line indent.
    KEEP_INDENT = 1,
  };

  /// Auto-wrap modes.
  enum struct SE_PROTOCOL_ENUM(config, NONE) WrapMode {
    /// No wrapping.
    NONE,
    /// Character-level wrapping.
    CHAR_BREAK,
    /// Word-level wrapping.
    WORD_BREAK,
  };

  /// Current line render modes.
  enum struct SE_PROTOCOL_ENUM(config, BACKGROUND) CurrentLineRenderMode {
    /// Fill full line background.
    BACKGROUND = 0,
    /// Draw line border only.
    BORDER = 1,
    /// Disable current-line decoration.
    NONE = 2,
  };

  /// Bracket pair definition (open/close character pair)
  struct BracketPair {
    char32_t open;            ///< Opening bracket char, like '('
    char32_t close;           ///< Closing bracket char, like ')'
  };

  /// Construction-time immutable options for EditorCore
  struct SE_PROTOCOL_IN(config) EditorOptions {
    /// Threshold to treat a gesture as move; below this it is a tap
    float touch_slop {10};
    /// Double tap time threshold
    int64_t double_tap_timeout {300};
    /// Long press time threshold
    int64_t long_press_ms {500};
    /// Fling friction coefficient (higher = faster deceleration)
    float fling_friction {3.5f};
    /// Minimum fling velocity threshold in pixels/second
    float fling_min_velocity {50.0f};
    /// Maximum fling velocity cap in pixels/second
    float fling_max_velocity {8000.0f};
    /// Max undo stack size (0 = unlimited)
    SE_PROTOCOL_WIRE(size_as_u64)
    size_t max_undo_stack_size {512};
    /// Multi-chord key binding timeout in milliseconds
    int64_t key_chord_timeout_ms {2000};
    /// Whether selectAll() should reveal the selection end after updating the selection
    SE_PROTOCOL_WIRE(bool_u8)
    bool reveal_selection_end_on_select_all {false};

    TouchConfig simpleAsTouchConfig() const;
    U8String dump() const;
  };

  /// Selection handle hit-test configuration.
  /// All geometry is owned by the platform drawing layer; C++ only needs hit areas.
  struct SE_PROTOCOL_IN(config) HandleConfig {
    /// Hit area for the start handle, as an offset rect relative to the cursor bottom anchor (handle tip)
    OffsetRect start_hit_offset {-32.1f, -8.0f, 8.0f, 32.1f};
    /// Hit area for the end handle, as an offset rect relative to the cursor bottom anchor (handle tip)
    OffsetRect end_hit_offset {-8.0f, -8.0f, 32.1f, 32.1f};
  };

  enum class SE_PROTOCOL_ENUM(config, ALWAYS) ScrollbarMode : uint8_t {
    ALWAYS = 0,
    TRANSIENT = 1,
    NEVER = 2,
  };

  enum class SE_PROTOCOL_ENUM(config, JUMP) ScrollbarTrackTapMode : uint8_t {
    JUMP = 0,
    DISABLED = 1,
  };

  /// Scrollbar configuration (geometry + interaction behavior)
  struct SE_PROTOCOL_IN(config) ScrollbarConfig {
    /// Scrollbar track/thumb thickness in pixels
    float thickness {10.0f};
    /// Minimum thumb length in pixels
    float min_thumb {24.0f};
    /// Extra thumb hit-test padding in pixels (applied on all sides)
    float thumb_hit_padding {0.0f};
    /// Visibility mode across platforms
    SE_PROTOCOL_WIRE(enum_i32)
    ScrollbarMode mode {ScrollbarMode::ALWAYS};
    /// Whether thumb drag interaction is enabled
    SE_PROTOCOL_WIRE(bool_u8)
    bool thumb_draggable {true};
    /// Track tap behavior
    SE_PROTOCOL_WIRE(enum_i32)
    ScrollbarTrackTapMode track_tap_mode {ScrollbarTrackTapMode::JUMP};
    /// Delay before hide (TRANSIENT mode)
    uint16_t fade_delay_ms {700};
    /// Fade duration in milliseconds (TRANSIENT mode; used for both fade-in and fade-out)
    uint16_t fade_duration_ms {300};
  };

  /// Editor colors resolved by the core when materializing visual runs.
  struct SE_PROTOCOL_IN(config) EditorRenderColors {
    int32_t text_foreground {0};
    int32_t link_foreground {0};
    int32_t active_link_foreground {0};
    int32_t codelens_foreground {0};
    int32_t active_codelens_foreground {0};

    bool operator==(const EditorRenderColors& other) const;
    bool operator!=(const EditorRenderColors& other) const;
  };

  /// Underline shape used by range effects.
  enum struct SE_PROTOCOL_ENUM(config, NONE) RangeEffectUnderlineStyle {
    NONE = 0,
    SOLID = 1,
    DASHED = 2,
    WAVY = 3,
  };

  /// Visual style for a document range effect.
  struct SE_PROTOCOL_VALUE(config) RangeEffectStyle {
    int32_t foreground_color {0};
    int32_t background_color {0};
    int32_t border_color {0};
    int32_t underline_color {0};
    SE_PROTOCOL_WIRE(enum_i32)
    RangeEffectUnderlineStyle underline_style {RangeEffectUnderlineStyle::NONE};

    bool operator==(const RangeEffectStyle& other) const;
    bool operator!=(const RangeEffectStyle& other) const;
  };

  /// Range-effect styles resolved by core and emitted in the render model.
  struct SE_PROTOCOL_IN(config) EditorRangeEffectStyles {
    RangeEffectStyle selection;
    RangeEffectStyle search_match;
    RangeEffectStyle search_current;
    RangeEffectStyle document_highlight_text;
    RangeEffectStyle document_highlight_read;
    RangeEffectStyle document_highlight_write;
    RangeEffectStyle linked_editing_active;
    RangeEffectStyle linked_editing_inactive;
    RangeEffectStyle ime_composition;
    RangeEffectStyle bracket_match;
    RangeEffectStyle diagnostic_error;
    RangeEffectStyle diagnostic_warning;
    RangeEffectStyle diagnostic_info;
    RangeEffectStyle diagnostic_hint;

    bool operator==(const EditorRangeEffectStyles& other) const;
    bool operator!=(const EditorRangeEffectStyles& other) const;
  };

  /// Runtime-mutable editor settings (modified via individual setters)
  struct EditorSettings {
    /// Max scale factor
    float max_scale {5};
    /// Read-only mode; block all edit actions (insert/delete/undo/redo/IME input)
    bool read_only {false};
    /// Auto indent mode; default keeps previous line indent
    AutoIndentMode auto_indent_mode {AutoIndentMode::KEEP_INDENT};
    /// When true, backspace on leading whitespace unindents to the previous tab stop,
    /// or merges the line upward if the entire line is blank
    bool backspace_unindent {true};
    /// When true, Tab inserts spaces up to the next tab stop instead of a literal '\t'
    bool insert_spaces {false};
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
    /// Whether gutter stays fixed during horizontal scroll (true=fixed, false=scrolls with content)
    bool gutter_sticky {true};
    /// Whether gutter area is visible (false = hide line numbers, icons, fold arrows)
    bool gutter_visible {true};
    /// Current auto-wrap mode
    WrapMode wrap_mode {WrapMode::NONE};
    /// Core-resolved editor render colors
    EditorRenderColors render_colors;
    /// Core-resolved range-effect styles
    EditorRangeEffectStyles range_effect_styles;

    U8String dump() const;
  };

  /// Core metric data needed by scrollbars
  struct SE_PROTOCOL_OUT(visual) ScrollMetrics {
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
  struct SE_PROTOCOL_OUT(foundation) TextChange {
    /// Replaced/deleted text range (coordinates before the operation)
    TextRange range;
    /// Old text (used only in C++ core, not serialized to platform layer)
    SE_PROTOCOL_SKIP
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
    /// Resolved command (for platform-handled commands like COPY/PASTE/CUT)
    EditorCommandId command {0};
  };

  /// Screen-space rectangle for cursor/text position (for panel placement)
  struct SE_PROTOCOL_VALUE(visual) CursorRect {
    float x {0};       ///< x coordinate relative to top-left of editor view
    float y {0};       ///< y coordinate relative to top-left of editor view (line top)
    float height {0};  ///< Line height (same as cursor height)
  };

}

#endif //SWEETEDITOR_EDITOR_TYPES_H
