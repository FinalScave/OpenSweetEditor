#ifndef SWEETEDITOR_EDITOR_TYPES_H
#define SWEETEDITOR_EDITOR_TYPES_H

#include "foundation.h"
#include "gesture.h"

namespace NS_SWEETEDITOR {
  /// Bracket pair definition (open/close character pair)
  struct BracketPair {
    char32_t open;            ///< Opening bracket char, like '('
    char32_t close;           ///< Closing bracket char, like ')'
  };

  /// Construction-time immutable options for EditorCore
  struct EditorOptions {
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
    size_t max_undo_stack_size {512};
    /// Multi-chord key binding timeout in milliseconds
    int64_t key_chord_timeout_ms {2000};
    /// Whether selectAll() should reveal the selection end after updating the selection
    bool reveal_selection_end_on_select_all {false};

    TouchConfig simpleAsTouchConfig() const;
    U8String dump() const;
  };

  /// Selection handle hit-test configuration.
  /// All geometry is owned by the platform drawing layer; C++ only needs hit areas.
  struct HandleConfig {
    /// Hit area for the start handle, as an offset rect relative to the cursor bottom anchor (handle tip)
    OffsetRect start_hit_offset {-32.1f, -8.0f, 8.0f, 32.1f};
    /// Hit area for the end handle, as an offset rect relative to the cursor bottom anchor (handle tip)
    OffsetRect end_hit_offset {-8.0f, -8.0f, 32.1f, 32.1f};
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
    /// When true, backspace on leading whitespace unindents to the previous tab stop,
    /// or merges the line upward if the entire line is blank
    bool backspace_unindent {true};
    /// When true, Tab inserts spaces up to the next tab stop instead of a literal '\t'
    bool insert_spaces {false};
    /// Whether to allow visible IME preedit in the document
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
    /// Whether gutter stays fixed during horizontal scroll (true=fixed, false=scrolls with content)
    bool gutter_sticky {true};
    /// Whether gutter area is visible (false = hide line numbers, icons, fold arrows)
    bool gutter_visible {true};
    /// Current auto-wrap mode
    WrapMode wrap_mode {WrapMode::NONE};

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
    /// Resolved command (for platform-handled commands like COPY/PASTE/CUT)
    EditorCommand command {EditorCommand::NONE};
  };

  enum struct ImeTextUnit {
    UTF16_CODE_UNIT,
    CODE_POINT,
  };

  enum struct ImeScriptClass {
    UNKNOWN,
    LATIN,
    CJK,
    KANA,
    HANGUL,
  };

  enum struct ImePreeditStorage {
    NONE,
    VISIBLE_DOCUMENT_COMPOSITION,
    SHADOW_ONLY,
    HIDDEN_AWAITING_COMMIT,
  };

  enum struct ImeContextPolicy {
    NONE,
    LIMITED_FOR_CANDIDATES,
    CURRENT_TOKEN,
    CURRENT_LINE,
  };

  /// Core-owned policy that decides how platform IME state is represented.
  struct ImeCompositionPolicy {
    bool allow_preedit {true};
    bool allow_document_range_preedit {true};
    bool allow_latin_reconversion {true};
    bool allow_non_latin_preedit {false};
    bool keep_preedit_at_word_end {false};
    ImeContextPolicy enabled_context_policy {ImeContextPolicy::LIMITED_FOR_CANDIDATES};
    ImeContextPolicy disabled_context_policy {ImeContextPolicy::LIMITED_FOR_CANDIDATES};
  };

  /// Core-owned IME session bookkeeping that is not exposed to platform layers.
  struct ImeSessionState {
    bool preedit_text_in_document {false};
    bool preedit_replaces_document_range {false};
    TextRange preedit_replaced_range;
    U8String preedit_replaced_text;
    bool visible_composition_exposed_to_platform {false};
    bool has_shadow_preedit {false};
    U8String shadow_preedit_text;
    ImeScriptClass shadow_script_class {ImeScriptClass::UNKNOWN};
    bool suppress_next_composing_commit {false};
    U8String suppressed_composing_commit_text;
    bool has_candidate_commit_window {false};
    TextRange candidate_committed_range;
    U8String candidate_committed_text;
    bool candidate_deleted_to_prefix {false};
    bool suppress_candidate_exact_range {false};
    bool candidate_exact_range_suppressed {false};
    bool plain_latin_input_lock {false};
    U8String plain_latin_preedit_text;
  };

  /// Snapshot that platform layers use to synchronize IME selection and marked ranges.
  struct ImeSyncSnapshot {
    TextPosition cursor;
    TextRange selection;
    bool has_selection {false};
    bool has_composing_session {false};
    bool has_visible_composition_range {false};
    TextRange visible_composition_range;
    bool has_platform_marked_range {false};
    TextRange platform_marked_range;
    ImePreeditStorage preedit_storage {ImePreeditStorage::NONE};
    ImeContextPolicy context_policy {ImeContextPolicy::NONE};
    bool clear_platform_preedit {false};
  };

  /// Result of a semantic IME action handled by the core.
  struct ImeActionResult {
    bool handled {false};
    bool content_changed {false};
    bool cursor_changed {false};
    bool selection_changed {false};
    TextEditResult edit_result;
    ImeSyncSnapshot sync;
  };

  /// IME composition ownership.
  enum struct CompositionKind {
    NONE,
    PREEDIT_TEXT,
    DOCUMENT_RANGE,
  };

  enum struct CompositionPhase {
    INACTIVE,
    ACTIVE,
    AWAITING_COMMIT,
  };

  enum struct CompositionFinishReason {
    FINISH,
    FOCUS_LOST,
    CURSOR_MOVED,
    SELECTION_CHANGED,
    CANCELED_BY_PLATFORM,
  };

  /// IME composition state
  struct CompositionState {
    /// Whether composition is visible and active
    bool is_composing {false};
    /// Whether there is an active or pending composition session
    bool has_session {false};
    /// Current session phase
    CompositionPhase phase {CompositionPhase::INACTIVE};
    /// Whether composition decoration and IME composing offsets should be exposed
    bool visible {false};
    /// Source and ownership of the active composition
    CompositionKind kind {CompositionKind::NONE};
    /// Start position of composition (position in document)
    TextPosition start_position;
    /// Authoritative document range owned by this composition session
    TextRange anchor_range;
    /// Original text captured from anchor_range
    U8String original_text;
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

}

#endif //SWEETEDITOR_EDITOR_TYPES_H
