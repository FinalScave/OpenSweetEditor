//
// Created by Scave on 2025/12/8.
//

#ifndef SWEETEDITOR_C_API_H
#define SWEETEDITOR_C_API_H
#include <cstdint>

#if defined(WINDOWS) || defined(_WIN32) || defined(_WIN64)
  #ifdef SWEETEDITOR_EXPORT
    #define EDITOR_API __declspec(dllexport)
  #else
    #define EDITOR_API __declspec(dllimport)
  #endif
#else
  #define EDITOR_API __attribute__((visibility("default")))
#endif

extern "C" {

/// @note General C API conventions in this file:
///   - editor_handle:   EditorCore handle (intptr_t) returned by create_editor
///   - document_handle: Document handle (intptr_t) returned by create_document_xxx
///   - out_size:        For all APIs that return binary payloads, this outputs the byte length
///   - Coordinate system: line / column are both 0-based
///   - Payload uses native byte order (LE). Caller must free it with free_binary_data
///   - These common rules are not repeated in each function comment

/// Text measurement callback set, passed when creating EditorCore
typedef struct {
    float (__stdcall* measure_text_width)(const U16Char* text, int32_t font_style);
    float (__stdcall* measure_inlay_hint_width)(const U16Char* text);
    float (__stdcall* measure_icon_width)(int32_t icon_id);
    void  (__stdcall* get_font_metrics)(float* arr, size_t length);
} text_measurer_t;

#pragma region Document API

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
/// @return UTF8 text content
EDITOR_API const char* get_document_text(intptr_t document_handle);

/// Get total line count of Document
/// @return total line count of Document
EDITOR_API size_t get_document_line_count(intptr_t document_handle);

/// Get text of a specific Document line
/// @param line Line number
/// @return UTF16 text content of the specified line
EDITOR_API const U16Char* get_document_line_text(intptr_t document_handle, size_t line);

#pragma endregion

#pragma region Construction/Initialization/Lifecycle

/// Create EditorCore and return its handle
/// @param measurer Text measurement callback set
/// @param options_data EditorOptions binary payload（LE byte order）:
///        f32 touch_slop         — Move threshold for a tap (default 10)
///        i64 double_tap_timeout — Time window for double tap (default 300ms)
///        i64 long_press_ms      — Long press threshold (default 500ms)
///        u64 max_undo_stack_size — Max undo stack depth, 0=unlimited (default 512)
/// @param options_size Byte length of options_data
/// @return EditorCore handle
EDITOR_API intptr_t create_editor(text_measurer_t measurer, const uint8_t* options_data, size_t options_size);

/// Free EditorCore
EDITOR_API void free_editor(intptr_t editor_handle);

/// Load Document
EDITOR_API void set_editor_document(intptr_t editor_handle, intptr_t document_handle);

#pragma endregion

#pragma region Viewport/Font/Appearance Configuration

/// Set editor viewport
/// @param width Editor view width
/// @param height Editor view height
EDITOR_API void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height);

/// Reset editor text measurements (call when font changes)
EDITOR_API void reset_editor_text_measurer(intptr_t editor_handle);

/// Set fold arrow display mode (affects reserved gutter width)
/// @param mode 0=AUTO(auto show when fold regions exist), 1=ALWAYS(always reserve), 2=HIDDEN(always hide)
EDITOR_API void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode);

/// Set auto wrap mode
/// @param mode 0=NONE(no wrap), 1=CHAR_BREAK(character-level wrap), 2=WORD_BREAK(word-level wrap)
EDITOR_API void editor_set_wrap_mode(intptr_t editor_handle, int mode);

/// Set editor scale factor
/// @param scale Scale factor (1.0 = 100%)
EDITOR_API void editor_set_scale(intptr_t editor_handle, float scale);

/// Set line spacing parameters (formula: line_height = font_height * mult + add)
/// @param add Extra line spacing in pixels (default 0)
/// @param mult Line spacing multiplier (default 1.0)
EDITOR_API void editor_set_line_spacing(intptr_t editor_handle, float add, float mult);

/// Set extra horizontal padding between gutter split and text content start
/// @param padding Padding in pixels (clamped to >= 0)
EDITOR_API void editor_set_content_start_padding(intptr_t editor_handle, float padding);

/// Set whether to render gutter split line
/// @param show 0=hide, non-zero=show
EDITOR_API void editor_set_show_split_line(intptr_t editor_handle, int show);

/// Set current line render mode
/// @param mode 0=BACKGROUND(fill), 1=BORDER(stroke), 2=NONE(disabled)
EDITOR_API void editor_set_current_line_render_mode(intptr_t editor_handle, int mode);

#pragma endregion

#pragma region Rendering

/// Build render model for one editor frame
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return EditorRenderModel binary data; payload uses native byte order, and all supported platforms are currently LE.
///         Top-level layout:
///         1. f32 split_x
///         2. i32 split_line_visible (0=false, 1=true)
///         3. f32 scroll_x
///         4. f32 scroll_y
///         5. f32 viewport_width
///         6. f32 viewport_height
///         7. PointF current_line
///            - f32 x
///            - f32 y
///         8. i32 current_line_render_mode (0=BACKGROUND, 1=BORDER, 2=NONE)
///         9. i32 lines_count
///         10. VisualLine[lines_count] lines
///            VisualLine layout:
///            - i32 logical_line
///            - i32 wrap_index
///            - PointF line_number_position
///            - i32 is_phantom_line
///            - i32 fold_state
///            - i32 run_count
///            - VisualRun[run_count] runs
///            VisualRun layout:
///            - i32 type
///            - f32 x
///            - f32 y
///            - i32 text_utf8_length
///            - u8[text_utf8_length] text_utf8_bytes
///            - TextStyle style
///              - i32 color
///              - i32 background_color
///              - i32 font_style
///            - i32 icon_id
///            - i32 color_value
///            - f32 width
///            - f32 padding
///            - f32 margin
///         11. i32 gutter_icon_render_count
///         12. GutterIconRenderItem[gutter_icon_render_count] gutter_icons
///             GutterIconRenderItem layout:
///             - i32 logical_line
///             - i32 icon_id
///             - PointF origin
///             - f32 width
///             - f32 height
///         13. i32 fold_marker_render_count
///         14. FoldMarkerRenderItem[fold_marker_render_count] fold_markers
///             FoldMarkerRenderItem layout:
///             - i32 logical_line
///             - i32 fold_state
///             - PointF origin
///             - f32 width
///             - f32 height
///         15. Cursor cursor
///            - TextPosition text_position
///              - i32 line
///              - i32 column
///            - PointF position
///            - f32 height
///            - i32 visible
///            - i32 show_dragger
///         16. i32 selection_rect_count
///         17. SelectionRect[selection_rect_count] selection_rects
///             SelectionRect layout:
///             - PointF origin
///             - f32 width
///             - f32 height
///         18. SelectionHandle selection_start_handle
///         19. SelectionHandle selection_end_handle
///             SelectionHandle layout:
///             - PointF position
///             - f32 height
///             - i32 visible
///         20. CompositionDecoration composition_decoration
///             - i32 active
///             - PointF origin
///             - f32 width
///             - f32 height
///         21. i32 guide_segment_count
///         22. GuideSegment[guide_segment_count] guide_segments
///             GuideSegment layout:
///             - i32 direction
///             - i32 type
///             - i32 style
///             - PointF start
///             - PointF end
///             - i32 arrow_end
///         23. i32 diagnostic_count
///         24. DiagnosticDecoration[diagnostic_count] diagnostic_decorations
///             DiagnosticDecoration layout:
///             - PointF origin
///             - f32 width
///             - f32 height
///             - i32 severity
///             - i32 color
///         25. i32 max_gutter_icons
///         26. i32 linked_editing_rect_count
///         27. LinkedEditingRect[linked_editing_rect_count] linked_editing_rects
///             LinkedEditingRect layout:
///             - PointF origin
///             - f32 width
///             - f32 height
///             - i32 is_active
///         28. i32 bracket_highlight_rect_count
///         29. BracketHighlightRect[bracket_highlight_rect_count] bracket_highlight_rects
///             BracketHighlightRect layout:
///             - PointF origin
///             - f32 width
///             - f32 height
///         30. (optional append-only tail) ScrollbarModel vertical_scrollbar
///         31. (optional append-only tail) ScrollbarModel horizontal_scrollbar
///             ScrollbarModel layout:
///             - i32 visible
///             - f32 alpha (0~1)
///             - ScrollbarRect track
///             - ScrollbarRect thumb
///             ScrollbarRect layout:
///             - PointF origin
///             - f32 width
///             - f32 height
///         Call free_binary_data after use; returns NULL on failure
EDITOR_API const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size);

/// Get editor layout metrics
/// @param out_size Output: payload byte length (bytes, excluding extra '\0' terminator)
/// @return LayoutMetrics binary data; payload uses native byte order, and all supported platforms are currently LE.
///         Top-level layout:
///         1. f32 font_height
///         2. f32 font_ascent
///         3. f32 line_spacing_add
///         4. f32 line_spacing_mult
///         5. f32 line_number_margin
///         6. f32 line_number_width
///         7. i32 max_gutter_icons
///         8. f32 inlay_hint_padding
///         9. f32 inlay_hint_margin
///         10. i32 fold_arrow_mode (0=AUTO, 1=ALWAYS, 2=HIDDEN)
///         11. i32 has_fold_regions (0=false, 1=true)
///         Call free_binary_data after use; returns NULL on failure
EDITOR_API const uint8_t* get_layout_metrics(intptr_t editor_handle, size_t* out_size);

#pragma endregion

#pragma region Gesture/Keyboard Event Handling

/// GestureResult binary return layout (payload uses native byte order; all supported platforms are currently LE):
/// 1. i32 gesture_type
/// 2. Only when gesture_type is TAP / DOUBLE_TAP / LONG_PRESS / DRAG_SELECT / CONTEXT_MENU, append:
///    f32 tap_x, f32 tap_y
/// 3. Always append editor state:
///    i32 cursor_line
///    i32 cursor_column
///    i32 has_selection
///    i32 selection_start_line
///    i32 selection_start_column
///    i32 selection_end_line
///    i32 selection_end_column
///    f32 view_scroll_x
///    f32 view_scroll_y
///    f32 view_scale
///    i32 hit_target_type
///    i32 hit_target_line
///    i32 hit_target_column
///    i32 hit_target_icon_id
///    i32 hit_target_color_value
///    i32 needs_edge_scroll (1 = platform should start/continue 16ms timer calling
///        editor_tick_edge_scroll; 0 = platform should stop the timer)
///
/// Handle gesture event
/// @param type Event type
/// @param pointer_count Finger point count
/// @param points Data for each point
/// @return GestureResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* handle_editor_gesture_event(intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points, size_t* out_size);

/// Handle gesture event(extended version, supports modifier keys and wheel/scale parameters)
/// @param type Event type
/// @param pointer_count Finger point count
/// @param points Data for each point
/// @param modifiers Modifier key flags(SHIFT=1, CTRL=2, ALT=4, META=8)
/// @param wheel_delta_x Horizontal wheel delta (used for MOUSE_WHEEL/DIRECT_SCROLL)
/// @param wheel_delta_y Vertical wheel delta (used for MOUSE_WHEEL/DIRECT_SCROLL)
/// @param direct_scale Direct scale value (used for DIRECT_SCALE)
/// @return GestureResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* handle_editor_gesture_event_ex(intptr_t editor_handle, uint8_t type, uint8_t pointer_count, float* points,
    uint8_t modifiers, float wheel_delta_x, float wheel_delta_y, float direct_scale, size_t* out_size);

/// Tick edge-scroll during drag selection / handle drag.
/// Call at ~16ms intervals while the previous GestureResult.needs_edge_scroll was true.
/// Returns the same GestureResult binary layout as handle_editor_gesture_event.
/// When needs_edge_scroll becomes false in the returned payload, stop the timer.
/// @return GestureResult binary payload
EDITOR_API const uint8_t* editor_tick_edge_scroll(intptr_t editor_handle, size_t* out_size);

/// KeyEventResult binary return layout (payload uses native byte order; all supported platforms are currently LE):
/// 1. i32 handled
/// 2. i32 content_changed
/// 3. i32 cursor_changed
/// 4. i32 selection_changed
/// 5. i32 has_edit
/// 6. If has_edit != 0, append a TextEditResult.changes array:
///    i32 change_count
///    Repeat for change_count groups:
///    i32 range_start_line
///    i32 range_start_column
///    i32 range_end_line
///    i32 range_end_column
///    i32 new_text_len
///    u8[new_text_len] new_text_utf8
///
/// Handle keyboard event (optional default key mapping; platform layer can bypass this API and call atomic operation APIs directly)
/// @param key_code Key code (KeyCode enum value)
/// @param text Input text (UTF8; pass for normal character input, pass NULL for special keys)
/// @param modifiers Modifier key flags(SHIFT=1, CTRL=2, ALT=4, META=8)
/// @return KeyEventResult binary payload, returns NULL on failure
EDITOR_API const uint8_t* handle_editor_key_event(intptr_t editor_handle, uint16_t key_code, const char* text, uint8_t modifiers, size_t* out_size);

#pragma endregion

#pragma region Text Editing

/// TextEditResult binary return layout (payload uses native byte order; all supported platforms are currently LE):
/// 1. i32 changed
/// 2. When changed != 0, append change array:
///    i32 change_count
///    Repeat for change_count groups:
///    i32 range_start_line
///    i32 range_start_column
///    i32 range_end_line
///    i32 range_end_column
///    i32 new_text_len
///    u8[new_text_len] new_text_utf8
///
/// Insert text at cursor position (replace selected text if selection exists)
/// @param text UTF8 text to insert
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size);

/// Replace text in the specified range (atomic operation for precise replacements such as textEdit)
/// @param start_line start line of replacement range(0-based)
/// @param start_column Start column of replacement range (0-based)
/// @param end_line end line of replacement range(0-based)
/// @param end_column End column of replacement range (0-based)
/// @param text Replacement UTF8 text
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_replace_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text, size_t* out_size);

/// Delete text in the specified range
/// @param start_line start line of deletion range(0-based)
/// @param start_column Start column of deletion range (0-based)
/// @param end_line end line of deletion range(0-based)
/// @param end_column End column of deletion range (0-based)
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_delete_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column, size_t* out_size);

/// Delete one character before cursor (Backspace behavior); delete selection if present
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_backspace(intptr_t editor_handle, size_t* out_size);

/// Delete one character after cursor (Delete behavior); delete selection if present
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_delete_forward(intptr_t editor_handle, size_t* out_size);

#pragma endregion

#pragma region Line Operations

/// Move current line (or lines covered by selection) up by one line
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);

/// Move current line (or lines covered by selection) down by one line
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);

/// Copy current line (or lines covered by selection) upward
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);

/// Copy current line (or lines covered by selection) downward
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);

/// Delete current line (or all lines covered by selection)
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);

/// Insert empty line above current line
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);

/// Insert empty line below current line
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);

#pragma endregion

#pragma region Undo/Redo

/// Undo last edit operation
/// @return TextEditResult binary payload, returns NULL when nothing can be undone
EDITOR_API const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);

/// Redo last undone operation
/// @return TextEditResult binary payload, returns NULL when nothing can be redone
EDITOR_API const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);

/// Whether undo is available
/// @return 1=yes, 0=no
EDITOR_API int editor_can_undo(intptr_t editor_handle);

/// Whether redo is available
/// @return 1=yes, 0=no
EDITOR_API int editor_can_redo(intptr_t editor_handle);

#pragma endregion

#pragma region Cursor/Selection Management

/// Set cursor position
/// @param line Line number(0-based)
/// @param column Column number (0-based)
EDITOR_API void editor_set_cursor_position(intptr_t editor_handle, size_t line, size_t column);

/// Get cursor position
/// @param out_line Output: line number
/// @param out_column Output: column number
EDITOR_API void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column);

/// Select all
EDITOR_API void editor_select_all(intptr_t editor_handle);

/// Set selection range
/// @param start_line selection start line(0-based)
/// @param start_column selection start column (0-based)
/// @param end_line selection end line(0-based)
/// @param end_column selection end column (0-based)
EDITOR_API void editor_set_selection(intptr_t editor_handle, size_t start_line, size_t start_column, size_t end_line, size_t end_column);

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

#pragma endregion

#pragma region Cursor Movement

/// Move cursor left
/// @param extend_selection Whether to extend selection (Shift behavior)
EDITOR_API void editor_move_cursor_left(intptr_t editor_handle, int extend_selection);

/// Move cursor right
/// @param extend_selection Whether to extend selection
EDITOR_API void editor_move_cursor_right(intptr_t editor_handle, int extend_selection);

/// Move cursor up
/// @param extend_selection Whether to extend selection
EDITOR_API void editor_move_cursor_up(intptr_t editor_handle, int extend_selection);

/// Move cursor down
/// @param extend_selection Whether to extend selection
EDITOR_API void editor_move_cursor_down(intptr_t editor_handle, int extend_selection);

/// Move cursor to line start
/// @param extend_selection Whether to extend selection
EDITOR_API void editor_move_cursor_to_line_start(intptr_t editor_handle, int extend_selection);

/// Move cursor to line end
/// @param extend_selection Whether to extend selection
EDITOR_API void editor_move_cursor_to_line_end(intptr_t editor_handle, int extend_selection);

#pragma endregion

#pragma region IME Composition Input

/// Notify editor that IME composition starts
EDITOR_API void editor_composition_start(intptr_t editor_handle);

/// Update IME composition text
/// @param text Current composition text (UTF8), full composition text each time not incremental
EDITOR_API void editor_composition_update(intptr_t editor_handle, const char* text);

/// End IME composition and commit final text
/// @param committed_text Final committed text (UTF8); if NULL, use current composition text
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_composition_end(intptr_t editor_handle, const char* committed_text, size_t* out_size);

/// Cancel IME composition (do not commit any text)
EDITOR_API void editor_composition_cancel(intptr_t editor_handle);

/// Get whether composition is currently active
/// @return 1=composing, 0=not composing
EDITOR_API int editor_is_composing(intptr_t editor_handle);

/// Set whether IME composition is enabled
/// @param enabled 1=enabled, 0=disabled
EDITOR_API void editor_set_composition_enabled(intptr_t editor_handle, int enabled);

/// Get whether IME composition is enabled
/// @return 1=enabled, 0=disabled
EDITOR_API int editor_is_composition_enabled(intptr_t editor_handle);

#pragma endregion

#pragma region Read-Only Mode

/// Set read-only mode
/// @param read_only 1=read-only, 0=editable
EDITOR_API void editor_set_read_only(intptr_t editor_handle, int read_only);

/// Get whether read-only mode is active
/// @return 1=read-only, 0=editable
EDITOR_API int editor_is_read_only(intptr_t editor_handle);

#pragma endregion

#pragma region Auto Indent

/// Set auto indent mode
/// @param mode 0=NONE(no auto indent),1=KEEP_INDENT(keep previous line indent)
EDITOR_API void editor_set_auto_indent_mode(intptr_t editor_handle, int mode);

/// Get current auto indent mode
/// @return 0=NONE, 1=KEEP_INDENT
EDITOR_API int editor_get_auto_indent_mode(intptr_t editor_handle);

#pragma endregion

#pragma region Handle Config

/// Set selection handle appearance and touch configuration
/// @param radius Water-drop circle radius (default 22.0)
/// @param center_dist Distance from circle center to tip (default 56.0)
/// @param line_width Cursor vertical line width (default 3.0)
/// @param touch_padding Touch hot-zone expansion (default 10.0)
/// @param drag_y_offset Vertical offset during drag (default 50.0)
EDITOR_API void editor_set_handle_config(intptr_t editor_handle,
    float radius, float center_dist, float line_width,
    float touch_padding, float drag_y_offset);

#pragma endregion

#pragma region Scrollbar Config

/// Set scrollbar full configuration (geometry + behavior)
/// @param thickness Scrollbar thickness in pixels
/// @param min_thumb Minimum scrollbar thumb length in pixels
/// @param thumb_hit_padding Extra thumb hit-test padding in pixels
/// @param mode 0=ALWAYS, 1=TRANSIENT, 2=NEVER
/// @param thumb_draggable 1=thumb drag enabled, 0=disabled
/// @param track_tap_mode 0=JUMP, 1=DISABLED
/// @param fade_delay_ms Delay before hide in TRANSIENT mode
/// @param fade_duration_ms Fade duration in TRANSIENT mode (used for both fade-in and fade-out)
EDITOR_API void editor_set_scrollbar_config(intptr_t editor_handle,
    float thickness, float min_thumb, float thumb_hit_padding,
    int mode, int thumb_draggable, int track_tap_mode,
    int fade_delay_ms, int fade_duration_ms);

#pragma endregion

#pragma region Position Coordinate Query

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

#pragma endregion

#pragma region Scrolling/Navigation

/// Scroll to specified line
/// @param line Line number(0-based)
/// @param behavior Scroll behavior(0=GOTO_TOP, 1=GOTO_CENTER, 2=GOTO_BOTTOM)
EDITOR_API void editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior);

/// Go to specified line and column (scroll + cursor positioning)
/// @param line Line number(0-based)
/// @param column Column number (0-based)
EDITOR_API void editor_goto_position(intptr_t editor_handle, size_t line, size_t column);

/// Manually set scroll position (automatically clamped to valid range)
/// @param scroll_x Horizontal scroll offset
/// @param scroll_y Vertical scroll offset
EDITOR_API void editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y);

/// ScrollMetrics binary return layout (payload uses native byte order; all supported platforms are currently LE):
/// 1. f32 scale
/// 2. f32 scroll_x
/// 3. f32 scroll_y
/// 4. f32 max_scroll_x
/// 5. f32 max_scroll_y
/// 6. f32 content_width
/// 7. f32 content_height
/// 8. f32 viewport_width
/// 9. f32 viewport_height
/// 10. f32 text_area_x
/// 11. f32 text_area_width
/// 12. i32 can_scroll_x
/// 13. i32 can_scroll_y
///
/// Get scrollbar metrics
/// @return ScrollMetrics binary payload; Returns default payload for invalid handle
EDITOR_API const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);

#pragma endregion

#pragma region Style Registration + Highlight Spans

/// Register text style (color + background color + font style)
/// @param style_id Style ID
/// @param color Foreground color value (ARGB)
/// @param background_color Background color value (ARGB), 0 means transparent
/// @param font_style Font style (FontStyle enum value)
EDITOR_API void editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style);

/// Set style ranges for specified line and layer (compact binary)
/// @param data payload(LE):
///             u32 line, u32 layer, u32 span_count, then repeat for span_count groups
///             [u32 column, u32 length, u32 style_id]
/// @param size payload byte length
EDITOR_API void editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Batch set highlight spans for multiple lines (compact binary)
/// @param data payload(LE):
///             u32 layer, u32 entry_count,
///             [u32 line, u32 span_count, [u32 column, u32 length, u32 style_id] x span_count] x entry_count
/// @param size payload byte length
EDITOR_API void editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Clear all style ranges for specified line and layer
/// @param line Line number(0-based)
/// @param layer Highlight layer (0=SYNTAX, 1=SEMANTIC)
EDITOR_API void editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer);

/// Clear all highlight spans in specified layer
/// @param layer Highlight layer (0=SYNTAX, 1=SEMANTIC)
EDITOR_API void editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer);

#pragma endregion

#pragma region InlayHint / PhantomText

/// Set inlay hints for specified line (compact binary, replace whole line)
/// @param data payload(LE):
///             u32 line, u32 hint_count, then repeat for hint_count groups:
///             [u32 type(0=TEXT,1=ICON,2=COLOR), u32 column, i32 int_value(icon_id/color/0),
///              u32 text_len, u8[text_len] text_utf8]
/// @param size payload byte length
EDITOR_API void editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Batch set inlay hints for multiple lines (compact binary, variable length)
/// @param data payload(LE):
///             u32 entry_count,
///             [u32 line, u32 hint_count,
///              [u32 type, u32 column, i32 int_value, u32 text_len, u8[text_len] text_utf8] x hint_count] x entry_count
/// @param size payload byte length
EDITOR_API void editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Add one inlay hint (append to specified line, do not replace existing hints)
/// Set phantom texts for specified line (compact binary, replace whole line)
/// @param data payload(LE):
///             u32 line, u32 phantom_count, then repeat for phantom_count groups:
///             [u32 column, u32 text_len, u8[text_len] text_utf8]
/// @param size payload byte length
EDITOR_API void editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Batch set phantom texts for multiple lines (compact binary, variable length)
/// @param data payload(LE):
///             u32 entry_count,
///             [u32 line, u32 phantom_count,
///              [u32 column, u32 text_len, u8[text_len] text_utf8] x phantom_count] x entry_count
/// @param size payload byte length
EDITOR_API void editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);

#pragma endregion

#pragma region Gutter Icons

/// Set gutter icons for specified line (compact binary, replace whole line)
/// @param data payload(LE):
///             u32 line, u32 icon_count, then repeat for icon_count groups
///             [i32 icon_id]
/// @param size payload byte length
EDITOR_API void editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Batch set gutter icons for multiple lines (compact binary, fixed length)
/// @param data payload(LE):
///             u32 entry_count,
///             [u32 line, u32 icon_count, [i32 icon_id] x icon_count] x entry_count
/// @param size payload byte length
EDITOR_API void editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Set max gutter icon count (affects reserved gutter width)
/// @param count Max icon count (0=no reserved space)
EDITOR_API void editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count);

/// Clear all gutter icons
EDITOR_API void editor_clear_gutter_icons(intptr_t editor_handle);

#pragma endregion

#pragma region Diagnostic Decorations

/// Set diagnostic decoration ranges for specified line (compact binary)
/// @param data payload(LE):
///             u32 line, u32 diag_count, then repeat for diag_count groups
///             [u32 column, u32 length, i32 severity, i32 color]
/// @param size payload byte length
EDITOR_API void editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Batch set diagnostic decorations for multiple lines (compact binary, fixed length)
/// @param data payload(LE):
///             u32 entry_count,
///             [u32 line, u32 diag_count, [u32 column, u32 length, i32 severity, i32 color] x diag_count] x entry_count
/// @param size payload byte length
EDITOR_API void editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Clear all diagnostic decorations
EDITOR_API void editor_clear_diagnostics(intptr_t editor_handle);

#pragma endregion

#pragma region Guide(code structure lines)

/// Set indent guide list (compact binary, global replace)
/// @param data payload(LE):
///             u32 count, then repeat count groups
///             [u32 start_line, u32 start_column, u32 end_line, u32 end_column]
/// @param size payload byte length
EDITOR_API void editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Set bracket branch guide list (compact binary, global replace)
/// @param data payload(LE):
///             u32 count, then repeat count groups:
///             [u32 parent_line, u32 parent_column, u32 end_line, u32 end_column,
///              u32 child_count, then repeat child_count groups: [u32 child_line, u32 child_column]]
/// @param size payload byte length
EDITOR_API void editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Set control-flow back-arrow guide list (compact binary, global replace)
/// @param data payload(LE):
///             u32 count, then repeat count groups
///             [u32 start_line, u32 start_column, u32 end_line, u32 end_column]
/// @param size payload byte length
EDITOR_API void editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Set horizontal separator guide list (compact binary, global replace)
/// @param data payload(LE):
///             u32 count, then repeat count groups
///             [i32 line, i32 style, i32 count, u32 text_end_column]
/// @param size payload byte length
EDITOR_API void editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Clear all code structure lines (indent guides, bracket guides, control-flow arrows, separators)
EDITOR_API void editor_clear_guides(intptr_t editor_handle);

#pragma endregion

#pragma region Bracket Pair Highlight

/// Set bracket pair list (override default (){}[])
/// @param open_chars Open bracket char array (UTF-32)
/// @param close_chars Close bracket char array (UTF-32)
/// @param count Bracket pair count
EDITOR_API void editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count);

/// Externally set exact bracket match result (override built-in char scan)
/// @param open_line open bracket line number(0-based)
/// @param open_col open bracket column number (0-based)
/// @param close_line close bracket line number(0-based)
/// @param close_col close bracket column number (0-based)
EDITOR_API void editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col);

/// Clear externally set bracket match result (fall back to built-in char scan)
EDITOR_API void editor_clear_matched_brackets(intptr_t editor_handle);

#pragma endregion

#pragma region Code Folding

/// Set foldable region list (compact binary)
/// @param data payload(LE):
///             u32 region_count, then repeat for region_count groups
///             [u32 start_line, u32 end_line]
/// @param size payload byte length
EDITOR_API void editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Toggle fold state of specified line
/// @param line Line number(0-based)
/// @return 1=found and toggled, 0=region not found
EDITOR_API int editor_toggle_fold(intptr_t editor_handle, size_t line);

/// Fold region containing specified line
/// @param line Line number(0-based)
/// @return 1=success, 0=not found
EDITOR_API int editor_fold_at(intptr_t editor_handle, size_t line);

/// Unfold region containing specified line
/// @param line Line number(0-based)
/// @return 1=success, 0=not found
EDITOR_API int editor_unfold_at(intptr_t editor_handle, size_t line);

/// Fold all regions
EDITOR_API void editor_fold_all(intptr_t editor_handle);

/// Unfold all regions
EDITOR_API void editor_unfold_all(intptr_t editor_handle);

/// Check whether specified line is visible (not hidden by folding)
/// @param line Line number(0-based)
/// @return 1=visible, 0=hidden
EDITOR_API int editor_is_line_visible(intptr_t editor_handle, size_t line);

#pragma endregion

#pragma region Clear Operations

/// Clear all highlight spans
EDITOR_API void editor_clear_highlights(intptr_t editor_handle);

/// Clear all inlay hints
EDITOR_API void editor_clear_inlay_hints(intptr_t editor_handle);

/// Clear all phantom texts
EDITOR_API void editor_clear_phantom_texts(intptr_t editor_handle);

/// Clear all decoration data
EDITOR_API void editor_clear_all_decorations(intptr_t editor_handle);

#pragma endregion

#pragma region Linked Editing (LinkedEditing)

/// Insert VSCode snippet template and enter linked editing mode (convenience API)
/// @param snippet_template VSCode snippet template (UTF8)
/// @return TextEditResult binary payload, returns NULL if there is no change
EDITOR_API const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);

/// Start linked editing mode with generic LinkedEditingModel (compact binary)
/// @param data payload(LE):
///             u32 group_count, u32 range_count, u32 string_blob_size
///             group_count groups: [u32 index, u32 default_text_offset, u32 default_text_len]
///             range_count groups: [u32 group_ordinal, u32 start_line, u32 start_col, u32 end_line, u32 end_col]
///             UTF-8 string blob(default_text_offset=0xFFFFFFFF means null)
/// @param size payload byte length
EDITOR_API void editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size);

/// Whether linked editing mode is active
/// @return 1=yes, 0=no
EDITOR_API int editor_is_in_linked_editing(intptr_t editor_handle);

/// Linked editing: jump to next tab stop
/// @return 1=jumped successfully, 0=already at end (session ends automatically)
EDITOR_API int editor_linked_editing_next(intptr_t editor_handle);

/// Linked editing: jump to previous tab stop
/// @return 1=jumped successfully, 0=already at first
EDITOR_API int editor_linked_editing_prev(intptr_t editor_handle);

/// Cancel linked editing mode
EDITOR_API void editor_cancel_linked_editing(intptr_t editor_handle);

#pragma endregion

#pragma region Utilities/Memory Management

/// Free string memory allocated on C++ side
/// @param string_ptr String pointer
EDITOR_API void free_u16_string(intptr_t string_ptr);

/// Free binary memory returned by C++ side
/// Applies to all APIs that return const uint8_t* + out_size.
/// Platform must call once after reading payload; NULL/0 can be safely ignored.
/// @param data_ptr Start address of binary payload
EDITOR_API void free_binary_data(intptr_t data_ptr);

#ifdef _WIN32
/// Set crash log output for DLL calls, Windows only
EDITOR_API void init_unhandled_exception_handler();
#endif

#pragma endregion

}

#endif //SWEETEDITOR_C_API_H
