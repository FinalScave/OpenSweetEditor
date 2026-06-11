//
// Created by Scave on 2025/12/8.
//

#ifndef SWEETEDITOR_C_API_H
#define SWEETEDITOR_C_API_H

#ifdef __cplusplus
#include <cstddef>
#include <cstdint>
#else
#include <stddef.h>
#include <stdint.h>
#endif

#if defined(__EMSCRIPTEN__) && defined(SWEETEDITOR_BUILD_WASM_C_ABI)
  #include <emscripten/emscripten.h>
#endif

#if defined(__EMSCRIPTEN__) && defined(SWEETEDITOR_BUILD_WASM_C_ABI)
  #define EDITOR_API EMSCRIPTEN_KEEPALIVE
  #define EDITOR_CALL
  #ifdef __cplusplus
    using U16Char = char16_t;
  #else
    typedef uint16_t U16Char;
  #endif
#elif defined(WINDOWS) || defined(_WIN32) || defined(_WIN64)
  #ifdef SWEETEDITOR_STATIC
    #define EDITOR_API
  #elif defined(SWEETEDITOR_EXPORT)
    #define EDITOR_API __declspec(dllexport)
  #else
    #define EDITOR_API __declspec(dllimport)
  #endif
  #define EDITOR_CALL __stdcall
  #ifdef __cplusplus
    using U16Char = wchar_t;
  #else
    typedef uint16_t U16Char;
  #endif
#else
  #define EDITOR_API __attribute__((visibility("default")))
  #define EDITOR_CALL
  #ifdef __cplusplus
    using U16Char = char16_t;
  #else
    typedef uint16_t U16Char;
  #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// @note General C API conventions in this file:
///   - editor_handle:   EditorCore handle (intptr_t) returned by create_editor
///   - document_handle: Document handle (intptr_t) returned by create_document_xxx
///   - out_size:        For all APIs that return binary payloads, this outputs the byte length
///   - Coordinate system: line / column are both 0-based
///   - Binary payloads use CoreProtocol little-endian encoding. Caller must free returned payloads with free_binary_data
///   - U8String is u32 byte_length followed by UTF-8 bytes
///   - List<T> is u32 count followed by T items
///   - Map-like payload fields are u32 entry_count followed by key/value pairs in insertion order
///   - bool_u8 uses u8 where nonzero means true; bool_i32 uses i32 where nonzero means true
///   - PointF is f32 x followed by f32 y
///   - TextPosition is i32 line followed by i32 column; TextRange is TextPosition start followed by TextPosition end
///   - These common rules are not repeated in each function comment

/// Text measurement callback set, passed when creating EditorCore
typedef struct {
    float (EDITOR_CALL* measure_text_width)(const U16Char* text, int32_t font_style);
    float (EDITOR_CALL* measure_inlay_hint_width)(const U16Char* text);
    float (EDITOR_CALL* measure_icon_width)(int32_t icon_id);
    void  (EDITOR_CALL* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;

#pragma region [Core Lifecycle, View & Events]

/// Create a Document and return its handle
/// @param text UTF8 text content
/// @return Document handle
EDITOR_API intptr_t create_document_from_utf8(const char* text);

/// Create a Document and return its handle
/// @param text UTF16 text content
/// @return Document handle
EDITOR_API intptr_t create_document_from_utf16(const U16Char* text);

/// Create a Document and return its handle(created from local file)
/// @param path Local file path
/// @return Document handle
EDITOR_API intptr_t create_document_from_file(const char* path);

/// Free Document
EDITOR_API void free_document(intptr_t document_handle);

/// Get Document UTF8 text
/// @return UTF8 text content; caller owns returned buffer and must free it with free_u8_string
EDITOR_API char* get_document_utf8(intptr_t document_handle);

/// Get Document UTF16 text
/// @return UTF16 text content; caller owns returned buffer and must free it with free_u16_string
EDITOR_API U16Char* get_document_utf16(intptr_t document_handle);

/// Get total line count of Document
/// @return total line count of Document
EDITOR_API size_t get_document_line_count(intptr_t document_handle);

/// Get UTF8 text of a specific Document line
/// @param line Line number
/// @return UTF8 text content of the specified line; caller owns returned buffer and must free it with free_u8_string
EDITOR_API char* get_document_line_utf8(intptr_t document_handle, size_t line);

/// Get UTF16 text of a specific Document line
/// @param line Line number
/// @return UTF16 text content of the specified line; caller owns returned buffer and must free it with free_u16_string
EDITOR_API U16Char* get_document_line_utf16(intptr_t document_handle, size_t line);

/// Create EditorCore and return its handle
/// @param measurer Text measurement callback set
/// @param options_data EditorOptions binary payload encoded by CoreProtocol:
///        f32 touch_slop
///        i64 double_tap_timeout
///        i64 long_press_ms
///        f32 fling_friction
///        f32 fling_min_velocity
///        f32 fling_max_velocity
///        u64 max_undo_stack_size
///        i64 key_chord_timeout_ms
///        bool_u8 reveal_selection_end_on_select_all
/// @param options_size Byte length of options_data
/// @return EditorCore handle
EDITOR_API intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size);

/// Free EditorCore
EDITOR_API void free_editor(intptr_t editor_handle);

/// Load Document
EDITOR_API const uint8_t* editor_set_document(intptr_t editor_handle, intptr_t document_handle, size_t* out_size);

/// Set editor viewport
/// @param width Editor view width
/// @param height Editor view height
EDITOR_API const uint8_t* editor_set_viewport(intptr_t editor_handle, int32_t width, int32_t height, size_t* out_size);

/// Notify editor that font metrics have changed (call after font/scale changes)
EDITOR_API const uint8_t* editor_on_font_metrics_changed(intptr_t editor_handle, size_t* out_size);

/// Set fold arrow display mode (affects reserved gutter width)
/// @param mode 0=AUTO(auto show when fold regions exist), 1=ALWAYS(always reserve), 2=HIDDEN(always hide)
EDITOR_API const uint8_t* editor_set_fold_arrow_mode(intptr_t editor_handle, int mode, size_t* out_size);

/// Set auto wrap mode
/// @param mode 0=NONE(no wrap), 1=CHAR_BREAK(character-level wrap), 2=WORD_BREAK(word-level wrap)
EDITOR_API const uint8_t* editor_set_wrap_mode(intptr_t editor_handle, int mode, size_t* out_size);

/// Set tab size (number of spaces per tab stop)
/// @param tab_size Tab size (default 4, minimum 1)
EDITOR_API const uint8_t* editor_set_tab_size(intptr_t editor_handle, int tab_size, size_t* out_size);

/// Set editor scale factor
/// @param scale Scale factor (1.0 = 100%)
EDITOR_API const uint8_t* editor_set_scale(intptr_t editor_handle, float scale, size_t* out_size);

/// Set line spacing parameters (formula: line_height = font_height * mult + add)
/// @param add Extra line spacing in pixels (default 0)
/// @param mult Line spacing multiplier (default 1.0)
EDITOR_API const uint8_t* editor_set_line_spacing(intptr_t editor_handle, float add, float mult, size_t* out_size);

/// Set extra horizontal padding between gutter split and text content start
/// @param padding Padding in pixels (clamped to >= 0)
EDITOR_API const uint8_t* editor_set_content_start_padding(intptr_t editor_handle, float padding, size_t* out_size);

/// Set whether to render gutter split line
/// @param show 0=hide, non-zero=show
EDITOR_API const uint8_t* editor_set_show_split_line(intptr_t editor_handle, int show, size_t* out_size);

/// Set current line render mode
/// @param mode 0=BACKGROUND(fill), 1=BORDER(stroke), 2=NONE(disabled)
EDITOR_API const uint8_t* editor_set_current_line_render_mode(intptr_t editor_handle, int mode, size_t* out_size);

/// Set whitespace marker rendering mode
/// @param mode 0=NONE, 1=BOUNDARY, 2=SELECTION, 3=TRAILING, 4=ALL
EDITOR_API const uint8_t* editor_set_render_whitespace(intptr_t editor_handle, int mode, size_t* out_size);

/// Set whether line-ending markers should be rendered
/// @param enabled 0=hide, non-zero=show
EDITOR_API const uint8_t* editor_set_render_line_breaks(intptr_t editor_handle, int enabled, size_t* out_size);

/// Set whether gutter stays fixed during horizontal scroll
/// @param sticky 0=gutter scrolls with content (mobile style), non-zero=gutter fixed (desktop style)
EDITOR_API const uint8_t* editor_set_gutter_sticky(intptr_t editor_handle, int sticky, size_t* out_size);

/// Set whether gutter area is visible
/// @param visible 0=hide entire gutter, non-zero=show gutter
EDITOR_API const uint8_t* editor_set_gutter_visible(intptr_t editor_handle, int visible, size_t* out_size);

/// Set selection handle hit-test configuration.
/// @param data HandleConfig binary payload encoded by CoreProtocol:
///        HandleHitArea start_hit_area
///        HandleHitArea end_hit_area
///        HandleHitArea is f32 left, f32 top, f32 right, f32 bottom
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_handle_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set scrollbar full configuration (geometry + behavior).
/// @param data ScrollbarConfig binary payload encoded by CoreProtocol:
///        f32 thickness
///        f32 min_thumb
///        f32 thumb_hit_padding
///        enum_i32 mode
///        bool_u8 thumb_draggable
///        enum_i32 track_tap_mode
///        u16 fade_delay_ms
///        u16 fade_duration_ms
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_scrollbar_config(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set editor colors resolved by core when building visual runs.
/// @param data EditorRenderColors binary payload encoded by CoreProtocol:
///        i32 text_foreground
///        i32 link_foreground
///        i32 active_link_foreground
///        i32 codelens_foreground
///        i32 active_codelens_foreground
/// @param size payload byte length
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return EditorActionResult binary payload encoded by CoreProtocol
EDITOR_API const uint8_t* editor_set_editor_render_colors(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set range-effect styles resolved by core when building the render model.
/// @param data EditorRangeEffectStyles binary payload encoded by CoreProtocol
/// @param size payload byte length
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return EditorActionResult binary payload encoded by CoreProtocol
EDITOR_API const uint8_t* editor_set_editor_range_effect_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Build render model for one editor frame
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return EditorRenderModel binary payload encoded by CoreProtocol. Caller owns returned buffer and must free it with free_binary_data.
///         Wire layout:
///         f32 split_x
///         bool_i32 split_line_visible
///         f32 scroll_x
///         f32 scroll_y
///         Size viewport_size
///         PointF current_line
///         enum_i32 current_line_render_mode
///         List<VisualLine> lines
///         Cursor cursor
///         List<RangeEffectRenderItem> range_effects
///         SelectionHandle selection_start_handle
///         SelectionHandle selection_end_handle
///         List<GuideSegment> guide_segments
///         u32 max_gutter_icons
///         List<GutterIconRenderItem> gutter_icons
///         List<FoldMarkerRenderItem> fold_markers
///         ScrollbarModel vertical_scrollbar
///         ScrollbarModel horizontal_scrollbar
///         bool_i32 gutter_sticky
///         bool_i32 gutter_visible
///         enum_i32 pointer_cursor_type
///         VisualLine is i32 logical_line, i32 wrap_index, PointF line_number_position, List<VisualRun> runs, enum_i32 kind, bool_i32 owns_gutter_semantics, enum_i32 fold_state
///         VisualRun is enum_i32 type, f32 x, f32 y, U8String text, TextStyle style, i32 icon_id, i32 color_value, f32 width, f32 padding, f32 margin, bool_i32 active
///         TextStyle is i32 color, i32 background_color, i32 font_style
///         Cursor is TextPosition text_position, PointF position, f32 height, bool_i32 visible, bool_i32 show_dragger
///         Rect is PointF origin, f32 width, f32 height
///         SelectionHandle is PointF position, f32 height, bool_i32 visible
///         RangeEffectRenderItem is Rect rect, enum_i32 kind, RangeEffectStyle style
///         RangeEffectStyle is i32 foreground_color, i32 background_color, i32 border_color, i32 underline_color, enum_i32 underline_style
///         GuideSegment is enum_i32 direction, enum_i32 type, enum_i32 style, PointF start, PointF end, bool_i32 arrow_end
///         GutterIconRenderItem is i32 logical_line, i32 icon_id, Rect rect
///         FoldMarkerRenderItem is i32 logical_line, enum_i32 fold_state, Rect rect
///         ScrollbarModel is bool_i32 visible, f32 alpha, bool_i32 thumb_active, Rect track, Rect thumb
EDITOR_API const uint8_t* editor_build_render_model(intptr_t editor_handle, size_t* out_size);

/// Get editor layout metrics
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return LayoutMetrics binary payload encoded by CoreProtocol. Caller owns returned buffer and must free it with free_binary_data.
///         Wire layout:
///         f32 font_height
///         f32 font_ascent
///         f32 line_spacing_add
///         f32 line_spacing_mult
///         f32 line_number_margin
///         f32 line_number_width
///         f32 content_start_padding
///         u32 max_gutter_icons
///         f32 inlay_hint_padding
///         f32 inlay_hint_margin
///         enum_i32 fold_arrow_mode
///         bool_i32 has_fold_regions
///         bool_i32 gutter_sticky
///         bool_i32 gutter_visible
EDITOR_API const uint8_t* editor_get_layout_metrics(intptr_t editor_handle, size_t* out_size);

/// EditorActionResult binary payloads are encoded by CoreProtocol.
/// Wire layout:
///   bool_i32 handled
///   bool_i32 needs_redraw
///   enum_i32 source
///   enum_i32 text_change_kind
///   bool_i32 content_changed
///   bool_i32 cursor_changed
///   bool_i32 selection_changed
///   bool_i32 scroll_changed
///   bool_i32 scale_changed
///   bool_i32 pointer_cursor_changed
///   bool_i32 composition_changed
///   bool_i32 decoration_changed
///   bool_i32 needs_ime_sync
///   bool_i32 needs_edge_scroll
///   bool_i32 needs_fling
///   bool_i32 needs_animation
///   bool_i32 is_handle_drag
///   List<TextChange> changes
///   TextPosition cursor_before
///   TextPosition cursor_after
///   bool_i32 has_selection_before
///   bool_i32 has_selection_after
///   TextRange selection_before
///   TextRange selection_after
///   f32 scroll_x_before
///   f32 scroll_y_before
///   f32 scroll_x_after
///   f32 scroll_y_after
///   f32 scale_before
///   f32 scale_after
///   enum_i32 pointer_cursor_before
///   enum_i32 pointer_cursor_after
///   ImeSyncSnapshot ime_sync
///   enum_i32 gesture_type
///   enum_i32 gesture_event_type
///   PointF tap_point
///   HitTarget hit_target
///   enum_i32 modifiers
///   enum_i32 command
///   TextChange is TextRange range followed by U8String new_text
///   ImeSyncSnapshot is TextPosition cursor, TextRange selection, bool_i32 has_selection, bool_i32 has_composing_session, bool_i32 has_visible_composition_range, TextRange visible_composition_range, bool_i32 has_platform_marked_range, TextRange platform_marked_range, enum_i32 preedit_storage, enum_i32 context_policy, bool_i32 clear_platform_preedit
///   HitTarget is enum_i32 type, i32 line, i32 column, i32 icon_id, i32 color_value
/// This is the only result payload for core state-changing APIs. Platforms should use needs_redraw from this payload
/// to decide whether to flush editor state and schedule repaint.
///
/// Handle gesture event.
/// @param data GestureEvent binary payload encoded by CoreProtocol:
///        enum_i32 type
///        List<PointF> points
///        i32 modifiers
///        f32 wheel_delta_x
///        f32 wheel_delta_y
///        f32 direct_scale
///        PointF is f32 x followed by f32 y
/// @param size payload byte length
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_handle_gesture_event(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Recompute pointer presentation for the last observed mouse position after modifier keys change.
/// @param modifiers Modifier key flags(SHIFT=1, CTRL=2, ALT=4, META=8)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_update_pointer_modifiers(intptr_t editor_handle, uint8_t modifiers, size_t* out_size);

/// Unified animation tick: advances all active animations (edge-scroll, fling).
/// Platform should use a single frame callback driven by needs_animation and call this.
/// Returns the same EditorActionResult binary layout as editor_handle_gesture_event.
/// When needs_animation becomes false in the returned payload, stop the callback.
/// @return EditorActionResult binary payload
EDITOR_API const uint8_t* editor_tick_animations(intptr_t editor_handle, size_t* out_size);

/// Handle keyboard event (optional default key mapping; platform layer can bypass this API and call atomic operation APIs directly)
/// @param key_code Key code (KeyCode enum value)
/// @param text Input text (UTF8; pass for normal character input, pass NULL for special keys)
/// @param modifiers Modifier key flags(SHIFT=1, CTRL=2, ALT=4, META=8)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_handle_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size);

/// Set custom key map from binary payload.
/// @param data SetKeyMapPayload binary payload encoded by CoreProtocol
///        List<KeyBinding> bindings
///        KeyBinding is KeyChord first, KeyChord second, u32 command
///        KeyChord is u8 modifiers followed by u16 key_code
///        second.key_code == 0 means a single-chord binding
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_keymap(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

#pragma endregion

#pragma region [Editing, Cursor & Interaction]

/// Insert text at cursor position (replace selected text if selection exists)
/// @param text UTF8 text to insert
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size);

/// Replace text in the specified range (atomic operation for precise replacements such as textEdit)
/// @param start_line start line of replacement range(0-based)
/// @param start_column Start column of replacement range (0-based)
/// @param end_line end line of replacement range(0-based)
/// @param end_column End column of replacement range (0-based)
/// @param text Replacement UTF8 text
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_replace_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text, size_t* out_size);

/// Delete text in the specified range
/// @param start_line start line of deletion range(0-based)
/// @param start_column Start column of deletion range (0-based)
/// @param end_line end line of deletion range(0-based)
/// @param end_column End column of deletion range (0-based)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_delete_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column, size_t* out_size);

/// Apply multiple text edits as one undoable operation.
/// @param data ApplyTextEditsPayload binary payload encoded by CoreProtocol
///        List<TextEdit> edits
///        TextEdit is TextRange range followed by U8String new_text
///        edits[0] is the primary edit and determines the final cursor position
/// @param size payload byte length
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_apply_text_edits(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Delete one character before cursor (Backspace behavior); delete selection if present
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size);

/// Delete one character after cursor (Delete behavior); delete selection if present
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size);

/// Move current line (or lines covered by selection) up by one line
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);

/// Move current line (or lines covered by selection) down by one line
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);

/// Copy current line (or lines covered by selection) upward
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);

/// Copy current line (or lines covered by selection) downward
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);

/// Delete current line (or all lines covered by selection)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);

/// Insert empty line above current line
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);

/// Insert empty line below current line
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);

/// Undo last edit operation
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);

/// Redo last undone operation
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);

/// Whether undo is available
/// @return 1=yes, 0=no
EDITOR_API int editor_can_undo(intptr_t editor_handle);

/// Whether redo is available
/// @return 1=yes, 0=no
EDITOR_API int editor_can_redo(intptr_t editor_handle);

/// Search document text.
/// @param data SearchRequest binary payload encoded by CoreProtocol
///        SearchRequest is U8String pattern followed by SearchOptions options
///        SearchOptions is bool case_sensitive, bool whole_word, bool use_regex, bool wrap_around, u32 max_matches
/// @param size payload byte length
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_search(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Move to the next search match.
EDITOR_API const uint8_t* editor_find_next_search_match(intptr_t editor_handle, size_t* out_size);

/// Move to the previous search match.
EDITOR_API const uint8_t* editor_find_previous_search_match(intptr_t editor_handle, size_t* out_size);

/// Replace the current search match.
/// @param data U8String replacement payload: u32 byte length followed by UTF-8 bytes
/// @param size payload byte length
EDITOR_API const uint8_t* editor_replace_current_search_match(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Replace all current search matches.
/// @param data U8String replacement payload: u32 byte length followed by UTF-8 bytes
/// @param size payload byte length
EDITOR_API const uint8_t* editor_replace_all_search_matches(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear active search state, rendered highlights, and the current search-owned selection.
EDITOR_API const uint8_t* editor_clear_search(intptr_t editor_handle, size_t* out_size);

/// Get the latest search state.
/// @return SearchState binary payload encoded by CoreProtocol
EDITOR_API const uint8_t* editor_get_search_state(intptr_t editor_handle, size_t* out_size);

/// Set cursor position
/// @param line Line number(0-based)
/// @param column Column number (0-based)
EDITOR_API const uint8_t* editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size);

/// Get cursor position
/// @param out_line Output: line number
/// @param out_column Output: column number
EDITOR_API void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column);

/// Select all
EDITOR_API const uint8_t* editor_select_all(intptr_t editor_handle, size_t* out_size);

/// Set selection range
/// @param start_line selection start line(0-based)
/// @param start_column selection start column (0-based)
/// @param end_line selection end line(0-based)
/// @param end_column selection end column (0-based)
EDITOR_API const uint8_t* editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column, size_t* out_size);

/// Get current selection range (two cursor positions)
/// @param out_start_line Output: selection start line
/// @param out_start_column Output: selection start column
/// @param out_end_line Output: selection end line
/// @param out_end_column Output: selection end column
/// @return 1=has selection, 0=no selection
EDITOR_API int editor_get_selection(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column);

/// Get selected text
/// @return Selected text (UTF8)
EDITOR_API const char* editor_get_selected_text(intptr_t editor_handle);

/// Get text range of word at cursor (scan continuous word chars to the left)
/// @param out_start_line Output: start line
/// @param out_start_column Output: start column
/// @param out_end_line Output: end line
/// @param out_end_column Output: end column
EDITOR_API void editor_get_word_range_at_cursor(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column);

/// Get text content of word at cursor
/// @return Word text (UTF8); returns empty string when cursor is not on a word
EDITOR_API const char* editor_get_word_at_cursor(intptr_t editor_handle);

/// Move cursor left
/// @param extend_selection Whether to extend selection (Shift behavior)
EDITOR_API const uint8_t* editor_move_cursor_left(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Move cursor right
/// @param extend_selection Whether to extend selection
EDITOR_API const uint8_t* editor_move_cursor_right(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Move cursor up
/// @param extend_selection Whether to extend selection
EDITOR_API const uint8_t* editor_move_cursor_up(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Move cursor down
/// @param extend_selection Whether to extend selection
EDITOR_API const uint8_t* editor_move_cursor_down(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Move cursor to line start
/// @param extend_selection Whether to extend selection
EDITOR_API const uint8_t* editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Move cursor to line end
/// @param extend_selection Whether to extend selection
EDITOR_API const uint8_t* editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection, size_t* out_size);

/// Set read-only mode
/// @param read_only 1=read-only, 0=editable
EDITOR_API const uint8_t* editor_set_read_only(intptr_t editor_handle, int read_only, size_t* out_size);

/// Get whether read-only mode is active
/// @return 1=read-only, 0=editable
EDITOR_API int editor_is_read_only(intptr_t editor_handle);

/// Set auto indent mode
/// @param mode 0=NONE(no auto indent),1=KEEP_INDENT(keep previous line indent)
EDITOR_API const uint8_t* editor_set_auto_indent_mode(intptr_t editor_handle, int mode, size_t* out_size);

/// Get current auto indent mode
/// @return 0=NONE, 1=KEEP_INDENT
EDITOR_API int editor_get_auto_indent_mode(intptr_t editor_handle);

/// Set backspace unindent behavior
/// @param enabled 1=enabled, 0=disabled
EDITOR_API const uint8_t* editor_set_backspace_unindent(intptr_t editor_handle, int enabled, size_t* out_size);

/// Set whether Tab inserts spaces up to the next tab stop instead of a literal '\t'
/// @param enabled 1=insert spaces, 0=insert '\t'
EDITOR_API const uint8_t* editor_set_insert_spaces(intptr_t editor_handle, int enabled, size_t* out_size);

#pragma endregion

#pragma region [Navigation, Styles & Decorations]

/// Scroll to specified line
/// @param line Line number(0-based)
/// @param behavior Scroll behavior(0=GOTO_TOP, 1=GOTO_CENTER, 2=GOTO_BOTTOM)
EDITOR_API const uint8_t* editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior, size_t* out_size);

/// Go to specified line and column (scroll + cursor positioning)
/// @param line Line number(0-based)
/// @param column Column number (0-based)
EDITOR_API const uint8_t* editor_goto_position(intptr_t editor_handle, size_t line, size_t column, size_t* out_size);

/// Adjust scroll offset just enough to keep current cursor visible in viewport
EDITOR_API const uint8_t* editor_ensure_cursor_visible(intptr_t editor_handle, size_t* out_size);

/// Manually set scroll position (automatically clamped to valid range)
/// @param scroll_x Horizontal scroll offset
/// @param scroll_y Vertical scroll offset
EDITOR_API const uint8_t* editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y, size_t* out_size);

/// Get scrollbar metrics
/// @return ScrollMetrics binary payload encoded by CoreProtocol. Caller owns returned buffer and must free it with free_binary_data.
///         Wire layout:
///         f32 scale
///         f32 scroll_x
///         f32 scroll_y
///         f32 max_scroll_x
///         f32 max_scroll_y
///         Size content_size
///         Size viewport_size
///         f32 text_area_x
///         f32 text_area_width
///         bool_i32 can_scroll_x
///         bool_i32 can_scroll_y
EDITOR_API const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);

/// Get screen coordinate rect for any text position (for floating panel positioning)
/// @param line Line number(0-based)
/// @param column Column number (0-based)
/// @param out_x Output: x coordinate in viewport
/// @param out_y Output: y coordinate in viewport (line top)
/// @param out_height Output: line height
EDITOR_API void editor_get_position_rect(intptr_t editor_handle,
    size_t line, size_t column,
    float* out_x, float* out_y, float* out_height);

/// Get screen coordinate rect at current cursor position (shortcut)
/// @param out_x Output: x coordinate in viewport
/// @param out_y Output: y coordinate in viewport (line top)
/// @param out_height Output: line height
EDITOR_API void editor_get_cursor_rect(intptr_t editor_handle,
    float* out_x, float* out_y, float* out_height);

/// Register text style (color + background color + font style)
/// @param style_id Style ID
/// @param color Foreground color value (ARGB)
/// @param background_color Background color value (ARGB), 0 means transparent
/// @param font_style Font style (FontStyle enum value)
EDITOR_API const uint8_t* editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style, size_t* out_size);

/// Set style ranges for specified line and layer.
/// @param data SetLineSpansPayload binary payload encoded by CoreProtocol
///        u32 line
///        enum_i32 layer
///        List<StyleSpan> spans
///        StyleSpan is u32 column, u32 length, u32 style_id
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set style ranges for multiple lines.
/// @param data SetBatchLineSpansPayload binary payload encoded by CoreProtocol
///        enum_i32 layer
///        u32 entry_count
///        Repeated entry is u32 line followed by List<StyleSpan> spans
///        StyleSpan is u32 column, u32 length, u32 style_id
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Register text styles.
/// @param data RegisterBatchTextStylesPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 style_id followed by TextStyle style
///        TextStyle is i32 color, i32 background_color, i32 font_style
/// @param size payload byte length
EDITOR_API const uint8_t* editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all style ranges for specified line and layer
/// @param line Line number(0-based)
/// @param layer Highlight layer (0=SYNTAX, 1=SEMANTIC)
EDITOR_API const uint8_t* editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer, size_t* out_size);

/// Clear all highlight spans in specified layer
/// @param layer Highlight layer (0=SYNTAX, 1=SEMANTIC)
EDITOR_API const uint8_t* editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer, size_t* out_size);

/// Set inlay hints for specified line.
/// @param data SetLineInlayHintsPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<InlayHint> hints
///        InlayHint is enum_i32 type, u32 column, i32 int_value, U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set inlay hints for multiple lines.
/// @param data SetBatchLineInlayHintsPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<InlayHint> hints
///        InlayHint is enum_i32 type, u32 column, i32 int_value, U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set phantom texts for specified line.
/// @param data SetLinePhantomTextsPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<PhantomText> phantoms
///        PhantomText is u32 column followed by U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set phantom texts for multiple lines.
/// @param data SetBatchLinePhantomTextsPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<PhantomText> phantoms
///        PhantomText is u32 column followed by U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set gutter icons for specified line.
/// @param data SetLineGutterIconsPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<GutterIcon> icons
///        GutterIcon is i32 icon_id
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set gutter icons for multiple lines.
/// @param data SetBatchLineGutterIconsPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<GutterIcon> icons
///        GutterIcon is i32 icon_id
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set max gutter icon count (affects reserved gutter width)
/// @param count Max icon count (0=no reserved space)
EDITOR_API const uint8_t* editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count, size_t* out_size);

/// Clear all gutter icons
EDITOR_API const uint8_t* editor_clear_gutter_icons(intptr_t editor_handle, size_t* out_size);

/// Set CodeLens items for specified line.
/// @param data SetLineCodeLensPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<CodeLensItem> items
///        CodeLensItem is i32 column, i32 command_id, U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set CodeLens items for multiple lines.
/// @param data SetBatchLineCodeLensPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<CodeLensItem> items
///        CodeLensItem is i32 column, i32 command_id, U8String text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all CodeLens items
EDITOR_API const uint8_t* editor_clear_codelens(intptr_t editor_handle, size_t* out_size);

/// Set link ranges for specified line.
/// @param data SetLineLinksPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<LinkSpan> links
///        LinkSpan is u32 column, u32 length, U8String target
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set link ranges for multiple lines.
/// @param data SetBatchLineLinksPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<LinkSpan> links
///        LinkSpan is u32 column, u32 length, U8String target
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_links(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all link ranges
EDITOR_API const uint8_t* editor_clear_links(intptr_t editor_handle, size_t* out_size);

/// Resolve link target by line and column inside that link
/// @return UTF8 target string; caller owns returned buffer and must free it with free_u8_string.
///         Returns an empty string when no link matches the requested position.
EDITOR_API const char* editor_get_link_target_at(intptr_t editor_handle, size_t line, size_t column);

/// Set diagnostic decoration ranges for specified line.
/// @param data SetLineDiagnosticsPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<Diagnostic> diagnostics
///        Diagnostic is u32 column, u32 length, enum_i32 severity
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set diagnostic decoration ranges for multiple lines.
/// @param data SetBatchLineDiagnosticsPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<Diagnostic> diagnostics
///        Diagnostic is u32 column, u32 length, enum_i32 severity
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all diagnostic decorations
EDITOR_API const uint8_t* editor_clear_diagnostics(intptr_t editor_handle, size_t* out_size);

/// Set document highlight ranges for specified line.
/// @param data SetLineDocumentHighlightsPayload binary payload encoded by CoreProtocol
///        u32 line
///        List<DocumentHighlight> highlights
///        DocumentHighlight is u32 column, u32 length, enum_i32 kind
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set document highlight ranges for multiple lines.
/// @param data SetBatchLineDocumentHighlightsPayload binary payload encoded by CoreProtocol
///        u32 entry_count
///        Repeated entry is u32 line followed by List<DocumentHighlight> highlights
///        DocumentHighlight is u32 column, u32 length, enum_i32 kind
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_batch_line_document_highlights(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all document highlight ranges
EDITOR_API const uint8_t* editor_clear_document_highlights(intptr_t editor_handle, size_t* out_size);

/// Set indent guide list.
/// @param data SetIndentGuidesPayload binary payload encoded by CoreProtocol
///        List<IndentGuide> guides
///        IndentGuide is TextPosition start followed by TextPosition end
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set bracket branch guide list.
/// @param data SetBracketGuidesPayload binary payload encoded by CoreProtocol
///        List<BracketGuide> guides
///        BracketGuide is TextPosition parent, TextPosition end, List<TextPosition> children
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set control-flow back-arrow guide list.
/// @param data SetFlowGuidesPayload binary payload encoded by CoreProtocol
///        List<FlowGuide> guides
///        FlowGuide is TextPosition start followed by TextPosition end
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Set horizontal separator guide list.
/// @param data SetSeparatorGuidesPayload binary payload encoded by CoreProtocol
///        List<SeparatorGuide> guides
///        SeparatorGuide is i32 line, enum_i32 style, i32 count, u32 text_end_column
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Clear all code structure lines (indent guides, bracket guides, control-flow arrows, separators)
EDITOR_API const uint8_t* editor_clear_guides(intptr_t editor_handle, size_t* out_size);

/// Set bracket pair list (override default (){}[])
/// @param open_chars Open bracket char array (UTF-32)
/// @param close_chars Close bracket char array (UTF-32)
/// @param count Bracket pair count
EDITOR_API const uint8_t* editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size);

/// Set auto-closing pair list (empty count = disable auto-closing)
/// @param open_chars Open char array (UTF-32)
/// @param close_chars Close char array (UTF-32)
/// @param count Pair count
EDITOR_API const uint8_t* editor_set_auto_closing_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count, size_t* out_size);

/// Externally set exact bracket match result (override built-in char scan)
/// @param open_line open bracket line number(0-based)
/// @param open_col open bracket column number (0-based)
/// @param close_line close bracket line number(0-based)
/// @param close_col close bracket column number (0-based)
EDITOR_API const uint8_t* editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col, size_t* out_size);

/// Clear externally set bracket match result (fall back to built-in char scan)
EDITOR_API const uint8_t* editor_clear_matched_brackets(intptr_t editor_handle, size_t* out_size);

/// Set foldable region list.
/// @param data SetFoldRegionsPayload binary payload encoded by CoreProtocol
///        List<FoldRegion> regions
///        FoldRegion is u32 start_line, u32 end_line, bool_u8 collapsed
/// @param size payload byte length
EDITOR_API const uint8_t* editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Toggle fold state of specified line
/// @param line Line number(0-based)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_toggle_fold(intptr_t editor_handle, size_t line, size_t* out_size);

/// Fold region containing specified line
/// @param line Line number(0-based)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_fold_at(intptr_t editor_handle, size_t line, size_t* out_size);

/// Unfold region containing specified line
/// @param line Line number(0-based)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_unfold_at(intptr_t editor_handle, size_t line, size_t* out_size);

/// Fold all regions
EDITOR_API const uint8_t* editor_fold_all(intptr_t editor_handle, size_t* out_size);

/// Unfold all regions
EDITOR_API const uint8_t* editor_unfold_all(intptr_t editor_handle, size_t* out_size);

/// Check whether specified line is visible (not hidden by folding)
/// @param line Line number(0-based)
/// @return 1=visible, 0=hidden
EDITOR_API int editor_is_line_visible(intptr_t editor_handle, size_t line);

/// Get visible logical line range from the most recent completed layout pass
/// @param out_start_line Output first visible logical line (inclusive)
/// @param out_end_line Output last visible logical line (inclusive), or -1 when empty
EDITOR_API void editor_get_visible_line_range(intptr_t editor_handle, int32_t* out_start_line, int32_t* out_end_line);

/// Clear all highlight spans
EDITOR_API const uint8_t* editor_clear_highlights(intptr_t editor_handle, size_t* out_size);

/// Clear all inlay hints
EDITOR_API const uint8_t* editor_clear_inlay_hints(intptr_t editor_handle, size_t* out_size);

/// Clear all phantom texts
EDITOR_API const uint8_t* editor_clear_phantom_texts(intptr_t editor_handle, size_t* out_size);

/// Clear all decoration data
EDITOR_API const uint8_t* editor_clear_all_decorations(intptr_t editor_handle, size_t* out_size);

#pragma endregion

#pragma region [Linked Editing & Utilities]

/// Insert VSCode snippet template and enter linked editing mode (convenience API)
/// @param snippet_template VSCode snippet template (UTF8)
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);

/// Start linked editing mode with generic LinkedEditingModel payload
/// @param data StartLinkedEditingPayload binary payload encoded by CoreProtocol
///        LinkedEditingModel model
///        LinkedEditingModel is List<TabStopGroup> groups
///        TabStopGroup is u32 index, List<TextRange> ranges, U8String default_text
/// @param size payload byte length
EDITOR_API const uint8_t* editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size, size_t* out_size);

/// Whether linked editing mode is active
/// @return 1=yes, 0=no
EDITOR_API int editor_is_in_linked_editing(intptr_t editor_handle);

/// Linked editing: jump to next tab stop
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_linked_editing_next(intptr_t editor_handle, size_t* out_size);

/// Linked editing: jump to previous tab stop
/// @return EditorActionResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* editor_linked_editing_prev(intptr_t editor_handle, size_t* out_size);

/// Cancel linked editing mode
EDITOR_API const uint8_t* editor_cancel_linked_editing(intptr_t editor_handle, size_t* out_size);

/// Free string memory allocated on C++ side
/// @param string_ptr String pointer
EDITOR_API void free_u16_string(intptr_t string_ptr);

/// Free UTF-8 string memory allocated on C++ side
/// @param string_ptr String pointer
EDITOR_API void free_u8_string(intptr_t string_ptr);

/// Free binary memory returned by C++ side
/// Applies to all APIs that return const uint8_t* + out_size.
/// Platform must call once after reading payload; NULL/0 can be safely ignored.
/// @param data_ptr Start address of binary payload
EDITOR_API void free_binary_data(intptr_t data_ptr);

#pragma endregion

#pragma region [IME]

/// Get whether composition is currently active
/// @return 1=composing, 0=not composing
EDITOR_API int editor_is_composing(intptr_t editor_handle);

/// Get current composition range, or -1 values when composition is inactive
EDITOR_API void editor_get_composing_range(intptr_t editor_handle,
                                           int32_t* out_start_line,
                                           int32_t* out_start_column,
                                           int32_t* out_end_line,
                                           int32_t* out_end_column);

/// Get current active composition session range
EDITOR_API void editor_get_composing_session_range(intptr_t editor_handle,
                                                   int32_t* out_start_line,
                                                   int32_t* out_start_column,
                                                   int32_t* out_end_line,
                                                   int32_t* out_end_column);

/// Update platform IME preedit text.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_update_preedit(intptr_t editor_handle,
                                                    const char* text,
                                                    int script_hint,
                                                    size_t* out_size);

EDITOR_API const uint8_t* editor_ime_set_composing_text(intptr_t editor_handle,
                                                        const char* text,
                                                        int cursor_offset,
                                                        int script_hint,
                                                        size_t* out_size);

EDITOR_API const uint8_t* editor_ime_set_composing_text_selection(intptr_t editor_handle,
                                                                  const char* text,
                                                                  size_t selection_start_offset,
                                                                  size_t selection_end_offset,
                                                                  int script_hint,
                                                                  size_t* out_size);

/// Commit platform IME text.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_commit_text(intptr_t editor_handle,
                                                 const char* text,
                                                 int script_hint,
                                                 size_t* out_size);

EDITOR_API const uint8_t* editor_ime_commit_text_with_cursor(intptr_t editor_handle,
                                                             const char* text,
                                                             int cursor_offset,
                                                             int script_hint,
                                                             size_t* out_size);

/// Finish the current platform IME preedit.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_finish_preedit(intptr_t editor_handle, size_t* out_size);

/// Cancel the current platform IME preedit.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_cancel_preedit(intptr_t editor_handle, size_t* out_size);

/// Mark a document range that the platform IME explicitly reports as composing.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_mark_document_range(intptr_t editor_handle,
                                                          size_t start_line,
                                                          size_t start_column,
                                                          size_t end_line,
                                                          size_t end_column,
                                                          int script_hint,
                                                          size_t* out_size);

EDITOR_API const uint8_t* editor_ime_mark_document_range_by_offset(intptr_t editor_handle,
                                                                   size_t start_offset,
                                                                   size_t end_offset,
                                                                   int script_hint,
                                                                   size_t* out_size);

/// Report platform candidate replacement text.
/// @param data ImeTextReplacement binary payload encoded by CoreProtocol:
///   TextRange range, U8String text, enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_replace_text(intptr_t editor_handle,
                                                  const uint8_t* data,
                                                  size_t size,
                                                  size_t* out_size);

/// Replace text in the document IME context by UTF-16 offsets.
/// @param data ImeDocumentTextReplacement binary payload encoded by CoreProtocol:
///   size_as_u32 start_offset, size_as_u32 end_offset, U8String text,
///   int32_t cursor_offset, enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_replace_document_text(intptr_t editor_handle,
                                                           const uint8_t* data,
                                                           size_t size,
                                                           size_t* out_size);

/// Replace text in the input-context IME window by UTF-16 offsets.
/// @param data ImeInputContextTextReplacement binary payload encoded by CoreProtocol:
///   size_as_u32 start_offset, size_as_u32 end_offset, U8String text,
///   int32_t cursor_offset, enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_replace_input_context_text(intptr_t editor_handle,
                                                                const uint8_t* data,
                                                                size_t size,
                                                                size_t* out_size);

EDITOR_API const uint8_t* editor_ime_mark_input_context_range(intptr_t editor_handle,
                                                              size_t start_offset,
                                                              size_t end_offset,
                                                              int script_hint,
                                                              size_t* out_size);

EDITOR_API const uint8_t* editor_ime_notify_document_selection_changed(intptr_t editor_handle,
                                                                       size_t start_offset,
                                                                       size_t end_offset,
                                                                       size_t* out_size);

EDITOR_API const uint8_t* editor_ime_notify_input_context_selection_changed(intptr_t editor_handle,
                                                                            size_t start_offset,
                                                                            size_t end_offset,
                                                                            size_t* out_size);

/// Update the external text model state snapshot.
/// @param data ImeTextModelState binary payload encoded by CoreProtocol:
///   enum_i32 ImeTextModelMode mode, uint64_t context_id, int32_t document_start_offset,
///   U8String text, ImeOffsetRange selection, ImeOffsetRange composition,
///   enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_update_text_model_state(intptr_t editor_handle,
                                                             const uint8_t* data,
                                                             size_t size,
                                                             size_t* out_size);

/// Update the external text model by delta.
/// @param data ImeTextModelDelta binary payload encoded by CoreProtocol:
///   enum_i32 ImeTextModelMode mode, uint64_t context_id, int32_t document_start_offset,
///   U8String old_text, ImeOffsetRange delta, U8String delta_text,
///   ImeOffsetRange selection, ImeOffsetRange composition, enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_update_text_model_delta(intptr_t editor_handle,
                                                             const uint8_t* data,
                                                             size_t size,
                                                             size_t* out_size);

EDITOR_API const uint8_t* editor_ime_update_input_state_selection(intptr_t editor_handle,
                                                                  uint64_t context_id,
                                                                  int32_t document_start_offset,
                                                                  int32_t selection_start_offset,
                                                                  int32_t selection_end_offset,
                                                                  size_t* out_size);

/// Replace text in the platform input state.
/// @param data ImeInputStateTextReplacement binary payload encoded by CoreProtocol:
///   uint64_t context_id, int32_t document_start_offset, size_as_u32 start_offset,
///   size_as_u32 end_offset, U8String text, int32_t cursor_offset,
///   enum_i32 ImeScriptClass script_class
/// @param size Binary payload size in bytes
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_replace_input_state_text(intptr_t editor_handle,
                                                              const uint8_t* data,
                                                              size_t size,
                                                              size_t* out_size);

/// Delete text before the caret through IME.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_delete_backward(intptr_t editor_handle,
                                                     size_t before_length,
                                                     int text_unit,
                                                     size_t* out_size);

/// Delete text after the caret through IME.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_delete_forward(intptr_t editor_handle,
                                                    size_t after_length,
                                                    int text_unit,
                                                    size_t* out_size);

/// Delete surrounding text through IME.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_delete_surrounding(intptr_t editor_handle,
                                                        size_t before_length,
                                                        size_t after_length,
                                                        int text_unit,
                                                        size_t* out_size);

/// Notify IME-driven selection movement.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_notify_selection_changed(intptr_t editor_handle,
                                                              size_t start_line,
                                                              size_t start_column,
                                                              size_t end_line,
                                                              size_t end_column,
                                                              size_t* out_size);

/// Notify IME-driven cursor movement.
/// @return EditorActionResult binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_ime_notify_cursor_changed(intptr_t editor_handle,
                                                           size_t cursor_line,
                                                           size_t cursor_column,
                                                           size_t* out_size);

/// Set the current IME keyboard script class.
EDITOR_API const uint8_t* editor_ime_set_keyboard_script_class(intptr_t editor_handle, int script_class, size_t* out_size);

/// Get the current IME keyboard script class.
EDITOR_API int editor_ime_get_keyboard_script_class(intptr_t editor_handle);

/// Get the current IME synchronization snapshot.
/// @return ImeSyncSnapshot binary payload, returns NULL when editor handle is invalid
EDITOR_API const uint8_t* editor_get_ime_sync_snapshot(intptr_t editor_handle, size_t* out_size);

EDITOR_API const uint8_t* editor_get_ime_input_context(intptr_t editor_handle,
                                                       size_t before_length,
                                                       size_t after_length,
                                                       size_t* out_size);

EDITOR_API const uint8_t* editor_get_ime_text_model_input_context(intptr_t editor_handle,
                                                                  int mode,
                                                                  size_t before_length,
                                                                  size_t after_length,
                                                                  size_t* out_size);

#pragma endregion

#ifdef _WIN32
/// Set crash log output for DLL calls, Windows only
EDITOR_API void init_unhandled_exception_handler();
#endif

#ifdef __cplusplus
}
#endif

#endif //SWEETEDITOR_C_API_H
