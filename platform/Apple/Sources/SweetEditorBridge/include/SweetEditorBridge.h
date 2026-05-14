//
// SweetEditorBridge.h
// Pure C bridge header for Swift interop (independent from c_api.h)
//
// Each platform maintains its own FFI declarations, mirroring the
// extern "C" functions in c_api.h without requiring C++ headers.
//

#ifndef SWEETEDITOR_BRIDGE_H
#define SWEETEDITOR_BRIDGE_H

#include <stdint.h>
#include <stddef.h>

// Corresponds to char16_t (U16Char) on non-Windows platforms
typedef uint16_t SEU16Char;

// ===================== Text measurer callbacks =====================

/// Text measurement callback set passed when creating EditorCore.
typedef struct {
    float (*measure_text_width)(const SEU16Char* text, int32_t font_style);
    float (*measure_inlay_hint_width)(const SEU16Char* text);
    float (*measure_icon_width)(int32_t icon_id);
    void  (*get_font_metrics)(float* arr, size_t length);
} se_text_measurer_t;

// ===================== Document API =====================

intptr_t create_document_from_utf16(const SEU16Char* text);
intptr_t create_document_from_file(const char* path);
void     free_document(intptr_t document_handle);
char*          get_document_utf8(intptr_t document_handle);
SEU16Char*     get_document_utf16(intptr_t document_handle);
size_t          get_document_line_count(intptr_t document_handle);
char*          get_document_line_utf8(intptr_t document_handle, size_t line);
SEU16Char*     get_document_line_utf16(intptr_t document_handle, size_t line);

// ===================== Editor API =====================

intptr_t create_editor(se_text_measurer_t measurer,
                       const uint8_t* options_data,
                       size_t options_size);
void free_editor(intptr_t editor_handle);

void set_editor_viewport(intptr_t editor_handle, int16_t width, int16_t height);
void set_editor_document(intptr_t editor_handle, intptr_t document_handle);

const uint8_t* handle_editor_gesture_event(intptr_t editor_handle,
                                           uint8_t type,
                                           uint8_t pointer_count,
                                           float* points,
                                           size_t* out_size);

const uint8_t* handle_editor_gesture_event_ex(intptr_t editor_handle,
                                              uint8_t type,
                                              uint8_t pointer_count,
                                              float* points,
                                              uint8_t modifiers,
                                              float wheel_delta_x,
                                              float wheel_delta_y,
                                              float direct_scale,
                                              size_t* out_size);

void editor_on_font_metrics_changed(intptr_t editor_handle);

const uint8_t* build_editor_render_model(intptr_t editor_handle, size_t* out_size);
const uint8_t* get_layout_metrics(intptr_t editor_handle, size_t* out_size);

// ===================== Keyboard Input API =====================

const uint8_t* handle_editor_key_event(intptr_t editor_handle,
                                       uint16_t key_code,
                                       const char* text,
                                       uint8_t modifiers,
                                       size_t* out_size);

const uint8_t* editor_insert_text(intptr_t editor_handle, const char* text, size_t* out_size);

const uint8_t* editor_replace_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    const char* text,
    size_t* out_size);

const uint8_t* editor_delete_text(intptr_t editor_handle,
    size_t start_line, size_t start_column,
    size_t end_line, size_t end_column,
    size_t* out_size);

const char* editor_get_selected_text(intptr_t editor_handle);

// ===================== Line Operations API =====================

const uint8_t* editor_move_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_move_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_up(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_copy_line_down(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_delete_line(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_above(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_insert_line_below(intptr_t editor_handle, size_t* out_size);

// ===================== IME Composition API =====================

const uint8_t* editor_ime_update_preedit(intptr_t editor_handle,
    const char* text,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_set_composing_text_selection(intptr_t editor_handle,
    const char* text,
    size_t selection_start_offset,
    size_t selection_end_offset,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_commit_text(intptr_t editor_handle,
    const char* text,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_finish_preedit(intptr_t editor_handle,
    size_t* out_size);
const uint8_t* editor_ime_cancel_preedit(intptr_t editor_handle,
    size_t* out_size);
const uint8_t* editor_ime_mark_document_range(intptr_t editor_handle,
    size_t start_line,
    size_t start_column,
    size_t end_line,
    size_t end_column,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_mark_document_range_by_offset(intptr_t editor_handle,
    size_t start_offset,
    size_t end_offset,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_update_input_state_text(intptr_t editor_handle,
    uint64_t context_id,
    int32_t document_start_offset,
    const char* text,
    int32_t selection_start_offset,
    int32_t selection_end_offset,
    int32_t composing_start_offset,
    int32_t composing_end_offset,
    int script_hint,
    size_t* out_size);
const uint8_t* editor_ime_update_input_state_selection(intptr_t editor_handle,
    uint64_t context_id,
    int32_t document_start_offset,
    int32_t selection_start_offset,
    int32_t selection_end_offset,
    size_t* out_size);
const uint8_t* editor_ime_replace_input_state_text(intptr_t editor_handle,
    uint64_t context_id,
    int32_t document_start_offset,
    size_t start_offset,
    size_t end_offset,
    const char* text,
    int cursor_offset,
    int script_hint,
    size_t* out_size);
int  editor_is_composing(intptr_t editor_handle);

// ===================== ReadOnly API =====================

void editor_set_read_only(intptr_t editor_handle, int read_only);
int  editor_is_read_only(intptr_t editor_handle);

// ===================== AutoIndent API =====================

void editor_set_auto_indent_mode(intptr_t editor_handle, int mode);
int  editor_get_auto_indent_mode(intptr_t editor_handle);
void editor_set_backspace_unindent(intptr_t editor_handle, int enabled);
void editor_set_insert_spaces(intptr_t editor_handle, int enabled);

// ===================== Position Rect API =====================

void editor_get_position_rect(intptr_t editor_handle,
    size_t line, size_t column,
    float* out_x, float* out_y, float* out_height);
void editor_get_cursor_rect(intptr_t editor_handle,
    float* out_x, float* out_y, float* out_height);

// ===================== Navigation API =====================

void editor_set_scrollbar_config(intptr_t editor_handle,
                                 float thickness, float min_thumb, float thumb_hit_padding,
                                 int mode, int thumb_draggable, int track_tap_mode,
                                 int fade_delay_ms, int fade_duration_ms);
void editor_scroll_to_line(intptr_t editor_handle, size_t line, uint8_t behavior);
void editor_goto_position(intptr_t editor_handle, size_t line, size_t column);
void editor_set_scroll(intptr_t editor_handle, float scroll_x, float scroll_y);
const uint8_t* editor_get_scroll_metrics(intptr_t editor_handle, size_t* out_size);

// ===================== Selection API =====================

void editor_select_all(intptr_t editor_handle);
void editor_set_selection(intptr_t editor_handle,
                          size_t start_line, size_t start_column,
                          size_t end_line, size_t end_column);
int  editor_get_selection(intptr_t editor_handle,
                          size_t* out_start_line, size_t* out_start_column,
                          size_t* out_end_line, size_t* out_end_column);
void editor_get_cursor_position(intptr_t editor_handle, size_t* out_line, size_t* out_column);

void editor_get_word_range_at_cursor(intptr_t editor_handle, size_t* out_start_line, size_t* out_start_column, size_t* out_end_line, size_t* out_end_column);
const char* editor_get_word_at_cursor(intptr_t editor_handle);

// ===================== Gutter Icon API =====================

void editor_clear_gutter_icons(intptr_t editor_handle);
void editor_set_max_gutter_icons(intptr_t editor_handle, uint32_t count);
void editor_set_fold_arrow_mode(intptr_t editor_handle, int mode);
void editor_set_wrap_mode(intptr_t editor_handle, int mode);
void editor_set_tab_size(intptr_t editor_handle, int tab_size);
void editor_set_scale(intptr_t editor_handle, float scale);
void editor_set_line_spacing(intptr_t editor_handle, float add, float mult);
void editor_set_content_start_padding(intptr_t editor_handle, float padding);
void editor_set_show_split_line(intptr_t editor_handle, int show);
void editor_set_current_line_render_mode(intptr_t editor_handle, int mode);

// ===================== Undo/Redo API =====================

const uint8_t* editor_undo(intptr_t editor_handle, size_t* out_size);
const uint8_t* editor_redo(intptr_t editor_handle, size_t* out_size);
int editor_can_undo(intptr_t editor_handle);
int editor_can_redo(intptr_t editor_handle);

// ===================== Style / Highlight API =====================

void editor_register_text_style(intptr_t editor_handle, uint32_t style_id, int32_t color, int32_t background_color, int32_t font_style);
void editor_register_batch_text_styles(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_spans(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_line_spans(intptr_t editor_handle, size_t line, uint8_t layer);
void editor_clear_highlights(intptr_t editor_handle);
void editor_clear_highlights_layer(intptr_t editor_handle, uint8_t layer);

// ===================== Diagnostic API =====================

void editor_set_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_diagnostics(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_diagnostics(intptr_t editor_handle);

// ===================== Inlay / Phantom API =====================

void editor_set_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_inlay_hints(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_inlay_hints(intptr_t editor_handle);
void editor_set_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_phantom_texts(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_phantom_texts(intptr_t editor_handle);

// ===================== Gutter Icon Batch API =====================

void editor_set_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_gutter_icons(intptr_t editor_handle, const uint8_t* data, size_t size);

// ===================== CodeLens API =====================

void editor_set_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_codelens(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_codelens(intptr_t editor_handle);

// ===================== Link API =====================

void editor_set_line_links(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_batch_line_links(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_links(intptr_t editor_handle);
const char* editor_get_link_target_at(intptr_t editor_handle, size_t line, size_t column);

// ===================== Guide API =====================

void editor_set_indent_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_bracket_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_flow_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_set_separator_guides(intptr_t editor_handle, const uint8_t* data, size_t size);
void editor_clear_guides(intptr_t editor_handle);

// ===================== Fold API =====================

void editor_set_fold_regions(intptr_t editor_handle, const uint8_t* data, size_t size);
int  editor_toggle_fold(intptr_t editor_handle, size_t line);
int  editor_fold_at(intptr_t editor_handle, size_t line);
int  editor_unfold_at(intptr_t editor_handle, size_t line);
void editor_fold_all(intptr_t editor_handle);
void editor_unfold_all(intptr_t editor_handle);
int  editor_is_line_visible(intptr_t editor_handle, size_t line);
void editor_get_visible_line_range(intptr_t editor_handle, int32_t* out_start_line, int32_t* out_end_line);

// ===================== Decorations Clear API =====================

void editor_clear_all_decorations(intptr_t editor_handle);

// ===================== LinkedEditing API =====================

const uint8_t* editor_insert_snippet(intptr_t editor_handle, const char* snippet_template, size_t* out_size);
void     editor_start_linked_editing(intptr_t editor_handle, const uint8_t* data, size_t size);
int      editor_is_in_linked_editing(intptr_t editor_handle);
int      editor_linked_editing_next(intptr_t editor_handle);
int      editor_linked_editing_prev(intptr_t editor_handle);
void     editor_cancel_linked_editing(intptr_t editor_handle);

// ===================== Bracket Highlight =====================

void editor_set_bracket_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count);
void editor_set_auto_closing_pairs(intptr_t editor_handle, const uint32_t* open_chars, const uint32_t* close_chars, size_t count);
void editor_set_matched_brackets(intptr_t editor_handle, size_t open_line, size_t open_col, size_t close_line, size_t close_col);
void editor_clear_matched_brackets(intptr_t editor_handle);

// ===================== Memory Management =====================

void free_u8_string(intptr_t string_ptr);
void free_u16_string(intptr_t string_ptr);
void free_binary_data(intptr_t data_ptr);

#endif // SWEETEDITOR_BRIDGE_H
